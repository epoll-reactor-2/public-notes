struct User {
    active: bool,
    username: String,
    email: String,
    sign_in_count: u64,
}

struct Color(i32, i32, i32);
struct Point(i32, i32, i32);

struct Empty;

fn build_user(email: String, username: String) -> User {
    User {
        active: true,
        /* Use so called shorthands if parameter
         * match with the name. */
        /* username: */ username,
        /* email: */ email,
        sign_in_count: 1,
    }
}

#[derive(Debug)]
struct Rectangle {
    width: u32,
    height: u32,
}

fn derive_debug_usage() {
    let scale = 2;
    let rect1 = Rectangle {
        width: dbg!(30 * scale),
        height: 50,
    };

    dbg!(&rect1);
}

fn main() {
    let _user1 = build_user(
        String::from("email@gmail.com"),
        String::from("uname")
    );

    let _user2 = User {
        email: String::from("e@mail.com"),
        /* Copy the rest from user1 */
        .._user1
    };

    let _color = Color(0, 0, 0);
    let _point = Point(0, 1, 2);
    let _empty = Empty;

    derive_debug_usage();
}
