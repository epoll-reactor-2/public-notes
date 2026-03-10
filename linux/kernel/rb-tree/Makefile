NAME   = rb-tree
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
	sudo dmesg -c
