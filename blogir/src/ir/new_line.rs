#[derive(Debug, PartialEq)]
pub struct NewLine(());

impl NewLine {
    pub fn new() -> Self {
        Self(())
    }
}
