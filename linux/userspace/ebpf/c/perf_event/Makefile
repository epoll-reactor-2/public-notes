all:
	clang -O2 -target bpf -c perf.bpf.c -o perf.bpf.o
	clang userspace.c -o userspace.o -lbpf -lelf

clean:
	rm -rf *.o
