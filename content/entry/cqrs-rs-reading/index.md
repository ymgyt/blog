+++
title = "📥 cqrs-esからみるRustのCQRS & Event Sourceの実装"
slug = "cqrs-rs-reading"
date = "2022-10-15"
draft = false
[taxonomies]
tags = ["rust"]
+++


最近会社で[This week in rust](https://this-week-in-rust.org/)ならぬThis week in fraimという会が週1で行われる様になりました。そこで[CQRS and Event Sourcing using Rust](https://doc.rust-cqrs.org/intro.html)というドキュメントを教えてもらいました。  
このドキュメントは[cqrs-rs](https://github.com/serverlesstechnology/cqrs)というRustのCQRS lightweight frameworkについて書かれており、RustにおけるCQRSの実装の具体例としてとても参考になりました。  
そこで本記事では、cqrs-rsとデモ実装である[cqrs-demo](https://github.com/serverlesstechnology/cqrs-demo)のコードを読んでRustにおけるCQRSの実装を追っていきます。

## 用語

本記事で利用する用語については以下の意味で利用します。

| 用語 | ここでの意味 |
| --- | --- |
| CQRS | application(domain)のmodelをwriteとreadに分けてるくらいの意味です。それぞれの永続化に利用するbackendも異なる場合もあります。   |
| Aggregate |  * DDDにおける集約のRoot<br> * 関連するEntityとValueObjectの集合。実質Entity<br> * 変更はAggregateに対してのみCommandを適用する形でのみなされる |
| Command   | Aggregateに対する作成/更新のリクエスト                                                                             |
| Event | Aggregateに対してCommandを適用した結果の表現      |


## 概要

{{ figure(caption="cqrs-rsの概要", images=["images/cqrs_overview.png"] )}}

全体の登場人物と処理の概要を説明します。  

1. CommandHandlerはRESTのhandlerやGraphQLのresolverのように外部から処理のリクエストをうけるレイヤーです。cqrs-esはこのレイヤーに特に関与しません。
2. EventStoreはwriteの永続化処理を担うコンポーネントです。EventStoreが処理対象のaggregateに関するeventをloadしてきます。
3. 永続化層から取得したeventsをaggregateに適用します。これによりaggregateが最新の状態になります。
4. 作成/更新を表現したCommandを適用します。
5. 成功した場合は新しいeventsが生成されます。
6. 生成されたeventsを永続化します。同時に発せられたcommandのようなreadModifyWrite(conflict)の処理はここで行います。
7. 永続化が成功したeventを関心のあるコンポーネントに届けるためにdispatchされます。
8. 一般的にはwriteに対応するreadのmodelを更新する処理が行われます
9. ClientからのReadの要求に対して更新されたviewを利用することで、commandの適用結果がみえるようになります。

以上が処理の概要になります。cqrs-esはこの処理の流れを提供してくれます。application全体に組み込まれるというよりaggregate(domain model)単位で利用できるところがlightweightと言われているところなのかなと思います。

### Aggregate

```rust
#[derive(Serialize, Deserialize)]
pub struct BankAccount {
    account_id: String,
    balance: f64,
}
```

[https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/aggregate.rs#L10](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/aggregate.rs#L10)

cqrs-demoで利用されるaggregateはBankAccountで識別子の`account_id`とcommandによって変化する`balance`をもっており、`balance`の変更にはドメインのルール(0以下にならない等)が適用されます。
### Command

```rust
#[derive(Debug, Serialize, Deserialize)]
pub enum BankAccountCommand {
    OpenAccount { account_id: String },
    DepositMoney { amount: f64 },
    WithdrawMoney { amount: f64, atm_id: String },
    WriteCheck { check_number: String, amount: f64 },
}
```

[https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/commands.rs#L4](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/commands.rs#L4)

`BankAccount` aggregateに対する変更要求です。  
作成とbalanceを変更するcommandが定義されています。  
enumを使うことがapiから強制されます。

### Event

```rust
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum BankAccountEvent {
    AccountOpened {
        account_id: String,
    },
    CustomerDepositedMoney {
        amount: f64,
        balance: f64,
    },
    CustomerWithdrewCash {
        amount: f64,
        balance: f64,
    },
    CustomerWroteCheck {
        check_number: String,
        amount: f64,
        balance: f64,
    },
}
```

[https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/events.rs#L6](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/events.rs#L6)

`BankAccount` aggregateに対してcommandを適用した結果起きるeventです。  
ここではcommandと発生するeventが1:1になっていますが、commandに対してeventが発生しない場合や複数起きる場合もあります。

### 1 execute

```rust
// pub type PostgresCqrs<A> = CqrsFramework<A, PersistedEventStore<PostgresEventRepository, A>>;

async fn command_handler(
    Path(account_id): Path<String>,
    Json(command): Json<BankAccountCommand>,
    Extension(cqrs): Extension<Arc<PostgresCqrs<BankAccount>>>,
    MetadataExtension(metadata): MetadataExtension,
) -> Response {
    match cqrs
        .execute_with_metadata(&account_id, command, metadata)
        .await
    {
        Ok(_) => StatusCode::NO_CONTENT.into_response(),
        Err(err) => (StatusCode::BAD_REQUEST, err.to_string()).into_response(),
    }
}
```

[https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/main.rs#L74](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/main.rs#L74)

[https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/metadata_extension.rs#L15](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/metadata_extension.rs#L15)

axumのhandlerでcommandをdeserializeしてaggregate(bank account)のcqrs instanceを呼び出すコードです。 リクエスト時にaggregateの識別子(`aggregate_id`), command(`BankAccountCommand`), cqrs instance(`PostgresCqrs<BankAccount>`)があればよいです。

MetadataExtensionはrequestからUseragentや現在時刻を付加する情報です。  
write層で永続化されるのはあくまでeventですが、auditや運用の観点から永続化したい情報(処理時刻やclient ip等)はmetadataとして表現します。

### 3 apply

```rust
use cqrs_es::Aggregate;

#[async_trait]
impl Aggregate for BankAccount {
    type Command = BankAccountCommand;
    type Event = BankAccountEvent;
    type Error = BankAccountError;
    type Services = BankAccountServices;

    // ... 
    fn apply(&mut self, event: Self::Event) {
        match event {
            BankAccountEvent::AccountOpened { account_id } => {
                self.account_id = account_id;
            }
            BankAccountEvent::CustomerDepositedMoney { amount: _, balance } => {
                self.balance = balance;
            }
            BankAccountEvent::CustomerWithdrewCash { amount: _, balance } => {
                self.balance = balance;
            }
            BankAccountEvent::CustomerWroteCheck {
                check_number: _,
                amount: _,
                balance,
            } => {
                self.balance = balance;
            }
        }
    }
}
```

[https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/aggregate.rs#L88](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/aggregate.rs#L88)

Eventをaggregateに適用して、状態を更新する。エラーは返せないので絶対に成功する。 
cqrs frameworkが過去のeventでapplyを呼んでくれるのでaggregateは最新の状態になる。  
また、各aggregateは`cqrs_es::Aggregate`を実装することが要求され、その中でCommand, Event,Error, Servicesをそれぞれassociate typeで指定する。  
CommandとEventはこれまで述べてきたもので、Errorはcommand適用時に発生するエラー。ServicesはCommand適用時の依存(api call等)。


### 4 handle

```rust
#[async_trait]
impl Aggregate for BankAccount {
    // ...
    async fn handle(
        &self,
        command: Self::Command,
        services: &Self::Services,
    ) -> Result<Vec<Self::Event>, Self::Error> {
        match command {
            BankAccountCommand::OpenAccount { account_id } => {
                Ok(vec![BankAccountEvent::AccountOpened { account_id }])
            }
            BankAccountCommand::DepositMoney { amount } => {
                let balance = self.balance + amount;
                Ok(vec![BankAccountEvent::CustomerDepositedMoney {
                    amount,
                    balance,
                }])
            }
            BankAccountCommand::WithdrawMoney { amount, atm_id } => {
                let balance = self.balance - amount;
                if balance < 0_f64 {
                    return Err("funds not available".into());
                }
                if services
                    .services
                    .atm_withdrawal(&atm_id, amount)
                    .await
                    .is_err()
                {
                    return Err("atm rule violation".into());
                };
                Ok(vec![BankAccountEvent::CustomerWithdrewCash {
                    amount,
                    balance,
                }])
            }
            BankAccountCommand::WriteCheck {
                check_number,
                amount,
            } => {
                let balance = self.balance - amount;
                if balance < 0_f64 {
                    return Err("funds not available".into());
                }
                if services
                    .services
                    .validate_check(&self.account_id, &check_number)
                    .await
                    .is_err()
                {
                    return Err("check invalid".into());
                };
                Ok(vec![BankAccountEvent::CustomerWroteCheck {
                    check_number,
                    amount,
                    balance,
                }])
            }
        }
    }
```

[https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/aggregate.rs#L29](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/domain/aggregate.rs#L29)

最新のaggregateに対してcommandをhandleすることでeventを算出する処理。引数は`&self` なのでaggregate自身の状態は更新できず更新はeventで表現する。


## CQRSFramework Components Diagram

{{ figure(caption="Component diagram", images=["images/cqrs_component_diagram.png"] )}}

1aggregateを担当する`CqrsFramework`のcomponent間の概要。  


- ユーザが実装するのは
    - `DynamoEventRepository` `PosgresEventRepository` といった永続化層からevent(SerializedEvent)のrecord/itemを取得する処理
        - Dynamo, Postgres, MySqlの実装はcqrsの別リポジトリで用意されている。
    - `Query` commitされて永続化に成功したeventを反映させる処理
- cqrs instanceの初期化処理
    - [https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/config.rs](https://github.com/serverlesstechnology/cqrs-demo/blob/424acda6e3256c7967ca0d8cea97fd580617721e/src/config.rs)

## CQRSFramework execute_with_metadata Sequence Diagram

{{ figure(caption="Sequence diagram", images=["images/cqrs_execute_sequence_diagram.png"]) }}

ユーザはaggregateに対してのapplyとhandleを定義すればあとの取り回しはframework側が行ってくれる。  
ただし、EventRepositoryの実装でeventのconflictを処理する必要がある。

### SerializedEvent

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SerializedEvent {
    /// The id of the aggregate instance.
    pub aggregate_id: String,
    /// The sequence number of the event for this aggregate instance.
    pub sequence: usize,
    /// The type of aggregate the event applies to.
    pub aggregate_type: String,
    /// The type of event that is serialized.
    pub event_type: String,
    /// The version of event that is serialized.
    pub event_version: String,
    /// The serialized domain event.
    pub payload: Value,
    /// Additional metadata, serialized from a HashMap<String,String>.
    pub metadata: Value,
}
```

[https://github.com/serverlesstechnology/cqrs/blob/master/src/persist/serialized_event.rs#L11](https://github.com/serverlesstechnology/cqrs/blob/master/src/persist/serialized_event.rs#L11)

各種Eventを直接serializeするのではなく、`SerializedEvent`という中間表現にして取り回す。  
したがって、writeの永続化ではmodelごとにtable(collection)を分けるのではなく一つのtableですべてのmodelのeventを永続化できる。(分けようと思えば分けれる)

### event_upcast

```rust
pub trait EventUpcaster: Send + Sync {
    /// Examines and event type and version to understand if the event should be upcasted.
    fn can_upcast(&self, event_type: &str, event_version: &str) -> bool;

    /// Modifies the serialized event to conform the the new structure.
    fn upcast(&self, event: SerializedEvent) -> SerializedEvent;
}

pub(crate) fn deserialize_events<A: Aggregate>(
    events: Vec<SerializedEvent>,
    upcasters: &Option<Vec<Box<dyn EventUpcaster>>>,
) -> Result<Vec<EventEnvelope<A>>, PersistenceError> {
    let mut result: Vec<EventEnvelope<A>> = Default::default();
    for event in events {
        let upcasted_event = match upcasters {
            None => event,
            Some(upcasters) => {
                let mut upcasted_event = event;
                for upcaster in upcasters {
                    if upcaster
                        .can_upcast(&upcasted_event.event_type, &upcasted_event.event_version)
                    {
                        upcasted_event = upcaster.upcast(upcasted_event)
                    }
                }
                upcasted_event
            }
        };
        result.push(EventEnvelope::<A>::try_from(upcasted_event)?);
    }
    Ok(result)
}

// impl example
/*
{
  "UpdateAddress": {
    "address": "912 Spring St",
    "city": "Seattle",
    "state": "WA"
  }
}
*/

let upcaster = SemanticVersionEventUpcaster::new("UpdateAddress", "0.3.0", Box::new(my_upcaster));

fn my_upcast_fn(mut payload: Value) -> Value {
    match payload.get_mut("UpdateAddress").unwrap() {
        Value::Object(object) => {
            object.insert("state".to_string(), Value::String("WA".to_string()));
            payload
        }
        _ => panic!("invalid payload encountered"),
    }
}
```

[https://github.com/serverlesstechnology/cqrs/blob/master/src/persist/serialized_event.rs#L61](https://github.com/serverlesstechnology/cqrs/blob/master/src/persist/serialized_event.rs#L61)

[https://doc.rust-cqrs.org/advanced_event_upcasters.html](https://doc.rust-cqrs.org/advanced_event_upcasters.html)

applicationを運用していく中でEventにfieldを追加したくなる場合の機構。enumなので、UpdateAddress,UpdateAddressV2のようにvariantを増やすこともできるがそうではなく、`SerializedEvent`をdeserializeする際に直接値を加工するレイヤーが用意されている。  
このあたりの考慮はCQRS独自のものだと思いました。

### events table

```sql
CREATE TABLE events
(
    aggregate_type text                         NOT NULL,
    aggregate_id   text                         NOT NULL,
    sequence       bigint CHECK (sequence >= 0) NOT NULL,
    event_type     text                         NOT NULL,
    event_version  text                         NOT NULL,
    payload        json                         NOT NULL,
    metadata       json                         NOT NULL,
    PRIMARY KEY (aggregate_type, aggregate_id, sequence)
);
```

具体例として`SerializedEvent`を永続化する場合のDDL。  
aggregate_type, aggregate_id, sequenceに対してprimary key(=一意性制約)が貼ってあるので、競合するeventの書き込みがエラーになる。  
このように永続化層に一意性制約が付与できれば実装はとても楽になる。

```rust
impl From<sqlx::Error> for PostgresAggregateError {
    fn from(err: sqlx::Error) -> Self {
        // TODO: improve error handling
        match &err {
            Error::Database(database_error) => {
                if let Some(code) = database_error.code() {
                    if code.as_ref() == "23505" { // 23505はPostgresにおける一意性制約違反
                        return PostgresAggregateError::OptimisticLock;
                    }
                }
                PostgresAggregateError::UnknownError(Box::new(err))
            }
            Error::Io(_) | Error::Tls(_) => PostgresAggregateError::ConnectionError(Box::new(err)),
            _ => PostgresAggregateError::UnknownError(Box::new(err)),
        }
    }
}
```

デモではPostgresの一意性制約違反をそのまま利用していた。  
Eventsの書き込み競合をPostgresの機能で解決しているのでCqrsFrameworkとしてはEventRepositoryの実装に競合の解決を委ねている。

[https://github.com/serverlesstechnology/postgres-es/blob/f99103368850689313b9b06a5c8762f4bc619ff2/src/error.rs#L28](https://github.com/serverlesstechnology/postgres-es/blob/f99103368850689313b9b06a5c8762f4bc619ff2/src/error.rs#L28)

### EventEnvelope

```rust
pub struct EventEnvelope<A>
where
    A: Aggregate,
{
    /// The id of the aggregate instance.
    pub aggregate_id: String,
    /// The sequence number for an aggregate instance.
    pub sequence: usize,
    /// The event payload with all business information.
    pub payload: A::Event,
    /// Additional metadata for use in auditing, logging or debugging purposes.
    pub metadata: HashMap<String, String>,
}
```

[https://github.com/serverlesstechnology/cqrs/blob/master/src/event.rs#L61](https://github.com/serverlesstechnology/cqrs/blob/master/src/event.rs#L61)

Eventの永続化が成功すると各Queryに渡されるEvent。metadataやsequenceを渡すために`EventEnvelope`としてwrapされている。  
`HashMap<String,String>`なので何が入っているか型で表現できない。このあたりがopinionatedなところなのかなと思った。

### Cqrs init

```rust
pub fn cqrs_framework(
    pool: Pool<Postgres>,
) -> (
    Arc<PostgresCqrs<BankAccount>>,
    Arc<PostgresViewRepository<BankAccountView, BankAccount>>,
) {
    // A very simple query that writes each event to stdout.
    let simple_query = SimpleLoggingQuery {};

    // A query that stores the current state of an individual account.
    let account_view_repo = Arc::new(PostgresViewRepository::new("account_query", pool.clone()));
    let mut account_query = AccountQuery::new(account_view_repo.clone());

    // Without a query error handler there will be no indication if an
    // error occurs (e.g., database connection failure, missing columns or table).
    // Consider logging an error or panicking in your own application.
    account_query.use_error_handler(Box::new(|e| println!("{}", e)));

    // Create and return an event-sourced `CqrsFramework`.
    let queries: Vec<Box<dyn Query<BankAccount>>> =
        vec![Box::new(simple_query), Box::new(account_query)];
    let services = BankAccountServices::new(Box::new(HappyPathBankAccountServices));
    (
        Arc::new(postgres_es::postgres_cqrs(pool, queries, services)),
        account_view_repo,
    )
}
```

[https://github.com/serverlesstechnology/cqrs-demo/blob/master/src/config.rs](https://github.com/serverlesstechnology/cqrs-demo/blob/master/src/config.rs)

わかりにくいが、cqrs instanceの初期化処理。viewとqueryで同じ実装を利用しているので同じ処理でconstructしている。

## GenericQuery Component Diagram

{{ figure(caption="Component diagram", images=["images/cqrs_generic_query_component_diagram.png"] )}}

Aggregateを更新した後に対応するviewを更新する処理は一般的なフローなので、そのための汎用的な処理は`GenericQuery`として提供されている。

## GenericQuery dispatch Sequence Diagram

{{ figure(caption="Sequence diagram", images=["images/cqrs_generic_query_dispatch_sequence_diagram.png"] )}}

ここでもユーザはviewの取得と更新処理、永続化をそれぞれ実装しておけばよい。  
難しいのが、`Query::dispatch`はエラーを返せないので、viewの更新に失敗してもcommandの処理自体は完結しているので、retryしない限りwriteとreadで整合性がとれなくなってしまう。

## Test

ドメインのルールはEventの適用とCommandの処理に集約されているので、過去のeventsと現在のcommandに対して出力されるeventsの形ですべて定義できる。そのためのtest helperも用意されていた。

```rust
#[cfg(test)]
mod tests {
    use cqrs_es::test::TestFramework;

    use super::*;
    use crate::domain::services::MockUserApi;

    type UserTestFramework = TestFramework<User>;

    #[test]
    fn create_user() {
        let services = UserServices::new(Box::new(MockUserApi::new()));
        let command = UserCommand::CreateUser {
            user_id: "Xxx".into(),
            email: "xxx@ymgyt.io".into(),
        };
        let expected = UserCreatedEvent {
            user_id: UserId::try_from("Xxx").unwrap(),
            email: "xxx@ymgyt.io".parse().unwrap(),
            user_status: UserStatus::Active,
        };

        UserTestFramework::with(services)
            .given_no_previous_events()
            .when(command)
            .then_expect_events(vec![expected.into()])
    }

    #[test]
    fn test_deactivate() {
        let services = UserServices::new(Box::new(MockUserApi::new()));
        let previous = UserCreatedEvent {
            user_id: UserId::try_from("Xxx").unwrap(),
            email: "xxx@ymgyt.io".parse().unwrap(),
            user_status: UserStatus::Active,
        };
        let command = UserCommand::DeactivateUser {};
        let expected = UserDeactivatedEvent {};

        UserTestFramework::with(services)
            .given(vec![previous.into()])
            .when(command)
            .then_expect_events(vec![expected.into()])
    }
}
```

- 過去のevent, serviceのmock, 適用されるcommandから期待通りのeventが返されるかのtestがunit testで書ける。
    - 外部サービスの呼び出しはmockを書く必要はある
- `cqrs_es::test::TestFramework` が用意されているので、eventのapplyやcommandのhandleまわりを書かなくてよい。

## わかっていないこと

実装上はSnapshot関連の記述があるものの、demoのユースケースではでてこなかった(と思われる)ので、どのように活用するか理解できなかった。

## 余談

SourceOfTruthという型名がかっこいいと思った

```rust
enum SourceOfTruth {
    EventStore,
    Snapshot(usize),
    AggregateStore,
}
```

[https://docs.rs/cqrs-es/latest/src/cqrs_es/persist/event_store.rs.html#13-17](https://docs.rs/cqrs-es/latest/src/cqrs_es/persist/event_store.rs.html#13-17)

## 自分で試した感想

- Frameworkといいつつ、application全体を制御するものでないので割と薄い
    - Read(view)に関してはかなり自由。
- readModifyWrite(event更新の衝突)については、aggregate_type,aggregate_id,sequenceに一意制約付与できればよいのでそれができればわりと実装は簡単そうだった。
- Aggregate関連はgenericになっているが、trait object(dyn)もでてくる。
    - metadatadateに関してはHashMap<String,String>
- writeのmodel(aggregate)に関しては変更がしやすい。fieldの型を変えてもapplyで対応すればよい
    - Eventはdeserializeする必要があるので互換性のない変更はしにくい(そのためのevent_upcaster)
- writeとviewで実質modelの定義が二つでてくる。
    - メリットでもデメリットでもあると思う。viewのときだけ欲しい追加の情報のせたりできるが、大抵はwriteとread両方にはねるとおもう。
- query dispatchでエラーになってもwriteの処理は完了するので、適切にretryする必要がありそう。
- がんばった分、command → apply → resultant_event の処理にfieldの更新ロジックが集中するのでよいと思った

## まとめ

CQRSは概念としてしか知らなかったのでRustでの具体的な実装を知れてうれしかった。  
Aggregateにcommandを適用して結果をEventとして表現し、これをSourceOfTruthとして永続化するという発送はシンプルでわかりやすいと思った。  
こうなってくると運用してみたいので、CQRSの設計に関する本も読んでみようと思った。(例えば[The Art of Immutable Architecture](https://www.immutablearchitecture.com/))


## 参考

- [CQRS and Events Sourcing using Rust](https://doc.rust-cqrs.org/intro.html)
- [cqrs-demo](https://github.com/serverlesstechnology/cqrs-demo)
- [cqrs-es](https://github.com/serverlesstechnology/cqrs)
    - github repository名がcqrsだが、cargo(package)はcqrs-es
- https://github.com/serverlesstechnology/postgres-espostgresのPersistedEventRepositoryの実装

