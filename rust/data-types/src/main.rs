fn main() {
    // Note on overflow:
    // 1. In debug mode, rust will panic
    // 2. In release mode overflow will result wrapping
    //    value modulo maximum for type.
    let large: u128 = 111_111_111_111_111_111_111_111_111_111_111_111_111;
    println!("{large}");

    // Classical 0.30000000000000004
    let f = 0.1 * 3.0;
    println!("{f}");

    let shift = 1 << 10;
    println!("{shift}");

    let kitty = '😻';
    println!("{kitty}");

    // Is not printable out of the box...
    let _tuple = (
        1, (
            2, (
                3, (
                    4, 5, 6, 7
        )), 8), 9);

    let (
        a, (
            b, (
                c, (
                    d, e, f, g
        )), h), j
    ) = _tuple;

    let fifth_in_tuple = _tuple.1.1.1.1;

    println!("{a} {b} {c} {d} {e} {f} {g} {h} {j}");
    println!("{fifth_in_tuple}");

    let _static_array /* : [i32; 4] */ = [0, 1, 2, 3];
    let _static_array_first = _static_array[0];

    println!("{_static_array_first}");
}
