#[derive(Debug)]
struct Collection(Vec<i32>);

impl Collection {
    fn new() -> Collection {
        Collection(Vec::new())
    }

    fn add(&mut self, e: i32) {
        self.0.push(e);
    }
}

impl IntoIterator for Collection {
    type Item = i32;
    type IntoIter = std::vec::IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        self.0.into_iter()
    }
}

fn main() {
    let mut c = Collection::new();
    c.add(10);
    c.add(20);
    c.add(30);

    for n in c {
        println!("{n}");
    }
}
