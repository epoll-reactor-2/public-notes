fn basic() {
    let mut s = String::from("Hello");
    s.push_str(", World!");
    println!("{s}");
    // Just like RAII in C++, Rust calls
    // drop() function when scope ends.
}

fn dont_take_ownership(some_string: &mut String) {
    println!("{some_string}")
}

fn take_ownership(some_string: String) {
    println!("{some_string}")
}

fn several_borrows() {
    let mut s = String::from("Hello");
    let r1 = &mut s;
    println!("{r1}");
    let r2 = &mut s;
    println!("{r2}"); // r1 will result error.
}

fn return_reference(some_string: &mut String) -> &mut String {
    some_string
}

fn main() {
    basic();
    let mut s = String::from("Abc");
    dont_take_ownership(&mut s);
    let _len1 = s.len();
    return_reference(&mut s);
    take_ownership(s);

    // Cannot do this. We borrow s above, since
    // passing by value.
    // let _len2 = s.len();

    // {
    // error[E0382]: borrow of moved value: `_s1`
    //   --> src/main.rs:14:19
    //    |
    // 11 |         let _s1 = String::from("S");
    //    |             --- move occurs because `_s1` has type `String`, which does not implement the `Copy` trait
    // 12 |         let _s2 = _s1;
    //    |                   --- value moved here
    // 13 |
    // 14 |         println!("{_s1}");
    //    |                   ^^^^^ value borrowed here after move
    //    |
    //    = note: this error originates in the macro `$crate::format_args_nl` which comes from the expansion of the macro `println` (in Nightly builds, run with -Z macro-backtrace for more info)
    // help: consider cloning the value if the performance cost is acceptable
    //    |
    // 12 |         let _s2 = _s1.clone();
    //    |                      ++++++++
    // 
    // ----------------------------------------------------
    //     let _s1 = String::from("S");
    //     let _s2 = _s1;
    //
    //     println!("{_s1}");
    //
    // }
}
