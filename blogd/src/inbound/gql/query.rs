use std::marker::PhantomData;

use async_graphql::{Context, Object, Result, ID};

use crate::domain::usecase::{BlogEntriesUsecase, Usecase};
use crate::inbound::gql::resolver::BlogEntry;

pub struct Query<U> {
    _phantom: PhantomData<U>,
}

impl<U> Query<U> {
    pub fn new() -> Self {
        Self {
            _phantom: PhantomData,
        }
    }
}

#[Object]
impl<U> Query<U>
where
    U: Usecase + Send + Sync + 'static,
{
    async fn blog_entry<'ctx>(
        &self,
        _ctx: &Context<'ctx>,
        #[graphql(desc = "Id of object")] _id: ID,
    ) -> Result<BlogEntry> {
        Ok(BlogEntry {
            title: "entry1".into(),
            body: "hello".into(),
        })
    }

    async fn blog_entries<'ctx>(
        &self,
        ctx: &Context<'ctx>,
        _after: Option<String>,
        _first: Option<i32>,
    ) -> Result<Vec<BlogEntry>> {
        let usecase = ctx.data::<U>()?.blog_entries();
        usecase
            .find_blog_entries()
            .await
            .map(|blog_entries| {
                blog_entries
                    .into_iter()
                    .map(|blog_entry| blog_entry.into())
                    .collect()
            })
            .map_err(|err| async_graphql::Error::new(format!("{:?}", err)))
    }
}
