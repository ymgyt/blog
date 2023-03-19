+++
title = "🦀  RustでGitHub GraphQL APIを使ってissue一覧を取得する"
slug = "fetch-issues-using-github-graphql-api-in-rust"
description = "graphql-clientを使ってrustからgraphqlを利用する方法について"
date = "2023-03-20"
draft = false
[taxonomies]
tags = ["rust"]
[extra]
image = "images/emoji/crab.png"
+++
 
この記事では[graphql-client](https://github.com/graphql-rust/graphql-client)を使ってRustから[GitHub GraphQL API](https://docs.github.com/en/graphql)を利用する方法について書きます。  
実際に作成したcliは[こちら。](https://github.com/ymgyt/gh-report-gen)

## 準備  

GraphQL APIを利用するためにGithub Personal access tokens (PAT)が必要です。  
本記事ではUserのissue一覧を取得するのでScopeはrepoが必要となります。  
2023/03/20現在、fine-grained personal access tokenはGraphQL APIではサポートされていません。  

> The GraphQL API does not support authentication with fine-grained personal access tokens.  

以下では、作成したPATが環境変数に設定されていることを前提にしています。  

```sh
export GH_PAT=$(cat ./github_pat)
```

## graphql-clientの利用方法  

### Schemaの取得  

まずGraphQL APIのschemaを取得します。  
graphql-clientはcliも提供してくれており、`cargo install graphq_client`でinstallできます。  
schemaの取得方法はなんでもよいのですが、上記のcliを使う場合は以下のコマンドを実行します。  

```sh
graphql-client introspect-schema https://api.github.com/graphql \
    --header "Authorization: bearer ${GH_PAT}" \
    --header "user-agent: rust-graphql-client" > ./schema.json
```

### Queryの作成  

次にRustから実行したいqueryを書きます。  
まずsimpleにPATを作成したuserを取得するqueryを書いてみます。  

```graphql
query Authenticate {
  viewer {
    login,
  }
}
```

`viewer` queryの[doc](https://docs.github.com/en/graphql/reference/queries#viewer)を参照するとThe username used to loginとして`login`が取得できるとわかるのでそれを取得します。


### Rustの型生成

Schemaとqueryが揃ったので、graphql-clientを利用して、request/response型を生成します。  
 
```rust
use graphql_client::GraphQLQuery;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "src/github/gql/schema.json",
    query_path = "src/github/gql/query.graphql",
    variables_derives = "Debug",
    response_derives = "Debug"
)]
pub struct Authenticate;
```

`src/github/gql/query.rs`に上記のように定義します。  
`schema_path`と`query_path`にはさきほど準備した、schema fileとquery fileのpathを記載します。project root(Cargo.toml)からの相対pathです。
`Authenticate` structが`query Authenticate`と一致させます。これはgraphql-client側の約束事です。  
`#[derive(GraphQLQuery)]`を定義すると`Authenticate`にmethodが生成され、`authenticate` moduleが作成され、queryに対応する型が生成されます。  
`{variables,response}_derives`は生成される型に定義したいderiveの指定です。今回は`Debug`を生やしています。


### Requestの実行

これで準備が揃ったので実際にrequestを実行していきましょう。  
まずは、`GithubClient`を定義します。

```rust
use reqwest::header::{self, HeaderMap, HeaderValue};
use crate::github::Pat;

pub struct GithubClient {
    inner: reqwest::Client,
}

impl GithubClient {
    const ENDPOINT: &str = "https://api.github.com/graphql";

    /// Construct GithubClient.
    pub fn new(pat: Option<Pat>) -> anyhow::Result<Self> {
        let user_agent = concat!(env!("CARGO_PKG_NAME"), "/", env!("CARGO_PKG_VERSION"),);

        let mut headers = HeaderMap::new();

        if let Some(pat) = pat {
            let mut token = HeaderValue::try_from(format!("bearer {}", pat.into_inner()))?;
            token.set_sensitive(true);
            headers.insert(header::AUTHORIZATION, token);
        }

        let inner = reqwest::ClientBuilder::new()
            .user_agent(user_agent)
            .default_headers(headers)
            .timeout(Duration::from_secs(10))
            .connect_timeout(Duration::from_secs(10))
            .build()?;

        Ok(Self { inner })
    }
}
``` 

http clientには`reqwest`を利用します。  
PATは`authorization` headerに設定します。  
Apiのendpointは`https://api.github.com/graphql`です。  

Authenticate queryを実行する処理は以下のように定義しました。  

```rust
use crate::github::gql::query;

impl GithubClient {
  /// Authenticated by current pat token, return github user name.
    pub async fn authenticate(&self) -> anyhow::Result<String> {
        let variables = query::authenticate::Variables {};
        let req = query::Authenticate::build_query(variables);
        let res: query::authenticate::ResponseData = self.request(&req).await?;

        Ok(res.viewer.login)
    }
}
```

今回利用するAuthenticate queryには引数がないので、空の`query::authenticate::Variables`を利用します。  
これは生成された型なので、queryを更新するとfieldが自動で追加されます。  
次に、`query::Authenciate`に生成された`build_query()`を利用してrequestを生成します。  
後はこのrequestをjsonでencodeするだけです。

```rust
use graphql_client::Response;

impl GithubClient {

  #[tracing::instrument(
        level = tracing::Level::TRACE,
        skip(self),
        ret,
    )]
    async fn request<Body, ResponseData>(&self, body: &Body) -> anyhow::Result<ResponseData>
    where
        Body: Serialize + ?Sized + Debug,
        ResponseData: DeserializeOwned + Debug,
    {
        let res: Response<ResponseData> = self
            .inner
            .post(Self::ENDPOINT)
            .json(&body)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        match (res.data, res.errors) {
            (_, Some(errs)) if !errs.is_empty() => {
                for err in errs {
                    error!("{err:?}");
                }
                Err(anyhow::anyhow!("failed to request github api"))
            }
            (Some(data), _) => Ok(data),
            _ => Err(anyhow::anyhow!("unexpected response",)),
        }
    }
}
```

requestの共通処理です。  
`graphql_client::Response`はgraphqlのresponseを表しており、以下のように定義されています。  

```rust

pub struct Response<Data> {
    pub data: Option<Data>,
    pub errors: Option<Vec<Error>>,
    pub extensions: Option<HashMap<String, Value>>,
}
```

`ResponseData`はqueryごとのresponseで、queryに応じて生成されます。  
今回のqueryは

```graphql
query Authenticate {
  viewer {
    login,
  }
}
```

のように定義したので、`res.viewer.login`のようにaccessできます。直感的ですね。


### Issue一覧の取得

requestの処理の流れがわかったので、issue一覧を取得してみます。
queryを以下のように定義しました。

```graphql
query Issues(
  $user: String!, 
  $since: DateTime!,
  $after: String,
  $first: Int = 20,
){
  viewer {
    login,
    issues(
      filterBy: { assignee: $user since: $since }, 
      orderBy: { direction: ASC, field: CREATED_AT },
      first: $first, 
      after: $after,
    ) {
      totalCount,
      pageInfo {
        endCursor,
        hasNextPage,
      },
      nodes {
        assignees(first: 10) {
          nodes {
            login,
          },
        },
        closed,
        closedAt,
        createdAt,
        updatedAt,
        number,
        repository {
          name,
          owner {
            __typename,
            login,
          },
        },
        state,
        title,
        url,
        labels(orderBy: { direction:ASC, field: NAME }, first: 10) {
          nodes {
            name,
          },
        },
        trackedIssuesCount,
        trackedClosedIssuesCount: trackedIssuesCount(states: [CLOSED]),
      }
    }
  }
}
```

`viewer.issues`のargument`filterBy`に`assignee`で先程取得した`viewer.login`を指定します。また、`since`を指定すると指定された時点以降に作成/更新されたissueのみが対象となります。  
`Issues`  queryの引数`$since`で指定した`DateTime!`はGitHub schemaで定義された型です。  
このqueryをRustから使うには以下のように定義します。  

```rust
use graphql_client::GraphQLQuery;

use crate::github::gql::scaler::*;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "src/github/gql/schema.json",
    query_path = "src/github/gql/query.graphql",
    variables_derives = "Debug",
    response_derives = "Debug"
)]
pub struct Issues;
```

`use crate::github::gql::scaler::*;`に着目してください。これはgraphql-clientがscaler型をサポートするための仕組みで、`#[derive(GraphQLQuery)]`を書いたscopeで、`DateTime`型を解決するために追加しています。  

`src/github/gql/mod.rs`に以下のようにscaler moduleを定義しました。(別fileにしてもいいです)  

```rust
pub(super) mod scaler {
    use serde::{Deserialize, Serialize};

    #[allow(clippy::upper_case_acronyms)]
    pub type URI = String;

    #[derive(Serialize, Deserialize, Debug)]
    pub struct DateTime(String);

    impl From<&chrono::DateTime<chrono::Utc>> for DateTime {
        fn from(value: &chrono::DateTime<chrono::Utc>) -> Self {
            DateTime(value.to_rfc3339())
        }
    }

    impl TryFrom<DateTime> for chrono::DateTime<chrono::Utc> {
        type Error = chrono::ParseError;

        fn try_from(value: DateTime) -> Result<Self, Self::Error> {
            chrono::DateTime::parse_from_rfc3339(value.0.as_str()).map(Into::into)
        }
    }
}
```

`URI`型は、responseに`URI` scaler typeが指定されているため必要になります。  
このようにschema側で定義されたcustom scalerに対応する型をRustで定義ないしuseして使うことができます。  
GitHubの場合、`DateTime`型はRFC3339 formatであるとのことだったので、`chrono`を利用してparseしています。  
`URI`も`String`でなく、`http::Url`型等を利用してもよいと思います。  

この`Issues` queryをRustから利用する処理が以下です。  


```rust
use chrono::{DateTime, Utc};
use crate::github::gql::query;

impl GithubClient {
    pub async fn query_issues(
        &self,
        gh_user: impl Into<String>,
        since: &DateTime<Utc>,
        cursor: Option<String>,
    ) -> anyhow::Result<query::issues::ResponseData> {
        let variables = query::issues::Variables {
            user: gh_user.into(),
            since: since.into(),
            after: cursor,
            first: Some(100),
        };
        let req = query::Issues::build_query(variables);
        let res: query::issues::ResponseData = self.request(&req).await?;

        Ok(res)
    }
}
```

今回のqueryではinputがあるので、対応するfieldが`query::issues::Variables`に生成されています。  
query側のoptionalは`Option`で表現されています。  
今回のtoolでは全件取得したいので、以下の処理を追加しました。

```rust
impl GithubClient {
    pub async fn query_issues_all(
        &self,
        gh_user: impl Into<String>,
        since: &DateTime<Utc>,
    ) -> anyhow::Result<Vec<query::issues::IssuesViewerIssuesNodes>> {
        let gh_user = gh_user.into();
        let since = since;
        let mut cursor = None;
        let mut issues = Vec::new();

        loop {
            let res = self.query_issues(&gh_user, since, cursor).await?;
            if let Some(new_issues) = res.viewer.issues.nodes {
                issues.extend(new_issues.into_iter().flatten());
            }

            if !res.viewer.issues.page_info.has_next_page {
                break;
            }
            cursor = res.viewer.issues.page_info.end_cursor;
        }

        Ok(issues)
    }
}
```


## まとめ

簡単ではありますが、Rustからgraphql-clientを利用してGraphQL APIを利用することができました。  
queryは素のGraphQLを書いて結果に対応する型をRust側に生成するという形が使いやすいと思いました。  
今回のcodeは`gh-report-gen`というtoolを作成する際に書きました。  

```sh
cargo install gh-report-gen

gh-report-gen --include myorg/* --exclude myorg/foo --since "2023-03-01T00:00:00+09:00"  
```

のように利用できるので、最近やったissueを一覧にしてmarkdownにしたいみたいなユースケースでよかったら使ってください。