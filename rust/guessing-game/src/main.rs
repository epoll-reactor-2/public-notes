// Rust uses basic things from stdlib subset
// called prelude. No need to import things
// from it.
use std::{
    io, cmp::Ordering
};
use rand::Rng;

fn main() {
    println!("Guess the number!");

    let secret_number = rand::rng().random_range(1..=100);
    println!("The secret number is {secret_number}");

    loop {
        println!("Please input your number");

        // String is growable, UTF-8 encoded bit of text.
        let mut guess = String::new();

        io::stdin()
            // Read from /dev/stdin.
            .read_line(&mut guess)
            .expect("Failed to read line");

        // Rust allows to shadow variable with same name
        // for different types.
        let guess: u32 = match guess.trim().parse() {
            Ok(num) => num,
            Err(_) => {
                println!("Failed to parse number");
                continue
            }
        };

        println!("You guessed: {guess}");

        match guess.cmp(&secret_number) {
            Ordering::Less => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal => {
                println!("You win");
                break
            }
        }
    }
}
