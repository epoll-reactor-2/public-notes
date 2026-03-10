fn oh() {
    let a: i32 = 5;
    let b: &i32 = &a;
    let c: &&i32 = &b;
    let d: &&&i32 = &c;
    let e: &&&&i32 = &d;
    let f: &&&&&i32 = &e;
    let g: &&&&&&i32 = &f;
    let h: &&&&&&&i32 = &g;
    let i: &&&&&&&&i32 = &h;
    let j: &&&&&&&&&i32 = &i;
    let k: &&&&&&&&&&i32 = &j;
    let l: &&&&&&&&&&&i32 = &k;
    let m: &&&&&&&&&&&&i32 = &l;
    let n: &&&&&&&&&&&&&i32 = &m;
    let o: &&&&&&&&&&&&&&i32 = &n;
    let p: &&&&&&&&&&&&&&&i32 = &o;
    let q: &&&&&&&&&&&&&&&&i32 = &p;
    let r: &&&&&&&&&&&&&&&&&i32 = &q;
    let s: &&&&&&&&&&&&&&&&&&i32 = &r;
    let t: &&&&&&&&&&&&&&&&&&&i32 = &s;
    let u: &&&&&&&&&&&&&&&&&&&&i32 = &t;
    let v: &&&&&&&&&&&&&&&&&&&&&i32 = &u;
    let w: &&&&&&&&&&&&&&&&&&&&&&i32 = &v;
    let x: &&&&&&&&&&&&&&&&&&&&&&&i32 = &w;
    let y: &&&&&&&&&&&&&&&&&&&&&&&&i32 = &x;
    let z: &&&&&&&&&&&&&&&&&&&&&&&&&i32 = &y;

    println!("{z}");
    let result = *************************z;
    println!("{result}");
}

fn uh() {
    trait Hurts {
        fn hurts(&self);
    }

    impl<T: Hurts> Hurts for &T {
        fn hurts(&self) {
            println!("It hurts");
            (*self).hurts();
        }
    }

    impl Hurts for i32 {
        fn hurts(&self) {
            println!("Done hurting");
        }
    }

    let v = &&&&&&&&&&&&&&&&&&&&&&&5;
    v.hurts();
}

fn main() {
    oh();
    uh();
}

