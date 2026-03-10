// Will compile. But for
// - fn pick_first<'a, 'b>(x: &'a str, _y: &'b str) -> &'b str {
// AND
// - let string2 = String::from("I'm short-lived")
// not
//
// Compiler build relation between function declaration with
// their references and its call. Nice.
fn pick_first<'a, 'b>(x: &'a str, _y: &'b str) -> &'a str {
    x
}

fn usage_basic() {
    let string1 = String::from("I'm alive for a long time");

    let result: &str;
    {
        let string2 = String::from("I'm short-lived");
        result = pick_first(&string1, &string2); // ✅ only string1 is returned
    } // string2 is dropped here

    println!("Result: {result}");
}

// Example from compiler
//
// fn pick_larger_token<'a, 'b>(
//      t1: &'a Token<'a>,
//      t2: &'b Token<'b>
// ) -> &'a Token<'a>
//
// If we return &'a, so we are never allowed to return &'b references
// with this signature? &'b references are only for internal use by function.

fn main() {
    usage_basic();
}
