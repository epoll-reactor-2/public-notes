#include <linux/kthread.h>
#include <linux/sched.h>
#include <linux/sched/task.h> // for set_cpus_allowed_ptr()
#include <linux/module.h>
#include <linux/delay.h>
#include <linux/init.h>

static struct task_struct *global_task;

static int thread_worker(void *data)
{
	while (!kthread_should_stop()) {
		pr_info("Thread running on CPU %d with nice %d",
			smp_processor_id(), task_nice(current));
		usleep_range(100000, 100001);
	}

	return 0;
}

__init static int study_kthread_init(void)
{
	global_task = kthread_run(thread_worker, NULL, "study_thread");
	if (IS_ERR(global_task)) {
		pr_err("Failed to create thread");
		return PTR_ERR(global_task);
	}

	set_user_nice(global_task, 5);

	pr_info("Thread module loaded");

	return 0;
}

__exit static void study_kthread_exit(void)
{
	if (global_task)
		kthread_stop(global_task);
	pr_info("Thread module unloaded");
}

module_init(study_kthread_init);
module_exit(study_kthread_exit);

MODULE_LICENSE("GPL");
