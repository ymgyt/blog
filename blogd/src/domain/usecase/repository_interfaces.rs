use async_trait::async_trait;

use crate::domain::model::BlogEntry;
use crate::domain::usecase::{BlogEntriesError, UsecaseError};

#[async_trait]
pub trait BlogEntryRepository {
    async fn find_blog_entries(&self) -> Result<Vec<BlogEntry>, UsecaseError<BlogEntriesError>>;
}
