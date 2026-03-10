use std::thread;
use std::time::Duration;

fn basic() {
    let handle = thread::spawn(|| {
        for i in 1..10 {
            println!("hi number {i} from the spawned thread!");
            thread::sleep(Duration::from_millis(1));
        }
    });

    for i in 1..5 {
        println!("hi number {i} from the main thread!");
        thread::sleep(Duration::from_millis(1));
    }

    handle.join().unwrap()
}

fn pass() {
    let v = vec![1, 2, 3];
    // Move like in C++, uh.
    //
    // Rust: move converts any variables captured by reference
    // or mutable reference to variables captured by value
    let handle = thread::spawn(move || {
        println!("Here's a vector {v:?}");
    });

    handle.join().unwrap();
}

fn main() {
    basic();
    pass();
}
