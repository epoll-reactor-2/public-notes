fn create_from_macro() {
    println!("{:?}", vec![0, 1, 2]);
    println!("{:?}", vec![vec![0, 1], vec![2, 3], vec![3, 4]]);
}

fn create_from_fn() {
    let mut v1 = Vec::<i32>::new();
    let mut v2: Vec<i32> = Vec::new();

    v1.push(1);
    v1.push(2);
    v1.push(3);

    v2.push(4);
    v2.push(5);
    v2.push(6);

    assert_eq!(v1, vec![1, 2, 3]);
    assert_eq!(v2, vec![4, 5, 6]);
}

fn create_from_enum() {
    #[allow(dead_code)]
    #[derive(Debug)]
    enum SpreadsheetCell {
        Int(i32),
        Float(f64),
        Text(String),
    }

    let row = vec![
        SpreadsheetCell::Int(3),
        SpreadsheetCell::Text(String::from("blue")),
        SpreadsheetCell::Float(10.12),
    ];

    println!("{row:?}");
}

fn read() {
    // Out of range, None returned.
    match vec![1, 2].get(100) {
        Some(x) => {
            println!("Got {x}");
        },
        None => {
            println!("Failed to get");
        }
    }

    // Will panic on overflow.
    let x = &vec![1, 2][0];
    println!("Raw index: {x}. Unsafe to use, I recommend get() instead");
}

fn split_inclusive() {
    // Get subslice separated by element matching given predicate.
    // Both vector and array can be used.
    for i in [1, 3, 5, 7, 9, 10, 11, 13, 15, 16, 17, 18, 19]
        .split_inclusive(|x| x % 2 == 0) {

        println!("-");
        for j in i {
            println!("Split inclusive result: {j}");
        }
    }
}

fn main() {
    create_from_macro();
    create_from_fn();
    create_from_enum();
    read();
    split_inclusive();
}
