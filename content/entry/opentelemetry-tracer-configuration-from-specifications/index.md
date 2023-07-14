+++
title = "🔭 RustでOpenTelemetry: Tracerの設定を仕様から理解する"
slug = "understanding-opentelemetry-tracer-configuration-from-specifications"
description = "RustにおけるOpenTelemetryの実装を見ながら仕様の理解を試みます。今回はTracerの設定について。"
date = "2023-07-16"
draft = true
[taxonomies]
tags = ["rust"]
[extra]
image = "images/emoji/telescope.png"
+++

本記事では、RustにおけるOpenTelemetry Tracerの設定をOpenTelemetryの仕様に照らして理解することを目指します。  
仕様を確認しながら、どうして各種crateが現在の型や構成になっているのかを説明します。  
Rust特有の話とOpenTelemetry共通の話が最初は分かりづらかったのですが、共通の概念を理解できれば他言語でも同様に設定できるようになります。


## 前提の確認

もろもろの前提を確認します。  
まず、traceの生成については[`tracing` crate](https://github.com/tokio-rs/tracing)を利用します。それに伴い、tracingとopentelemetryを連携させるために、[`tracing-opentelemetry` crate](https://github.com/tokio-rs/tracing-opentelemetry)も利用します。  
なお、tracing-opentelemetryなのですが、以前はtokio-rs/tracing配下のworkspace memberとして管理されていましたが、[こちらのPR](https://github.com/tokio-rs/tracing/pull/2523)で、tokio-rs/tracing-opentelemetryに移されました。  

次にtraceのexportは[`opentelemetry-otlp` crate](https://github.com/open-telemetry/opentelemetry-rust/tree/main/opentelemetry-otlp)を利用して、gRPCでremoteにexportします。(基本的にはopentelemetry-collectorになるかと思います)  
Opentelemetry-collectorやobservability-backendの立ち上げについては詳しくは触れません。  

対象とするOpenTelemetryの仕様は`v1.23.0`です。  
仕様の参照元としては、[公式のwebsite](https://opentelemetry.io/docs/specs/)と[`opentelemetry-specification` repository](https://github.com/open-telemetry/opentelemetry-specification/tree/v1.23.0/specification)があります。  
versionを固定したlinkを貼りやすいので、本記事ではrepositoryを参照します。  
仕様の範囲ですが、概ね、Traceと関連する共通項目についてみていきます。  

そもそも、Opentelemetryとは、という話は以前の[RustでOpenTelemetryをはじめよう](https://blog.ymgyt.io/entry/starting_opentelemetry_with_rust/)の方に書いたのでよければ読んでみてください。 



## 具体的なcodeの概要

まずは本記事で扱う、traceをexportするための設定を行うcodeを確認します。のちほど詳しく見ていくので、ここで理解できなくても大丈夫です。  
関連する依存crateは以下です。  


```toml
[dependencies]
opentelemetry = { version = "=0.19.0", features = ["rt-tokio"] }
opentelemetry-otlp = "=0.12.0"
opentelemetry-semantic-conventions = "=0.11.0"
tracing = "0.1.38"
tracing-opentelemetry = "=0.19.0"
tracing-subscriber = "0.3.17"
# ...
```

```rust
#[tokio::main]
async fn main() {
    let _guard = init_opentelemetry();

    init_subscriber();

    // Run application ...
}
```

まず`main.rs`では、2つのことを行います。  

1. opentelemetry関連の初期化処理
1. tracing-subscriberの設定 

```rust
/// Guard to perform opentelemetry termination processing at drop time.
#[must_use]
pub struct OtelInitGuard();

impl Drop for OtelInitGuard {
    fn drop(&mut self) {
        opentelemetry::global::shutdown_tracer_provider();
    }
}

pub fn init_opentelemetry() -> OtelInitGuard {
    // for context propagation.
    opentelemetry::global::set_text_map_propagator(
        opentelemetry::sdk::propagation::TraceContextPropagator::new(),
    );

    OtelInitGuard()
}
```

`init_opentelemetry()`では、opentelemetry関連の初期化処理を実施し、終了処理をdrop時に行う`OtelInitGuard`を返します。  
この型は外部crateの型ではなくapplication側の実装です。`opentelemetry::global::set_text_map_propagator()`はcontext propagation関連の準備を行っています。  
Context propagationについては別の記事で詳しく触れたいと思います。  
ここでやりたいのは、application終了時に、`opentelemetry::global::shutdown_tracer_provider()`が確実に呼ばれるようにすることです。


### tracing subscriberの設定

次にtracing subscriberの設定を行います。  

```rust
fn init_subscriber() {
    use tracing_subscriber::{filter, fmt, layer::SubscriberExt, util::SubscriberInitExt};

    let sampling_ratio = std::env::var("OTEL_SAMPLING_RATIO")
        .ok()
        .and_then(|env| env.parse().ok())
        .unwrap_or(1.0);

    tracing_subscriber::registry::Registry::default()
        .with(fmt::layer().with_ansi(true))
        .with(filter::LevelFilter::INFO)
        .with(tracing_opentelemetry::layer().with_tracer(tracer(sampling_ratio)))
        .init();
}
```

ここでは、tracing subscriberを設定し、`tracing_opentelemetry::OpenTelemetryLayer`を設定します。  
tracing subscriberやlayerについては[tracing/tracing-subscirberでログが出力される仕組みを理解する](https://blog.ymgyt.io/entry/how-tracing-and-tracing-subscriber-write-events/)で書いたのでここでは特に説明しません。  
概要としては、`tracing::info!()`すると、そこで生成されたlog(event)が`OpenTelemetryLayer`に渡され、OpenTelemetryの仕様に定められたtraceに変換されたのちに、exportされるといった流れです。  

要点としては、tracing/tracing-subscriberの仕組みのおかげで、ここで見ているapplication初期化時以外では、traceがopentelemetryの仕組みで処理されるといったことを意識しなくてよくなっているということです。  
逆にいうと、opentelemetryにおけるtraceのデータが具体的にどうなるかは、`tracing::info!()`といった、tracing apiとtracing_opentelemetryによる変換処理次第となります。  
また、tracing/tracing_opentelemetryによるopentelemetryの抽象化は徹底されているわけではなく、他サービスをnetwork越しに呼んだ場合にもtraceを連携させるcontext propagation等の仕組みを利用する上では、opentelemetryを利用していることを意識する必要がでてきます。  


### Tracerの設定

```rust
fn tracer(sampling_ratio: f64) -> opentelemetry::sdk::trace::Tracer {
    use opentelemetry::sdk::trace::Sampler;
    use opentelemetry_otlp::WithExportConfig;

    opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_trace_config(
            opentelemetry::sdk::trace::Config::default()
                .with_sampler(Sampler::ParentBased(Box::new(Sampler::TraceIdRatioBased(
                    sampling_ratio,
                ))))
                .with_id_generator(opentelemetry::sdk::trace::XrayIdGenerator::default())
                .with_resource(opentelemetry::sdk::Resource::from_schema_url(
                    [
                        opentelemetry::KeyValue::new(
                            opentelemetry_semantic_conventions::resource::SERVICE_NAME,
                            env!("CARGO_PKG_NAME"),
                        ),
                        opentelemetry::KeyValue::new(
                            opentelemetry_semantic_conventions::resource::SERVICE_VERSION,
                            env!("CARGO_PKG_VERSION"),
                        ),
                    ],
                    "https://opentelemetry.io/schemas/1.20.0",
                )),
        )
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://localhost:4317"),
        )
        .install_batch(opentelemetry::sdk::runtime::Tokio)
        .unwrap()
}
```

ここがメインとなる、Tracerの設定です。  
どの型がどのcrateから来ているかわかりやすくするために、長くなりますが、crateから書いています。 
まず、以下のcrateが出てきます。  

* `opentelemetry`
* `opentelemetry_otlp`
* `opentelemetry_semantic_convensions` 

`opentelemetry` crateは`opentelemetry_api`と`opentelemetry_sdk`をre-exportしているだけのcrateです。
 
これらのcrateはそれぞれ対応する仕様やその実装に対応しているので、この設定項目の仕様を理解することを目指します。

## crate間の関係

まずはこれらのcrate間の関係を整理します。  

{{ figure(images=["images/opentelemetry_crates_overview.svg"], caption="crates間の関係") }}

まずApplicationはtracingのapiを利用して計装します。  
具体的には、`tracing::instrument`や、`info_span!()`, `info!()`等を組み込みます。  
Applicationが実行されるとtracingの情報はtracing_subscriberによって処理されるので、subscriberの処理にopentelemetryを組み込むためにtracing_opentelemetryを利用します。  
tracing_opentelemetryはopentelemetry_apiに依存しており、実行時にその実装をinjectする必要があります。  
opentelemetry_sdkがその実装を提供してくれているので、それを利用するのですが、opentelemetry_sdkはplugin構造になっており、protocol依存な箇所はsdkには組み込まれていません。  
今回はgRPCを利用してtraceをexportするのですが、そのgRPC関連の実装はopentelemetry_otlpによって提供されます。  
そして、opentelemetry_otlpはopentelemetry_sdkの設定を行うhelper関数を公開してくれているので、applicationではそれを利用します。  

概ねこのような役割分担となっています。


## Traceの生成からexportまでの流れ

ここまで見てきたところで、初めてだと上記のcodeは何を設定しているのかよくわからないのではないでしょうか。  
ということで、メンタルモデルとして、traceが生成されてからexportされるまでの流れを確認します。

{{ figure(images=["images/opentelemetry_trace_flow_overview.svg"], caption="traceがexportされる概要") }}

それぞれのcomponentの詳細はのちほど確認しますが、全体の流れとしては上記のようになっております。  

spanがdropされたり、`#[tracing::instrument]`が付与された関数を抜けると、tracing apiによって、subsriberの`on_close()`が呼ばれます。 
subscriberはlayered構成になっているので、各layerのspan終了処理が走ります。`OpenTelemetryLayer`はここで、tracingのspan情報をopentelemetryのspanに変換を行い、`TracerProvider`を経由して、`SpanProcessor`にexportするspanを渡します。  
`SpanExporter`はbatchやtimeout,retry処理等を行い、serializeやprotocolの処理を担う`SpanExporter`がnetwork越しのopentelemetry collectorにspanをexportします。  
`OpenTelemetryLayer`から先の`Tracer`についてはrustの独自実装ではなく、**opentelemetryの仕様に定められています。**  
このSDKがどのように実装されているかの仕様というのがopentelemetry projectの特徴だと思っています。


## APIとSDK



## Memo

v1.22.0 -> v1.23.0にした(7/14)
