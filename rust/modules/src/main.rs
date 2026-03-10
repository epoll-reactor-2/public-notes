// Top-level garden module.
pub mod garden;

// Use Asparagus through
// 0. crate is currently processed module. Means
//    local uses.
// 1. garden top-level module. This is root module.
// 2. vegetables module. Defined in vegetables.rs.
// 3. Asparagus is struct.
use crate::garden::vegetables::Asparagus;

mod level_1 {
    // Module required to be public. Otherwise usable only
    // inside parent module.
    pub mod level_2 {
        pub fn level_3() {
            println!("Function from modules called");
        }
    }
}

fn main() {
    let plant = Asparagus {};
    println!("I'm growing {plant:?}!");

    level_1::level_2::level_3();
    // Or.
    crate::level_1::level_2::level_3();
}
