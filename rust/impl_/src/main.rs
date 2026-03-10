#[derive(Debug)]
struct Rectangle {
    width: u32,
    height: u32,
}

// impl keyword used to provide logic implementation
// for given type.
//
// We can put several functions in `impl` block.
// We can split them like
//
// impl Rectangle {
//      fn f1(&self) {}
// }
//
// impl Rectangle {
//      fn f2(&self) {}
// }
impl Rectangle {
    // First parameter in functions inside
    // impl is always self.
    fn area(&self) -> u32 {
        self.width * self.height
    }
    fn width(&self) -> bool {
        self.width > 0
    }
}

fn main() {
    let rect1 = Rectangle {
        width: 30,
        height: 50,
    };

    let r = Rectangle {
        width: 1,
        height: 1
    };
    // Two ways to call function inside impl.
    Rectangle::area(&r);
    r.area();
    r.width();

    {
        // This syntax is functionally the same, however
        // first one is much clearer.
        r.area();
        (&r).area();
    }

    println!(
        "The area of the rectangle is {} square pixels.",
        dbg!(rect1).area()
    );
}
