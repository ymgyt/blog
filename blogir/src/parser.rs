use nom::character::complete::{char, newline, not_line_ending};
use nom::error::ErrorKind;
use nom::sequence::terminated;
use nom::{combinator, multi, sequence};
use nom::{IResult, Parser as _};

use std::fmt;
use std::fmt::Formatter;

use crate::parser::errors::ParseError;
use crate::{Document, Heading, HeadingLevel};

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

fn heading(input: &str) -> NomResult<Heading> {
    sequence::separated_pair(
        heading_level,
        char(' '),
        terminated(not_line_ending, newline),
    )
    .map(|(level, text)| Heading::new(level, text))
    .parse(input)
}

#[cfg(test)]
mod tests {
    use super::*;

    macro_rules! heading_gen {
        ($level:expr, $text:expr) => {{
            let level: HeadingLevel = HeadingLevel::new($level).unwrap();
            Heading::new(level, $text)
        }};
    }

    #[test]
    fn should_parse_valid_heading_level() {
        assert_eq!(
            heading_level("# "),
            Ok((" ", HeadingLevel::new(1).unwrap()))
        );
        assert_eq!(
            heading_level("## "),
            Ok((" ", HeadingLevel::new(2).unwrap()))
        );
        assert_eq!(
            heading_level("### "),
            Ok((" ", HeadingLevel::new(3).unwrap()))
        );
        assert_eq!(
            heading_level("#### "),
            Ok((" ", HeadingLevel::new(4).unwrap()))
        );
        assert_eq!(
            heading_level("##### "),
            Ok((" ", HeadingLevel::new(5).unwrap()))
        );
        assert_eq!(
            heading_level("###### "),
            Ok((" ", HeadingLevel::new(6).unwrap()))
        );
    }

    #[test]
    fn should_fail_invalid_heading_level() {
        assert_eq!(
            heading_level("#".repeat(7).as_str()),
            Err(nom::Err::Failure(ParseError::InvalidHeadingLevel(7))),
        );
    }

    #[test]
    fn should_parse_heading() {
        assert_eq!(
            heading("# Hello blogir!\n\ncontent..."),
            Ok(("\ncontent...", heading_gen!(1, "Hello blogir!"))),
        );
        assert_eq!(
            heading("# 見出し1\n\ncontent..."),
            Ok(("\ncontent...", heading_gen!(1, "見出し1"))),
        );
    }
}
