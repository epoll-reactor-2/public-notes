#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <linux/perf_event.h>
#include <sys/syscall.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <bpf/libbpf.h>
#include <string.h>

static long perf_event_open(struct perf_event_attr *hw_event, pid_t pid,
			    int cpu, int group_fd, unsigned long flags)
{
	return syscall(__NR_perf_event_open, hw_event, pid, cpu, group_fd, flags);
}

int main()
{
	struct bpf_object *obj = bpf_object__open_file("perf.bpf.o", NULL);
	if (!obj) {
		perror("bpf_object__open_file");
		return 1;
	}
	
	if (bpf_object__load(obj)) {
		perror("bpf_object__load");
		return 1;
	}

	struct bpf_program *prog = bpf_object__find_program_by_name(obj, "on_cpu_cycles");
	if (!prog) {
		fprintf(stderr, "Program not found\n");
		return 1;
	}

	int prog_fd = bpf_program__fd(prog);

	// Triggered every N CPU cycles, as counted by a hardware performance counter.
	struct perf_event_attr attr = {
		.type		= PERF_TYPE_HARDWARE,
		.config		= PERF_COUNT_HW_CPU_CYCLES,
		.sample_period	= 100000,
		.size		= sizeof(struct perf_event_attr),
		.disabled	= 0,
		.exclude_kernel	= 0,
		.exclude_hv	= 0,
	};
	
	// Attach to CPU 0
	int perf_fd = perf_event_open(&attr, -1 /* pid */, 0 /* cpu */, -1, 0);
	if (perf_fd < 0) {
		perror("perf_event_open");
		return 1;
	}
	
	if (ioctl(perf_fd, PERF_EVENT_IOC_ENABLE, 0)) {
		perror("PERF_EVENT_IOC_ENABLE");
		return 1;
	}
	
	if (ioctl(perf_fd, PERF_EVENT_IOC_SET_BPF, prog_fd)) {
		perror("PERF_EVENT_IOC_SET_BPF");
		return 1;
	}
	
	printf("Perf event and BPF program attached. Press Ctrl+C to exit.\n");
	
	while (1) {
		sleep(1);
	}
	
	return 0;
}

