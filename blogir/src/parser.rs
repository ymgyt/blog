use nom::character::complete::char;
use nom::multi;
use nom::IResult;

use nom::error::ErrorKind;
use std::fmt;
use std::fmt::Formatter;

use crate::parser::errors::ParseError;
use crate::{Document, HeadingLevel};

mod errors;

#[derive(Default)]
pub struct Parser(());

impl Parser {
    pub fn parse(&self, text: &str) -> Result<Document, ParseError> {
        todo!()
    }
}

type NomResult<'a, O = &'a str> = IResult<&'a str, O, ParseError<'a>>;

fn heading_level(input: &str) -> NomResult<HeadingLevel> {
    let (remain, level) = multi::many1_count(char('#'))(input)?;
    match HeadingLevel::new(level) {
        Some(level) => Ok((remain, level)),
        None => Err(nom::Err::Failure(ParseError::invalid_heading_level(level))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_parse_valid_heading_level() {
        assert_eq!(heading_level("#"), Ok(("", HeadingLevel::new(1).unwrap())));
        assert_eq!(heading_level("##"), Ok(("", HeadingLevel::new(2).unwrap())));
        assert_eq!(
            heading_level("###"),
            Ok(("", HeadingLevel::new(3).unwrap()))
        );
        assert_eq!(
            heading_level("####"),
            Ok(("", HeadingLevel::new(4).unwrap()))
        );
        assert_eq!(
            heading_level("#####"),
            Ok(("", HeadingLevel::new(5).unwrap()))
        );
        assert_eq!(
            heading_level("######"),
            Ok(("", HeadingLevel::new(6).unwrap()))
        );
    }

    #[test]
    fn should_fail_invalid_heading_level() {
        assert_eq!(
            heading_level("#".repeat(7).as_str()),
            Err(nom::Err::Failure(ParseError::InvalidHeadingLevel(7))),
        )
    }
}
