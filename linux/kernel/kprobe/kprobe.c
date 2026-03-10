// https://docs.kernel.org/trace/kprobes.html
//
// This code illustrates how to implement simple
// kprobe-based profiler. It counts openat2() calls
// from userspace and prints these calls along with
// simple statistics.
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/uaccess.h>
#include <linux/spinlock.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Korenchuk");

static struct kprobe probe;
static unsigned long call_count;
static DEFINE_SPINLOCK(probe_lock);

__always_inline static void kprobe_handle_arguments(struct pt_regs *regs)
{
	char fname[512];
	__user const char *fname_ptr;

#if defined(__x86_64__)
	fname_ptr = (__user const char *) regs->si;
#elif defined(__aarch64__)
	fname_ptr = (__user const char *) regs->regs[1];
#else
	fname_ptr = NULL;
#endif
	if (likely(fname_ptr)) {
		if (strncpy_from_user(fname, fname_ptr, sizeof (fname)) > 0) {
			pr_info("kprobe: do_sys_openat2 called, filename: %s\n", fname);
		} else {
			pr_info("kprobe: do_sys_openat2 failed to fetch filename from userspace");
		}
	}
}

__always_inline static void kprobe_collect_stat(void)
{
	unsigned long flags;
	spin_lock_irqsave(&probe_lock, flags);

	++call_count;
	if (call_count % 100 == 0) {
		pr_info("[kprobe-profiler] open() called %lu times\n", call_count);
	}

	spin_unlock_irqrestore(&probe_lock, flags);
}

// Pre-handler: runs before probed instruction
static int kprobe_handle_pre(struct kprobe *p, struct pt_regs *regs)
{
	kprobe_handle_arguments(regs);
	kprobe_collect_stat();
	return 0;
}

__init static int study_kprobe_init(void)
{
	// Specify symbol name we want to attach to.
	probe.symbol_name = "do_sys_openat2";
	probe.pre_handler = kprobe_handle_pre;
	
	if (register_kprobe(&probe) < 0) {
		pr_err("kprobe registration failed\n");
		return -1;
	}
	
	pr_info("kprobe registered at %s\n", probe.symbol_name);
	return 0;
}

__exit static void study_kprobe_exit(void)
{
	unregister_kprobe(&probe);
	pr_info("kprobe unregistered\n");
}

module_init(study_kprobe_init)
module_exit(study_kprobe_exit)
