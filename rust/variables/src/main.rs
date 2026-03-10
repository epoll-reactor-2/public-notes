fn main() {
    let mut x = 5;
    println!("The value of x: {x}");
    x = 6;
    println!("The value of x: {x}");
    // Constant variable produced with `let` statement
    // can be created from any kind of expressions.
    let _constant = 1;
    // Constant can be defined in global scope,
    // unlike variables, and required to have
    // constant-evaluable body.
    const _THREE_HOURS_IN_SECOND: u32 = 60 * 60 * 3;
}
