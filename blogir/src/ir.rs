mod heading;
pub use heading::{Heading, HeadingLevel};

#[derive(Debug)]
pub struct Document {
    sections: Vec<Section>,
}

#[derive(Debug)]
pub struct Section {
    heading: Heading,
    elements: Vec<Element>,
}

#[derive(Debug)]
pub enum Element {
    Text(Text),
    Link(Link),
    NewLine,
    Image(Image),
    OrderedList(OrderedList),
    UnOrderedList(UnOrderedList),
    Quote(Quote),
    CodeBlock(CodeBlock),
}

#[derive(Debug)]
pub struct Text;

#[derive(Debug)]
pub struct Link;

#[derive(Debug)]
pub struct Image;

#[derive(Debug)]
pub struct OrderedList;

#[derive(Debug)]
pub struct UnOrderedList;

#[derive(Debug)]
pub struct Quote;

#[derive(Debug)]
pub struct CodeBlock;
