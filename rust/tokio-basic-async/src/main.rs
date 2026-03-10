use std::{thread, time::Duration};

// async means that function returns Future<Output = ()>.
async fn app() {
    println!("fn app() entered");
    thread::sleep(Duration::from_secs(1));
    println!("App");
    thread::sleep(Duration::from_secs(1));
    println!("fn app() exited");
}

/// This is the naive way to launch Tokio runtime.
///
/// ```rust
/// fn main() {
///     let mut runtime = tokio::runtime::Runtime::new().unwrap();
///     let future = app();
///     println!("Future acquired");
///     println!("Waiting on future...");
///     runtime.block_on(future);
/// }
/// ```
///
/// This is shorter way:
#[tokio::main]
async fn main() {
    let future = tokio::task::spawn(app());
    println!("Future acquired. There we can do anything we want in main thread.");
    println!("Awaiting on future...");
    match future.await {
        Ok(_)  => println!("Future finished"),
        Err(_) => println!("Error"),
    };
}
