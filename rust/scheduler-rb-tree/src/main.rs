use std::{
    future::Future,
    pin::Pin,
    task::{Context, Poll},
    collections::BTreeMap
};

struct Task {
    id: usize,
    priority: u64,
    vruntime: u64,
    future: Pin<Box<dyn Future<Output = ()>>>,
}

struct Scheduler {
    tasks: BTreeMap<(u64, usize), Task>,
    next_id: usize,
}

impl Scheduler {
    fn debug_print(&self) {
        println!("{:<10} {:<5} {:<10}", "VRUNTIME", "ID", "STATUS");
        println!("{}", "-".repeat(30));
        for (&(vruntime, id), _task) in &self.tasks {
            println!("{:<10} {:<5} {:<10}", vruntime, id, "Pending");
        }
    }
}

impl Scheduler {
    fn new() -> Self {
        Self {
            tasks: BTreeMap::new(),
            next_id: 0
        }
    }

    fn spawn<F>(&mut self, fut: F, priority: u64)
    where
        F: Future<Output = ()> + 'static
    {
        let id = self.next_id;
        self.next_id += 1;
        self.tasks.insert(
            (0, id),
            Task {
                id,
                priority,
                vruntime: 0,
                future: Box::pin(fut)
            }
        );
    }

    // EEVDF-like scheduling (simplified).
    fn run(&mut self) {
        self.debug_print();
        use futures::task::{noop_waker, Context};
        let waker = noop_waker();
        // The context of an asynchronous task.
        // Currently, `Context` only serves to provide access to a [`&Waker`](Waker)
        // which can be used to wake the current task.
        let mut cx = Context::from_waker(&waker);

        while let Some(((_, id), mut task)) = self.tasks.pop_first() {
            // Can you make progress now? Return Ready if done,
            // or Pending if you need to wait
            match task.future.as_mut().poll(&mut cx) {
                Poll::Pending => {
                    task.vruntime += task.priority;
                    self.tasks.insert((task.vruntime, id), task);
                },
                Poll::Ready(()) => {}
            }
        }
    }
}

struct YieldOnce {
    yielded: bool,
}

// Implementation of standard Future trait. We able to
// await on YieldOnce then.
impl Future for YieldOnce {
    type Output = ();
    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        if !self.yielded {
            self.yielded = true;
            cx.waker().wake_by_ref();
            Poll::Pending
        } else {
            Poll::Ready(())
        }
    }
}

fn async_yield() -> YieldOnce {
    YieldOnce { yielded: false }
}

async fn task1() {
    for i in 0..50 {
        println!("Task 1: step {i}");
        async_yield().await;
    }
}

async fn task2() {
    for i in 0..50 {
        println!("Task 2: step {i}");
        async_yield().await;
    }
}

async fn task3() {
    for i in 0..50 {
        println!("Task 3: step {i}");
        async_yield().await;
    }
}

fn main() {
    let mut sched = Scheduler::new();
    sched.spawn(task1(), 1);
    sched.spawn(task2(), 5);
    sched.spawn(task3(), 10);
    sched.run();
}
