use std::{thread, time::Duration};
use rand::{thread_rng, Rng};
use rand::distributions::Uniform;

async fn part() {
    let mut rng = thread_rng();
    let dist = Uniform::from(0..10);

    loop {
        let sample = rng.sample(dist);
        let jobs = sample % 6;
        let dur = Duration::from_millis(sample);
        println!("Part {:?}", dur);

        (1..=jobs).for_each(|_| {
            thread::sleep(dur);
            println!("Job");
        });
    }
}

async fn smthelse() {
    loop {
        (1..=10).for_each(|_| {
            thread::sleep(Duration::from_secs(1));
            println!("Something else");
        });
    }
}

async fn parent() {
    (1..=10).for_each(|_| {
        tokio::task::spawn(part());
        tokio::task::spawn(smthelse());
    });
}

#[tokio::main]
async fn main() {
    match tokio::task::spawn(parent()).await {
        Ok(_) => {
            println!("Ok");
        },
        Err(_) => {
            println!("Nok");
        }
    };
}
