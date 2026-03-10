/* sched.c - CFS-like scheduler. */

/* Since we have nowhere to get kernel-like data from,
 * we simulate incrementing vruntime with random values.
 * Thus task with minimal runtime is selected to run.
 *
 * Eventually weight for tasks can be added to control
 * task priority. */

/* Possible applications:
 *
 * 1. fibers / green threads - When userspace-level
 *    multitasking is desired, without huge amount
 *    of kernel calls or synchronization routines.
 *    Usable in embedded systems without scheduling
 *    policy, only with timer interrupts.
 *
 * 2. Implementation of the concept based on limited
 *    resources per user. Applicable in games (higher player
 *    rating allows to consume more in-game resources),
 *    client-server applications (restrict CPU access per
 *    users priority/subscription).
 *
 * 3. Resource consumption priority in blockchain-based
 *    environments like EVM/WASM/custom one. Based on
 *    account balance or stake balance, users can have more
 *    or less vruntime per call.
 */

#include <assert.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <ucontext.h>
#include <unistd.h>
#include "rb/rb.h"

#define SCHED_STACK_SIZE	(64 * 1024)
#define SCHED_MAX_TASKS		32
#define SCHED_TIME_SLICE_MS	500

struct sched_task {
	ucontext_t	context;
	uint8_t		*stack;
	int		id;
	int		finished;
	uint64_t	vruntime;
	rbnode		*rb_node;
};

static struct sched_task sched_tasks[SCHED_MAX_TASKS] = {0};
static int sched_tasks_count = 0;
static ucontext_t sched_context = {0};
static rbtree *sched_rb_tree = NULL;

void sched_rb_print(void *data)
{
	struct sched_task *task = data;

	printf("#%d v=%lu", task->id, task->vruntime);
}

void sched_task(void (*f)(), int id)
{
	struct sched_task *task = &sched_tasks[sched_tasks_count++];
	task->stack = calloc(1, SCHED_STACK_SIZE);
	task->id = id;
	task->finished = 0;

	getcontext(&task->context);
	task->context.uc_stack.ss_sp = task->stack;
	task->context.uc_stack.ss_size = SCHED_STACK_SIZE;
	task->context.uc_link = &sched_context;
	makecontext(&task->context, f, 1, id);

	rb_insert(sched_rb_tree, task);
}

/* This function responsible for scheduling according
 * to its schedule policy. Since we have no reasonable
 * metrics to esimate vruntime, just advance it by random
 * number. The scheduler will pick leftmost element and
 * rebalance the tree. Thus, tree will rotate in the left
 * direction step-by-step.
 *
 * Schedule task with minimum vruntime value. */
void schedule(int sig)
{
	rbnode *min = sched_rb_tree->min;
	assert(min);
	struct sched_task *next = (struct sched_task *) min->data;

	if (next->finished)
		return;

	rb_delete(sched_rb_tree, min, 0);
	next->vruntime += rand() % 1000;
	rb_insert(sched_rb_tree, next);

	/* Clear the screen for better visualisation. */
	printf("\033[2J\033[H");
	rb_print(sched_rb_tree, sched_rb_print);

	struct sched_task *curr = sched_rb_tree->min->data;

	if (!next->finished)
		swapcontext(&next->context, &curr->context);
}

void sched_example_task(int idx)
{
	for (int i = 0; i < 100000; ++i) {
		printf("Task #%d ticked %d times\n", idx, i++);
		usleep(SCHED_TIME_SLICE_MS * 1000);
	}

	sched_tasks[idx - 1].finished = 1;
	while (1)
		;
}

int rb_vruntime_compare(const void *lhs, const void *rhs)
{
	const struct sched_task *l = lhs;
	const struct sched_task *r = rhs;

	if (l->vruntime < r->vruntime)
		return -1;

	if (l->vruntime > r->vruntime)
		return 1;

	return 0;
}

void rb_vruntime_destroy(void *p)
{

}

int main()
{
	sched_rb_tree = rb_create(rb_vruntime_compare, rb_vruntime_destroy);

	for (int i = 0; i < SCHED_MAX_TASKS; ++i)
		sched_task(sched_example_task, i);

	struct sigaction sa = {0};
	sa.sa_handler = schedule;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_NODEFER;
	/* Trigger re-schedule on SIGALRM. */
	sigaction(SIGALRM, &sa, NULL);

	struct itimerval sched_timer = {
		.it_interval.tv_sec	= 0,
		.it_interval.tv_usec	= SCHED_TIME_SLICE_MS * 1000,
		.it_value		= sched_timer.it_interval
	};
	/* Interval timer delivers SIGALRM to the process each tv_*sec. */
	setitimer(ITIMER_REAL, &sched_timer, NULL);
	/* Switch to first task. Then context will be switched during schedule. */

	rbnode *min = sched_rb_tree->min;
	if (!min)
		return -1;

	struct sched_task *first = min->data;

	setcontext(&first->context);
}
