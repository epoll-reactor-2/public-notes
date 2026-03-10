all:
	clang -target bpf -I/usr/include/`uname -m`-linux-gnu -g -O2 -c xdp.bpf.c -o xdp.bpf.o
	llvm-objdump -S xdp.bpf.o

.PHONY: clean
clean:
	rm -rf *.o

.PHONY: load
load:
	sudo bpftool prog load xdp.bpf.o /sys/fs/bpf/xdp
	sudo ls -l /sys/fs/bpf
	sudo bpftool prog list
	# ID from the list

.PHONY: show
show:
	sudo bpftool prog show id $(BPF_ID) --pretty
	@echo ""
	@echo ""
	@echo "-----------------"
	@echo "  eBPF disassembly:"
	@sudo bpftool prog dump xlated id $(BPF_ID)

.PHONY: attach
attach:
	# Attach eBPF code to WLAN interface
	#
	# Terminal 1
	# ---------------------------------------------------------------------------------------
	# StreamT~ns #105-106677  [001] b.s21  5419.363842: bpf_trace_printk: Hello world 60
	# StreamT~ns #105-106677  [001] b.s21  5419.363864: bpf_trace_printk: Hello world 61
	# irq/59-rtw88_pc-855     [001] ..s21  5419.434074: bpf_trace_printk: Hello world 62
	# irq/59-rtw88_pc-855     [001] ..s21  5419.509169: bpf_trace_printk: Hello world 63
	# irq/59-rtw88_pc-855     [001] ..s21  5419.509177: bpf_trace_printk: Hello world 64
	# irq/59-rtw88_pc-855     [001] ..s21  5419.579607: bpf_trace_printk: Hello world 65
	# irq/59-rtw88_pc-855     [001] ..s21  5424.777363: bpf_trace_printk: Hello world 66
	# irq/59-rtw88_pc-855     [001] ..s21  5433.090184: bpf_trace_printk: Hello world 67
	# irq/59-rtw88_pc-855     [001] ..s21  5433.128912: bpf_trace_printk: Hello world 68
	# irq/59-rtw88_pc-855     [001] ..s21  5434.198919: bpf_trace_printk: Hello world 69
	# irq/59-rtw88_pc-855     [001] ..s21  5435.158243: bpf_trace_printk: Hello world 70
	# irq/59-rtw88_pc-855     [001] ..s21  5436.137867: bpf_trace_printk: Hello world 71
	# irq/59-rtw88_pc-855     [001] ..s21  5438.801169: bpf_trace_printk: Hello world 72
	# irq/59-rtw88_pc-855     [001] ..s21  5441.059204: bpf_trace_printk: Hello world 73
	#
	# Terminal 2
	# --------------------------------------------------------------------------------------
	# fuck@user ~ $ ping google.com
	# PING google.com (142.250.203.142) 56(84) bytes of data.
	# 64 bytes from waw07s06-in-f14.1e100.net (142.250.203.142): icmp_seq=1 ttl=117 time=37.9 ms
	# 64 bytes from waw07s06-in-f14.1e100.net (142.250.203.142): icmp_seq=2 ttl=117 time=107 ms
	# 64 bytes from waw07s06-in-f14.1e100.net (142.250.203.142): icmp_seq=3 ttl=117 time=66.2 ms
	# 64 bytes from waw07s06-in-f14.1e100.net (142.250.203.142): icmp_seq=4 ttl=117 time=45.5 ms
	#
	# Note: When new packet is received, trace pipe shows a new message.
	sudo bpftool net attach xdp id $(BPF_ID) dev wlp1s0 || true
	sudo cat /sys/kernel/debug/tracing/trace_pipe

.PHONY: attach-ip-link
attach-ip-link:
	# Attach eBPF code to WLAN interface with `ip link` command
	# instead of bpftool.
	sudo ip link set dev wlp1s0 xdp off 
	sudo ip link set dev wlp1s0 xdp obj xdp.bpf.o sec xdp

.PHONY: net-list
net-list:
	sudo bpftool net list

.PHONY: xdp-show-lists
xdp-show-lists:
	sudo bpftool map list
	sudo bpftool map dump name xdp.bss
	sudo bpftool map dump name xdp.rodata
