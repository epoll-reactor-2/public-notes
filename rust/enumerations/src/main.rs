use std::fmt;

// Enum is really selection statement
// for different structures.
enum IpAddr {
    V4(u8, u8, u8, u8),
    V6(String),
}

// We implement Display trait for our enum.
impl fmt::Display for IpAddr {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            IpAddr::V4(a, b, c, d)
                => write!(f, "{a}.{b}.{c}.{d}"),
            IpAddr::V6(s)
                => write!(f, "{s}")
        }
    }
}

fn main() {
    let ip1 = IpAddr::V4(192, 168, 0, 1);
    let ip2 = IpAddr::V6(String::from("fe80::1"));

    println!("{ip1}");
    println!("{ip2}");
}
