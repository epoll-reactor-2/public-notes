struct Pair<'x, 'y> {
    first: &'x i32,
    second: &'y i32,
}

// 'a must live as long as both 'x and 'y.
//
// Other syntax: we move lifetime bounds after "where",
// hello Haskell.
//
// fn select<'a, 'x, 'y>(p: &Pair<'x, 'y>) -> &'a i32
//     where 'x: 'a, 'y: 'a {
//
fn select<'a, 'x: 'a, 'y: 'a>(p: &Pair<'x, 'y>) -> &'a i32 {
    if p.first < p.second {
        p.first
    } else {
        p.second
    }
}

fn usage_correct() {
    let f = 1;
    let s = 2;
    let p: Pair<'_, '_> = Pair {
        first: &f,
        second: &s
    };

    let r = select(&p);

    println!("{} {} {}", p.first, p.second, r);
}

fn usage_may_be_incorrect() {
    let longer = 100;
    let result: &i32;

    // Note: Remove comment below to break compilation.
    // {
        let shorter = 42;

        let pair = Pair {
            first: &longer,
            second: &shorter,
        };

        result = select(&pair);
    // Note: Remove comment below to break compilation.
    // }

    // result used here, but it may refer to `shorter` which is dropped
    println!("Selected: {result}");
}

fn main() {
    usage_correct();
    usage_may_be_incorrect();
}
