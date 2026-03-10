// Box<T> type owns object of type T on the heap.
// Kinda smart pointer.
//
// There used in similar way like in C:
//
// struct Expr {
//     struct Expr e;  // Impossible. Structure with
//                     // undefined size.
//     struct Expr *e; // Legit. Pointer size is known.
// }
enum Expr {
    Number(i32),
    Add(Box<Expr>, Box<Expr>),
    Sub(Box<Expr>, Box<Expr>),
    Mul(Box<Expr>, Box<Expr>),
    Neg(Box<Expr>),
}

fn eval(expr: &Expr) -> i32 {
    match expr {
        Expr::Number(n) => *n,
        Expr::Add(l, r) => eval(l) + eval(r),
        Expr::Mul(l, r) => eval(l) * eval(r),
        Expr::Sub(l, r) => eval(l) - eval(r),
        Expr::Neg(inner) => -eval(inner),
    }
}

fn main() {
    let expr = Expr::Mul(
        Box::new(Expr::Add(
            Box::new(Expr::Number(3)),
            Box::new(Expr::Number(4)),
        )),
        Box::new(Expr::Neg(Box::new(Expr::Sub(
            Box::new(Expr::Number(2)),
            Box::new(Expr::Number(5)),
        )))),
    );

    println!("Expression evaluates to: {}", eval(&expr));
}
