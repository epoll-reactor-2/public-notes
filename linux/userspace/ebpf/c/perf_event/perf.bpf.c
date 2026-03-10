#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

// Just print message per perf_event
SEC("perf_event")
int on_cpu_cycles(struct bpf_perf_event_data *ctx)
{
	bpf_printk("CPU cycle perf event triggered");
	return 0;
}

char LICENSE[] SEC("license") = "GPL";
