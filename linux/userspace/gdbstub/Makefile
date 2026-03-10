all:
	gcc gdbstub.c -o gdbstub

.PHONY: run
run:
	@echo "GDB stub working..."
	@echo "  Note: run gdb -ex \"target remote localhost:1234\" in another window"
	@./gdbstub
