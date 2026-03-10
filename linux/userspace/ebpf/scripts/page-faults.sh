sudo stackcount-bpfcc -f -PU t:exceptions:page_fault_user > out.pagefaults.txt
flamegraph.pl --hash --width=809 --title="aaa" --colors=java --bgcolor=green < out.pagefaults.txt > out.pagefaults.png
