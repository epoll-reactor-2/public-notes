use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::thread::{self, JoinHandle};

// API usage.
fn basic() {
    let five = Arc::new(5);

    for _ in 0..10 {
        let five = Arc::clone(&five);

        thread::spawn(move || {
            println!("{five:?}");
        });
    }
}

// This just increments atomic concurrently.
fn atomic_ops() {
    let arc= Arc::new(AtomicUsize::new(0));
    let mut handles: Vec<JoinHandle<()>> = Vec::new();

    for _ in 0..100 {
        let arc = arc.clone();
        let handle = thread::spawn(move || {
            arc.fetch_add(1, Ordering::SeqCst);
        });
        handles.push(handle);
    }

    for h in handles {
        h.join().unwrap();
    }

    println!("Atomic arc: {}", arc.load(Ordering::Relaxed));
}

//
fn into_inner() {
    let x = Arc::new(3);
    let y = Arc::clone(&x);

    // Two threads calling `Arc::into_inner` on both clones of an `Arc`:
    let x_thread = std::thread::spawn(|| Arc::into_inner(x));
    let y_thread = std::thread::spawn(|| Arc::into_inner(y));

    let x_inner_value = x_thread.join().unwrap();
    let y_inner_value = y_thread.join().unwrap();

    println!("1 thread result is None? {}", x_inner_value.is_none());
    println!("2 thread result is None? {}", y_inner_value.is_none());

    // One of the threads is guaranteed to receive the inner value:
    assert!(matches!(
        (x_inner_value, y_inner_value),
        (None, Some(3)) | (Some(3), None)
    ));
}

fn main() {
    basic();
    atomic_ops();
    into_inner();
}
