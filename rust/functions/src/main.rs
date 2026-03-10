fn main() {
    print_labeled_measurement(5, 'h');
    let_let_let();
}

fn print_labeled_measurement(value: i32, unit_label: char) {
    println!("The measurement is: {value}{unit_label}");
}

// Uh?
fn let_let_let() {
    let x = {
        let y = 3;
        // Notice that there is no semicolon.
        // Inserting ; will turn expression to a
        // statement. But function allowed to return
        // expressions only.
        y + 1
    };

    println!("{x}");
}
