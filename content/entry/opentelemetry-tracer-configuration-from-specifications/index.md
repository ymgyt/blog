+++
title = "🔭 RustでOpenTelemetry: Tracerの設定を仕様から理解する"
slug = "understanding-opentelemetry-tracer-configuration-from-specifications"
description = "RustにおけるOpenTelemetryの実装を見ながら仕様の理解を試みます。今回はTracerの設定について。"
date = "2023-07-18"
draft = false
[taxonomies]
tags = ["rust", "opentelemetry"]
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
もっとも、tracing/tracing_opentelemetryによるopentelemetryの抽象化は徹底されているわけではなく、他サービスをnetwork越しに呼んだ場合にもtraceを連携させるcontext propagation等の仕組みを利用する上では、opentelemetryを利用していることを意識する必要がでてきます。  


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

{{ figure(images=["images/opentelemetry_crates_overview.svg"], caption="crate間の関係") }}

まずApplicationはtracingのapiを利用して計装します。  
具体的には、`tracing::instrument`や、`info_span!()`, `info!()`等を組み込みます。  
Applicationが実行されるとtracingの情報はtracing_subscriberによって処理されるので、subscriberの処理にopentelemetryを組み込むためにtracing_opentelemetryを利用します。  
tracing_opentelemetryはopentelemetry_apiに依存しており、実行時にその実装をinjectする必要があります。  
opentelemetry_sdkがその実装を提供してくれているので、それを利用するのですが、opentelemetry_sdkはplugin構造になっており、protocol依存な箇所はsdkには組み込まれていません。  
今回はgRPCを利用してtraceをexportするのですが、そのgRPC関連の実装はopentelemetry_otlpによって提供されます。  
そして、opentelemetry_otlpはopentelemetry_sdkの設定を行うhelper関数を公開してくれているので、applicationではそれを利用します。  

概ねこのような役割分担となっています。


## Traceの生成からexportまでの流れ

メンタルモデルとして、traceが生成されてからexportされるまでの流れを確認します。

{{ figure(images=["images/opentelemetry_trace_flow_overview.svg"], caption="traceがexportされる概要") }}

それぞれのcomponentの詳細はのちほど確認しますが、全体の流れとしては上記のようになっております。  

spanがdropされたり、`#[tracing::instrument]`が付与された関数を抜けると、tracing apiによって、subsriberの`on_close()`が呼ばれます。 
subscriberはlayered構成になっているので、各layerのspan終了処理が走ります。`OpenTelemetryLayer`はここで、tracingのspan情報をopentelemetryのspanに変換を行い、`TracerProvider`を経由して、`SpanProcessor`にexportするspanを渡します。  
`SpanExporter`はbatchやtimeout,retry処理等を行い、serializeやprotocolの処理を担う`SpanExporter`がnetwork越しのopentelemetry collectorにspanをexportします。  
`OpenTelemetryLayer`から先の`Tracer`についてはrustの独自実装ではなく、**opentelemetryの仕様に定められています。**  
このSDKがどのように実装されているかの仕様というのがopentelemetry projectの特徴だと思っています。


## APIとSDK

