#!/usr/bin/python3  
from bcc import BPF
from time import sleep

program = r"""
// Define a hashtable.
BPF_HASH(counter_table);

int ebpf_trace_per_uid(void *ctx) {
    u64 uid;
    u64 counter = 0;
    u64 *p;

    // bpf_get_current_uid_gid() used to obtain a
    // User ID which process triggered the kprobe event.
    uid = bpf_get_current_uid_gid() & 0xFFFFFFFF;

    // Usual hash table lookup function.
    p = counter_table.lookup(&uid);
    if (p != 0) {
       counter = *p;
    }
    counter++;

    // Update the values.
    counter_table.update(&uid, &counter);
    return 0;
}
"""

b = BPF(text=program)
syscall = b.get_syscall_fnname("execve")
b.attach_kprobe(event=syscall, fn_name="ebpf_trace_per_uid")

# Attach to a tracepoint that gets hit for all syscalls 
# b.attach_raw_tracepoint(tp="sys_enter", fn_name="hello")

while True:
    sleep(1)
    s = ""
    for k,v in b["counter_table"].items():
        s += f"UID {k.value} has executed {v.value} process(es)\t"
    print(s)
