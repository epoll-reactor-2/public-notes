fn _1() {
    let n = 1;

    if n == 0 {
        println!("A");
    } else {
        println!("B");
    }
}

fn _2() {
    let _number = if true { 1 } else { 2 };
}

fn _3() {
    loop {
        println!("Again");
    }
}

fn _4() {
    let mut counter = 0;

    let result = loop {
        counter += 1;

        if counter == 10 {
            break counter * 2;
        }
    };

    println!("{result}");
}

fn _5() {
    let mut count = 0;
    'counting_up: loop {
        println!("count = {count}");
        let mut remaining = 10;

        loop {
            println!("remaining = {remaining}");
            if remaining == 9 {
                break;
            }
            if count == 2 {
                break 'counting_up;
            }
            remaining -= 1;
        }

        count += 1;
    }
    println!("End count = {count}");
}

fn main() {
    _1();
    _2();
    _4();
    _5();
}
