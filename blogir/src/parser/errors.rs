use nom::error::ErrorKind;
use nom::Err;

#[derive(Debug, thiserror::Error, PartialEq)]
pub enum ParseError<'a> {
    #[error("invalid heading level {0}")]
    InvalidHeadingLevel(usize),
    #[error("parse error")]
    Nom(&'a str, ErrorKind),
}

impl<'a> ParseError<'a> {
    pub(super) fn invalid_heading_level(level: usize) -> Self {
        ParseError::InvalidHeadingLevel(level)
    }
}

impl<'a> nom::error::ParseError<&'a str> for ParseError<'a> {
    fn from_error_kind(input: &'a str, kind: ErrorKind) -> Self {
        ParseError::Nom(input, kind)
    }

    fn append(_input: &'a str, _kind: ErrorKind, other: Self) -> Self {
        other
    }
}
