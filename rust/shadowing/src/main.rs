fn shadowing_1() {
    let x = 5;
    let x = x + 1;

    {
        let x = x * 2;
        println!("The value of x in the inner scope is: {x}");
    }

    println!("The value of x is: {x}");
}

fn shadowing_2() {
    let spaces = "    ";
    let spaces = spaces.len();

    println!("Spaces length is {spaces}");
}

fn main() {
    shadowing_1();
    shadowing_2();
}
