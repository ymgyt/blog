use async_graphql::Object;

pub struct QueryRoot;

#[Object]
impl QueryRoot {
    async fn add(&self, x: i64, y: i64) -> i64 {
        x + y
    }
}
