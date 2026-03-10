/*============================================*/
/*=== Test case 1                          ===*/
/*============================================*/

// Rust analyzer don't take tests into
// accound when analyzes usages of traits or
// structures.
#[allow(dead_code)]
trait SomeTrait {
    fn cheer(&self) -> String;
}

#[allow(dead_code)]
struct Cheer {
    buffer: String,
}

impl SomeTrait for Cheer {
    fn cheer(&self) -> String {
        String::from("Hi")
    }
}

/*============================================*/
/*=== Test case 2                          ===*/
/*============================================*/

#[allow(dead_code)]
struct Guess {
    value: i32,
}

#[allow(dead_code)]
impl Guess {
    pub fn new(value: i32) -> Guess {
        if value < 1 {
            panic!(
                "Guess value must be greater than or equal to 1, got {value}."
            );
        } else if value > 100 {
            panic!(
                "Guess value must be less than or equal to 100, got {value}."
            );
        }

        Guess { value }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    /*============================================*/
    /*=== Test case 1                          ===*/
    /*============================================*/
    #[test]
    fn test_case_1() {
        let c = Cheer {
            buffer: String::from("Uhhm")
        };

        println!("-- {} {}", c.cheer(), c.buffer);

        assert_eq!(c.cheer(), String::from("Hi"));
    }

    /*============================================*/
    /*=== Test case 2                          ===*/
    /*============================================*/
    #[test]
    #[should_panic(expected = "less than or equal to 100")]
    fn test_case_2() {
        Guess::new(200);
    }
}
