use async_graphql::SimpleObject;

/// BlogEntry is a main contents which author write.
#[derive(SimpleObject)]
pub struct BlogEntry {
    /// Title of this entry.
    pub title: String,
    pub body: String,
}
