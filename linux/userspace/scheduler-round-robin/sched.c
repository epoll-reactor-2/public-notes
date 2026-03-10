/* sched.c - Basic Round-robin scheduler. */

/* Round-robin scheduling policy is the simplest one.
 *
 * Here how it works:
 * Given tasks list = [ 0, 1, 2, 3 ] and time slice = 50ms
 *
 * Time
 * |--------|--------|--------|--------|--------|--------|---->
 * | task 0 | task 1 | task 2 | task 3 | task 0 | task 1 | ...
 * |        |        |        |        |        |        |
 * |  50ms  |  50ms  |  50ms  |  50ms  |  50ms  |  50ms  |
 * |--------|--------|--------|--------|--------|--------|---->
 */

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <ucontext.h>
#include <unistd.h>

#define SCHED_STACK_SIZE	(64 * 1024)
#define SCHED_MAX_TASKS		4
#define SCHED_TIME_SLICE_MS	50

struct sched_task {
	ucontext_t	context;
	uint8_t		*stack;
	int		id;
	int		finished;
};

static struct sched_task sched_tasks[SCHED_MAX_TASKS] = {0};
static int sched_current_task = 0;
static int sched_tasks_count = 0;
static ucontext_t sched_context = {0};
static struct sigaction sched_sigaction = {0};
static struct itimerval sched_timer = {0};

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
	makecontext(&task->context, f, 0);
}

/* This function responsible for scheduling according
 * to its schedule policy.
 *
 * Tasks can be scheduled in different ways using
 * different metrics such as static or dynamic (
 * computed from some process properties like user interactions)
 * priority. */
void schedule(int sig)
{
	int prev = sched_current_task;

	do {
		sched_current_task = (sched_current_task + 1) % sched_tasks_count;
	} while (sched_tasks[sched_current_task].finished);

	if (!sched_tasks[prev].finished)
		swapcontext(
			&sched_tasks[prev].context,
			&sched_tasks[sched_current_task].context
		);
}

#define __define_example_task(idx) \
void sched_example_task_ ## idx() \
{ \
	for (int i = 0; i < 100000; ++i) { \
		printf("sched: task %d tick %d\n", idx, i++); \
		usleep(20000); \
	} \
 \
	sched_tasks[idx - 1].finished = 1; \
	while (1) \
		; \
}

__define_example_task(1)
__define_example_task(2)
__define_example_task(3)
__define_example_task(4)

int main()
{
	sched_task(sched_example_task_1, 0);
	sched_task(sched_example_task_2, 1);
	sched_task(sched_example_task_3, 2);
	sched_task(sched_example_task_4, 3);

	sched_sigaction.sa_handler = schedule;
	sigemptyset(&sched_sigaction.sa_mask);
	sched_sigaction.sa_flags = SA_NODEFER;
	/* Trigger re-schedule on SIGALRM. */
	sigaction(SIGALRM, &sched_sigaction, NULL);

	sched_timer.it_interval.tv_sec = 0;
	sched_timer.it_interval.tv_usec = SCHED_TIME_SLICE_MS * 1000;
	sched_timer.it_value = sched_timer.it_interval;
	/* Interval timer delivers SIGALRM to the process each tv_*sec. */
	setitimer(ITIMER_REAL, &sched_timer, NULL);
	/* Switch to first task. Then context will be switched during schedule. */
	setcontext(&sched_tasks[0].context);
}
