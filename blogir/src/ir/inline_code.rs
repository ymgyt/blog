#[derive(Debug, PartialEq)]
pub struct InlineCode {
    code: String,
}

impl InlineCode {
    pub fn new(code: impl Into<String>) -> Self {
        let code = code.into();
        Self { code }
    }
}
