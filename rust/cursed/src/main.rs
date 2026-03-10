use regex::Regex;

fn uh() {
    let Some(result) = Regex::new(r"^(?<mail>\w+)@(?<service>\w+)\.(?<domain>\w+)$")
        .unwrap().captures("example@gmail.com")
        else {
            println!("No match");
            return;
        };
    println!("Matched: - {} - {} - {}",
        &result["mail"],
        &result["service"],
        &result["domain"]
    );
}

fn oh() {
    let dates: Vec<(&str, &str, &str)> = Regex::new(r"([0-9]{4})-([0-9]{2})-([0-9]{2})")
        .unwrap()
        .captures_iter("What do 1865-04-14, 1881-07-02, 1901-09-06 and 1963-11-22 have in common?")
        .map(|capture| {
            let (_, [y, m, d]) = capture.extract();
            (y, m, d)
        }).collect();
    dbg!(dates);
}

fn allah_akbar() {
    let Some(result) = Regex::new(r"\u{FDF2}")
        .unwrap()
        .find("نسأل ﷲَ أن يمنحنا الصبر والقوة في مواجهة التحديات، وأن يرزقنا النجاح والتوفيق في حياتنا‎")
        else {
            println!("No match found");
            return;
        };
    println!("{}", result.as_str());
}

fn main() {
    uh();
    oh();
    allah_akbar();
}
