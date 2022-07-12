mod heading;
pub use heading::{Heading, HeadingLevel};

mod inline_code;
pub use inline_code::InlineCode;

mod new_line;
pub use new_line::NewLine;

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
    PlainText(PlainText),
    InlineCode(InlineCode),
    Link(Link),
    NewLine(NewLine),
    BlankLine(BlankLine),
    Image(Image),
    OrderedList(OrderedList),
    UnOrderedList(UnOrderedList),
    Quote(Quote),
    CodeBlock(CodeBlock),
}

#[derive(Debug)]
pub struct PlainText;

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

#[derive(Debug)]
pub struct BlankLine;
