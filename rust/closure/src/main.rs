fn rect() {
    #[derive(Debug)]
    struct Rect {
        x: i32,
        y: i32,
    }
    let mut list = [
        Rect { x: 10, y:  3 },
        Rect { x:  2, y:  9 },
        Rect { x:  4, y: 12 }
    ];

    list.sort_by_key(|r| r.x);

    assert_eq!(
        list.iter().map(|r| r.x)
            .collect::<Vec<_>>(),
        vec![2, 4, 10]
    );

    dbg!(list);
}

fn code_piece() {
    let some = || println!("Ok");
    let some2 = || {
        println!("Ok 1");
        println!("Ok 2");
    };

    some();
    some2();

    (|| { println!("Inline"); })();

    (||{(||{(||{(||{println!("Fuck");})()})()})()})();
}

fn main() {
    rect();
    code_piece();
}
