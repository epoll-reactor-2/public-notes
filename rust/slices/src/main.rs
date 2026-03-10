fn first_word(s: &String) -> usize {
    for (i, &item) in s.as_bytes().iter().enumerate() {
        if item == b' ' {
            return i;
        }
    }

    s.len()
}

// Notice the difference:
// 1. String is data type for the string object
// 2. str is the string slice.
fn first_word_slice(s: &String) -> &str {
    let bytes = s.as_bytes();

    for (i, &item) in bytes.iter().enumerate() {
        if item == b' ' {
            return &s[0..i];
        }
    }

    &s[..]
}

fn example_panic() {
    let mut s = String::from("Literal");
    s.clear();
    // s.chars().nth(10000).unwrap();
}

fn example_slice() {
    let s = String::from("hello world");

    let hello = &s[0..5];
    let world = &s[6..11];

    println!("{hello} {world}");
}

fn example_slice_2() {
    let a = [1, 2, 3, 4, 5];
    let slice = &a[1..3];
    assert_eq!(slice, &[2, 3]);
}

fn main() {
    let s = String::from("First string literal");
    let first = first_word(&s);
    println!("First space in \"{s}\": {first}");

    let first = first_word_slice(&s);
    println!("(slice) First word in \"{s}\": {first}");

    example_slice();
    example_slice_2();
    example_panic();
}
