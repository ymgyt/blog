#[derive(Debug, Clone, PartialEq)]
pub struct Heading {
    level: HeadingLevel,
    text: String,
}

impl Heading {
    // NOTE: want to guarantee text is not empty.
    pub fn new(level: HeadingLevel, text: impl Into<String>) -> Self {
        let text = text.into();
        debug_assert!(!text.is_empty());

        Self { level, text }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, PartialOrd)]
pub struct HeadingLevel(u8);

impl HeadingLevel {
    pub fn new(level: usize) -> Option<Self> {
        let level = match level {
            1..=6 => level as u8,
            _ => return None,
        };
        Some(HeadingLevel(level))
    }

    pub fn as_u8(&self) -> u8 {
        self.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_heading_level() {
        assert_eq!(HeadingLevel::new(0), None);
        assert_eq!(HeadingLevel::new(7), None);
        assert_eq!(HeadingLevel::new(1).unwrap().as_u8(), 1);
    }
}
