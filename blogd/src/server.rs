use std::{
    future::Future,
    net::{SocketAddr, TcpListener},
};

use async_graphql::{
    http::{playground_source, GraphQLPlaygroundConfig},
    EmptyMutation, EmptySubscription,
};
use async_graphql_axum::{GraphQLRequest, GraphQLResponse};
use axum::{
    extract::Extension,
    response::{self, IntoResponse},
    routing::{get, post},
    AddExtensionLayer, Router,
};
use tower_http::trace::TraceLayer;
use tracing::info;

use crate::gql::{AppSchema, QueryRoot};

async fn graphql_handler(schema: Extension<AppSchema>, req: GraphQLRequest) -> GraphQLResponse {
    schema.execute(req.into_inner()).await.into()
}

async fn graphql_playground() -> impl IntoResponse {
    response::Html(playground_source(GraphQLPlaygroundConfig::new(
        "/graphql/playground",
    )))
}

async fn healthcheck() -> &'static str {
    "OK"
}

async fn sdl(schema: Extension<AppSchema>) -> impl IntoResponse {
    schema.sdl()
}

pub async fn run(
    addr: impl Into<SocketAddr>,
    shutdown: impl Future<Output = ()>,
) -> Result<(), anyhow::Error> {
    let addr = addr.into();
    let listener = std::net::TcpListener::bind(addr)?;

    info!(?addr, "listening");

    run_with_listener(listener, shutdown).await
}

pub async fn run_with_listener(
    listener: TcpListener,
    shutdown: impl Future<Output = ()>,
) -> Result<(), anyhow::Error> {
    let schema = AppSchema::build(QueryRoot, EmptyMutation, EmptySubscription).finish();

    let app = Router::new()
        .route("/graphql", post(graphql_handler))
        .route("/graphql/playground", get(graphql_playground))
        .route("/graphql/sdl", get(sdl))
        .route("/healthcheck", get(healthcheck))
        .layer(
            tower::ServiceBuilder::new()
                .layer(TraceLayer::new_for_http().on_request(
                    |request: &axum::http::Request<_>, _: &tracing::Span| {
                        tracing::info!(?request);
                    },
                ))
                .layer(AddExtensionLayer::new(schema)),
        );

    axum::Server::from_tcp(listener)?
        .serve(app.into_make_service())
        .with_graceful_shutdown(shutdown)
        .await
        .map_err(anyhow::Error::from)
}
