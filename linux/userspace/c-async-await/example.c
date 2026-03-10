// https://github.com/xhawk18/s_task.git

#include <stdio.h>
#include "s_task.h"

static void *stack_main[64 * 1024];
static void *stack_0[64 * 1024];
static void *stack_1[64 * 1024];

/* Channels there comes from general async/await concept.
 * Implemented in Rust in the same way to interchange data
 * between threads without manual synchronization with some
 * primitives. */
s_chan_declare(chan_main_to_sub, int, 1);
s_chan_declare(chan_sub_to_main, int, 1);

static void task_sub(__async__, void *arg)
{
	(void) arg;
	int received = 0;

	for (int i = 0; i < 10; ++i) {
		printf("%s: iteration %d\n", __FUNCTION__, i);
		s_chan_get(__await__, chan_main_to_sub, &received);
		int response = received * 1000;
		s_chan_put(__await__, chan_sub_to_main, &response);
		s_task_msleep(__await__, 250);
		s_task_yield(__await__);
	}
}

static void task_main(__async__, void *arg)
{
	(void) arg;

	s_chan_init(chan_main_to_sub, int, 1);
	s_chan_init(chan_sub_to_main, int, 1);

	s_task_create(stack_0, sizeof (stack_0), task_sub, 0);

	for (int i = 0; i < 10; ++i) {
		printf("%s: sending %d to sub", __FUNCTION__, i);
		s_chan_put(__await__, chan_main_to_sub, &i);
		int reply = 0;
		s_chan_get(__await__, chan_sub_to_main, &reply);
		printf("%s: received %d from sub", __FUNCTION__, reply);
		s_task_msleep(__await__, 300);
		s_task_yield(__await__);
	}
}

int main()
{
	s_task_init_system();
	s_task_create(stack_main, sizeof (stack_main), task_main, 0);
	s_task_join(__await__, stack_main);
}
