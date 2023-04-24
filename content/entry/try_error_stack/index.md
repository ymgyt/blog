+++
title = "🥞 error-stackを試してみる"
slug = "try_error_stack"
date = "2022-07-21"
draft = false
[taxonomies]
tags = ["rust"]
+++

この記事では最近(2022-06-10)`0.1.0`がリリースされた[`error-stack`]を試してみます。  
[README](https://github.com/hashintel/hash/blob/d14efbc38559fc38d36e03ebdd499b44cb80c668/packages/libs/error-stack/README.md)には

> error-stack is a context-aware error-handling library that supports arbitrary attached user data.

とあり、crate/moduleで利用する、`Result`型を提供しており、anyhow/thiserrorの代替で利用するイメージです。  
[`error-stack`]が開発された背景は[Announcing error-stack](https://hash.dev/blog/announcing-error-stack)というブログ記事で説明されています。  
自分が触ってみた範囲で、thiserrorとの違いは、thiserrorでは、

```rust
#[derive(thiserror::Error, Debug)]
pub enum MyError{
    #[error("io error {0}")]
    Io(#[from] std::io::Error),
    #[error("timeout")]
    Timeout,
}
```

のように、原因となったエラーをwrapするための`From`を生成していくことでエラーのコンテキストを保持していくと理解しています。  
一方で[`error-stack`]では、`Report`という型を中心に、heapに`Frame`のStackを形成することでエラーのコンテキストを表現していきます。  

`Frame`は`Context`と`Attachment`からなります。  

```rust
pub enum FrameKind<'f> {
    Context(&'f dyn Context),
    Attachment(AttachmentKind<'f>),
}
```
[https://docs.rs/error-stack/latest/error_stack/enum.FrameKind.html]([https://docs.rs/error-stack/latest/error_stack/enum.FrameKind.html])

`Context`はtraitで[`error-stack`]を利用するユーザはエラー型を定義して、この`Context`をimplします。  
`impl<C: std::error::Error + Send + Sync + 'static> Context for C`のimplがあり、大抵はエラー型に、`std::error::Error`を実装してあると思うので基本的には追加の実装は必要ありません。  
`Attachment`はエラーに付与するgenericなデータ型で、エラーハンドリング時に、`Report::request_ref`や`Report::request_value`で取得することができます。  
これだけだとよくわからないと思うので具体例をみていきます。

```rust
use std::{fmt::{self, Formatter}, path::Path};

use error_stack::{Context, IntoReport, ResultExt};
use serde::Deserialize;

#[derive(Debug)]
pub struct ParseConfigError {}

impl ParseConfigError {
    pub fn new() -> Self {
        Self {}
    }
}

impl fmt::Display for ParseConfigError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str("Could not parse configuration file")
    }
}

impl Context for ParseConfigError {}

#[derive(Debug, Deserialize)]
pub struct Config {
    #[serde(deserialize_with = "provider::deserialize_provider")]
    pub provider: Provider,
    pub aws: Option<AwsConfig>,
}

impl Config {
    pub fn from_path(path: impl AsRef<Path>) -> error_stack::Result<Self, ParseConfigError> {
        let path = path.as_ref();

        let mut f = std::fs::File::open(path)
            .report()
            .change_context_lazy(|| ParseConfigError::new())
            .attach_printable_lazy(|| format!("Could not read file {path:?}"))?;

        serde_yaml::from_reader::<_, Config>(&mut f)
            .report()
            .change_context_lazy(|| ParseConfigError::new())
            .attach_printable_lazy(|| format!("Could not deserialize file {path:?}"))
    }
}
```

ここでは、yamlで書かれた設定ファイルを与えられたファイルパスから取得する処理をみていきます。  
ファイルパスのファイルが存在しなかったりパーミッションの関係で読めないと`std::io::Error`が返りますが、なにもしないと引数のファイルパスは保持されないので、エラーのコンテキストや追加情報を付与したい典型例だと思います。  

```rust
pub fn from_path(path: impl AsRef<Path>) -> error_stack::Result<Self, ParseConfigError> {}
```

まず、戻り値の型として、`error_stack::Result`を利用しています。  
これは`pub type Result<T, C> = Result<T, Report<C>>`のaliasで、ユーザが定義したエラー(`ParseConfigError`)を`Report`でwrapして取り回すのが基本になります。

```rust
let mut f = std::fs::File::open(path)                 // Result<File,io::Error>
    .report()                                         // Result<File, Report<io::Error>>
    .change_context_lazy(|| ParseConfigError::new())  // Result<File, Report<ParseConfigError>>
    .attach_printable_lazy(|| format!("Could not read file {path:?}"))?;
```

[`IntoReport`](https://docs.rs/error-stack/latest/error_stack/trait.IntoReport.html)をuseしておくと、`report`が利用でき、`Result<T,E>`から`Result<T, Report<E>>`の変換が利用できます。  `Context`はドメインのエラーというイメージで、基本的に各処理で、contextとなるエラーを定義して明示的`change_context`で変換することが要求されます。  
`attach_printable_lazy`でcontextのエラーにエラー時の情報を付与しています。

発生したerrorは`tracing::error!`でdebug出力するとします。

```rust
let config = match kubeprovision::Config::from_path(cli.config.as_path())
    .attach_printable(format!("Loading configuration file {cli:?}"))
{
    Ok(config) => config,
    Err(report) => {
        tracing::error!("{report:?}");
        return Ok(());
    }
};
// ...
```

引数のfileが存在しない場合。

```sh
2022-07-20T17:04:24.685595Z ERROR src/main.rs:17: Could not parse configuration file
             at /Users/ymgyt/ymgyt.io/kubeprovision/src/config.rs:47:14
      - Loading configuration file Cli { config: "not_exists", command: Status }
      - Could not read file "not_exists"

Caused by:
   0: No such file or directory (os error 2)
             at /Users/ymgyt/ymgyt.io/kubeprovision/src/config.rs:46:14
```

引数のfileのyamlが不正な場合。

```sh
2022-07-20T17:08:10.639151Z ERROR src/main.rs:17: Could not parse configuration file
             at /Users/ymgyt/ymgyt.io/kubeprovision/src/config.rs:52:14
      - Loading configuration file Cli { config: "/tmp/hello.txt", command: Status }
      - Could not deserialize file "/tmp/hello.txt"

Caused by:
   0: invalid type: string "hogeeeeeeeee", expected struct Config at line 1 column 1
             at /Users/ymgyt/ymgyt.io/kubeprovision/src/config.rs:51:14
```

となり、引数のfile pathと原因が表示できたかと思います。

## Backtraces

[`Backtraces`](https://doc.rust-lang.org/nightly/std/backtrace/struct.Backtrace.html)についてはannouncingの記事では、thiserrorでは、常に`RUST_BACKTRACE=1`が必要になってしまうのがissueとして述べられていたのですが、[`error-stack`]で利用する場合でも、`RUST_LIB_BACKTRACE=1`のような環境変数の指定は必要でした。  
[https://github.com/hashintel/hash/blob/main/packages/libs/error-stack/tests/test_backtrace.rs#L13]([https://github.com/hashintel/hash/blob/main/packages/libs/error-stack/tests/test_backtrace.rs#L13])

上記の処理を以下のように`RUST_LIB_BACKTRACE=1 cargo +nightly`で実行するとbacktraceが取得できます。

```sh
❯ RUST_LIB_BACKTRACE=1 cargo +nightly run --quiet -- --config /tmp/hello.txt status
2022-07-20T17:18:43.109086Z ERROR src/main.rs:17: Could not parse configuration file
at /Users/ymgyt/ymgyt.io/kubeprovision/src/config.rs:52:14
- Loading configuration file Cli { config: "/tmp/hello.txt", command: Status }
- Could not deserialize file "/tmp/hello.txt"

Caused by:
0: invalid type: string "hogeeeeeeeee", expected struct Config at line 1 column 1
at /Users/ymgyt/ymgyt.io/kubeprovision/src/config.rs:51:14

Stack backtrace:
0: std::backtrace_rs::backtrace::libunwind::trace
    at /rustc/9a7b7d5e50ab0b59c6d349bbf005680a7c880e98/library/std/src/../../backtrace/src/backtrace/mod.rs:66:5
1: std::backtrace_rs::backtrace::trace_unsynchronized
    at /rustc/9a7b7d5e50ab0b59c6d349bbf005680a7c880e98/library/std/src/../../backtrace/src/backtrace/mod.rs:66:5
2: std::backtrace::Backtrace::create
    at /rustc/9a7b7d5e50ab0b59c6d349bbf005680a7c880e98/library/std/src/backtrace.rs:328:13
3: error_stack::report::Report<C>::new
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/error-stack-0.1.1/src/report.rs:189:18
4: error_stack::context::<impl core::convert::From<C> for error_stack::report::Report<C>>::from
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/error-stack-0.1.1/src/context.rs:82:9
5: <core::result::Result<T,E> as error_stack::ext::result::IntoReport>::report
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/error-stack-0.1.1/src/ext/result.rs:203:31
6: kubeprovision::config::Config::from_path
    at ./src/config.rs:50:9
7: kubeprovision::main::{{closure}}
    at ./src/main.rs:12:24
8: <core::future::from_generator::GenFuture<T> as core::future::future::Future>::poll
    at /rustc/9a7b7d5e50ab0b59c6d349bbf005680a7c880e98/library/core/src/future/mod.rs:91:19
9: tokio::park::thread::CachedParkThread::block_on::{{closure}}
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/park/thread.rs:263:54
10: tokio::coop::with_budget::{{closure}}
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/coop.rs:102:9
11: std::thread::local::LocalKey<T>::try_with
    at /rustc/9a7b7d5e50ab0b59c6d349bbf005680a7c880e98/library/std/src/thread/local.rs:445:16
12: std::thread::local::LocalKey<T>::with
    at /rustc/9a7b7d5e50ab0b59c6d349bbf005680a7c880e98/library/std/src/thread/local.rs:421:9
13: tokio::coop::with_budget
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/coop.rs:95:5
14: tokio::coop::budget
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/coop.rs:72:5
15: tokio::park::thread::CachedParkThread::block_on
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/park/thread.rs:263:31
16: tokio::runtime::enter::Enter::block_on
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/runtime/enter.rs:151:13
17: tokio::runtime::thread_pool::ThreadPool::block_on
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/runtime/thread_pool/mod.rs:73:9
18: tokio::runtime::Runtime::block_on
    at /Users/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/tokio-1.16.1/src/runtime/mod.rs:477:43
19: kubeprovision::main
    at ./src/main.rs:22:5
// ...
```

Backtraceは[`error-stack`]側が`cfg(all(nightly, feature= "std"))`で管理しているので、ユーザ側で定義することは不要です。

```rust
pub struct ReportImpl {
    pub(super) frame: Frame,
    #[cfg(all(nightly, feature = "std"))]
    backtrace: Option<Backtrace>,
    #[cfg(feature = "spantrace")]
    span_trace: Option<SpanTrace>,
}
```

## anyhow/eyreとの互換性

また、`0.1.1`ではanyhowやeyreとの互換処理も追加されており、段階的に移行していくこともできそうです。


## まとめ

簡単にですが、[`error-stack`]を利用してみました。  
thiserrorでcrate/module単位でエラーを切っていくなかで、追加のエラー情報を付与したくなった際の選択肢になるのではと考えております。  
まだまだ触れられていない機能もあるので、もう少し使ってみてソースを読んでみたいと思っています。


## CHANGELOG

* 2023-02-14: `https://github.com/hashintel/hash/tree/main/packages/libs/error-stack/src/compat`へのlinkを削除


[`error-stack`]: https://github.com/hashintel/hash/tree/e248d06d0b783a7d93875a7323d13e4ddd319fc9/packages/libs/error-stack

