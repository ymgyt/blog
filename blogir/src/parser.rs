use nom::character::complete::{char, newline, not_line_ending};
use nom::error::ErrorKind;
use nom::sequence::terminated;
use nom::{combinator, multi, sequence};
use nom::{IResult, Parser as _};

use nom::bytes::complete::{tag, take_until1};
use std::fmt;
use std::fmt::Formatter;

use crate::parser::errors::ParseError;
use crate::{Document, Heading, HeadingLevel, InlineCode, NewLine};

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

fn inline_code(input: &str) -> NomResult<InlineCode> {
    sequence::delimited(char('`'), take_until1("`"), char('`'))
        .map(|inline_code| InlineCode::new(inline_code))
        .parse(input)
}

fn new_line(input: &str) -> NomResult<NewLine> {
    sequence::tuple((char(' '), char(' '), newline))
        .map(|_| NewLine::new())
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

    #[test]
    fn should_parse_inline_code() {
        assert_eq!(
            inline_code("`Result<T,E>`"),
            Ok(("", InlineCode::new("Result<T,E>"))),
        );
    }

    #[test]
    fn should_parse_new_line() {
        assert_eq!(new_line("  \ncontent"), Ok(("content", NewLine::new())),);
    }
}
