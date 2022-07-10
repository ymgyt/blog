use uuid::Uuid;

use crate::domain::blog::entry::content::EntryContentId;
use crate::domain::blog::entry::status::EntryStatus;
use crate::domain::shared::Time;

mod content;
mod status;

/// Represent BlogEntry.
#[derive(Debug)]
pub struct Entry {
    /// Entry identifier.
    id: EntryId,
    /// Entry current status.
    status: EntryStatus,
    title: String,
    created_at: Time,
    last_updated_at: Time,
    content_id: EntryContentId,
}

#[derive(Debug, Clone, Copy, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct EntryId(Uuid);
