#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

int counter = 0;

SEC("xdp")
int hello(void *ctx)
{
	bpf_printk("Hello world %d", counter++);
	// Fun fact: XDP_DROP will disable internet connection
	// on selected interface.
	return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
