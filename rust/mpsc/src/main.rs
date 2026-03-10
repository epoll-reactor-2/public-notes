use std::sync::mpsc;
use std::thread;
use std::time::Duration;

fn main() {
    let (tx, rx) = mpsc::channel();
  
    let tx1 = tx.clone();
    thread::spawn(move || {
        for _ in 0..5 {
            tx1.send(0).unwrap();
            thread::sleep(Duration::from_millis(100));
        }
    });

    thread::spawn(move || {
        for _ in 0..5 {
            tx.send(1).unwrap();
            thread::sleep(Duration::from_millis(100));
        }
    });

    for recv in rx {
        println!("Got {recv}");
    }
}
