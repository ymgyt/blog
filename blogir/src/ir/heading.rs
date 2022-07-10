#[derive(Debug)]
pub struct Heading {
    level: HeadingLevel,
}

impl Heading {
    pub fn new(level: HeadingLevel) -> Self {
        Self { level }
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
