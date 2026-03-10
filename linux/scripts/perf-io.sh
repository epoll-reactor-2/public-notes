# perf allows to trace block I/block_rq_insert

# Backgro~Pool #3           Command (thread name) issuing the I/O
# 466151                    Thread/process ID (PID)
# [006]                     CPU core number
# 25966.624347              Timestamp (in seconds since boot or trace start)
# block:block_rq_insert     Perf event: a block request was inserted into the queue
# 8,0                       Major, minor device number (typically sda = 8,0)
# W / RA / RM               Operation type: write, readahead, read
# 4096 / etc.               Request size in bytes
# ()                        Additional flags (usually unused)
# 226368672                 Starting sector
# + 8                       Number of sectors (512B each, so 8 * 512 = 4096B)

sudo perf record -e block:block_rq_insert,block:block_rq_issue,block:block_rq_complete -a
sudo perf script
