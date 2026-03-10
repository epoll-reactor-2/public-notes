# Public notes

## Roadmap

### Языки

- С++ глубже
- Rust

### Computer science

- lock-free структуры данных, memory ordering

### Linux

- структуры данных: list, hashmap, radix tree, bitmap, другие если есть
- memory management: buddy allocator, кэш, виртуальная память
- scheduler'ы
  - Completely Fair Scheduler (CFS)
  - Earliest eligible virtual deadline first (EEVDF)
  - real time scheduling
- аллокация: slab allocator, kmalloc, mmap
- спинлоки, mutex/RW-семафоры, RCU, seqlock
- трассировка: ftrace, bpftrace, SystemTap
- основы файловых систем: VFS, Superblock, inode
- port- или memory-based IO (MMIO). Как в линуксе это реализовано
- KVM
- SELinux
- gdbstub
- BPF
  - что это?
  - kprobe
  - bpftrace
  - BPF-программы на C (SEC(...))
  - seccomp-bpf
- self-tests (tools/testing/selftests)
- как использовать perf в ядре
- POSIX real-time extensions
- источник: <https://github.com/cirosantilli/linux-kernel-module-cheat/tree/master>
- источник: <https://0xax.gitbooks.io/linux-insides/content/SyncPrim/linux-sync-6.html>. Целая книга с понятными главами

### Периферия

- Разобраться в PCI/PCIe
- Разобраться в DMA и его API в Linux

### Ассемблер

- x86_64 глубоко
- RISC-V глубоко

### Загрузчики

- BIOS
  - что это?
  - SPI flash
  - простой загрузчик (есть в проекте OS). Это BIOS или нет?
- UEFI
  - что это?
  - расписать больше

### Общественность

- Написать пару осмысленных, хороших статей на англоязычных источниках
  - Dataflow analysis in Clang
  - Syscall analyzer

### Подготовка к собесу

- 100 решённых задач на Leetcode
