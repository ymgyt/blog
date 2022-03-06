use crate::gql::resolver::BlogEntry;
use async_graphql::{Context, Object, Result, ID};

pub struct Query;

#[Object]
impl Query {
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
}
