+++
title = "🏊 deadpoolでConnectionPoolを作る"
slug = "deadpool"
date = "2022-07-29"
draft = false
[taxonomies]
tags = ["rust"]
+++

本記事では、[`deadpool`]を利用したConnectionPoolの作り方とその仕組みについてみていきます。
外部リソースを抽象化した形でPoolが提供されているので同時利用数に制限のある外部リソースを複数作成して、必要に応じて使いまわしたい場面において[`deadpool`]が利用できます。

## [`deadpool`]の概要

ユーザが[`deadpool`]にConnectionの作成処理を渡すとそのConnectionPoolが提供されます。  
ここでいうConnectionPoolは以下の機能を提供してくれるものです

* Connectionの最大保持数を定義できる
* ユーザが利用したConnectionが再利用される
* Connection取得時に所有権も取得できる(referenceでない)

この機能により、ユーザがConnectionを必要としたときに再利用可能なConnectionがあればそれを利用でき、Connectionがなければそのときはじめて接続処理が開始されます。また、最大保持数のConnectionが利用中のときは、いずれかのConnectionが利用可能になるまで、ブロックされます。(エラーにもできる)  
Connection取得時にreferenceやsmart pointer(`Arc`)でなく直接Connectionを取得できるにもかかわらずConnectionがPoolで再利用されているが便利だったのが[`deadpool`]のコードを読んでみようとおもったきっかけでした。

[`deadpool`]の概要を以下に示します。

{{ figure(caption="deadpoolの概要", images=["images/deadpool_overview.png"] )}}

Connectionの作成(`create`)と再利用(`recycle`)のロジックを実装した`Manager`を[`deadpool`]に渡すとそれを利用したPoolが提供される形です。

