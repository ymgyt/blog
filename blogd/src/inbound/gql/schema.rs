use crate::domain::usecase::mock::MockUsecase;
use crate::inbound::gql::query::Query;

pub(crate) type AppSchema<U = MockUsecase> =
    async_graphql::Schema<Query<U>, async_graphql::EmptyMutation, async_graphql::EmptySubscription>;
pub(crate) type AppSchemaBuilder<U = MockUsecase> = async_graphql::SchemaBuilder<
    Query<U>,
    async_graphql::EmptyMutation,
    async_graphql::EmptySubscription,
>;

pub(crate) fn build_schema() -> AppSchemaBuilder {
    AppSchema::build(
        Query::new(),
        async_graphql::EmptyMutation,
        async_graphql::EmptySubscription,
    )
}

pub fn print_sdl() -> String {
    build_schema().finish().sdl()
}
