use std::{
    collections::VecDeque,
    future::Future,
    pin::Pin,
    task::{Context, Poll}, thread, time::Duration,
};

struct Task {
    future: Pin<Box<dyn Future<Output = ()>>>,
}

struct Scheduler {
    tasks: VecDeque<Task>,
}

impl Scheduler {
    fn new() -> Self {
        Scheduler {
            tasks: VecDeque::new(),
        }
    }

    fn spawn<F: Future<Output = ()> + 'static>(&mut self, future: F) {
        self.tasks.push_back(Task {
            future: Box::pin(future),
        });
    }

    // This implements FIFO.
    // 1. pop_front()
    // 2. push_back()
    fn run(&mut self) {
        let waker = futures::task::noop_waker();
        // The context of an asynchronous task.
        // Currently, `Context` only serves to provide access to a [`&Waker`](Waker)
        // which can be used to wake the current task.
        let mut cx = Context::from_waker(&waker);

        while let Some(mut task) = self.tasks.pop_front() {
            // Can you make progress now? Return Ready if done,
            // or Pending if you need to wait
            match task.future.as_mut().poll(&mut cx) {
                Poll::Pending => self.tasks.push_back(task),
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
    sched.spawn(task1());
    sched.spawn(task2());
    sched.spawn(task3());
    sched.run();
}
