#include "thread-pool.h"
#include <pthread.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static bool thread_pool_has_work(thpool_t *pool)
{
    for (int i = 0; i < WORKQUEUE_MAX_SIZE; ++i)
        if (atomic_load_explicit(&pool->workqueue[i].scheduled, memory_order_acquire) ||
            atomic_load_explicit(&pool->workqueue[i].busy, memory_order_acquire))
            return true;

    return false;
}

/* This task is allocated for each worker thread.
 * Then each worker starts to "poll" workqueue
 * on tasks that are ready for execution. If function
 * pointer is set, we are ready to run it.
 *
 * When nothing to do, function periodically checks
 * for incoming work and stays in idle mode.
 *
 * NOTE: There is ONE queue for all the threads.
 * NOTE: Each thread scanning this queue for pending
 *       task and takes first available one. */
static void *workqueue_task(void *arg)
{
    thpool_t *pool = arg;

    for (;;) {
        pthread_mutex_lock(&pool->queue_lock);

        while (!atomic_load_explicit(&pool->finished, memory_order_acquire) &&
               !thread_pool_has_work(pool))
            pthread_cond_wait(&pool->queue_condvar, &pool->queue_lock);

        if (atomic_load_explicit(&pool->finished, memory_order_acquire) && !thread_pool_has_work(pool)) {
            pthread_mutex_unlock(&pool->queue_lock);
            break;
        }

        /* Search for a scheduled slot and claim it by setting busy=1 */
        queue_entry_t *candidate = NULL;
        for (int i = 0; i < WORKQUEUE_MAX_SIZE; ++i) {
            queue_entry_t *slot = &pool->workqueue[i];
            if (atomic_load_explicit(&slot->scheduled, memory_order_acquire)) {
                bool expected_busy = false;
                if (atomic_compare_exchange_weak_explicit(
                        &slot->busy, &expected_busy, true,
                        memory_order_acq_rel, memory_order_relaxed)) {
                    candidate = slot;
                    break;
                }
            }
        }

        /* If no slot claimed (rare due to races / spurious wakeups), loop again */
        if (!candidate) {
            pthread_mutex_unlock(&pool->queue_lock);
            continue;
        }

        /* Take the fn and arg while still holding mutex to maintain consistency */
        thpool_fn task = atomic_exchange_explicit(&candidate->fn, NULL, memory_order_acq_rel);
        void *task_arg = atomic_exchange_explicit(&candidate->fn_arg, NULL, memory_order_acq_rel);

        /* Release the mutex while executing user task */
        pthread_mutex_unlock(&pool->queue_lock);

        /* Execute the task (if for some reason fn was NULL, just skip) */
        if (/* likely */ task)
            task(task_arg);

        /* After execution, mark slot free and notify waiters/submitters */
        pthread_mutex_lock(&pool->queue_lock);
        atomic_store_explicit(&candidate->scheduled, false, memory_order_release);
        atomic_store_explicit(&candidate->busy, false, memory_order_release);

        /* Notify any threads waiting for a free slot or for all work to finish */
        pthread_cond_broadcast(&pool->queue_condvar);
        pthread_mutex_unlock(&pool->queue_lock);
    }

    return NULL;
}

void thread_pool_init(thpool_t *pool)
{
    atomic_store_explicit(&pool->finished, false, memory_order_relaxed);
    pthread_mutex_init(&pool->queue_lock, NULL);
    pthread_cond_init(&pool->queue_condvar, NULL);

    for (int i = 0; i < WORKQUEUE_MAX_SIZE; ++i) {
        atomic_store_explicit(&pool->workqueue[i].fn, NULL, memory_order_relaxed);
        atomic_store_explicit(&pool->workqueue[i].fn_arg, NULL, memory_order_relaxed);
        atomic_store_explicit(&pool->workqueue[i].scheduled, false, memory_order_relaxed);
        atomic_store_explicit(&pool->workqueue[i].busy, false, memory_order_relaxed);
    }

    for (int i = 0; i < THPOOL_MAX_THREADS; ++i) {
        if (pthread_create(&pool->threads[i], NULL, workqueue_task, pool) != 0) {
            perror("pthread_create");
            atomic_store_explicit(&pool->finished, true, memory_order_release);
            pthread_cond_broadcast(&pool->queue_condvar);
            for (int j = 0; j < i; ++j)
                pthread_join(pool->threads[j], NULL);
            return;
        }
    }
}

