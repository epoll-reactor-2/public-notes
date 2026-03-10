#ifndef THREAD_POOL_H
#define THREAD_POOL_H

#include <pthread.h>
#include <stdatomic.h>

/* Assume const threads and queue size. */
#define THPOOL_MAX_THREADS 32
#define WORKQUEUE_MAX_SIZE 1024

typedef void (*thpool_fn)(void *);

typedef struct {
  _Atomic(thpool_fn) fn;
  _Atomic(void *) fn_arg;
  atomic_bool scheduled;
  atomic_bool busy;
} queue_entry_t;

typedef struct {
  atomic_bool *scheduled; //< Means that task was enqueued but not executed yet.
  atomic_bool *busy;      //< Means that task is currently running.
} future_t;

typedef struct {
  pthread_t threads[THPOOL_MAX_THREADS];
  queue_entry_t workqueue[WORKQUEUE_MAX_SIZE];
  atomic_bool finished;
  pthread_mutex_t queue_lock;
  pthread_cond_t queue_condvar;
} thpool_t;

/** Allocate \c THPOOL_MAX_THREADS workers and start to accept
 *  new events, submitted with \c thread_pool_submit.
 */
void thread_pool_init(thpool_t *pool);

/** Wait until each task in the workqueue will finish execution.
 */
void thread_pool_wait(thpool_t *pool);

/** Submit task for the execution.
 *
 *  \return Future: busy.
 */
future_t thread_pool_submit(thpool_t *pool, thpool_fn fn, void *arg);

/** Wait for specific task without blocking whole thread pool.
 *
 *  Can be used in case of nested tasks allocation.
 */
void thread_pool_wait_task(future_t *task);

/** Interrupt all executed currently tasks and
 *  deinitialize threads along with workqueue.
 */
void thread_pool_destroy(thpool_t *pool);

#endif /* THREAD_POOL_H */
