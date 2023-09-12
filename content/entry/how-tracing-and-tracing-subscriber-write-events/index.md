+++
title = "🔭 tracing/tracing-subscriberでログが出力される仕組みを理解する"
slug = "how-tracing-and-tracing-subscriber-write-events"
date = "2022-11-19"
draft = false
[taxonomies]
tags = ["rust"]
+++

本記事ではRustの[tracing]/[tracing-subscriber]でログが出力される仕組みをソースコードを読みながら理解することを目指します。
具体的には以下のコードにおいて[tracing]がどのようにしてログを出力するかを見ていきます。

```rust
use tracing::{info, info_span};

fn main() {
    tracing_subscriber::fmt()
        .init();

    let span = info_span!("span_1", key="hello");
    let _guard = span.enter();

    info!("hello");
}
```

`Cargo.toml`
```toml
[dependencies]
thread_local = "1.1.4"
tracing = "=0.1.35"
tracing-core = "=0.1.30"
tracing-subscriber = { version = "=0.3.16", default-features = false, features = ["smallvec", "fmt", "ansi", "std"] }
```

上記のコードを実行すると以下の出力を得ます。
```sh
2022-11-11T08:39:02.198973Z  INFO span_1{key="hello"}: tracing_handson: hello
```

versionは[`tracing-subscriber-0.3.16`](https://github.com/tokio-rs/tracing/tree/tracing-subscriber-0.3.16)を対象にしました。  
(なお、`tracing::info!()`はtracing的にはEventといわれているので以下ではログではなくEventと呼んでいきます)


## 本記事のゴール

本記事では以下の点を目指します。

* `tracing_subscriber::fmt()::init()`でなにが初期化されているか
  * `tracing_subscriber::Subscriber`の内部構造 
    * `Subscriber`の実態は`Layer * n` + `Registry`
  * `tracing_subscriber::Registry`の役割
* `tracing::Span`の仕組み
  * `info_span!()`の内容がどのようにして後続のeventに出力されるか
* `tracing::info!()`が出力される仕組み

本記事で扱わないこと

* `tracing-future`
  * `async/await`でのtracingの利用の仕方(ただし、`async`なコードでそのまま使うとどうしてうまく動作しないかは理解できます)
* `tracing-log`
  * log crateとの互換処理も提供されています
* per-filter-layer
  * [tracing-opentelemetryにPRを送った記事](https://blog.ymgyt.io/entry/produce-measurement-with-attributes-from-tracing/)でper-filter-layerの利用方法について書きました

## 前提の確認

### Spanとは

最初にtracingを触った時に`info!()`や`error!()`はログの出力として理解できたのですが、spanの役割や使い方がわかりませんでした。公式のdocには以下のようにあります。

>  Unlike a log line that represents a moment in time, a span represents a period of time with a beginning and an end.

自分の言葉で説明するなら、spanは後続のstack trace上で作られるevent(`info!()`)に付与されるkey,valueで、eventに実行時のcontextを付与するものです。といってもわかりづらいと思うので具体的なコードでみていきます。

```rust
use tracing::{info, info_span};

fn start() {
    // Generate unique request id
    let request_id = "req-123";

    let _guard = info_span!("req", request_id).entered();

    handle_request();
}

fn handle_request() {
    // Authenticate
    let user_id = "user_aaa";
    let _guard = info_span!("user", user_id).entered();

    do_process();
}

fn do_process() {
    info!("successfully processed");
}

fn main() {
    tracing_subscriber::fmt()
        .init();

    start();
}
```

処理の内容はなんでもよいのですが、まずリクエストの識別子を生成して次に認証して、...と処理を進めていく中で処理内容のcontextができていくと思います。それをspanとして表現します。上記のコードを実行すると以下のようなログが出力されます。

```sh
2022-11-11T09:19:18.317693Z  INFO req{request_id="req-123"}:user{user_id="user_aaa"}: span: successfully processed
```

`info!()`で生成したeventにspanに与えたkey,valueが付与されました。このように処理の階層構造のcontextをログに構造的に表現できます。一度このログが作れるとわかるともうspanなしには戻れないです。

### `thread_local!`, `thread_local::ThreadLocal`

tracingの実装ではしばしば`thread_local!`や`thread_local::ThreadLocal`がでてきます。  
自分自身、thread localという機構への理解があやしいのですが本記事を読む範囲では以下のようにRustのAPI的観点から捉えておけばよいと考えております。

`thread_local!`はglobalなstatic変数に`RefCell`を保持できる。  
具体的には以下のコードはglobalなstatic変数を複数threadから変更しようとしておりcompileに失敗します。

```rust
static STATE: RefCell<String> = RefCell::new(String::new());

fn main() {
    let threads = 5;
    let mut handles = Vec::with_capacity(threads);
    for i in 0..threads {
        let handle = thread::spawn(move || {
            STATE.borrow_mut().push_str(i.to_string().as_str());
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().unwrap();
    }
}
```

```sh
--> examples/thread_local.rs:8:15
  |
8 | static STATE: RefCell<String> = RefCell::new(String::new());
  |               ^^^^^^^^^^^^^^^ `RefCell<String>` cannot be shared between threads safely
  |
  = help: the trait `Sync` is not implemented for `RefCell<String>`
  = note: shared static variables must have a type that implements `Sync`
```

そこで、global変数`STATE`を`thread_local!`にするとcompileが通ります。

```rust
use std::cell::RefCell;
use std::thread;

thread_local! {
    static STATE: RefCell<String> = RefCell::new(String::new());
}

fn main() {
    let threads = 5;
    let mut handles = Vec::with_capacity(threads);
    for i in 0..threads {
        let handle = thread::spawn(move || {
            STATE.with(|state: &RefCell<String>| {
                state.borrow_mut().push_str(i.to_string().as_str());
            })
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().unwrap();
    }
}
```

`RefCell`は`Sync`ではないのでmulti threadでは`Arc<Mutext<T>>`等を使うところですが、thread localにするとthreadごとにglobal変数を保持でき、single threadで利用できた`RefCell`が使えます。

`ThreadLocal`は上記の機能をstructのfieldでも使えるようにするものです。
具体的には以下のコードはcompileが通りません。

```rust
use std::cell::RefCell;

struct A {
    _a: RefCell<String>,
}

fn should_sync<T: Sync>(_t: T) {}

fn main() {
    let a = A { _a: RefCell::new(String::new()) };
    should_sync(a);
}
```
```sh
  --> examples/thread_local.rs:14:17
   |
14 |     should_sync(a);
   |     ----------- ^ `RefCell<String>` cannot be shared between threads safely
   |     |
   |     required by a bound introduced by this call
   |
   = help: within `A`, the trait `Sync` is not implemented for `RefCell<String>`
```

`RefCell`が`Sync`でないと言われます。そこで、`ThreadLocal`でwrapするとcompileが通ります。

```rust
use std::cell::RefCell;
use thread_local::ThreadLocal;

struct A {
    _a: ThreadLocal<RefCell<String>>,
}

fn should_sync<T: Sync>(_t: T) {}

fn main() {
    let a = A { _a: ThreadLocal::new() };
    should_sync(a);
}
```

### `shareded_slab::Pool`

`shareded_slab::Pool`はslabというデータ構造をmulti thread間で共有できるようにし(`Sync`)かつ、object pool likeなAPIを提供するものです。あまり深入りすると本記事のゴールからそれてしまうので、ここではdataをcreate/insertするとindex(usize)を返してくれる`Sync`で効率的な`Vec`という程度に理解します。

## Macroをexpand

tracing以外のcrateで押さえておきたい型は前提の確認で概要を押さえたのであとはtracingとstdだけで完結します。  
まずはmacroをexpandして、実行されているtracingのapiを確認していきましょう。

```rust
use tracing::{info, info_span};

fn main() {
    tracing_subscriber::fmt()
        .init();

    let span = info_span!("span_1", key="hello");
    let _guard = span.enter();

    info!("hello");
}
```

このcodeを`cargo expand`すると以下のようになります。(compileできるようにprelude等を削りました。)

```rust
#![feature(fmt_internals)]
use std::prelude::rust_2021::*;
fn main() {
    tracing_subscriber::fmt().init();

    let span = {
        use ::tracing::__macro_support::Callsite as _;
        static CALLSITE: ::tracing::callsite::DefaultCallsite = {
            static META: ::tracing::Metadata<'static> = {
                ::tracing_core::metadata::Metadata::new(
                    "span_1",
                    "tracing_handson",
                    ::tracing::Level::INFO,
                    Some("src/main.rs"),
                    Some(8u32),
                    Some("tracing_handson"),
                    ::tracing_core::field::FieldSet::new(
                        &["key"],
                        ::tracing_core::callsite::Identifier(&CALLSITE),
                    ),
                    ::tracing::metadata::Kind::SPAN,
                )
            };
            ::tracing::callsite::DefaultCallsite::new(&META)
        };
        let mut interest = ::tracing::subscriber::Interest::never();
        if ::tracing::Level::INFO <= ::tracing::level_filters::STATIC_MAX_LEVEL
            && ::tracing::Level::INFO <= ::tracing::level_filters::LevelFilter::current()
            && {
                interest = CALLSITE.interest();
                !interest.is_never()
            }
            && ::tracing::__macro_support::__is_enabled(CALLSITE.metadata(), interest)
        {
            let meta = CALLSITE.metadata();
            ::tracing::Span::new(meta, &{
                #[allow(unused_imports)]
                use ::tracing::field::{debug, display, Value};
                let mut iter = meta.fields().iter();
                meta.fields().value_set(&[(
                    &iter.next().expect("FieldSet corrupted (this is a bug)"),
                    Some(&"hello" as  &dyn Value),
                )])
            })
        } else {
            let span = ::tracing::__macro_support::__disabled_span(CALLSITE.metadata());
            {};
            span
        }
    };
    let _guard = span.enter();
 {
        use ::tracing::__macro_support::Callsite as _;
        static CALLSITE: ::tracing::callsite::DefaultCallsite = {
            static META: ::tracing::Metadata<'static> = {
                ::tracing_core::metadata::Metadata::new(
                    "event src/main.rs:11",
                    "tracing_handson",
                    ::tracing::Level::INFO,
                    Some("src/main.rs"),
                    Some(11u32),
                    Some("tracing_handson"),
                    ::tracing_core::field::FieldSet::new(
                        &["message"],
                        ::tracing_core::callsite::Identifier(&CALLSITE),
                    ),
                    ::tracing::metadata::Kind::EVENT,
                )
            };
            ::tracing::callsite::DefaultCallsite::new(&META)
        };
        let enabled = ::tracing::Level::INFO <= ::tracing::level_filters::STATIC_MAX_LEVEL
            && ::tracing::Level::INFO <= ::tracing::level_filters::LevelFilter::current()
            && {
                let interest = CALLSITE.interest();
                !interest.is_never()
                    && ::tracing::__macro_support::__is_enabled(CALLSITE.metadata(), interest)
            };
        if enabled {
            (|value_set: ::tracing::field::ValueSet| {
                let meta = CALLSITE.metadata();
                ::tracing::Event::dispatch(meta, &value_set);
            })({
                #[allow(unused_imports)]
                use ::tracing::field::{debug, display, Value};
                let mut iter = CALLSITE.metadata().fields().iter();
                CALLSITE.metadata().fields().value_set(&[(
                    &iter.next().expect("FieldSet corrupted (this is a bug)"),
                    Some(&::core::fmt::Arguments::new_v1(&["hello"], &[]) as  &dyn Value),
                )])
            });
        } else {
        }
    };
}
```

長いですが、概要はシンプルです。 `info_span!()`,`info!()`共通で、macroを呼び出すと当該呼び出し箇所の情報が以下のように`tracing::callsite::DefaultCallsite`として表現されます。

```rust
        static CALLSITE: ::tracing::callsite::DefaultCallsite = {
            static META: ::tracing::Metadata<'static> = {
                ::tracing_core::metadata::Metadata::new(
                    // ...
                )
            };
            ::tracing::callsite::DefaultCallsite::new(&META)
        };
```
まず見ていただきたいのが、`static CALLSITE`のようにstaticになっている点です。  
tracingのコードを読むまで知らなかったのですが、rustでは関数の中でもstatic変数が定義できるそうです。  

> A static item defined in a generic scope (for example in a blanket or default implementation) will result in exactly one static item being defined, as if the static definition was pulled out of the current scope into the module.

https://doc.rust-lang.org/reference/items/static-items.html#statics--generics

関数内でstaticを定義しても実際にはmoduleのtop levelで定義したのと同様になり、当該変数には定義した関数からしかアクセスできないという挙動になります。  
`CALLSITE`については全体の構造を押さえてからのほうがわかりやすいのでここではmacroの呼び出しの情報(source code上の位置、key,value, span or event)を保持しているというくらいでOKです。

`CALLSITE`はstaticなのでcompile時に決まります。次の箇所からがruntime時の挙動です。  

```rust
let mut interest = ::tracing::subscriber::Interest::never();
if ::tracing::Level::INFO <= ::tracing::level_filters::STATIC_MAX_LEVEL
    && ::tracing::Level::INFO <= ::tracing::level_filters::LevelFilter::current()
    && {
        interest = CALLSITE.interest();
        !interest.is_never()
    }
    && ::tracing::__macro_support::__is_enabled(CALLSITE.metadata(), interest)
{ // ... }
```
subscriberの`Interest`なるものや、levelの判定を行っています。こちらもsubscriberの構造がかかわってくるので後述します。ざっくりですが`info_span!()`や`debug_span!()`のようなlevelに応じた判定処理を実施している程度に理解しておきます。次がspanの実質的な処理です。

```rust
let meta = CALLSITE.metadata();
::tracing::Span::new(meta, &{
    #[allow(unused_imports)]
    use ::tracing::field::{debug, display, Value};
    let mut iter = meta.fields().iter();
    meta.fields().value_set(&[(
        &iter.next().expect("FieldSet corrupted (this is a bug)"),
        Some(&"hello" as  &dyn Value),
    )])
})
```
ここで大事なのは`tracing::Span::new()`が呼び出されている点です。引数にはmacro呼び出し時の情報を渡しています。  
spanの処理についてまとめると概要としては以下のようになります。

```rust
fn main() {
    tracing_subscriber::fmt().init();
    
    let span = {
        static CALLSITE = { /* ... */ };
        tracing::Span::new(CALLSITE)
    };
    let _guard = span.enter();
}
```

要は、`tracing::Span::new()`にmacroの情報渡して、spanを生成し、`span.enter()`して、guardをdropしないように変数で保持しているだけです。  

`info!()`のevent生成でも流れはspanと同じで、staticな`CALLSITE`生成、levelの判定処理、api callという流れです。eventの場合は`tracing::Event::dispatch(CALLSITE)`が呼ばれます。  

話を整理すると、メンタルモデルとしてはspanとeventのmacroは概ね以下のように展開されるといえます。

```rust
fn main() {
    tracing_subscriber::fmt().init();

    let span = info_span!("span_1", key="hello");
    let _guard = span.enter();

    info!("hello");
}
```

⬇

```rust
fn main() {
    tracing_subscriber::fmt().init();

    let span = {
        static CALLSITE = { /* ... */ };
        tracing::Span::new(CALLSITE)
    };
    let _guard = span.enter();

    {
        static CALLSITE = { /* ... */ }
        tracing::Event::dispatch(CALLSITE)
    }
}
```

ということで、以下のtracingのapiの処理を追っていきます。

1. `tracing::Span::new()`
2. `tracing::Span::enter()`
3. `tracing::Event::dispatch()`

さっそく、`tracing::Span::new()`のdefinitionにjumpしていきたいところですが、ここからは`tracing_subscriber`側の処理になるので、`tracing_subscriber` crateについて説明させてください。

## `tracing_subscriber` crate

`tracing`は生成したspanやeventを処理するために必要な機能を[`tracing_core::Subscriber`](https://docs.rs/tracing-core/0.1.30/tracing_core/trait.Subscriber.html)として定義しています。tracingは`tracing_core::Subscriber`の実装がspanやeventの生成前にtracingのapiを通じて初期化されていることを期待しています。`tracing_subscriber`は`tracing_core::Subscriber`の実装を提供するためのcrateです。  
tracingではtraitとそれを実装する型に同じ名前を使う場合があり最初は紛らわしいのですが、`tracing_core::Subscriber`はtraitで`tracing_subscriber::fmt::Subscriber`はこのtraitの実装を提供するstructです。  
以後は紛らわしいので`tracing_subscriber`のre-exportにならって、`tracing_subscriber::fmt::Subscriber`を`FmtSubscriber`と呼びます。

上記のコードの最初にでてきた`tracing_subscriber::fmt().init();`は`FmtSubscriber`を生成して、`tracing`に見える位置にセットする処理と理解することができます。

### `FmtSubscriber`

さっそく`FmtSubscriber`の定義を確認してみましょう。

```rust
pub struct Subscriber<
    N = format::DefaultFields,
    E = format::Format<format::Full>,
    F = LevelFilter,
    W = fn() -> io::Stdout,
> {
    inner: layer::Layered<F, Formatter<N, E, W>>,
}
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/mod.rs#L225](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/mod.rs#L225-L232)

Genericsが4つもでてきて、うっとなります。ただし、よくみてみると以下の構造をしている`inner`のwrapperであることがわかります。

```rust
inner: layer::Layered<F,Formatter<_>>
```

`Formatter<_>`はすぐ下に以下のように定義されています。

```rust
pub type Formatter<
    N = format::DefaultFields,
    E = format::Format<format::Full>,
    W = fn() -> io::Stdout,
> = layer::Layered<fmt_layer::Layer<Registry, N, E, W>, Registry>;
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/mod.rs#L237](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/mod.rs#L237-L241)

ということで、`Formatter`も実体は`layer::Layered`でした。  
`N = format::DefaultFields`と`E = format::Fromat<format::Full>`はログの出力方法をカスタマイズするためのgenerics、`W = fn() -> io::Stdout`はログの出力先を切り替えるためのgenericです。そこでこれらのgenericsをいったん無視すると`FmtSubscriber`は概ね以下の構造をしているといえます。

```
Layered<
    LevelFilter,
    Layered<
        fmt_layer::Layer,
        Registry,
    >
>
```

`FmtSubscriber`は、`LevelFilter`,`fmt_layer::Layer`, `Registry`を`Layered`というstructでnestさせてできていえるように見えないでしょうか。  
ということで、`tracing_subscriber`の`Layer`,`Layered`をまずは理解していきましょう。

### `Layer`

まずはdocを見てみます。`Layer`については[`tracing_subscriber::layer` module](https://docs.rs/tracing-subscriber/0.3.16/tracing_subscriber/layer/index.html)に説明があります。

> The Layer trait, a composable abstraction for building Subscribers.

`Layer`は`Subscriber`を作るためのcomposable abstractionなtraitとあります。Layerを知ったあとに読むとなるほどと思えますが最初に読むとピンとこなかったです。

> The Subscriber trait in tracing-core represents the complete set of functionality required to consume tracing instrumentation. This means that a single Subscriber instance is a self-contained implementation of a complete strategy for collecting traces; but it also means that the Subscriber trait cannot easily be composed with other Subscribers.

`tracing_core::Subscriber`はtracing instrumentationをconsumeするために必要な機能をすべて集約したものなので、Subscriber instanceはいろいろな責務をもちます。そのためSubscriberを他のSubscriberと組み合わせづらいという問題点があります。

> In particular, Subscribers are responsible for generating span IDs and assigning them to spans. Since these IDs must uniquely identify a span within the context of the current trace, this means that there may only be a single Subscriber for a given thread at any point in time — otherwise, there would be no authoritative source of span IDs.

Subscriberを他のSubscriberとcomposableにできない理由が書いてあります。このspan IDを生成する箇所については後述します。ここではどうやらSubscriberの責務のひとつにspanにIDを振ることがあるくらいを押さえておきます。

> On the other hand, the majority of the Subscriber trait’s functionality is composable: any number of subscribers may observe events, span entry and exit, and so on, provided that there is a single authoritative source of span IDs. The Layer trait represents this composable subset of the Subscriber behavior; it can observe events and spans, but does not assign IDs.

一方で、Subscriber traitのmethodはcomposable。  
eventの出力やspanのentryやexitといった処理は複数のsubscriberで実装できます。(stdoutにjsonでloggingしつつ、特定のspanのパフォーマンス計測しつつ、特定のeventをmetricsで収集したり)  
Layer traitはSubscriber traitの一部のmethodの実装を担い、Subscriberをcomposableにするためにあります。

まとめ

* `tracing_core::Subscriber`にはtracingを利用するうえで必要な処理がまとめて定義されている
* Subscriberの実装はspanにIDを付与する責務をもつ観点から特定のcontext内で1つである必要がある
* そこでSubscriberをcomposableに作っていくためにLayerがある

### `Layered`

次に`tracing_subscriber::layer::Layered`をみていきます。`Layered`は以下のように定義されています。

```rust
pub struct Layered<L, I, S = I> {
    /// The layer.
    layer: L,

    /// The inner value that `self.layer` was layered onto.
    ///
    /// If this is also a `Layer`, then this `Layered` will implement `Layer`.
    /// If this is a `Subscriber`, then this `Layered` will implement
    /// `Subscriber` instead.
    inner: I,
    // ...
}
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/layered.rs#L22

省略していますが、基本的には1つのLayerでinnerをwrapするstructです。コメントにある通り、`inner: I`には`Subscriber`や`Layer`をいれます。

重要なのは`Layered`は`Subscriber`をwrapしているときはSubscriberとして振る舞う点です。

```rust
impl<L, S> Subscriber for Layered<L, S>
where
    L: Layer<S>,
    S: Subscriber,
{
    // ...
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/layered.rs#L89](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/layered.rs#L89)

また`Subscriber`の実装方法は

```rust
fn event(&self, event: &Event<'_>) {
        self.inner.event(event);
        self.layer.on_event(event, self.ctx());
}
```
https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/layered.rs#L151-L154

のように、wrapしているinnerを呼び出した後自身のlayerを呼び出します。

まとめると`Layered`は`Subscriber`をcomposableに構築するための`Layer`をまとめていくためのstructでそれ自身も`Subscriber`の実装であることがわかりました。  

### `Filter`

あらためて`FmtSubscriber`の概要を確認します。

```
Layered<
    LevelFilter,
    Layered<
        fmt_layer::Layer,
        Registry,
    >
>    
```

`Layered`はinnerに`Subscriber`(or`Layer`)をもち`Layer`と組み合わせるということをみてきました。  
とすると、`LevelFilter`もFilterといいながらLayerなのでしょうか。ここではFilterについて見ていきます。

Filterについては[layer moduleのdoc](https://docs.rs/tracing-subscriber/0.3.16/tracing_subscriber/layer/index.html#filtering-with-layers)で以下のように説明されています。

> As well as strategies for handling trace events, the Layer trait may also be used to represent composable filters. This allows the determination of what spans and events should be recorded to be decoupled from how they are recorded: a filtering layer can be applied to other layers or subscribers. 

ということで`Layer`のうち,spanやeventを処理対象とするかの判定のみを行う`Layer`を`Filter`としているようです。

```rust
pub use tracing_core::metadata::{LevelFilter, ParseLevelFilterError as ParseError};

impl<S: Subscriber> crate::Layer<S> for LevelFilter {
    fn register_callsite(&self, metadata: &'static Metadata<'static>) -> Interest {
        if self >= metadata.level() {
            Interest::always()
        } else {
            Interest::never()
        }
    }

    fn enabled(&self, metadata: &Metadata<'_>, _: crate::layer::Context<'_, S>) -> bool {
        self >= metadata.level()
    }

    fn max_level_hint(&self) -> Option<LevelFilter> {
        Some(*self)
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/filter/level.rs#L11](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/filter/level.rs#L11)

として、`LevelFilter`に`Layer`を実装しています。  
ということで`LevelFilter`の実体はtracingの有効判断を実装した`Layer`ということがわかりました。

### `Registry`

`FmtSubscriber`のcomponentで次にみていくのが`Registry`です。

```
Layered<
    LevelFilter,
    Layered<
        fmt_layer::Layer,
        Registry,
    >
>    
```

`Registry`はもっとも深くnestされており、他のLayerはRegistry上にcomposeされています。また、`Layered`の実装では基本的にinnerを最初に呼び出すので実質的に最初に呼び出されるのは`Registry`の処理になります。まずは[`tracing_subscriber::registry::Registry`のdoc](https://docs.rs/tracing-subscriber/0.3.16/tracing_subscriber/registry/struct.Registry.html)を見てみます。

> A shared, reusable store for spans.
> A Registry is a Subscriber around which multiple Layers implementing various behaviors may be added. Unlike other types implementing Subscriber, Registry does not actually record traces itself: instead, it collects and stores span data that is exposed to any Layers wrapping it through implementations of the LookupSpan trait. The Registry is responsible for storing span metadata, recording relationships between spans, and tracking which spans are active and which are closed. In addition, it provides a mechanism for Layers to store user-defined per-span data, called extensions, in the registry. This allows Layer-specific data to benefit from the Registry’s high-performance concurrent storage.

まとめると

* Subscriberの実装で、layerが追加される
* traceを記録しない
* spanのdataをcollectして他のlayerに提供する
* metadataやrelationships,activeやcloseといったspanの情報を管理する
* extensionを通じてuser側でspanを拡張できる仕組みを提供する

ということで、`Subscriber`の機能のうちspan関連の責務をになっていそうです。詳細についてはこのあと`Span::new()`や`Span::enter()`をおっていく中でみていきます。  
ここでは以下の点をおさえます

* `Layered`の実装から最初によばれるのは`Registry`の処理
* spanの情報を管理して他の`Layer`に提供するのが`Registry`の責務

### `fmt_layer::Layer`

```
Layered<
    LevelFilter,
    Layered<
        fmt_layer::Layer,
        Registry,
    >
>    
```

`FmtSubscriber`の最後のcomponentは`fmt_layer::Layer`です。[doc](https://docs.rs/tracing-subscriber/0.3.16/tracing_subscriber/fmt/struct.Layer.html)に

> A Layer that logs formatted representations of tracing events.

とある通り、`tracing_subscriber::Layer`を実装するstructです。このLayerが実際に`info!()`した際にeventを出力する処理を実装します。

以下のように定義されています。

```rust
pub struct Layer<
    S,
    N = format::DefaultFields,
    E = format::Format<format::Full>,
    W = fn() -> io::Stdout,
> {
    make_writer: W,
    fmt_fields: N,
    fmt_event: E,
    fmt_span: format::FmtSpanConfig,
    is_ansi: bool,
    log_internal_errors: bool,
    _inner: PhantomData<fn(S)>,
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L62](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L62)

4つもgenericsをもっています。`FmtSubscriber`のgenericsが多かったのはこの`fmt_layer::Layer`のためです。  
まず`S`ですが、これは`fmt_layer::Layer`がwrapしている`Subscriber`を抽象化しています。最初わかりづらかったのは`fmt_layer::Layer`自体は`Subscriber`を保持しておらず、実際に保持しているのは`Layered`になります。そのため、`PhantomData<fn(S)>`となっています。  
`N`と`E`ですが、`tracing_subscriber`ではeventを出力する際に必要な機能が細かくtraitになっています。  
`N`はeventとspan共通のkey,valueを出力し、`E`は実際にeventを出力します。`W`は出力先の切り替えを担います。

```rust
impl<S, N, E, W> layer::Layer<S> for Layer<S, N, E, W>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'writer> FormatFields<'writer> + 'static,
    E: FormatEvent<S, N> + 'static,
    W: for<'writer> MakeWriter<'writer> + 'static,
{
    // ...
    fn on_event(&self, event: &Event<'_>, ctx: Context<'_, S>) { /* .. */ }
}
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L764](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L764)

のちほど処理の内容をおっていきますが、`fmt_layer::Layer`が`Layer`を実装しており、`Layered`から呼ばれる`on_event()`が実際のeventのロギング処理です。

### `Subscriber`の登録

`FmtSubscriber`の各componentをみてきたので最後にconstructした`FmtSubscriber`を`tracing`から見える位置にセットする処理をみます。

```rust
tracing_subscriber::fmt().init();
```
この処理が呼ばれると`SubscriberBuilder`が`FmtSubscriber`をconstructしたのち以下の処理が呼ばれます

```rust
fn try_init(self) -> Result<(), TryInitError> {
        dispatcher::set_global_default(self.into()).map_err(TryInitError::new)?;
    
        // ...

        Ok(())
    }
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/util.rs#L59](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/util.rs#L59)

`dispatcher::set_global_default`は`tracing_core`に定義されており、以下のような処理です。


```rust
static GLOBAL_INIT: AtomicUsize = AtomicUsize::new(UNINITIALIZED);

const UNINITIALIZED: usize = 0;
const INITIALIZING: usize = 1;
const INITIALIZED: usize = 2;

static mut GLOBAL_DISPATCH: Option<Dispatch> = None;
// ...
pub fn set_global_default(dispatcher: Dispatch) -> Result<(), SetGlobalDefaultError> {
    if GLOBAL_INIT
        .compare_exchange(
            UNINITIALIZED,
            INITIALIZING,
            Ordering::SeqCst,
            Ordering::SeqCst,
        )
        .is_ok()
    {
        unsafe {
            GLOBAL_DISPATCH = Some(dispatcher);
        }
        GLOBAL_INIT.store(INITIALIZED, Ordering::SeqCst);
        EXISTS.store(true, Ordering::Release);
        Ok(())
    } else {
        Err(SetGlobalDefaultError { _no_construct: () })
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L296](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L296)

名前にglobalとある通りglobal変数の`GLOBAL_DISPATCH`にセットする処理です。  
`AtomicUsize::compare_exchange()`は現在の値が第一引数のときのみ第二引数の値をセットする関数です。  
そのためこの処理は一度しか呼べないことがわかります。  
`set_global_default()`の引数の型は`Dispatch`となっているので、`FmtSubscriber`から`Dispatch`への変換が必要です。

ここで`Dispatch`の定義ですが以下にある通り、`Subscriber`を`Arc`でtrait objectとして保持しているwrapperです。

```rust
#[derive(Clone)]
pub struct Dispatch {
    subscriber: Arc<dyn Subscriber + Send + Sync>,
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L154](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L154)

シンプルなwrapperなので`tracing_core::Subscriber`を実装した型から`Dispatch`への変換が提供されています。

```rust
impl<S> From<S> for Dispatch
where
    S: Subscriber + Send + Sync + 'static,
{
    #[inline]
    fn from(subscriber: S) -> Self {
        Dispatch::new(subscriber)
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L720](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L720)

```rust
impl Dispatch {
    // ...
    pub fn new<S>(subscriber: S) -> Self
        where
            S: Subscriber + Send + Sync + 'static,
    {
        let me = Dispatch {
            subscriber: Arc::new(subscriber),
        };
        callsite::register_dispatch(&me);
        me
    }
}
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L451](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L451)

`Dispatch::new()`の中で`Subscriber`をHeapに確保します。`callsite::register_dispatch()`はのちほど言及します。

ということで、`FmtSubscriber`の初期化処理(`init()`)では`FmtSubscriber`をArcにして`Dispatch`で薄くwrapしてglobal変数にセットしていることがわかりました。`info!()`や`info_span!()`ではこのglobalの`Dispatch`(`FmtSubscriber`)が参照されます。  
`callsite::register_dispatch()`はfiltering処理を見ていく際に確認します。


### `FmtSubscriber` まとめ

```
Layered<
    LevelFilter,
    Layered<
        fmt_layer::Layer,
        Registry,
    >
>
```

`FmtSubscriber`の各componentの概要をみてきました。  
`Layered`は`Layer`と`Subscriber`をcomposeする型でそれ自身が`Subscriber`です。  
`LevelFilter`はloggingのenable判断を行う`Layer`です。  
`fmt_layer::Layer`はeventのloggingを担う`Layer`で`info!()`がloggingされるのはこの`Layer`の実装によります。  
`Register`はroot Layerともいうべき役割で、spanの管理をおこないます。  


## `tracing::Span::new()`

`FmtSubscriber`の概要を押さえたのでいよいよtracingのapiを追っていきます。  コードの概略をもう一度みてみます。

```rust
fn main() {
    tracing_subscriber::fmt().init();

    let span = {
        static CALLSITE = { /* ... */ };
        tracing::Span::new(CALLSITE)
    };
    let _guard = span.enter();

    {
        static CALLSITE = { /* ... */ }
        tracing::Event::dispatch(CALLSITE)
    }
}
```

`tracing_subscriber::fmt().init()`が`FmtSubscriber`のconstructとglobal変数へのセットということを見てきたので、`tracing::Span::new()`をみていきます。

```rust
impl Span {
    pub fn new(meta: &'static Metadata<'static>, values: &field::ValueSet<'_>) -> Span {
        dispatcher::get_default(|dispatch| Self::new_with(meta, values, dispatch))
    }
    
    pub fn new_with(
        meta: &'static Metadata<'static>,
        values: &field::ValueSet<'_>,
        dispatch: &Dispatch,
    ) -> Span {
        let new_span = Attributes::new(meta, values);
        Self::make_with(meta, new_span, dispatch)
    }

    fn make_with(
        meta: &'static Metadata<'static>,
        new_span: Attributes<'_>,
        dispatch: &Dispatch,
    ) -> Span {
        let attrs = &new_span;
        let id = dispatch.new_span(attrs);
        let inner = Some(Inner::new(id, dispatch));

        let span = Self {
            inner,
            meta: Some(meta),
        };

        // ...
        
        span
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L436](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L436)

`dispatcher::get_default()`に`Span::new_with()`で自身をconstructする処理をclosureで渡しています。

```rust
thread_local! {
    static CURRENT_STATE: State = State {
        default: RefCell::new(None),
        can_enter: Cell::new(true),
    };
}

struct State {
    default: RefCell<Option<Dispatch>>,
    can_enter: Cell<bool>,
}

pub fn get_default<T, F>(mut f: F) -> T
where
    F: FnMut(&Dispatch) -> T,
{
    CURRENT_STATE
        .try_with(|state| {
            if let Some(entered) = state.enter() {
                return f(&*entered.current());
            }

            f(&Dispatch::none())
        })
        .unwrap_or_else(|_| f(&Dispatch::none()))
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L364](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L364)

`dispatcher::get_default()`の中ではthreadごとに保持している`Dispatch`を参照します。`State.default`に保持されている`RefCell<Option<Dispatch>>`は初期状態では`None`です。

`State`自体はstaticでcompile時に初期化されているので、`State::enter()`の処理をみてみると

```rust
impl State {
    // ...
    fn enter(&self) -> Option<Entered<'_>> {
    if self.can_enter.replace(false) {
        Some(Entered(self))
    } else {
        None
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L799](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L799)

`Entered`という`State`のguardを表す型を返し、`Entered::current()`の戻り値で`Span::new()`で渡したclosureを呼び出します。

```rust
impl<'a> Entered<'a> {
    #[inline]
    fn current(&self) -> RefMut<'a, Dispatch> {
        let default: RefMut<Option<Dispatch>> = self.0.default.borrow_mut();
        // default is None
        RefMut::map(default, |default| {
            default.get_or_insert_with(|| get_global().cloned().unwrap_or_else(Dispatch::none))
        })
    }
}
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L811](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L811)

わかりづらいかもしれませんがここにきてようやく最初にセットしたGlobalの`Dispatch`が参照されます。上記の`default`変数は`None`で、`Option::get_or_insert_with()`はNoneの場合closureの戻り値を自身にセットしたうでそのmut参照を返します。

```rust
fn get_global() -> Option<&'static Dispatch> {
    if GLOBAL_INIT.load(Ordering::SeqCst) != INITIALIZED {
        return None;
    }
    unsafe {
        // This is safe given the invariant that setting the global dispatcher
        // also sets `GLOBAL_INIT` to `INITIALIZED`.
        Some(GLOBAL_DISPATCH.as_ref().expect(
            "invariant violated: GLOBAL_DISPATCH must be initialized before GLOBAL_INIT is set",
        ))
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L423](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L423)

これでようやく最初の`tracing_subscriber::fmt().init()`でセットした`Dispatch`(`FmtSubscriber`)が参照されていることがわかりました。

あらためて、`Span::new()`に戻ると`new()` -> `new_with()` -> `make_with()`と呼ばれます。

```rust
impl Span {
    // ...
    fn make_with(
        meta: &'static Metadata<'static>,
        new_span: Attributes<'_>,
        dispatch: &Dispatch,
    ) -> Span {
        let attrs = &new_span;
        let id = dispatch.new_span(attrs);
        let inner = Some(Inner::new(id, dispatch));

        let span = Self {
            inner,
            meta: Some(meta),
        };

        // ...

        span
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L563](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L563)

`Metadata`や`Attributes`は`info_span!()`の情報です。  

```rust
let id = dispatch.new_span(attrs);
```

ここにきてようやく`tracing`と`tracing_subscriber`がつながりました。  
引数の`dispatch`はglobalに確保した`Dispatch`であることを見てきておりさらに`Dispatch`は`FmtSubscriber`のwrapperであることもわかっています。ということで`FmtSubscriber::new_span()`をみていきます。

```rust
pub struct Subscriber<
    N = format::DefaultFields,
    E = format::Format<format::Full>,
    F = LevelFilter,
    W = fn() -> io::Stdout,
> {
    inner: layer::Layered<F, Formatter<N, E, W>>,
}

impl<N, E, F, W> tracing_core::Subscriber for Subscriber<N, E, F, W>
    where // ...
{
    fn new_span(&self, attrs: &span::Attributes<'_>) -> span::Id {
        self.inner.new_span(attrs)
    }
}
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/mod.rs#L387](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/mod.rs#L387)

`Subscriber`(`FmtSubscriber`)は`Layered`のwrapperなので基本的に処理をすべて`inner`に委譲します。ということで次は`Layered::new_span()`です。

```rust
impl<L, S> Subscriber for Layered<L, S>
where
    L: Layer<S>,
    S: Subscriber,
{
    fn new_span(&self, span: &span::Attributes<'_>) -> span::Id {
        let id = self.inner.new_span(span);
        self.layer.on_new_span(span, &id, self.ctx());
        id
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/layered.rs#L125](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/layered.rs#L125)

`Layered`のgenerics`S`は自身がwrapしている`Subscriber`(or`Layer`)でそれが`Subscriber`を実装していることがわかっています。  
ここで注目していただきたいのが、最初に`self.inner.new_span()`を呼び出した後自身の`self.layer.on_new_span()`を呼んでいる点です。  
`FmtSubscriber`の構造の概略を再掲すると

```
Layered<
    LevelFilter,
    Layered<
        fmt_layer::Layer,
        Registry,
    >
>
```

のようになっているので、上記の`self.inner`は`Layered<fmt_layer::Layer,Registry>`を参照します。そして、このnestした`Layered`の`new_span()`でも`self.inner.new_span()`が最初によばれるので結局、`Registry::new_span()`が呼ばれることになります。

```rust
impl Subscriber for Registry {
    // ...
    fn new_span(&self, attrs: &span::Attributes<'_>) -> span::Id {
        let parent = if attrs.is_root() {
            None
        } else if attrs.is_contextual() {
            self.current_span().id().map(|id| self.clone_span(id))
        } else {
            attrs.parent().map(|id| self.clone_span(id))
        };

        let id = self
            .spans
            .create_with(|data| {
                data.metadata = attrs.metadata();
                data.parent = parent;
                data.filter_map = crate::filter::FILTERING.with(|filtering| filtering.filter_map());
                #[cfg(debug_assertions)]
                {
                    if data.filter_map != FilterMap::default() {
                        debug_assert!(self.has_per_layer_filters());
                    }
                }

                let refs = data.ref_count.get_mut();
                debug_assert_eq!(*refs, 0);
                *refs = 1;
            })
            .expect("Unable to allocate another span");
        idx_to_id(id)
    }
}
```

ようやくspanの実質的な処理にたどり着きました。  
まず、
```rust
let parent = if attrs.is_root() {
    None
} else if attrs.is_contextual() {
    self.current_span().id().map(|id| self.clone_span(id))
} else {
    attrs.parent().map(|id| self.clone_span(id))
};
```

この`parent`は`None`が入ります。`info_span!()` macroは明示的に親のspanを指定することもできるのでここで親の`span::Id`の判定をしています。今回の例では今生成しているspanがrootなので親はいません。  
重要なのは以下の箇所です。

```rust
let id = self
    .spans
    .create_with(|data: &mut DataInner| {
        data.metadata = attrs.metadata();
        data.parent = parent;
        // ...
```

`Registry`の定義を確認すると

```rust
use sharded_slab::{pool::Ref, Clear, Pool};

pub struct Registry {
    spans: Pool<DataInner>,
    current_spans: ThreadLocal<RefCell<SpanStack>>,
    next_filter_id: u8,
}
```

となっており、`self.span.create_with()`は`shareded_slab::Pool::create_with()`を呼んでいます。  
ここで前提でふれた`shareded_slab::Pool`がでてきます。
[doc](https://docs.rs/sharded-slab/0.1.4/sharded_slab/pool/struct.Pool.html#method.create_with)には

> Creates a new object in the pool with the provided initializer, returning a key that may be used to access the new object.

とあるので、この処理で`Registry`内に`DataInner`が生成され、その`DataInner`を識別するためのidが返されます。`DataInner`の定義をみてみると以下のようになっています。

```rust
struct DataInner {
    filter_map: FilterMap,
    metadata: &'static Metadata<'static>,
    parent: Option<Id>,
    ref_count: AtomicUsize,
    pub(crate) extensions: RwLock<ExtensionsInner>,
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L123](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L123)

ここで、`metadata`として、`info_span!()`で生成した呼び出し元の情報を
保持していることがわかります。また`extensions`を通じて任意の型を保持できる機能もあるのですがこれは`Span::enter()`で利用します。

最後に`idx_to_id()`で`sharded_slab`のindexを`Span::Id`にwrapします。

```rust
pub struct Id(NonZeroU64);

fn idx_to_id(idx: usize) -> Id {
    Id::from_u64(idx as u64 + 1)
}
```

この生成された`sharded_slab`のindexをspanのidとして呼び出し元に返します。

```rust
impl Span {
    // ...
    fn make_with(
        meta: &'static Metadata<'static>,
        new_span: Attributes<'_>,
        dispatch: &Dispatch,
    ) -> Span {
        let attrs = &new_span;
        // 👇
        let id = dispatch.new_span(attrs);
        let inner = Some(Inner::new(id, dispatch));

        let span = Self {
            inner,
            meta: Some(meta),
        };

        // ...

        span
    }
}
```

このidと`Dispatch`と`Metadata`を保持する`Span`を返します。

```rust
pub struct Span {
    inner: Option<Inner>,
    meta: Option<&'static Metadata<'static>>,
}

#[derive(Debug)]
pub(crate) struct Inner {
    id: Id,
    subscriber: Dispatch,
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L348](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L348)

ということで、`Spann::new()`を呼び出すとglobalに確保した`FmtSubscriber`のinnerに保持していた`Registry`内の`sharded_slab::Pool`に`Span`に関する情報が保持され識別子として`Span::Id`が振り出されることがわかりました。  
これが`Registry`のdocに書いてあった

> Registry is responsible for storing span metadata

の実体ということがわかりました。  
次に`Span::enter()`をみていくのですが、この処理を追っていくとdocの

> recording relationships between spans, and tracking which spans are active and which are closed.

の具体的な処理内容がわかります。

## `tracing::Span::enter()`

`Span::enter()`の内容は以下にようになっています。

```rust
impl Span {
    // ...
    pub fn enter(&self) -> Entered<'_> {
        self.do_enter();
        Entered { span: self }
    }

    fn do_enter(&self) {
        if let Some(inner) = self.inner.as_ref() {
            inner.subscriber.enter(&inner.id);
        }

        // ...
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L785](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing/src/span.rs#L785)

`Entered`はguard用のstructで`Drop`を実装しているので最後に見ます。`Span`は以下のように定義されているので、`Span.inner.subscriber`は`FmtSubscriber`を参照しています。  


```rust
#[derive(Clone)]
pub struct Span {
    inner: Option<Inner>,
    meta: Option<&'static Metadata<'static>>,
}

#[derive(Debug)]
pub(crate) struct Inner {
    id: Id,
    subscriber: Dispatch,
}
```

そして、`FmtSubscriber`は処理を`Layered`に委譲しており、`Layered`は`Span::new()`でみたとおり、`inner`をまず呼び出します。

```rust
impl<L, S> Subscriber for Layered<L, S>
    where
        L: Layer<S>,
        S: Subscriber,
{
    // ...
    fn enter(&self, span: &span::Id) {
        self.inner.enter(span);
        self.layer.on_enter(span, self.ctx());
    }
}
```

ということで、`Span::new()`同様、`Span::enter()`も最初に`Registry`によって処理されます。  
`Registry`が`Span::enter()`で渡された`Span::Id`をどのように扱うかみていきます。

```rust
pub struct Registry {
    spans: Pool<DataInner>,
    current_spans: ThreadLocal<RefCell<SpanStack>>,
    next_filter_id: u8,
}

impl Subscriber for Registry {
    // ...
    fn enter(&self, id: &span::Id) {
        if self
            .current_spans
            .get_or_default()
            .borrow_mut()
            .push(id.clone())
        {
            self.clone_span(id);
        }
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L289](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L289)

`self.current_spans`は`ThreadLocal`を参照しており、以下のように`ThreadLocal`は以下のように`ThreadLocal<T>`の`T`が`Default`を実装している場合、`ThreadLocal::get_or_default()`は`T::default()`を返します。

```rust
impl<T: Send + Default> ThreadLocal<T> {
    pub fn get_or_default(&self) -> &T {
        self.get_or(Default::default)
    }
}
```

[https://docs.rs/thread_local/latest/thread_local/struct.ThreadLocal.html#method.get_or_default](https://docs.rs/thread_local/latest/thread_local/struct.ThreadLocal.html#method.get_or_default)

同様に`RefCell<T>`も`T`が`Default`を実装している場合、`T::default()`を返すので最終的には`SpanStack::default()`が呼ばれます。

```rust
pub(crate) use tracing_core::span::Id;

#[derive(Debug)]
struct ContextId {
    id: Id,
    duplicate: bool,
}

#[derive(Debug, Default)]
pub(crate) struct SpanStack {
    stack: Vec<ContextId>,
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/stack.rs#L14](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/stack.rs#L14)

`SpanStack`は`Vec<ContextId>`のwrapperで、`ContextId`は`span::Id`のwrapperなので、実体としては`Vec<span::Id>`といえます。  
以上を踏まえてもう一度`Registry::enter()`をみてみると

```rust
    fn enter(&self, id: &span::Id) {
        if self
            .current_spans    // ThreadLocal<RefCell<SpanStack>>
            .get_or_default() // RefCell<SpanStack>
            .borrow_mut()     // RefMut<SpanStack>
            .push(id.clone()) // SpanStack::push()
        {
            self.clone_span(id);
        }
    }
```

のようになっており、`SpanStack`をconstructしたのち、`span::Id`を`Vec`にpushします。  

```rust
impl SpanStack {
    #[inline]
    pub(super) fn push(&mut self, id: Id) -> bool {
        let duplicate = self.stack.iter().any(|i| i.id == id);
        self.stack.push(ContextId { id, duplicate });
        !duplicate
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/stack.rs#L20](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/stack.rs#L20)

`SpanStack::push()`は現在のstack上に重複があるかを判定したのちpushします。  
ここでなぜ重複を考慮する必要があるのだろうという疑問が生じます。

```rust
let _guard_a = info_span!("outer").entered();
{
    let _guard_b = info_span!("inner").entered();
}
```
のように`Span`はmacroの呼び出しごとに生成されるので、上記のouter spanがdropされるまではouter spanに再びenterすることはないように思われるからです。  
ここが`tracing`の注意点でもあるのですが、`tracing`はasync/awaitのコードではそのまま使えません。(本記事の例のようには)。async/await用に`tracing_future` crateが用意されそちらを合わせて使う必要があります。本記事では`tracing_future`にはふれません。(次回言及するかもしれません)

> Warning: in asynchronous code that uses async/await syntax, Span::enter should be used very carefully or avoided entirely. Holding the drop guard returned by Span::enter across .await points will result in incorrect traces

[doc](https://docs.rs/tracing/0.1.35/tracing/struct.Span.html#in-asynchronous-code)にも上記のようにwarningが書かれています。

tracingのコードを読んでみようとおもったきっかけのひとつにどうしてasync/awaitで使うとうまく動作しないのか知りたいというのが一つありました。これはあくまで推測なのですが、async fnの中で`info_span!()`を書くと最終的には以下のようなコードになるからではと考えております。

```rust
impl Future for MyFuture {
    type Output = ();

    fn poll(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Self::Output> {
        match self.project().state {
            // Running at thread A
            MyFutureState::A(..) => {
                self.span = info_span!("my_span");
                self.guard = span.enter();
                self.state = MyFutureState::B;
                // ...
            }
            // Running at thread B
            MyFutureState::B(..) => { /* ... */ }
        }
    }
}
```

のような`Future::poll`になり、`Span::enter()`がthread Aで実行され、guardのdropがthread Bで実行される結果、thread AのSpanStack上のidがpopされずstack上に留まり続けることになってしまう。  

話を`Registry::enter()`に戻します。ここで注意したいのが

```rust
pub struct Registry {
    spans: Pool<DataInner>,
    current_spans: ThreadLocal<RefCell<SpanStack>>,
    // ...
}
```

`spans`はthread間で共有されるのに対して、`current_spans`は`ThreadLocal`型なのでthreadごとに`SpanStack`が生成される点です。

これで`Span::enter()`の中で、`Registry`のstackにenterしたspanのidを保持することによって

> tracking which spans are active

していることがわかりました。

```rust
impl Span {
    pub fn enter(&self) -> Entered<'_> {
        self.do_enter();
        Entered { span: self }
    }
}
```

`Span::enter()`は戻り値として`Entered`を返します。`Entered`はdrop時にspanを閉じる責務をもつguardです。

```rust
impl<'a> Drop for Entered<'a> {
    #[inline(always)]
    fn drop(&mut self) {
        self.span.do_exit()
    }
}
```
Drop時に`Span::do_exit()`を呼んでいます。

```rust
impl Span {
    fn do_exit(&self) {
        if let Some(inner) = self.inner.as_ref() {
            inner.subscriber.exit(&inner.id);
        }
        // ...
    }
}
```

`Span::do_exit()`も`enter()`同様subscriberのexitを呼び出します。`exit()`の実装も興味深い点(`Drop`時特有の考慮事項)が多いのですがeventのloggingの観点からはずれてしまうので詳細は割愛します。基本的には`SpanStack`から当該idをremoveします。

ここまででようやくspanの生成とactivate(enter)の処理内容がわかりました。  
前準備が終わったのでついに`info!()`処理に入ることができます。


## `tracing::Event::dispatch`

Macroのexpandで確認したように`info!()`は最終的に`Event::dispatch()`に展開されます。  
`Metadada`と`field::ValueSet`は呼び出し時の情報です。

```rust
impl<'a> Event<'a> {
    /// Constructs a new `Event` with the specified metadata and set of values,
    /// and observes it with the current subscriber.
    pub fn dispatch(metadata: &'static Metadata<'static>, fields: &'a field::ValueSet<'_>) {
        let event = Event::new(metadata, fields);
        crate::dispatcher::get_default(|current| {
            current.event(&event);
        });
    }
}
```

`Event`は以下のように定義されています。`field`と`metadata`はmacro呼び出し時の情報です。`parent`は`Event`が含まれているspanです。

```rust
#[derive(Debug)]
pub struct Event<'a> {
    fields: &'a field::ValueSet<'a>,
    metadata: &'static Metadata<'static>,
    parent: Parent,
}

impl<'a> Event<'a> {
    pub fn new(metadata: &'static Metadata<'static>, fields: &'a field::ValueSet<'a>) -> Self {
        Event {
            fields,
            metadata,
            parent: Parent::Current,
        }
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/event.rs#L23](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/event.rs#L23)

```rust
pub(crate) enum Parent {
    Root,
    Current,
    Explicit(Id),
}
```

`Parent`は上記のように`Explicit`で明示的に指定するか、`Current`でcontextから判断するかの情報です。`info!()`は内部的に`event!()` macro呼び出しに展開されるのですが`event!()`では紐づくspanを下記のように指定することも可能です。

```rust
let span = span!(Level::TRACE, "my span");
event!(parent: &span, Level::INFO, "something has happened!");
```

`Event::dispatch()`は`Dispatch::event()`を呼び出しています。

```rust
impl Dispatch {
    pub fn event(&self, event: &Event<'_>) {
        if self.subscriber.event_enabled(event) {
            self.subscriber.event(event);
        }
    } 
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L584](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L584)

`Subscriber::event_enabled()`のenable判定は一通りの流れを確認したあと、`CALLSITE`のregister処理でみるのでここでは割愛します。  
`Dispatch::event()` -> `FmtSubscriber::event()` -> `Layered::event()`の委譲の流れはspanと同様です。また`Layered`の処理もまずinnerに先に委譲するのも同じです。

```rust
impl<L, S> Subscriber for Layered<L, S>
where
    L: Layer<S>,
    S: Subscriber,
{
    fn event(&self, event: &Event<'_>) {
        self.inner.event(event);
        self.layer.on_event(event, self.ctx());
    }
}
```

ということで、最初に`Registry`はなにかしているでしょうか。

```rust
impl Subscriber for Registry {
    /// This is intentionally not implemented, as recording events
    /// is the responsibility of layers atop of this registry.
    fn event(&self, _: &Event<'_>) {}
}
```

コメントにもある通り、`Registry::event()`ではなにもしていません。eventのhandlingはlayerの責務であるとしています。ということで、次は`fmt_layer::Layer`です。

```rust
impl<S, N, E, W> layer::Layer<S> for Layer<S, N, E, W>
    where
        S: Subscriber + for<'a> LookupSpan<'a>,
        N: for<'writer> FormatFields<'writer> + 'static,
        E: FormatEvent<S, N> + 'static,
        W: for<'writer> MakeWriter<'writer> + 'static,
{
    fn on_event(&self, event: &Event<'_>, ctx: Context<'_, S>) {
        thread_local! {
                static BUF: RefCell<String> = RefCell::new(String::new());
            }

        BUF.with(|buf| {
            let borrow = buf.try_borrow_mut();
            let mut a;
            let mut b;
            let mut buf = match borrow {
                Ok(buf) => {
                    a = buf;
                    &mut *a
                }
                _ => {
                    b = String::new();
                    &mut b
                }
            };

            let ctx = self.make_ctx(ctx, event);
            if self
                .fmt_event
                .format_event(
                    &ctx,
                    format::Writer::new(&mut buf).with_ansi(self.is_ansi),
                    event,
                )
                .is_ok()
            {
                let mut writer = self.make_writer.make_writer_for(event.metadata());
                let res = io::Write::write_all(&mut writer, buf.as_bytes());
                if self.log_internal_errors {
                    if let Err(e) = res {
                        eprintln!("[tracing-subscriber] Unable to write an event to the Writer for this Subscriber! Error: {}\n", e);
                    }
                }
            } else if self.log_internal_errors {
                let err_msg = format!("Unable to format the following event. Name: {}; Fields: {:?}\n",
                                      event.metadata().name(), event.fields());
                let mut writer = self.make_writer.make_writer_for(event.metadata());
                let res = io::Write::write_all(&mut writer, err_msg.as_bytes());
                if let Err(e) = res {
                    eprintln!("[tracing-subscriber] Unable to write an \"event formatting error\" to the Writer for this Subscriber! Error: {}\n", e);
                }
            }

            buf.clear();
        });
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L904](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L904)

がっつり処理が書かれています。また`io::Write::write_all()`があるのでどうやらここでeventの書き込み処理まで実施していそうです。ここがeventのlogging処理と思われるで見ていきましょう。

```rust
fn on_event(&self, event: &Event<'_>, ctx: Context<'_, S>) { }
```

まず`on_event()`の引数ですが、`Event`は`info!()`で生成した`Event`なのは良いとして、`Context`はどこから来たのでしょうか。  
`Layered`の`event()`をもう一度みてみると

```rust
    fn event(&self, event: &Event<'_>) {
        self.inner.event(event);
        self.layer.on_event(event, self.ctx());
    }
```

`fmt_layer::Layer::on_event()`に`self.ctx()`で`Context`を生成して渡していました。

```rust
impl<L, S> Layered<L, S>
where
    S: Subscriber,
{
    fn ctx(&self) -> Context<'_, S> {
        Context::new(&self.inner)
    }
}

pub struct Context<'a, S> {
    subscriber: Option<&'a S>,
    #[cfg(all(feature = "registry", feature = "std"))]
    filter: FilterId,
}

// === impl Context ===

impl<'a, S> Context<'a, S>
    where
        S: Subscriber,
{
    pub(super) fn new(subscriber: &'a S) -> Self {
        Self {
            subscriber: Some(subscriber),

            #[cfg(feature = "registry")]
            filter: FilterId::none(),
        }
    }
}
```

ということで、`Context`は`Subscriber`のwrapperで、ここでは`Registry`を渡していると考えることができます。


```rust
    fn on_event(&self, event: &Event<'_>, ctx: Context<'_, S>) {
        thread_local! {
                static BUF: RefCell<String> = RefCell::new(String::new());
            }

        BUF.with(|buf| {
            let borrow = buf.try_borrow_mut();
            let mut a;
            let mut b;
            let mut buf = match borrow {
                Ok(buf) => {
                    a = buf;
                    &mut *a
                }
                _ => {
                    b = String::new();
                    &mut b
                }
            };

            // ...
        }
}
```

ここは実質的にformatしたeventの書き込みbufferの生成処理です。thread localと`RefCell`の合わせ技で`String`をこの様に再利用する方法が参考になります。  

```rust
let ctx = self.make_ctx(ctx, event);
```

`Context`と`Event`を保持する`FmtContext`を生成しています。

```rust
pub struct FmtContext<'a, S, N> {
    pub(crate) ctx: Context<'a, S>,
    pub(crate) fmt_fields: &'a N,
    pub(crate) event: &'a Event<'a>,
}

impl<S, N, E, W> Layer<S, N, E, W>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'writer> FormatFields<'writer> + 'static,
    E: FormatEvent<S, N> + 'static,
    W: for<'writer> MakeWriter<'writer> + 'static,
{
    #[inline]
    fn make_ctx<'a>(&'a self, ctx: Context<'a, S>, event: &'a Event<'a>) -> FmtContext<'a, S, N> {
        FmtContext {
            ctx,
            fmt_fields: &self.fmt_fields,
            event,
        }
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L971](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L971)

```rust
if self
    .fmt_event
    .format_event(
        &ctx,
        format::Writer::new(&mut buf).with_ansi(self.is_ansi),
        event,
    )
    .is_ok()
{
    let mut writer = self.make_writer.make_writer_for(event.metadata());
    let res = io::Write::write_all(&mut writer, buf.as_bytes());
    if self.log_internal_errors {
        if let Err(e) = res {
            eprintln!("[tracing-subscriber] Unable to write an event to the Writer for this Subscriber! Error: {}\n", e);
        }
    }
} else if self.log_internal_errors {
    let err_msg = format!("Unable to format the following event. Name: {}; Fields: {:?}\n",
                          event.metadata().name(), event.fields());
    let mut writer = self.make_writer.make_writer_for(event.metadata());
    let res = io::Write::write_all(&mut writer, err_msg.as_bytes());
    if let Err(e) = res {
        eprintln!("[tracing-subscriber] Unable to write an \"event formatting error\" to the Writer for this Subscriber! Error: {}\n", e);
    }
}

buf.clear();
```

`self.fmt_event.format_event()`でおそらく、確保した`String`にeventの情報を書き込んでおり、成功した場合は

```rust
let mut writer = self.make_writer.make_writer_for(event.metadata());
let res = io::Write::write_all(&mut writer, buf.as_bytes());
```

`self.make_writer`で書き込み先のwriterを生成します。

```rust
pub struct Subscriber<
    // ...
    W = fn() -> io::Stdout,
> {/* ... */ }
```
としてデフォルトで`io::Stdout`を返す関数が指定されているのでここでは`writer`は`Stdout`になります。残りの処理はeventのformat時のエラーやbuffer書き込み時のエラーハンドリングなので省略します。  
async fnの中で`info!()`を呼ぶと上記でみたように`io::Stdout`に書きこみ処理が走っておりこれはblockingな処理と思われるので、async fnの中ではblockingな処理を呼ばないという原則に反しないのかなという疑問が生じました。ソースを読んだ限りですと、`Event::dispatch()`といっても別threadに逃すような処理は見受けられなかったので気になりました。

この点はともかくとして、ついにeventの書き込み処理をみつけたので残りは以下のeventのformat処理です。

```rust
self
    .fmt_event
    .format_event(
        &ctx,
        format::Writer::new(&mut buf).with_ansi(self.is_ansi),
        event,
   )
```

`fmt_layer::Layer`の定義は以下のようになっており、`fmt_event`はデフォルトでは`format::Format<format::Full>`です。

```rust
pub struct Layer<
    S,
    N = format::DefaultFields,
    E = format::Format<format::Full>,
    W = fn() -> io::Stdout,
> {
    make_writer: W,
    fmt_fields: N,
    fmt_event: E,
    fmt_span: format::FmtSpanConfig,
    is_ansi: bool,
    log_internal_errors: bool,
    _inner: PhantomData<fn(S)>,
}
```
また、`format_event()`は`FormatEvent` traitとして定義されており、`format::Format<format::Full>`はこれを実装しています。

```rust
pub trait FormatEvent<S, N>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
{
    /// Write a log message for `Event` in `Context` to the given [`Writer`].
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result;
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L195](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L195)


```rust
impl<S, N, T> FormatEvent<S, N> for Format<Full, T>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
    T: FormatTime,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result {
        // ...
        let meta = event.metadata();
        
        if let Some(ansi) = self.ansi {
            writer = writer.with_ansi(ansi);
        }

        self.format_timestamp(&mut writer)?;

        if self.display_level {
            // ...
        }

        if self.display_thread_name {
            // ...
        }

        if self.display_thread_id {
            // ...
        }

        let dimmed = writer.dimmed();

        if let Some(scope) = ctx.event_scope() {
            // ...
            for span in scope.from_root() {
                write!(writer, "{}", bold.paint(span.metadata().name()))?;
                // ...

                let ext = span.extensions();
                if let Some(fields) = &ext.get::<FormattedFields<N>>() {
                    if !fields.is_empty() {
                        write!(writer, "{}{}{}", bold.paint("{"), fields, bold.paint("}"))?;
                    }
                }
                // ...
            }
            // ...
        };

        if self.display_target {
            // ...
        }

        // ...

        if self.display_filename {
            // ...
        }

        ctx.format_fields(writer.by_ref(), event)?;
        writeln!(writer)
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L890](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L890)

長いですが、概要としては以下のようなログの情報を設定に応じて書き込んでいます。  

```sh
2022-11-11T08:39:02.198973Z  INFO span_1{key="hello"}: tracing_handson: hello
```

今回注目するのは、どのようにspanの情報を書き込んでいるかですが、おそらく以下の処理と思われます。

```rust
if let Some(scope) = ctx.event_scope() {
    // ...
    for span in scope.from_root() {
        // ...
        let ext = span.extensions();
        if let Some(fields) = &ext.get::<FormattedFields<N>>() {
            if !fields.is_empty() {
                write!(writer, "{}{}{}", bold.paint("{"), fields, bold.paint("}"))?;
            }
        }
        // ...
    }
    // ...
};
```

概要としては、`ctx`(`FmtContext`)から`scope`を取得し、scopeから`Span`のiteratorを取得したのち、`FormattedFields<N>`がspanの情報(key/value)を書き込んでいます。  
ということで、まずは`scope`から見てみます。

```rust
impl<'a, S, N> FmtContext<'a, S, N>
where
    S: Subscriber + for<'lookup> LookupSpan<'lookup>,
    N: for<'writer> FormatFields<'writer> + 'static,
{
    pub fn event_scope(&self) -> Option<registry::Scope<'_, S>>
        where
            S: for<'lookup> registry::LookupSpan<'lookup>,
    {
        self.ctx.event_scope(self.event)
    }    
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L1147](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L1147)

まず`Context.event_scope()`に委譲します。

```rust
impl<'a, S> Context<'a, S>
where
    S: Subscriber,
{
    pub fn event_scope(&self, event: &Event<'_>) -> Option<registry::Scope<'_, S>>
        where
            S: for<'lookup> LookupSpan<'lookup>,
    {
        Some(self.event_span(event)?.scope())
    }

    pub fn event_span(&self, event: &Event<'_>) -> Option<SpanRef<'_, S>>
        where
            S: for<'lookup> LookupSpan<'lookup>,
    {
        if event.is_root() {
            None
        } else if event.is_contextual() {
            self.lookup_current()
        } else {
            event.parent().and_then(|id| self.span(id))
        }
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/context.rs#L364](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/context.rs#L364)

`Context::event_scope()`は`Context::event_span()`を呼び出します。  
`is_root()`や`is_contextual()`は`Event.parent`の判定でここでは、`Parent::Current`が設定されているので、`is_contextual()`がtrueを返し、`Context::lookup_current()`が呼び出されます。

```rust

impl<'a, S> Context<'a, S>
    where
        S: Subscriber,
{

    pub fn lookup_current(&self) -> Option<registry::SpanRef<'_, S>>
        where
            S: for<'lookup> LookupSpan<'lookup>,
    {
        let subscriber = *self.subscriber.as_ref()?;
        let current = subscriber.current_span();
        let id = current.id()?;
        let span = subscriber.span(id);
        debug_assert!(
            span.is_some(),
            "the subscriber should have data for the current span ({:?})!",
            id,
        );
        
        // ...
        
        span
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/context.rs#L256](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/context.rs#L256)

ということでようやく取得処理にたどり着きました。  
`Context`は`Subscriber`のwrapperでここでは`Registry`を指しています。  

```rust
let current = subscriber.current_span();
let id = current.id()?;
let span = subscriber.span(id);
```

上記で、`Registry::current_span()`で現在のspanの情報を取得したのち当該`span::Id`から`SpanRef`を取得して返しています。  


```rust
impl Subscriber for Registry {
    fn current_span(&self) -> Current {
        self.current_spans        // ThreadLocal<RefCell<SpanStack>>
            .get()                // Option<&RefCell<SpanStack>>
            .and_then(|spans: &RefCell<SpanStack>| {
                let spans = spans.borrow(); // Ref<SpanStack>
                let id = spans.current()?;
                let span = self.get(id)?;
                Some(Current::new(id.clone(), span.metadata))
            })
            .unwrap_or_else(Current::none)
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L330](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L330)

`Registry::current_span()`の中で`SpanStack`の先頭の`span::Id`を取得しています。

```rust
impl SpanStack {
    #[inline]
    pub(crate) fn iter(&self) -> impl Iterator<Item = &Id> {
        self.stack
            .iter()
            .rev()
            .filter_map(|ContextId { id, duplicate }| if !*duplicate { Some(id) } else { None })
    }

    #[inline]
    pub(crate) fn current(&self) -> Option<&Id> {
        self.iter().next()
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/stack.rs#L50](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/stack.rs#L50)

`Current`は`span::Id`のwrapperです。  

```rust
let current = subscriber.current_span();
let id = current.id()?;
let span = subscriber.span(id);
```

`subscriber.span`で`span::Id`からspanの情報を取得します。このspanの情報の取得は以下のように`LookupSpan`というtraitで定義されています。

```rust
pub trait LookupSpan<'a> {
    type Data: SpanData<'a>;
    fn span_data(&'a self, id: &Id) -> Option<Self::Data>;
    
    fn span(&'a self, id: &Id) -> Option<SpanRef<'_, Self>>
    where
        Self: Sized,
    {
        let data = self.span_data(id)?;
        Some(SpanRef {
            registry: self,
            data,
            #[cfg(feature = "registry")]
            filter: FilterId::none(),
        })
    }
    // ...
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L92](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L92)

`LookupSpan::span()`はdefaultの実装が提供されており、実装する型は`span_data()`をimplすればよさそうです。  
`Registry::span_data()`の実装はシンプルで`Pool<DataInner>`から取得するだけです。

```rust
impl<'a> LookupSpan<'a> for Registry {
    type Data = Data<'a>;

    fn span_data(&'a self, id: &Id) -> Option<Self::Data> {
        let inner = self.get(id)?;
        Some(Data { inner })
    }

    fn register_filter(&mut self) -> FilterId {
        let id = FilterId::new(self.next_filter_id);
        self.next_filter_id += 1;
        id
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L369](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L369)

```rust
impl Registry {
    fn get(&self, id: &Id) -> Option<Ref<'_, DataInner>> {
        self.spans.get(id_to_idx(id))
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L182](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/sharded.rs#L182)

ここまでで、`Registry`の`SpanStack`から先頭の`span::Id`を取得したのち、`Pool`に確保していた`Span`の情報を取得して、`SpanRef`として返すことがわかりました。  
必要なのは現在のeventを含んでいる`Span`のiteratorなので、それを取得するために、`SpanRef::scope()`が呼ばれています。

```rust
impl<'a, S> Context<'a, S>
where
    S: Subscriber,
{
    pub fn event_scope(&self, event: &Event<'_>) -> Option<registry::Scope<'_, S>>
        where
            S: for<'lookup> LookupSpan<'lookup>,
    {
        Some(self.event_span(event)?.scope())
    }
}
```

```rust
impl<'a, R> SpanRef<'a, R>
where
    R: LookupSpan<'a>,
{
    pub fn scope(&self) -> Scope<'a, R> {
        Scope {
            registry: self.registry,
            next: Some(self.id()),

            #[cfg(feature = "registry")]
            filter: self.filter,
        }
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L465](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L465)

```rust
#[derive(Debug)]
pub struct Scope<'a, R> {
    registry: &'a R,
    next: Option<Id>,
    // ...
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L210](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L210)

`Scope`はspanのiterateする手段をいくつか提供しており、今回はroot(outer)から取得したいので、`Scope::from_root()`を呼びます。

```rust
impl<'a, R> Scope<'a, R>
where
    R: LookupSpan<'a>,
{
    pub fn from_root(self) -> ScopeFromRoot<'a, R> {
        #[cfg(feature = "smallvec")]
        type Buf<T> = smallvec::SmallVec<T>;
        #[cfg(not(feature = "smallvec"))]
        type Buf<T> = Vec<T>;
        ScopeFromRoot {
            spans: self.collect::<Buf<_>>().into_iter().rev(),
        }
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L254](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L254)

わかりづらいのですが、`spans::self.collect::<Buf<_>>().into_iter().rev()`で`Scope`からiteratorを生成しています。

```rust
pub struct SpanRef<'a, R: LookupSpan<'a>> {
    registry: &'a R,
    data: R::Data,
    // ...
}

impl<'a, R> Iterator for Scope<'a, R>
where
    R: LookupSpan<'a>,
{
    type Item = SpanRef<'a, R>;

    fn next(&mut self) -> Option<Self::Item> {
        loop {
            let curr = self.registry.span(self.next.as_ref()?)?;

            // ...
            self.next = curr.data.parent().cloned();
            
            // ...
            
            return Some(curr);
        }
    }
}
```

wrapしている`Registry`から現在の`span::Id`に対応するspanの情報(`SpanRef`)を取得したのち、当該spanの親の情報を次に返すidとして保持します。

いろいろ型がでてきてわかりづらいですが、概要としては、`Registry`で管理している`SpanStack`の先頭の`span::Id`を取得したのち、そこからthread間で共有している、`Span`のmetadataや親情報を保持している`DataInner`を取得して親がなくなるまでiterateしているといえます。

ここまででて以下のようにeventをformatしてStringに書き込む処理のうち、当該eventをscopeに含むspanをiterateする方法がわかりました。

```rust
impl<S, N, T> FormatEvent<S, N> for Format<Full, T>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
    T: FormatTime,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result {
        // ...
        if let Some(scope) = ctx.event_scope() {
            // ...
            for span in scope.from_root() {
                write!(writer, "{}", bold.paint(span.metadata().name()))?;
                // ...

                let ext = span.extensions();
                if let Some(fields) = &ext.get::<FormattedFields<N>>() {
                    if !fields.is_empty() {
                        write!(writer, "{}{}{}", bold.paint("{"), fields, bold.paint("}"))?;
                    }
                }
                // ...
            }
            // ...
        };
        // ...
    }
}
```

```rust
for span in scope.from_root() {
    // ...

    let ext = span.extensions();
    if let Some(fields) = &ext.get::<FormattedFields<N>>() {
        if !fields.is_empty() {
            write!(writer, "{}{}{}", bold.paint("{"), fields, bold.paint("}"))?;
        }
    }
    // ...
}
```

次に`Span::extensions()`です。以下のようにこれは`Extensions`を返します。

```rust
impl<'a, R> SpanRef<'a, R>
where
    R: LookupSpan<'a>,
{
    pub fn extensions(&self) -> Extensions<'_> {
        self.data.extensions()
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L481](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/mod.rs#L481)

`Extensions`とはなんでしょうか。定義は以下のようになっています。

```rust

use crate::sync::RwLockReadGuard;

pub struct Extensions<'a> {
    inner: RwLockReadGuard<'a, ExtensionsInner>,
}

impl<'a> Extensions<'a> {
    #[cfg(feature = "registry")]
    pub(crate) fn new(inner: RwLockReadGuard<'a, ExtensionsInner>) -> Self {
        Self { inner }
    }

    /// Immutably borrows a type previously inserted into this `Extensions`.
    pub fn get<T: 'static>(&self) -> Option<&T> {
        self.inner.get::<T>()
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/extensions.rs#L39](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/registry/extensions.rs#L39)

`ExtensionsInner`をwrapしており、`Extension::get()`で任意の`T`を取得できるapiを提供しています。

```rust
if let Some(fields) = &ext.get::<FormattedFields<N>>() {
    if !fields.is_empty() {
        write!(writer, "{}{}{}", bold.paint("{"), fields, bold.paint("}"))?;
    }
}
```

eventのformat時に、この`get()`を利用して、`FormattedFields`を取得しており、この`FormattedFields`がspanのkey/valueの情報を`Display`として実装していそうです。

ちなみに`ExtensionsInner`は`std::any`を利用して任意の型を受け渡せる様になっています。

```rust
use std::{
    any::{Any, TypeId},
    hash::{BuildHasherDefault, Hasher},
};

type AnyMap = HashMap<TypeId, Box<dyn Any + Send + Sync>, BuildHasherDefault<IdHasher>>;

pub(crate) struct ExtensionsInner {
    map: AnyMap,
}
```

次にこの`Extensions`はどこで生成されてspanに付与されているかが気になります。  
spanのkey/valueの値は`Span::new()`時に決まるはずなので、`Span::new()`であるとあたりをつけます。  
Spanがenterした際に`Registry::new_span()`が呼ばれたあとに、`Layered`が`fmt_layer::Layer`の`on_new_span()`を呼ぶのでそこをみてみます。

```rust
impl<S, N, E, W> layer::Layer<S> for Layer<S, N, E, W>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'writer> FormatFields<'writer> + 'static,
    E: FormatEvent<S, N> + 'static,
    W: for<'writer> MakeWriter<'writer> + 'static,
{
    fn on_new_span(&self, attrs: &Attributes<'_>, id: &Id, ctx: Context<'_, S>) {
        let span = ctx.span(id).expect("Span not found, this is a bug");
        let mut extensions = span.extensions_mut();

        if extensions.get_mut::<FormattedFields<N>>().is_none() {
            let mut fields = FormattedFields::<N>::new(String::new());
            if self
                .fmt_fields
                .format_fields(fields.as_writer().with_ansi(self.is_ansi), attrs)
                .is_ok()
            {
                fields.was_ansi = self.is_ansi;
                extensions.insert(fields);
            } else {
                eprintln!(
                    "[tracing-subscriber] Unable to format the following event, ignoring: {:?}",
                    attrs
                );
            }
        }
        // ...
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L771](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/fmt_layer.rs#L771)

予想通り、`extensions.get_mut::<FormattedFields<N>>().is_none()`で判定し、`extension.insert(fields)`でセットしています。  
`self.fmt_fields`は`FormatFields` traitを実装しており、`span::Attributes`の書き込み方法を定義しています。 spanとeventのkey/valueの書き込み処理を共通化しているので、詳細はeventの書き込み時にみていきます。

ここまででて、spanの情報を書き込めたので最後に`Event`の情報を書き込むことでlogging処理が完了します。

```rust
impl<S, N, T> FormatEvent<S, N> for Format<Full, T>
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> FormatFields<'a> + 'static,
    T: FormatTime,
{
    fn format_event(
        &self,
        ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> fmt::Result {
        // ...

        ctx.format_fields(writer.by_ref(), event)?;
        writeln!(writer)
    }
}
```

`FmtContext::format_fields()`はwrapしている`fmt_fields`に処理を委譲しており、型は`DefaultFields`です。

```rust
pub struct FmtContext<'a, S, N> {
    // ...
    pub(crate) fmt_fields: &'a N,
}

impl<'cx, 'writer, S, N> FormatFields<'writer> for FmtContext<'cx, S, N>
where
    S: Subscriber + for<'lookup> LookupSpan<'lookup>,
    N: FormatFields<'writer> + 'static,
{
    fn format_fields<R: RecordFields>(
        &self,
        writer: format::Writer<'writer>,
        fields: R,
    ) -> fmt::Result {
        self.fmt_fields.format_fields(writer, fields)
    }
}
```

ということで、`DefaultFields`はどうやってeventとspanのkey/valueをformatしているのかなと確認したいところですが、この処理もカスタマイズできるようにgenericになっております。

```rust
impl<'writer, M> FormatFields<'writer> for M
where
    M: MakeOutput<Writer<'writer>, fmt::Result>,
    M::Visitor: VisitFmt + VisitOutput<fmt::Result>,
{
    fn format_fields<R: RecordFields>(&self, writer: Writer<'writer>, fields: R) -> fmt::Result {
        let mut v = self.make_visitor(writer);
        fields.record(&mut v);
        v.finish()
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L1141](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L1141)

ということで`DefaultFields`が`FormatFields`をimplする処理を見にいきたいところですが、このあたりは複雑になっており、どのような問題意識でこれらの処理がtraitに切り出されているか理解できていないです。具体的には以下のようになっています。  

`FormatFields` traitは`MakeOutput<_>`を実装する`M`に対してgenericに実装されています。

```rust
impl<'writer, M> FormatFields<'writer> for M
where
    M: MakeOutput<Writer<'writer>, fmt::Result>,
    M::Visitor: VisitFmt + VisitOutput<fmt::Result>,
{
    fn format_fields<R: RecordFields>(&self, writer: Writer<'writer>, fields: R) -> fmt::Result {
        let mut v = self.make_visitor(writer);
        fields.record(&mut v);
        v.finish()
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L1141](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L1141)

それなら`DefaultFields`が`MakeOutput<_>`を実装しているのかなと思うのですがもう一段かませてあり、`MakeOutput<_>`は`MakeVisitor<_>`を実装する`M`に対して実装されています。

```rust
impl<T, Out, M> MakeOutput<T, Out> for M
where
    M: MakeVisitor<T>,
    M::Visitor: VisitOutput<Out>,
{ }
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/field/mod.rs#L212](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/field/mod.rs#L212)

そして、`DefaultFields`はこの`MakeVisitor<_>`を実装しているので  

```rust
impl<'a> MakeVisitor<Writer<'a>> for DefaultFields {
    type Visitor = DefaultVisitor<'a>;

    #[inline]
    fn make_visitor(&self, target: Writer<'a>) -> Self::Visitor {
        DefaultVisitor::new(target, true)
    }
}
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L1187](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L1187)

`DefaultFields` ->(impl) `MakeVisitor<_>` ->(blanket impl) `MakeOutput<_>` ->(blanket impl) `FormatFields`という流れで、`DefaultFields`がfieldsのformat処理を実施しているという理解です。

あらためてeventのformat処理ですが以下のようにvisitorを生成し、`RecordFields::record()`に渡しています。

```rust
impl<'writer, M> FormatFields<'writer> for M
where
    M: MakeOutput<Writer<'writer>, fmt::Result>,
    M::Visitor: VisitFmt + VisitOutput<fmt::Result>,
{
    fn format_fields<R: RecordFields>(&self, writer: Writer<'writer>, fields: R) -> fmt::Result {
        let mut v = self.make_visitor(writer);
        fields.record(&mut v);
        v.finish()
    }
}
```

`fields: R`には`Event`が渡されるので`Event`の実装をみてみます。  

```rust
impl<'a> RecordFields for Event<'a> {
    fn record(&self, visitor: &mut dyn Visit) {
        Event::record(self, visitor)
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/field/mod.rs#L162](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/field/mod.rs#L162)

単純に`Event::record`に委譲しているようです。  

```rust
impl<'a> Event<'a> {
    pub fn record(&self, visitor: &mut dyn field::Visit) {
        self.fields.record(visitor);
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/event.rs#L86](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/event.rs#L86)

さらに、`Event.fields`に委譲しています。`Event`の定義を確認すると

```rust
pub struct Event<'a> {
    fields: &'a field::ValueSet<'a>,
    metadata: &'static Metadata<'static>,
    parent: Parent,
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/event.rs#L23](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/event.rs#L23)

`fields`は`ValueSet`型なので、`ValueSet::record()`を見てみます。  

```rust
impl<'a> ValueSet<'a> {
    pub fn record(&self, visitor: &mut dyn Visit) {
        let my_callsite = self.callsite();
        for (field, value) in self.values {
            if field.callsite() != my_callsite {
                continue;
            }
            if let Some(value) = value {
                value.record(field, visitor);
            }
        }
    }
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/field.rs#L990](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/field.rs#L990)

`self.values`をiterateして、それぞれの`value.record`にvisitorを渡しています。  
`ValueSet`の定義を確認すると

```rust
pub struct ValueSet<'a> {
    values: &'a [(&'a Field, Option<&'a (dyn Value + 'a)>)],
    fields: &'a FieldSet,
}
```

[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/field.rs#L166](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/field.rs#L166)

`Field`と`&dyn Value`のtupleのsliceになっています。

`Value`は以下のようなtraitで、visitorに自身を記録するmethodを実装しています。

```rust
pub trait Value: crate::sealed::Sealed {
    /// Visits this value with the given `Visitor`.
    fn record(&self, key: &Field, visitor: &mut dyn Visit);
}
```
[https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/field.rs#L335](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/field.rs#L335)

そして、この`Visit`の実装は`DefaultVisitor`として提供されています。

```rust
use tracing_core::{
    field::{self, Field, Visit},
};

// ...
impl<'a> field::Visit for DefaultVisitor<'a> { }
```
https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/fmt/format/mod.rs#L1222

試しにこの処理に以下のように🦀を出力する処理を入れてみます。

```rust
impl<'a> DefaultVisitor<'a> {
    fn record_debug(&mut self, field: &Field, value: &dyn fmt::Debug) {
        if self.result.is_err() {
            return;
        }

        self.maybe_pad();
        // 👇👇
        write!(self.writer, "🦀");
        
        self.result = match field.name() {
            "message" => write!(self.writer, "{:?}", value),
            // Skip fields that are actually log metadata that have already been handled
            #[cfg(feature = "tracing-log")]
            name if name.starts_with("log.") => Ok(()),
            name if name.starts_with("r#") => write!(
                self.writer,
                "{}{}{:?}",
                self.writer.italic().paint(&name[2..]),
                self.writer.dimmed().paint("="),
                value
            ),
            name => write!(
                self.writer,
                "{}{}{:?}",
                self.writer.italic().paint(name),
                self.writer.dimmed().paint("="),
                value
            ),
        };
    }
}
```

このあたりは[Custom Logging in Rust Using tracing and tracing-subscriber](https://burgers.io/custom-logging-in-rust-using-tracing)というブログの説明がわかりやすいのでおすすめです。

するとloggingにも🦀が出力されました。

```sh
2022-11-18T13:21:33.092617Z  INFO span_1{🦀key="hello"}: tracing_handson: 🦀hello
```

spanとevent両方に🦀がいるので、fieldのformat処理が共通化されていることもわかります。

## ログのfiltering

実際の処理の順番とは前後してしまいますが、最後にログのfiltering処理をみていきます。`info!()`macro展開後のコードは以下のようになっていました。

```rust
    use ::tracing::__macro_support::Callsite as _;
    static CALLSITE: ::tracing::callsite::DefaultCallsite = {/* ... */ };
    let enabled = ::tracing::Level::INFO <= ::tracing::level_filters::STATIC_MAX_LEVEL
        && ::tracing::Level::INFO <= ::tracing::level_filters::LevelFilter::current()
        && {
            let interest = CALLSITE.interest();
            !interest.is_never()
                && ::tracing::__macro_support::__is_enabled(CALLSITE.metadata(), interest)
        };
    if enabled {
        // Event dispatch
    } else {
    }
```

`enabled`を判定したのち、trueの場合のみlogging(`Event::dispatch()`)されます。  
判定は以下の条件についてなされます。

* `tracing::level_fiters::STATIC_MAX_LEVEL`
* `tracing::level_filters::LevelFilter::current()`
* `CALLISTE.interest()`
* `tracing::__macro_support::__is_enabled()`

順番にみていきます。

### `tracing::level_fiters::STATIC_MAX_LEVEL`

コードを読んで初めて知ったのですがloggingのverbosityをruntimeでなくcompile時に指定できるようにするための判定です。以下のようにfeature指定時にverbosityを指定できます。

```toml
[dependencies]
tracing = { 
    version = "0.1", 
    features = ["max_level_debug", "release_max_level_warn"],
}
```

実装方法ですが、`cfg_if`が使われています。  

```rust
cfg_if::cfg_if! {
    if #[cfg(all(not(debug_assertions), feature = "release_max_level_off"))] {
        const MAX_LEVEL: LevelFilter = LevelFilter::OFF;
    } else if #[cfg(all(not(debug_assertions), feature = "release_max_level_error"))] {
        const MAX_LEVEL: LevelFilter = LevelFilter::ERROR;
    } else if #[cfg(all(not(debug_assertions), feature = "release_max_level_warn"))] {
        const MAX_LEVEL: LevelFilter = LevelFilter::WARN;
    } else if #[cfg(all(not(debug_assertions), feature = "release_max_level_info"))] {
        const MAX_LEVEL: LevelFilter = LevelFilter::INFO;
    // ...    
    } else {
        const MAX_LEVEL: LevelFilter = LevelFilter::TRACE;
    }
}
```

featureで特定の設定値を決める実装方法として参考になりました。


### `tracing::level_filters::LevelFilter::current()`


```rust
static MAX_LEVEL: AtomicUsize = AtomicUsize::new(LevelFilter::OFF_USIZE);
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/metadata.rs#L246

初期状態では、OFFなので全てのloggingがdisableになります。どの時点で値がセットされているかというと`tracing_subscriber::fmt().init()`の中で実行される、`Dispatch::new()`です

```rust
impl Dispatch {
    pub fn new<S>(subscriber: S) -> Self
        where
            S: Subscriber + Send + Sync + 'static,
    {
        let me = Dispatch {
            subscriber: Arc::new(subscriber),
        };
        callsite::register_dispatch(&me);
        me
    }
}
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/dispatcher.rs#L458

`callsite::register_dispatch()`の中で`Dispatch`(=Subscriber)が新規に登録された際の`Interest`の再計算が行われ、その際に`LevelFilter::set_max()`が実行されます。

```rust
impl Callsites {
    /// Rebuild `Interest`s for all callsites in the registry.
    ///
    /// This also re-computes the max level hint.
    fn rebuild_interest(&self, dispatchers: dispatchers::Rebuilder<'_>) {
        let mut max_level = LevelFilter::OFF;
        dispatchers.for_each(|dispatch| {
            // If the subscriber did not provide a max level hint, assume
            // that it may enable every level.
            let level_hint = dispatch.max_level_hint().unwrap_or(LevelFilter::TRACE);
            if level_hint > max_level {
                max_level = level_hint;
            }
        });

        self.for_each(|callsite| {
            rebuild_callsite_interest(callsite, &dispatchers);
        });
        LevelFilter::set_max(max_level);
    }
}
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/callsite.rs#L425

### `CALLISTE.interest()`

```rust
pub struct DefaultCallsite {
    interest: AtomicU8,
    registration: AtomicU8,
    meta: &'static Metadata<'static>,
    next: AtomicPtr<Self>,
}

impl DefaultCallsite {
    pub fn interest(&'static self) -> Interest {
        match self.interest.load(Ordering::Relaxed) {
            Self::INTEREST_NEVER => Interest::never(),
            Self::INTEREST_SOMETIMES => Interest::sometimes(),
            Self::INTEREST_ALWAYS => Interest::always(),
            _ => self.register(),
        }
    }
}
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/callsite.rs#L351

`DefaultCallsite::interest()`は`Interest`を返します。  
`Interest`は`Subscriber`と当該callsite(macro呼び出し)の関係で、処理の対象とするかどうかの判定です。上記のようにNEVER,SOMETIMES, ALWAYSがあります。SOMETIMESはruntime時に都度判定することを意味すると理解しております。結果をcacheしており、初回は、`DefaultCallsite::register()`が実行されます。

```rust
impl DefaultCallsite {
    pub fn register(&'static self) -> Interest {
        // Attempt to advance the registration state to `REGISTERING`...
        match self.registration.compare_exchange(
            Self::UNREGISTERED,
            Self::REGISTERING,
            Ordering::AcqRel,
            Ordering::Acquire,
        ) {
            Ok(_) => {
                // Okay, we advanced the state, try to register the callsite.
                rebuild_callsite_interest(self, &DISPATCHERS.rebuilder());
                CALLSITES.push_default(self);
                self.registration.store(Self::REGISTERED, Ordering::Release);
            }
            // Great, the callsite is already registered! Just load its
            // previous cached interest.
            Err(Self::REGISTERED) => {}
            // Someone else is registering...
            Err(_state) => {
                debug_assert_eq!(
                    _state,
                    Self::REGISTERING,
                    "weird callsite registration state"
                );
                // Just hit `enabled` this time.
                return Interest::sometimes();
            }
        }

        match self.interest.load(Ordering::Relaxed) {
            Self::INTEREST_NEVER => Interest::never(),
            Self::INTEREST_ALWAYS => Interest::always(),
            _ => Interest::sometimes(),
        }
    }
}
```

`AtomicUsize`で状態を制御しつつ、初回は`rebuild_callsite_interest()`を実行します。

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/callsite.rs#L312

```rust
fn rebuild_callsite_interest(
    callsite: &'static dyn Callsite,
    dispatchers: &dispatchers::Rebuilder<'_>,
) {
    let meta = callsite.metadata();

    let mut interest = None;
    dispatchers.for_each(|dispatch| {
        let this_interest = dispatch.register_callsite(meta);
        interest = match interest.take() {
            None => Some(this_interest),
            Some(that_interest) => Some(that_interest.and(this_interest)),
        }
    });

    let interest = interest.unwrap_or_else(Interest::never);
    callsite.set_interest(interest)
}
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-core/src/callsite.rs#L494

`dispatchers::Rebuilder<_>`がわかりづらいですがここでは、これまでみてきた`Dispatch`(`FmtSubscriber`)が実体です。なので、`Layered::register_callsite()`を見ていきます。

```rust
impl<L, S> Subscriber for Layered<L, S>
    where
        L: Layer<S>,
        S: Subscriber,
{
    fn register_callsite(&self, metadata: &'static Metadata<'static>) -> Interest {
        self.pick_interest(self.layer.register_callsite(metadata), || {
            self.inner.register_callsite(metadata)
        })
    }
}
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/layer/layered.rs#L94

`Layered::pick_interest()`は第一引数の結果をうけて第二引数のclosureを実行する処理です。  
ここではinnerに委譲する前に`self.layer`を先に呼び出している点がポイントです。  
一番外側のlayerは`LevelFilter`なので、`LevelFilter::register_callsite()`を見てみます。

```rust
impl<S: Subscriber> crate::Layer<S> for LevelFilter {
    fn register_callsite(&self, metadata: &'static Metadata<'static>) -> Interest {
        if self >= metadata.level() {
            Interest::always()
        } else {
            Interest::never()
        }
    }
}
```

https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.16/tracing-subscriber/src/filter/level.rs#L11

自身の値に応じて`Interest`を返しています。  
これでようやく、`FmtSubscriber`の各layerの役割分担が理解できました。

### `tracing::__macro_support::__is_enabled()`

これまでの判定でdisableと判定されなかった場合に最終的に実行されるruntimeの判定処理です。  
逆にいうとlogging毎の判定処理をできるだけ避ける様に工夫されているといえます。  
コードの詳細はここではみませんが、実装は今までの委譲と同じ流れです。


## まとめ

ということで、`info!()`すると`info_span!()`の情報もあわせてloggingされるまでの流れをみてきました。  
以下の点がわかり、macroのブラックボックス度が少し減ったのがうれしいです。

* global変数にtracingのinstruction(`info!()`,`info_span!()`)を処理する`Subscriber`の実装が保持されている。
* `tracing_subscriber`は`Layer`という概念で、`Subscriber`をcomposableにできる機構を提供してくれている
* `tracing_subscriber::fmt::Subscriber(FmtSubscriber)`の実体は`Layered`でnestされた、`LevelFilter ` + `fmt_layer::Layer` + `Registry`
* `Span`のメタ情報とenterの状態は`Registry`によって管理されている
  * `span::Id`の実装は`shareded_slab`のindex
  * `Registry`は`ThreadLocal<_>`でenterしたspanのidを管理しているので、futureだとうまく動作しない

`tracing_core`,`tracing_suscriber`の役割がなんとなくわかったので、[tracing workspace](https://github.com/tokio-rs/tracing/tree/tracing-subscriber-0.3.16)にある他のcrateも理解できるように読んでみようと思います。

[tracing]: https://github.com/tokio-rs/tracing
[tracing-subscriber]: https://github.com/tokio-rs/tracing/tree/master/tracing-subscriber


