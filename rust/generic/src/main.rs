use std::fmt;

struct Pair<T> {
    x: T,
    y: T,
}

impl<T: fmt::Display> fmt::Display for Pair<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Pair(x({}) y({}))", self.x, self.y)
    }
}

fn main() {
    let p: Pair<i32> = Pair {
        x: 1,
        y: 2
    };

    println!("{p}");

    let p2: Pair<String> = Pair {
        x: String::from("Abc"),
        y: String::from("Def")
    };

    println!("{p2}");
}
