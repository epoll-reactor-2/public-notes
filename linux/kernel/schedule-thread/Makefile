NAME   = schedule-thread
obj-m += $(NAME).o
PWD   := $(CURDIR)

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

run:
	sudo dmesg -c > /dev/null
	sudo rmmod $(NAME).ko || true
	sudo insmod $(NAME).ko
	for i in `seq 1 25`; do sudo dmesg -c; sleep 0.1; done
	sudo rmmod $(NAME).ko || true
	sudo dmesg -c
