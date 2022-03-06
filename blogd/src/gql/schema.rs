use crate::gql::query::Query;

pub type AppSchema =
    async_graphql::Schema<Query, async_graphql::EmptyMutation, async_graphql::EmptySubscription>;
pub type AppSchemaBuilder = async_graphql::SchemaBuilder<
    Query,
    async_graphql::EmptyMutation,
    async_graphql::EmptySubscription,
>;

pub fn build_schema() -> AppSchemaBuilder {
    AppSchema::build(
        Query,
        async_graphql::EmptyMutation,
        async_graphql::EmptySubscription,
    )
}
