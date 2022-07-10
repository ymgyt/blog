use std::fmt;
use std::fmt::Formatter;

use crate::domain::shared::Time;

/// Represents entry status.
#[derive(Debug, Clone, PartialEq)]
pub enum EntryStatus {
    /// In the process of writing.
    Draft,
    /// Entry is published.
    Published {
        /// Published time.
        at: Time,
    },
}

impl fmt::Display for EntryStatus {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        match self {
            EntryStatus::Draft => write!(f, "Draft"),
            EntryStatus::Published { .. } => write!(f, "Published"),
        }
    }
}