本記事では、[`deadpool`]の[`managed`](https://docs.rs/deadpool/latest/deadpool/managed/index.html) moduleを前提にしています。  
また、Poolで管理する対象をConnectionとしていますが、実際には`Send`な型であればConnectionに限らずPoolで管理できます。


## 使い方

まずは一番シンプルな使い方からみていきます。本記事のサンプルコードのdependenciesは以下の通りです。

```toml
[dependencies]
async-trait = "0.1.56"
deadpool = "0.9.5"
thiserror = "1.0.31"
tracing = "0.1.35"

[dev-dependencies]
anyhow = "1.0.58"
tokio = { version = "1.20.1", features = ["full"] }
tracing-init = "0.1.0"
```

### `Pool`で管理するConnection

まず初めにPoolで管理したいConnectionを定義していきます。  
実際にはこの型は利用したいbackendのConnection型になると思うので基本的には自分で定義することは少ないかもしれません。

```rust
#[derive(Clone, Debug, PartialEq, Copy)]
pub enum ConnectionState {
    Connected,
    Closed,
    Error,
}

#[derive(Debug)]
pub struct Connection {
    name: String,
    state: ConnectionState,
}

impl Connection {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            state: ConnectionState::Connected,
        }
    }
}
```

debug用にもたせたnameとstateをもつだけの型です。

### `Manager`の実装

[`deadpool`]にはこのConnectionを作成/再利用する処理(`Manager` trait)を実装した型を渡します。

```rust
#[derive(thiserror::Error, Debug)]
pub enum MyError {
    #[error("A")]
    A,
    #[error("B")]
    B,
}

#[derive(Debug)]
pub struct ManagerImpl {
    connection_counter: AtomicUsize,
}

impl ManagerImpl {
    pub fn new() -> Self {
        Self {
            connection_counter: AtomicUsize::new(0),
        }
    }
}

#[async_trait]
impl Manager for ManagerImpl {
    type Type = Connection;
    type Error = MyError;

    async fn create(&self) -> Result<Connection, MyError> {
        let current = self.connection_counter.fetch_add(1, Ordering::Relaxed);

        Ok(Connection::new(format!("connection {current}")))
    }

    async fn recycle(&self, conn: &mut Connection) -> RecycleResult<MyError> {
        match conn.state {
            ConnectionState::Connected => Ok(()),
            other => Err(RecycleError::Message(format!(
                "connection is in state: {other:?}"
            ))),
        }
    }

    fn detach(&self, obj: &mut Self::Type) {
        tracing::info!("{obj:?} detached");
    }
}
```

`Manager`は`Sync + Send`である必要があるので、connection識別用のcounterには`AtomicUsize`を利用しています。   

`Manager::create`はConnectionの作成処理です。Poolに利用可能なConnectionがない場合にユーザがConnectionを要求すると実行されます。  
エラー型はユーザ定義型が利用でき、Connection取得時にハンドリングできます。

`Manager::recycle`はConnectionの再利用処理です。引数で渡されたConnectionの状態を確認して、エラーを返さなければそのConnectionが再利用されます。エラーを返した場合、Pool側で再利用可能なConnectionとされずdropされます。

`Manager::detach`はConnectionをPoolの管理対象外にする際に呼ばれます。defaultの実装が提供されており、特に処理がなければ定義する必要はないです。

### `Pool::get`

`Manager`型が実装してあれば使う方法は非常にシンプルです。(`deadpool_handson`に実装されている想定)

```rust
use deadpool::managed::{Object, Pool};

use deadpool_handson::ManagerImpl;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_init::init();

    let pool: Pool<ManagerImpl, Object<ManagerImpl>> = Pool::builder(ManagerImpl::new()).build()?;

    let conn: Object<ManagerImpl> = pool.get().await?;

    tracing::info!("connection state: {:?}", conn.state());

    Ok(())
}
```

わかりやすさのために、変数に型を書いていますが実際には必要ないです。  
`Object`については後述します。このコードを実行すると

```text
❯ cargo run --example get --quiet
2022-07-28T12:25:58.078486Z  INFO examples/get.rs:13: connection state: Connected
```

`Pool`に`Manager`の実装を渡して、`Pool::get`を呼ぶだけです。  
`let conn: Object<ManagerImpl>`となっていてこの型が実際に`Pool::get`で返される型なのですが

```rust
impl<M: Manager> Deref for Object<M> {
    type Target = M::Type;
    fn deref(&self) -> &M::Type {
        &self.inner.as_ref().unwrap().obj
    }
}
```

のように`Deref`を定義しているので、透過的に`Manager::Type`(=Connection)として利用できます。  
なぜ、Connectionを`Object`でwrapしているかについては後述します。  
一度`Pool`を作成したらあとは`Pool::get`を呼ぶだけで、あとのことは`Pool`が面倒をみてくれます。


### `Hooks`

[`deadpool`]にはConnectionのライフサイクル時に実行されるhook機能があります。  
現在のところ利用できるhookは、以下の3つです。

- post_create
- pre_recycle
- post_recycle

実際に利用するコードは以下のようになります。

```rust
use deadpool::managed::{Metrics, Object, Pool, Hook, HookFuture};

use deadpool_handson::{Connection, MyError, ManagerImpl};

fn post_create_hook<'a>(conn: &'a mut Connection, metrics: &'a Metrics) -> HookFuture<'a, MyError> {
    tracing::info!(hook="post_create", "{conn:?} {metrics:?}");

    Box::pin(async { Ok(()) })
}

fn pre_recycle_hook<'a>(conn: &'a mut Connection, metrics: &'a Metrics) -> HookFuture<'a, MyError> {
    tracing::info!(hook="pre_recycle", "{conn:?} {metrics:?}");

    Box::pin(async { Ok(()) })
}

fn post_recycle_hook<'a>(conn: &'a mut Connection, metrics: &'a Metrics) -> HookFuture<'a, MyError> {
    tracing::info!(hook="post_recycle", "{conn:?} {metrics:?}");

    Box::pin(async { Ok(()) })
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_init::init();

    let pool: Pool<ManagerImpl, Object<ManagerImpl>> = Pool::builder(ManagerImpl::new())
        .post_create(Hook::async_fn(post_create_hook))
        .pre_recycle(Hook::async_fn(pre_recycle_hook))
        .post_recycle(Hook::async_fn(post_recycle_hook))
        .build()?;

    let conn: Object<ManagerImpl> = pool.get().await?;
    tracing::info!(state=?conn.state(), "Got connection from pool");
    tracing::info!("Drop connection");
    drop(conn);

    let recycled_conn = pool.get().await?;
    tracing::info!("Recycled connection: {recycled_conn:?}");

    Ok(())
}
```

Pool生成時にそれぞれのhookにclosure/funcを渡します。ここでは、`Hook::async_fn`を利用していますが、asyncが必要ない場合は同期verを渡すこともできます。

この処理を実行すると

```text
❯ cargo run --example hook --quiet
2022-07-28T20:10:54.872028Z  INFO examples/hook.rs:6: Connection { name: "connection 0", state: Connected } Metrics { created: Instant { t: 8126598910934 }, recycled: None, recycle_count: 0 } hook="post_create"
2022-07-28T20:10:54.872113Z  INFO examples/hook.rs:35: Got connection from pool state=Connected
2022-07-28T20:10:54.872132Z  INFO examples/hook.rs:36: Drop connection
2022-07-28T20:10:54.872145Z  INFO /Users/ymgyt/rs/deadpool/src/managed/mod.rs:230: Object dropped
2022-07-28T20:10:54.87216Z  INFO /Users/ymgyt/rs/deadpool/src/managed/mod.rs:643: Current slot size=1 max_size=32
2022-07-28T20:10:54.872204Z  INFO examples/hook.rs:12: Connection { name: "connection 0", state: Connected } Metrics { created: Instant { t: 8126598910934 }, recycled: None, recycle_count: 0 } hook="pre_recycle"
2022-07-28T20:10:54.872225Z  INFO examples/hook.rs:18: Connection { name: "connection 0", state: Connected } Metrics { created: Instant { t: 8126598910934 }, recycled: None, recycle_count: 0 } hook="post_recycle"
2022-07-28T20:10:54.872244Z  INFO examples/hook.rs:40: Recycled connection: Object { inner: Some(ObjectInner { obj: Connection { name: "connection 0", state: Connected }, metrics: Metrics { created: Instant { t: 8126598910934 }, recycled: Some(Instant { t: 8126598916859 }), recycle_count: 1 } }) }
2022-07-28T20:10:54.872906Z  INFO /Users/ymgyt/rs/deadpool/src/managed/mod.rs:230: Object dropped
2022-07-28T20:10:54.872926Z  INFO /Users/ymgyt/rs/deadpool/src/managed/mod.rs:643: Current slot size=1 max_size=32
```

`deadpool/src/managed/mod.rs`のログはブログ用に自分が追加したもので実際には出力されません。  
一度取得したConnectionをdropしたのち再度取得すると再利用されていることがわかります。


## `deadpool::Pool`の仕組み

以上が[`deadpool`]の簡単な利用例になります。  
ここからは実際にPoolがどのように実装されているかをソースから追っていきたいと思います。  
最初にPoolの実装よりの概要を以下に示します。

{{ figure(caption="Poolの概要", images=["images/pool_overview.png"] )}}

ざっくりとした理解では、`Pool`の実態は`PoolInner`に保持されていて`Pool`は`Arc<PoolInner>`を持っており、`Clone`なので取り回しやすいです。  
また、Connectionを実際に保持しているcollectionは`VecDeque`でConnectionの再利用される順番に影響します。  
`Pool::get`の取得時には[`VecDeque::pop_front`](https://github.com/bikeshedder/deadpool/blob/bbe2f0c46f9b2ca695f352a2be8e4f887b272f73/src/managed/mod.rs#L388)で先頭から取得され、Connection再利用時には[`VecDeque::push_back`](https://github.com/bikeshedder/deadpool/blob/bbe2f0c46f9b2ca695f352a2be8e4f887b272f73/src/managed/mod.rs#L639)でqueueの最後に追加されます。  
結果的にConnectionの取得順序はラウンドロビンになります。

実際の`Pool`の定義

```rust
pub struct Pool<M: Manager, W: From<Object<M>> = Object<M>> {
    inner: Arc<PoolInner<M>>,
    _wrapper: PhantomData<fn() -> W>,
}
```

単にGenericsを消費したいだけのときは`PhantomData<W>`ではなく、`PhantomData<fn() -> W>`が良いとされていますがその通りになっていますね。

肝心の`PoolInner`

```rust
struct PoolInner<M: Manager> {
    manager: Box<M>,
    slots: Mutex<Slots<ObjectInner<M>>>,
    users: AtomicUsize,
    semaphore: Semaphore,
    config: PoolConfig,
    runtime: Option<Runtime>,
    hooks: hooks::Hooks<M>,
}
```

- `manager`: ユーザが定義した`Manaer`の実装をheapに保持します
- `slots`: ユーザが定義したConnectionをwrapする`ObjectInner`を`VecDeque`で保持して`Mutex`で保護しています。`Slots`は`VecDeque`のwrap型です

```rust
struct Slots<T> {
    vec: VecDeque<T>,
    size: usize,
    max_size: usize,
}
```

- `users`: `Pool::get`されてユーザが利用中のConnectionの数です。`Pool::status`で利用します
- `semaphore`: Poolの最大保持数の制御に利用します。`VecDeque`だけでは必要に応じて拡張してしまうので`Semaphre`を利用します。なお、deadpoolにruntimeの選択によらずtokioへの依存があるのは`tokio::sync::Semaphore`を利用しているためです
- `config`: Poolの設定を保持します。設定はシンプルで最大保持数と各種操作のtimeoutのみです。

```rust
pub struct PoolConfig {
    pub max_size: usize,
    pub timeouts: Timeouts,
}

pub struct Timeouts {
    pub wait: Option<Duration>,
    pub create: Option<Duration>,
    pub recycle: Option<Duration>,
}
```

defaultの`max_size`は`num_cpus::get_physical() * 4`が利用されます。  
また`Timeouts`のdefault値はすべて`None`なので後述しますが、`Pool::get`時に最大保持数にたっしているとブロックし続けてしまうので注意が必要です。

- `runtime`: ユーザがasync runtimeを選択できるようにするための抽象化です
- `hooks`: 上述したhookを保持します

### `Pool::get`処理

Poolの概要を把握できたところで、肝心の`Pool::get`処理についてみていきます。

まず、`Pool::get`は`Pool::timeout_get`へのシンプルな委譲です。

```rust
pub async fn get(&self) -> Result<W, PoolError<M::Error>> {
    self.timeout_get(&self.timeouts()).await
}
```

`Pool::timeout_get`は長いですが、おこなっていることは`Semaphore::acquire`でリソースを取得したのちPoolからConnectionを作成or再利用する処理です。

```rust
pub async fn timeout_get(&self, timeouts: &Timeouts) -> Result<W, PoolError<M::Error>> {
    // ...
    let permit = if non_blocking {
        self.inner.semaphore.try_acquire().map_err(|e| match e {
            TryAcquireError::Closed => PoolError::Closed,
            TryAcquireError::NoPermits => PoolError::Timeout(TimeoutType::Wait),
        })?
    } else {
        apply_timeout(
            self.inner.runtime,
            TimeoutType::Wait,
            timeouts.wait,
            async {
                self.inner
                    .semaphore
                    .acquire()
                    .await
                    .map_err(|_| PoolError::Closed)
            },
        )
            .await?
    };

    let inner_obj = loop {
        let inner_obj = self.inner.slots.lock().unwrap().vec.pop_front();
        if let Some(inner_obj) = inner_obj {
            // 再利用
        } else {
            // 新規作成
        }
    };
    
    // ...
    Ok(Object {
        inner: Some(inner_obj),
        pool: Arc::downgrade(&self.inner),
    }.into())
}
```

もろもろ省略すると概ね上記のようになります。  
`apply_timeout`はruntimeとtimeoutに応じてfutureを実行する処理なのですが以下のようになっています。

```rust
async fn apply_timeout<O, E>(
    runtime: Option<Runtime>,
    timeout_type: TimeoutType,
    duration: Option<Duration>,
    future: impl Future<Output = Result<O, impl Into<PoolError<E>>>>,
) -> Result<O, PoolError<E>> {
    match (runtime, duration) {
        (_, None) => future.await.map_err(Into::into),
        (Some(runtime), Some(duration)) => runtime
            .timeout(duration, future)
            .await
            .ok_or(PoolError::Timeout(timeout_type))?
            .map_err(Into::into),
        (None, Some(_)) => Err(PoolError::NoRuntimeSpecified),
    }
}
```
ここで、timeoutの設定がない場合、単純に`future.await`が実行されるのですが、このときにsemaphoreが最大利用数に達しているとブロックし続けてしまうので若干注意が必要です。

`Pool::get`,`Pool::timeout_get`はConnectionではなく、Connectionをwrapした`Object`を返します。  
ということで次に`Object`についてみてみます。

### `Object`

Connectionをwrapしている`Object`は以下のように定義されています。

```rust
use std::sync::Weak;

pub struct Object<M: Manager> {
    inner: Option<ObjectInner<M>>,
    pool: Weak<PoolInner<M>>,
}

pub(crate) struct ObjectInner<M: Manager> {
    obj: M::Type,
    metrics: Metrics,
}
```

`Weak<PoolInner<M>>`を保持しているのは、drop時にConnectionをPoolに戻すためです。  
`ObjectInner.metrics`はConnectionがいつ作成され何回再利用されたかについての情報を保持しています。  
`Object::drop`をみてみると

```rust
impl<M: Manager> Drop for Object<M> {
    fn drop(&mut self) {
        if let Some(inner) = self.inner.take() {
            if let Some(pool) = self.pool.upgrade() {
                pool.return_object(inner)
            }
        }
    }
}
```

`Weak::upgrade`を利用して`PoolInner`への参照(`Arc<PoolInner>`)を取得して、`PoolInner::return_object`を呼びます。

```rust
impl<M: Manager> PoolInner<M> {
    fn return_object(&self, mut inner: ObjectInner<M>) {
        let _ = self.users.fetch_sub(1, Ordering::Relaxed);
        let mut slots = self.slots.lock().unwrap();
        if slots.size <= slots.max_size {
            slots.vec.push_back(inner);
            drop(slots);
            self.semaphore.add_permits(1);
        } else {
            slots.size -= 1;
            drop(slots);
            self.manager.detach(&mut inner.obj);
        }
    }
}
```

ここでConnectionを保持している`VecDeque::push_back`をよんでConnectionを再び保持し、semaphoreの利用可能数を調整しています。  
最大利用数を超えている場合は、`Pool`の管理下でなくなるので、`Manager::detach`をコールしてくれます。  
ということで、Connectionが`Object`でwrapしていたのは、ユーザが利用し終わった(drop)ConnectionをPoolに戻すための処理をdrop時に行うためというわけでした。

## まとめ

[`deadpool`]の基本的な使い方とConnectionの取得と再利用処理について簡単にみていきました。  
runtime(`tokio`,`async-std`)をユーザ側で指定できたり、managed以外にもunmanaged moduleもあったりとすべてには言及できていないのですが、`Pool::get`を呼んだ時になにが起きているかの概要は把握できたかと思います。  
Connectionを`sync::Weak`を保持した`Object`でwrapすることで、ユーザに所有権を返しつつ、drop後にふたたびPoolの管理化にもどす方法が非常に参考になりました。  
またそうしたwrapper型に、Connectionの利用状況を記録した`Status`を保持させており運用時にも便利そうだなと思いました。  
[`deadpool`]プロジェクトではこの`Pool`を利用した[`Manager`の実装](https://docs.rs/deadpool/latest/deadpool/#database-connection-pools)が提供されています。postgres,diesel, redis, rabbitmq(lapin)等があるので、利用したいbackendがある場合、選択肢のひとつになるのではないでしょうか。

[`deadpool`]: https://github.com/bikeshedder/deadpool

