use crate::inbound::gql;

#[derive(Debug, PartialEq)]
pub struct BlogEntry {
    title: String,
    body: String,
}

impl BlogEntry {
    pub fn new(title: impl Into<String>, body: impl Into<String>) -> BlogEntry {
        Self {
            title: title.into(),
            body: body.into(),
        }
    }
}

impl From<BlogEntry> for gql::BlogEntry {
    fn from(entity: BlogEntry) -> Self {
        gql::BlogEntry {
            title: entity.title,
            body: entity.body,
        }
    }
}
