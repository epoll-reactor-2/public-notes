#!/usr/bin/python3  
from bcc import BPF
import ctypes as ct

program = r"""
// https://filippo.io/linux-syscall-table/
#include <asm/unistd.h>

// Each entry of the array is either a file descriptor to a BPF program or NULL.
BPF_PROG_ARRAY(syscall, 500);

int trace_default(struct bpf_raw_tracepoint_args *ctx)
{
    int opcode = ctx->args[1];

    // Tail call is placed there. eBPF replaces this
    // with bpf_tail_call().
    syscall.call(ctx, opcode);

    // If the tail call succeeds, this line tracing out the
    // opcode value will never be hit. When I run this program,
    // only few first lines prints this
    bpf_trace_printk("Another syscall: %s", opcode);
    return 0;
}

int trace_execve(void *ctx)
{
    bpf_trace_printk("execve() called");
    return 0;
}

int trace_timer(struct bpf_raw_tracepoint_args *ctx)
{
    int opcode = ctx->args[1];

    switch (opcode) {
    case __NR_timer_create:
        bpf_trace_printk("timer_create() syscall called");
        break;
    case __NR_timer_delete:
        bpf_trace_printk("timer_delete() syscall called");
        break;
    default:
        bpf_trace_printk("other timer_*() syscall called");
        break;
    }

    return 0;
}

int trace_ignore(void *ctx)
{
    return 0;
}
"""

b = BPF(text=program)
b.attach_raw_tracepoint(tp="sys_enter", fn_name="trace_default")

fn_ignore = b.load_func("trace_ignore", BPF.RAW_TRACEPOINT)
fn_execve = b.load_func("trace_execve", BPF.RAW_TRACEPOINT)
fn_timer = b.load_func("trace_timer", BPF.RAW_TRACEPOINT)

prog_array = b.get_table("syscall")

for i in range(len(prog_array)):
    prog_array[ct.c_int(i)] = ct.c_int(fn_ignore.fd)

prog_array[ct.c_int( 59)] = ct.c_int(fn_execve.fd)
prog_array[ct.c_int(222)] = ct.c_int(fn_timer.fd)
prog_array[ct.c_int(223)] = ct.c_int(fn_timer.fd)
prog_array[ct.c_int(224)] = ct.c_int(fn_timer.fd)
prog_array[ct.c_int(225)] = ct.c_int(fn_timer.fd)
prog_array[ct.c_int(226)] = ct.c_int(fn_timer.fd)

b.trace_print()
