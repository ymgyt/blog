#[derive(Debug)]
pub struct Section {
    heading: Heading,
    elements: Vec<Element>,
}

#[derive(Debug)]
pub struct Heading {
    level: HeadingLevel,
}

#[derive(Debug, Clone, Copy, PartialEq, PartialOrd)]
pub enum HeadingLevel {
    Level1,
    Level2,
    Level3,
    Level4,
    Level5,
    Level6,
}

#[derive(Debug)]
pub enum Element {
    Text(Text),
    Link(Link),
    NewLine,
    Image,
}

#[derive(Debug)]
pub struct Text;

#[derive(Debug)]
pub struct Link;

#[derive(Debug)]
pub struct Image;
