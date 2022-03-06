mod blog_entries;
pub use blog_entries::*;

mod errors;
pub use errors::*;

mod repository_interfaces;
pub use repository_interfaces::*;

pub trait Usecase {
    type BlogEntries: BlogEntriesUsecase + Send + Sync + 'static;

    fn blog_entries(&self) -> Self::BlogEntries;
}

// #[cfg(test)]
pub(crate) mod mock {
    use super::*;
    use crate::domain::model::*;
    use async_trait::async_trait;

    pub(crate) struct MockBlogEntryRepository {}

    #[async_trait]
    impl BlogEntryRepository for MockBlogEntryRepository {
        async fn find_blog_entries(
            &self,
        ) -> Result<Vec<BlogEntry>, UsecaseError<BlogEntriesError>> {
            Ok(vec![BlogEntry::new("entry1", "hello")])
        }
    }

    pub(crate) struct MockUsecase;

    impl MockUsecase {
        pub(crate) fn new() -> Self {
            Self
        }
    }

    impl Usecase for MockUsecase {
        type BlogEntries = BlogEntriesImpl<MockBlogEntryRepository>;

        fn blog_entries(&self) -> Self::BlogEntries {
            BlogEntriesImpl::new(MockBlogEntryRepository {})
        }
    }
}