OpenTelemetryの仕様にはAPIとSDKという用語がよくでてきます。  
どちらもpackageです。[packageもotel用語](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.23.0/specification/glossary.md#packages)で各種プログラミング言語のlibraryを抽象化したものです。  
ですので、rustにも、opentelemetry_apiとopentelemetry_sdk crateがあります。  
ただ、opentelemetry_apiとopentelemetry_sdkは基本的に同一versionで利用されることが想定されているので、opentelemetry crateが両者をre-exportしています。  

```rust
pub use opentelemetry_api::*;
pub use opentelemetry_sdk::runtime;
pub mod sdk {
    pub use opentelemetry_sdk::*;
}
```

[source](https://github.com/open-telemetry/opentelemetry-rust/blob/879d6ff9d251db158da7a5720ff903fa6cb7c1e2/opentelemetry/src/lib.rs#L225C1-L244C2)

SDKは`opentelemetry::sdk`で参照できますが、APIは`opentelemetry`直下なので、最初は混乱してしまいました。(かといって、`opentelemetry::api`にするとtoplevelになにもitemがなくなってしまうので結果的に今の状態が良いとは思います)

次にAPIとSDKの関係なのですが、公式の以下の図がわかりやすいです。  

{{ figure(images=["images/opentelemetry-long-term-support.png"], href="https://github.com/open-telemetry/opentelemetry-specification/blob/v1.23.0/internal/img/long-term-support.png") }}

図自体は、Opentelemetryの各種packageのmajor versionのsupport期間についてなのですが、登場人物とpackageの関係がわかりやすいので引用しました。  
まずOpenTelemetryに関わる開発者は以下の3つのroleに分類されます。  

* Application Owner
* Instrumentation Author
* Plugin Author

まずApplication Ownerですが、そのままapplicationのmaintainer(開発者)です。SDKを設定する責務を持ちます。  
Instrumentation AuthorはAPIを利用して、traceやmetricsを設定する人を指します。library(package)にOpenTelemetryを組み込んでいるlibraryのmaintainerやapplication ownerもinstrumentation authorに含まれます。  
Plugin AuthorはSDKのpluginのmaintainerです。本記事でいうと、opentelemetry_otlpがpluginにあたります。  

Application Ownerから、SDKのConstructorとPluginのConstructorに矢印が伸びています。

```rust
opentelemetry_otlp::new_pipeline() // 👈 Plugin Constructor
    .tracing()
    .with_trace_config(
        opentelemetry::sdk::trace::Config::default() // 👈 SDK Constructor
    // ...
```

Plugin AuthorからSDKのPlugin Interfaceに矢印が伸びていますが、これはPluginがSDKのtraitを実装しているということです。具体例はのちほど見ていきます。  
Instrumentation AuthorからAPIへ伸びている矢印そのままはAPIを利用していることを指しています。

また、APIがSDKをwrapしているような絵になっているところはAPIの実装はSDKへのdelegateになっており、初期状態だとなにもしない実装(Noop)が利用されるようになっています。  
この点も公式にわかりやすい図があるので引用します。

{{ figure(images=["images/opentelemetry-library-design.png"], href="https://github.com/open-telemetry/opentelemetry-specification/blob/v1.23.0/internal/img/library-design.png") }} 

例えば、初期状態では以下のように`NoopTracerProvider`が返るようになっていたりします。  

```rust
/// The global `Tracer` provider singleton.
static GLOBAL_TRACER_PROVIDER: Lazy<RwLock<GlobalTracerProvider>> = Lazy::new(|| {
    RwLock::new(GlobalTracerProvider::new(
        trace::noop::NoopTracerProvider::new(),
    ))
});
```

[opentelemetry_api::global::trace](https://github.com/open-telemetry/opentelemetry-rust/blob/34c73323238738e79ef353ac0e64b2a85fc59128/opentelemetry-api/src/global/trace.rs#L357)  
このnoop実装を切り替える処理はSDKの初期化処理によって行なわれます。

APIとSDKの関係の概要を説明したので、次からはいよいよcodeを見ていきます。

## `opentelemetry_api::trace::Trace`

Applicationが実行するOpenTelemetry関連の初期化処理のゴールは`tracing_opentelemetry::layer().with_tracer()`を利用して、tracing subscriberに`tracing_opentelemetry::OpenTelemetryLayer`を渡すことです。 
そして、そのconstruct処理では以下のようにtrait boundとして、`opentelemetry_api::trace::Trace`が指定されています。(`PreSampledTracer`の説明は割愛)  

```rust
use opentelemetry::trace as otel;

impl<S, T> OpenTelemetryLayer<S, T>
where
    S: Subscriber + for<'span> LookupSpan<'span>,
    T: otel::Tracer + PreSampledTracer + 'static,
{
    pub fn with_tracer<Tracer>(self, tracer: Tracer) -> OpenTelemetryLayer<S, Tracer>
    where
        Tracer: otel::Tracer + PreSampledTracer + 'static,
    { /* ... */ }
}
```

[tracing_opentelemetry::layer](https://github.com/tokio-rs/tracing-opentelemetry/blob/42e986929080a5f1f245876c1aaa82ce9a7d85de/src/layer.rs#L467)

この`opentelemetry::trace::Trace` traitは仕様で定義されたものの、rustにおける実装となっています。  
[仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.23.0/specification/trace/api.md#tracer)では  

> The tracer is responsible for creating Spans.
  Note that Tracers should usually not be responsible for configuration. This should be the responsibility of the TracerProvider instead.

Tracerの責務はSpanの生成であり、設定に関してはTracerProviderが担うとあります。  
OpenTelemetryにおけるtraceは実体としてはSpanのtreeなので、`OpenTelemetryLayer`がSpanの生成のみの責務をもつTracerを要求するのは自然に思えます。  

そして、[SDKのTracerはAPIのTracer traitをimpl](https://github.com/open-telemetry/opentelemetry-rust/blob/34c73323238738e79ef353ac0e64b2a85fc59128/opentelemetry-sdk/src/trace/tracer.rs#L125C1-L125C45)しています。  
なので、今回の例では以下のようにSDKのTracerを生成しています。

```rust
fn tracer(sampling_ratio: f64) -> opentelemetry::sdk::trace::Tracer { /* ...*/ }
```

## `opentelemetry_otlp`によるTracerの設定

ということで、SDKのTracerをconstructすることがゴールとわかりました。  
さきほどAPIとSDKの関係で述べたようにSDKを設定してconstructする処理はSDKのPluginが提供してくれるのがOpenTelemetryのdesignのようです。  

```rust
fn tracer(sampling_ratio: f64) -> opentelemetry::sdk::trace::Tracer {
    opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_trace_config( /*...*/ )
        .with_batch_config( /*...*/ )
        .with_exporter( /*...*/ )
        .install_batch(opentelemetry::sdk::runtime::Tokio)
        .unwrap()
}
```

`opentelemetry_otlp`も設定を行った後`install_batch()`を呼ぶと、`Result<sdk::trace::Tracer,_>`を返すようになっています。  
ここで、最後のconstruct処理が`build()`ではなく、installというどことなく副作用を感じさせる命名になっているのは副作用があるからです。  

[APIのTracerProviderに関する仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/trace/api.md#tracerprovider)では

> Normally, the TracerProvider is expected to be accessed from a central place. Thus, the API SHOULD provide a way to set/register and access a global default TracerProvider.

と、APIはdefaultのTracerProviderへのアクセスをglobal変数で提供すべきとされています。  
これをうけて上記の処理の中で、SDK Tracer生成の際に作成したTracerProviderを[global変数にセットする処理](https://github.com/open-telemetry/opentelemetry-rust/blob/34c73323238738e79ef353ac0e64b2a85fc59128/opentelemetry-otlp/src/span.rs#L202)があります。


## `opentelemetry_sdk::trace`の各種struct

各種設定の詳細を確認する前にtraceのexport時に登場するstructの概要を把握しておきます。  


{{ figure(images=["images/opentelemetry_sdk_trace_crate_overview.svg"], caption="opentelemetry_sdk::traceのstructの概要")}}

概ね上記のstructが、trace(span)の生成からexportに関与します。  
これからみていく設定はこれらのcomponentに関する設定を行います。  
実装にはasync runtime(tokio,async-std)の抽象化や、`futures::stream::FuturesUnordered`を利用したtask管理等参考になる処理が多くあるのですが今回は割愛します。  

最初に`opentelemetry_otlp::new_pipeline()`を見たとき、パイプラインとは?となりました。  
今は、上記の図でいう、TracerProvider -> BatchSpanProcessor -> SpanExporterをpipelineと表現しているのだなと考えています。


## `opentelemetry::sdk::trace::Config`

```rust
opentelemetry_otlp::new_pipeline()
    .tracing()
    .with_trace_config(
        opentelemetry::sdk::trace::Config::default()
            .with_sampler(/*...*/)
            .with_id_generator(/*...*/)
            .with_resource(/*...*/),
    )
```

`with_trace_config()`に`sdk::trace::Config`を渡します。  
まず仕様を確認します。さきほどみたように、Tracerは状態をもたず状態(=設定)の責務はTracerProviderにあります。  
そこで、今回はTracerProviderのSDKに関する仕様をみてみると、[Tracer Provider Configuration](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/trace/sdk.md#configuration)に  

> Configuration (i.e., SpanProcessors, IdGenerator, SpanLimits and Sampler) MUST be owned by the the TracerProvider. The configuration MAY be applied at the time of TracerProvider creation if appropriate.

Traceに関する設定(SamplerやIdGeneraor)はTracerProviderの作成時に適用させるといった記述があります。  
これをうけて、`opentelemetry_sdk::trace::Config`ではSDKの仕様に定められた設定を`Config`で実装しています。

### IdGenetaror

```rust
opentelemetry::sdk::trace::Config::default()
    .with_id_generator(opentelemetry::sdk::trace::XrayIdGenerator::default())
```

ここでは、TraceId,SpanIdの生成の責務をもつIdGeneratorを作成します。  
これらのIdはその名の通りtraceやspanの識別子です。[仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/trace/api.md#spancontext)では

> TraceId A valid trace identifier is a 16-byte array with at least one non-zero byte.
  SpanId A valid span identifier is an 8-byte array with at least one non-zero byte.

と定義されています。  
また、OpenTelemetryは[W3C TraceContext specification](https://www.w3.org/TR/trace-context/)に準拠しており、たびたびこちらの仕様が参照されます。  
これをうけて、[SDKの仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/trace/sdk.md#id-generators)では

> The SDK MUST by default randomly generate both the TraceId and the SpanId.

と定義されており、Idの実装を提供してくれています。  
`opentelemetry_sdk::trace`は[`RandomIdGenetor`](https://github.com/open-telemetry/opentelemetry-rust/blob/879d6ff9d251db158da7a5720ff903fa6cb7c1e2/opentelemetry-sdk/src/trace/id_generator/mod.rs#L22)を提供しているのですが、今回の例では利用していません。  

代わりに`opentelemetry_sdk::trace::id_generator::aws::XrayIdGenerator`という、唐突にAWSのXrayIdGeneratorを利用しています。 
これは、AWS XRayのtrace idには[trace idにtimestampを載せる](https://docs.aws.amazon.com/xray/latest/devguide/xray-api-sendingdata.html#xray-api-traceids)という仕様があるために、randomに生成されたidだとXRay上で利用できないためです。  

個人的にはこの制約には非常に不満をもっています。  
といいますのも、OpenTelemetryを利用したいモチベーションのひとつにapplication(計装されたコード)にobservability backendやvendorの概念を持ち込まないというものもがあります。  
このおかげで、applicationはopentelemetry collectorへのexportだけを考慮して、あとの事情はcollector側で吸収できるという設計です。  
しかしながら、XRayがtrace idに独自の制約が設定されているために、application側でtraceがどこにexportされるかを意識しなくならなければならなくなりました。  

ただ、XRayIdgeneratorを利用しても、OpenTelemetryのtrace idの仕様には反していないので、現状ではXRayを利用するかに関わらず、XRayIdGeneratorを利用しています。  

[SDKの仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/trace/sdk.md#id-generators)には

> Additional IdGenerator implementing vendor-specific protocols such as AWS X-Ray trace id generator MUST NOT be maintained or distributed as part of the Core OpenTelemetry repositories.

とあり、"Core OpenTelemetry repositories"にはvendor依存な処理はいれてはならないとあります。  
が、今のところは、XRayIdGeneratorは[`opentelemetry_sdk::trace::id_genrarator::aws`](https://github.com/open-telemetry/opentelemetry-rust/blob/879d6ff9d251db158da7a5720ff903fa6cb7c1e2/opentelemetry-sdk/src/trace/id_generator/aws.rs#L37)に定義されています。  
[issueでもこの点は議論](https://github.com/open-telemetry/opentelemetry-rust/issues/841)されていました。


### Sampler

次はSamplerについてです。  

```rust
opentelemetry::sdk::trace::Config::default()
    .with_sampler(Sampler::ParentBased(Box::new(Sampler::TraceIdRatioBased(
        sampling_ratio,
    ))))
```

Samplingについてはcontext propagationと関連するので、別で詳しく扱いたいと思っています。  
ここでは、traceをすべて取得して、export、永続化するとruntimeのcost、network cost, storage costといろいろ大変なので、全体のn％を取得できるようにする機構という程度の理解でいきます。  
[SDKの仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/trace/sdk.md#built-in-samplers)で、いくつかbuiltinの実装が提供されています。  


```rust
Sampler::ParentBased(
  Box::new(Sampler::TraceIdRatioBased(sampling_ratio))
)
```

の意味ですが、既にSampleするかの判定がなされていた場合はそれに従い、初めてsampleするかの判定を行う場合は、引数のsampling_ratioに従うという設定を実施しています。  
具体的には、graphqlのようなserver側のcomponentを設定している場合にgraphqlのrequestを実施するclient側で既にopentelemetryのsampling判定が実施され、それがhttp header等でserverにpropagate(context propagagation)されていた場合には、graphql serverはそれに従います。  


## Resource

次はResourceについてです。  

```rust
opentelemetry::sdk::trace::Config::default()
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
    ))
```

Resourceとは何かというと、traceに付与するkey valutのmetadataです。  
[仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/resource/sdk.md#resource-sdk)には

> A Resource is an immutable representation of the entity producing telemetry as Attributes.

と定義されています。key valutのデータ構造も[仕様で定義](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/common/README.md#attribute)されており、こちらはAttributeと言われます。  
Resourceはtraceだけでなく、metricsでも利用されます。また、AttributeはResourceに限らずSpan eventsであったり、key valueの情報を付与するcontextで参照されるデータ構造です。最大サイズであったり、空文字のkeyが禁止されていたりといったことが規定されています。  

Resourceで表現する情報ですが、traceがどこから来たかについてを表現します。  
また、その際に用いるkeyにはsemantic conventionsを利用します。  
Semantic conventionsはResourceに限らず、OpenTelemetry全体に適用される命名規則です。  
例えば、traceを生成したapplicationを指したい場合は[`service.name`](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/resource/README.md#service)を利用します。  

他にも様々なattributeが規定されています。traceにはrequestしたuserの識別子を載せたくなるのが一般的かと思いますがその際のkeyはどうされているでしょうか。  
`user.id`を使ってしまいそうですが、[General identity attributes](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/general/attributes.md#general-identity-attributes)として、`enduser.id`が指定されています。  
ちなみにAWS XRayでは、`enduser.id`をXRay側のuserの識別子に変換してくれたりするので、semantic conventionsに従っておくと、ecosystemの恩恵に預かれるメリットがあります。

productionやstagingといった、deployする環境についても、[`deployment.environment`](https://github.com/open-telemetry/semantic-conventions/blob/v1.21.0/docs/resource/deployment-environment.md)と定められています。  

このmetadataのkeyが仕様で定められているのは非常に重要だと考えています。  
この仕様のおかげで、logやtraceをqueryする際に、`query ... condition deployment.environment = "production"`のような条件が書けます。  

Rustではsemantic conventionsは`opentelemetry_semantic_conventions`に定義されているので、できるだけこちらを参照すると良いと思います。


### Schema URL

```rust
opentelemetry::sdk::Resource::from_schema_url(
    [ /*...*/ ],
    "https://opentelemetry.io/schemas/1.20.0",
)),
```

Resouce生成時に指定している、schema urlについて。  
[Telemetry Schemas](https://github.com/open-telemetry/opentelemetry-specification/tree/71813887597d18e3535dd56d2a18ecae7299daad/specification/schemas)として仕様に定められている仕組みです。  
概要としては、semantic conventionsのversionのようなもので、これによって、semantic conventionsに破壊的変更があっても既存のecosystemが壊れないような仕組みと理解しています。  

基本的には、Resource作成時に指定できるようなapiになっているので、自分が参照したsemantic conventionsのversionをいれておけば、関連するecosystem側でよしなにしてくれることが期待できます。  
具体例としては、production,stagingといった情報をenvironmentで表現したが、deployment.environmentに変更しても、query側が壊れないような例が挙げられていました。  
QueryはAlertで利用されると思うので、Alertingを壊してしまうと、実質的にapplication側で最新のsemantic conventionsを利用できなくなってしまいます。  
OpenTelemetryでは最新のversionへfearlessにupgradeできることが重視されていることがこういった機構からも伝わってきます。

## Export

最後にtraceのexport関連の設定を確認します。  

```rust
opentelemetry_otlp::new_pipeline()
    .tracing()
    .with_trace_config( /*...*/ )
    .with_batch_config(opentelemetry::sdk::trace::BatchConfig::default())
    .with_exporter(
        opentelemetry_otlp::new_exporter()
            .tonic()
            .with_endpoint("http://localhost:4317"),
    )
```

### BatchConfig

traceはexportされる際に一定程度、まとめてからexportされます。この挙動を実装しているのが、BatchSpanProcessorで、SDK側で実装されています。  
TracerProvider -> SpanProcessor(BatchSpanProcessor) -> SpanExporterのように、export前にSpanProcessorというlayerを用意している理由ですが、Plugin側を薄くするためだと考えています。  
仮にSpanProcessorがなく、traceが直接SpanExporterに渡されたとすると、Plugin(SpanExporter)は担当するprotocol処理以外にもbatch処理を時前で実装する必要があります。  

Batch処理において指定できる設定も[SDKの仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/71813887597d18e3535dd56d2a18ecae7299daad/specification/trace/sdk.md#batching-processor)で定められています。  
OpenTelemetryに仕様の特徴として、設定できる項目のdefault値も仕様で定められています。  
例えば、batch処理の際に用いられる`maxQueueSize`のdefault値は2048です。  
これはRust特有ということでなく、すべての言語に当てはまります。これによって、言語ごとに、微妙に挙動が違うということがなくなってきます。(もちろん実装次第ですが)  
仕様のdefault値はRustらしく、`Default::default`で表現されているので、上の例では特に設定せずに利用しています。  
また、Rust(`opentelemetry_sdk`)の場合、`max_concurrent_exports`も指定でき、同時に`tokio::task::span`する最大taskも指定できます。(defaultは1)  


### ExporterConfig

最後にgRPCとして、exportする設定を行っています。  
gRPCの実装にはtonicを利用しました。tonic以外にも、grpcioやhttpも選択できます。  


## まとめ

簡単にですが、rustでOpenTelemetryを利用する際のTracer関連の設定についてみてきました。  
最初は、なんでこんないろんなcrateでてくるんだと思ったりしたのですが、仕様を知ると、確かに実装するならこうなるなといろいろ納得できました。  

次はMetricsについて書く予定です。