void thread_pool_wait(thpool_t *pool)
{
    pthread_mutex_lock(&pool->queue_lock);
    while (thread_pool_has_work(pool))
        pthread_cond_wait(&pool->queue_condvar, &pool->queue_lock);

    atomic_store_explicit(&pool->finished, true, memory_order_release);
    pthread_cond_broadcast(&pool->queue_condvar);
    pthread_mutex_unlock(&pool->queue_lock);

    for (int i = 0; i < THPOOL_MAX_THREADS; ++i)
        pthread_join(pool->threads[i], NULL);
}

future_t thread_pool_submit(thpool_t *pool, thpool_fn fn, void *arg)
{
    /* clang-format off */
    future_t f = {
        .scheduled = NULL,
        .busy      = NULL
    };
    /* clang-format on */

    pthread_mutex_lock(&pool->queue_lock);

    for (;;) {
        /* If pool is finished, return empty future immediately */
        if (atomic_load_explicit(&pool->finished, memory_order_acquire)) {
            pthread_mutex_unlock(&pool->queue_lock);
            return f;
        }

        /* Find a free slot */
        int found = -1;
        for (int i = 0; i < WORKQUEUE_MAX_SIZE; ++i) {
            queue_entry_t *slot = &pool->workqueue[i];
            if (!atomic_load_explicit(&slot->scheduled, memory_order_acquire) &&
                !atomic_load_explicit(&slot->busy, memory_order_acquire)) {
                found = i;
                break;
            }
        }

        if (found >= 0) {
            queue_entry_t *slot = &pool->workqueue[found];
            atomic_store_explicit(&slot->fn_arg, arg, memory_order_release);
            atomic_store_explicit(&slot->fn, fn, memory_order_release);
            atomic_store_explicit(&slot->scheduled, true, memory_order_release);

            /* Wake a worker */
            pthread_cond_signal(&pool->queue_condvar);

            f.scheduled = &slot->scheduled;
            f.busy = &slot->busy;
            pthread_mutex_unlock(&pool->queue_lock);
            return f;
        }

        /* No free slot -> wait until a slot frees or pool finishes */
        while (!atomic_load_explicit(&pool->finished, memory_order_acquire) && !(
               /* Re-check for any free slot */
               ({
                   bool any_free = false;
                   for (int i = 0; i < WORKQUEUE_MAX_SIZE; ++i) {
                       queue_entry_t *s = &pool->workqueue[i];
                       if (!atomic_load_explicit(&s->scheduled, memory_order_acquire) &&
                           !atomic_load_explicit(&s->busy, memory_order_acquire)) {
                           any_free = true;
                           break;
                       }
                   }
                   any_free;
               }))) {
            pthread_cond_wait(&pool->queue_condvar, &pool->queue_lock);
        }

        /* Loop will re-check finished or search for a free slot again */
    }

    pthread_mutex_unlock(&pool->queue_lock);
    return f;
}

void thread_pool_wait_task(future_t *task)
{
    while (atomic_load(task->scheduled) ||
           atomic_load(task->busy))
        usleep(333);
}

void thread_pool_destroy(thpool_t *pool)
{
    atomic_store(&pool->finished, 1);

    memset(&pool->workqueue, 0, sizeof (pool->workqueue));
    pthread_cond_destroy(&pool->queue_condvar);
    pthread_mutex_destroy(&pool->queue_lock);
}


void thpool_task(void *arg)
{
    // int total = 10;

    // printf("Thread %lu\n", pthread_self());

    // while (--total) {
    //     usleep(100);
    // }
}

int main()
{
    thpool_t thpool = {0};
    thread_pool_init(&thpool);

    for (int i = 0; i < 20; ++i) {
        printf("Submit: %d\n", i);
        thread_pool_submit(&thpool, thpool_task, (void *) (long) i);
    }

    usleep(100);

    for (int i = 0; i < 10; ++i)
        thread_pool_submit(&thpool, thpool_task, (void *) (long) i);

    thread_pool_wait(&thpool);
    thread_pool_destroy(&thpool);
}
