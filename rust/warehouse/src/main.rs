use std::sync::mpsc;
use std::thread;
use std::time::Duration;
use rand::{thread_rng, Rng};
use rand::distributions::Uniform;

#[derive(Debug)]
enum JobTruck {
    Load { container_id: u32 },
    Unload { container_id: u32 },
}

#[derive(Debug)]
enum JobVehicle {
    MoveToTruck(u32),
    MoveToStorage(u32),
}

fn main() {
    let (tx_truck, rx_truck) = mpsc::channel::<JobTruck>();
    let (tx_vehicle, rx_vehicle) = mpsc::channel::<JobVehicle>();

    thread::spawn({
        let tx_truck = tx_truck.clone();
        move || {
            let mut id_counter = 1000;
            let mut rng = thread_rng();
            let dist = Uniform::from(0..2);

            loop {
                let job = match rng.sample(dist) {
                    0 => JobTruck::Unload { container_id: id_counter },
                    _ => JobTruck::Load { container_id: id_counter }
                };

                println!("[T] New job {:?}", job);
                tx_truck.send(job).unwrap();
                id_counter += 1;
                thread::sleep(Duration::from_millis(rng.gen_range(200..400)));
            }
        }
    });

    let manager_handle = thread::spawn(move || {
        while let Ok(job) = rx_truck.recv() {
            println!("[M] Received job: {:?}", job);

            match job {
                JobTruck::Unload { container_id } => {
                    println!("[M] Dispatching to move container {container_id} to storage");
                    tx_vehicle.send(JobVehicle::MoveToStorage(container_id)).unwrap();
                }
                JobTruck::Load { container_id } => {
                    println!("[M] Dispatching to move container {container_id} to truck");
                    tx_vehicle.send(JobVehicle::MoveToTruck(container_id)).unwrap();
                }
            }
            thread::sleep(Duration::from_millis(thread_rng().gen_range(200..400)));
        }
    });

    let vehicle_handle = thread::spawn(move || {
        while let Ok(task) = rx_vehicle.recv() {
            match task {
                JobVehicle::MoveToTruck(id) => {
                    println!("[V] Moving container {id} to truck");
                    println!("[V] Delivered container {id}");
                }
                JobVehicle::MoveToStorage(id) => {
                    println!("[V] Moving container {id} to storage");
                    println!("[V] Stored container {id}");
                }
            }
            thread::sleep(Duration::from_millis(thread_rng().gen_range(200..400)));
        }
    });

    manager_handle.join().unwrap();
    vehicle_handle.join().unwrap();
}
