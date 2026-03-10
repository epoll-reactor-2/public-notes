#!/usr/bin/python3

from bcc import BPF

# This is the entrie eBPF program written in C
# and compiled for the kernel.
program = r"""
// This function is run inside the kernel.
int hello(void *ctx) {
    bpf_trace_printk("Hello World!");
    return 0;
}
"""

# This line compiles code above to eBPF assembly.
b = BPF(text=program)
# This resolves for us arch-dependent function that
# implements given syscall.
#
# This = b'__x64_sys_execve'
syscall = b.get_syscall_fnname("execve")
# eBPF attaches kernel probe (like I was done in linux/kprobe example).
b.attach_kprobe(event=syscall, fn_name="hello")
# This function will run infinitely in a loop and
# print event when occurs.
b.trace_print()
