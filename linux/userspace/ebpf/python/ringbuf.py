#!/usr/bin/python3  
from bcc import BPF

program = r"""
BPF_RINGBUF_OUTPUT(output, 1); 

struct event {
    char command[16];
    char filename[256];
    int dfd;
};

TRACEPOINT_PROBE(syscalls, sys_enter_openat) 
{
    struct event ev = {};

    ev.dfd = args->dfd;
    bpf_probe_read_user_str(&ev.filename, sizeof(ev.filename), args->filename);

    // `comm` normally comes from the kernel and determines
    // process name.
    bpf_get_current_comm(&ev.command, sizeof(ev.command));

    bpf_trace_printk("File %d - %s", ev.dfd, ev.filename);
    bpf_trace_printk("     opened by:%s", ev.command);
    output.ringbuf_output(&ev, sizeof(ev), 0); 

    return 0;
}
"""

b = BPF(text=program)

def print_event(cpu, data, size):
    # b["output"] refers t the map.
    ev = b["output"].event(data)
    print(f"{ev.command.decode('utf-8')} - {ev.filename.decode('utf-8', 'replace')}")

b["output"].open_ring_buffer(print_event) 
while True:
    b.ring_buffer_poll()
