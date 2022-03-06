use async_trait::async_trait;

use crate::domain::model::BlogEntry;
use crate::domain::usecase::{BlogEntryRepository, UsecaseError};

#[derive(thiserror::Error, Debug)]
pub enum BlogEntriesError {}

#[async_trait]
pub trait BlogEntriesUsecase {
    async fn find_blog_entries(&self) -> Result<Vec<BlogEntry>, UsecaseError<BlogEntriesError>>;
}

pub struct BlogEntriesImpl<R> {
    repo: R,
}

impl<R> BlogEntriesImpl<R> {
    pub fn new(repo: R) -> Self {
        Self { repo }
    }
}

#[async_trait]
impl<R> BlogEntriesUsecase for BlogEntriesImpl<R>
where
    R: BlogEntryRepository + Send + Sync + 'static,
{
    async fn find_blog_entries(&self) -> Result<Vec<BlogEntry>, UsecaseError<BlogEntriesError>> {
        self.repo.find_blog_entries().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::model::*;
    use crate::domain::usecase::{mock::MockUsecase, Usecase};

    #[tokio::test]
    async fn find() -> anyhow::Result<()> {
        let u = MockUsecase::new().find_blog_entries();

        assert_eq!(u.find().await?, vec![BlogEntry::new("entry1", "hello")]);
        Ok(())
    }
}
