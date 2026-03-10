use tokio::net::{TcpListener, TcpStream};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

/// # Return
///
/// Ok(false)       - when client is disconnected
/// Ok(true)        - when data was read
/// Err(...)        - when error occurred
async fn try_read(socket: &mut TcpStream) -> Result<bool, String> {
    let mut buf = [0u8; 1024];
    let n = match socket.read(&mut buf).await {
        Ok(0) => return Ok(false), // Disconnected.
        Ok(n) => n,
        Err(e) => {
            return Err(format!("Failed to read from socket: {e}"));
        }
    };

    if socket.write_all(&buf[..n]).await.is_err() {
        return Err(String::from("Failed to write"));
    }

    Ok(true)
}

#[tokio::main]
async fn main() -> tokio::io::Result<()> {
    // .await? propagates error from the function with "return".
    // .await just waits for asynchronous operation.
    let mut listener = TcpListener::bind("127.0.0.1:8080").await?;
    println!("Listening on 127.0.0.1:8080");

    loop {
        let (mut socket, addr) = listener.accept().await?;
        println!("Accepted connection from {addr}");
        // Breakdown of "async move":
        // 1. "async" turns the block into a Future, which is executed
        //     when awaited.
        // 2. "move" forces all captured variables (like `socket`) to
        //     be moved into the block.
        // This allows the block to outlive the current scope and
        // run in another task.
        //
        // async move {}
        // Type: impl Future<Output = !>
        //
        // async move || {} is also valid.
        // Type: impl FnMut() -> impl Future<Output = ...>
        tokio::spawn(async move {
            loop {
                // "await" takes a future for execution and waits to
                // completion.
                match try_read(&mut socket).await {
                    Ok(true) => {}, // Continue to listen.
                    Ok(false) => break, // Client disconnected.
                    Err(e) => println!("Failed to read: {e}"),
                };
            }
        });
    }
}
