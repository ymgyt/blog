+++
title = "🔭 RustでOpenTelemetryをはじめよう"
slug = "starting_opentelemetry_with_rust"
date = "2022-12-18"
draft = false
[taxonomies]
tags = ["rust"]
[extra]
image = "images/emoji/telescope.png"
+++


本記事ではRustでOpentelemetryをはじめることを目標に以下の点について書きます。

* OpenTelemetryの概要
* RustのapplicationにOpenTelemetryを導入する方法

前半は[公式doc](https://opentelemetry.io/docs/)を読みながら登場人物を整理し、後半は実際にdocker-compose上でそれらを動かします。  
またRustでは[tracing-opentelemetry](https://github.com/tokio-rs/tracing/tree/master/tracing-opentelemetry) crateを利用します。  
tracingについては[別の記事](https://blog.ymgyt.io/entry/how-tracing-and-tracing-subscriber-write-events/)で基本的な仕組みについて書いたのでopentelemetry固有の処理について述べます。    
[sample code](https://github.com/ymgyt/opentelemetry-handson)

traceの設定については、[別の記事](https://blog.ymgyt.io/entry/understanding-opentelemetry-tracer-configuration-from-specifications/)に詳しい説明を書きました。

## OpenTelemetryとは

最初にOpenTelemetryについての現時点での自分の理解は以下です。

* OpenTelemetryとは文脈により以下のいずれかを指す
    * CNFNのproject
      * 2019年に誕生したOpenTracingとOpenCensusがmergeされて2019年に誕生したCNCF incubating project.
    * APIやdata formatに関する仕様のこと
* OpenTelemetry projectの目標はシステムをobservableにすること。observableとは問題調査の際に必要な情報が全て取得できている状態
* OpenTelemetry projectはapplicationがsignal(traces, metrics, logs)を出力できるようにする仕組みを標準化しようとしている
    * Vendor-agnosticなSDK,API, toolsを提供しているのでvendorに依存することなくobservabilityを向上させる実装ができる
    * Jaeger、Prometheus, Datadog, Elasticsearchといったobservability backendではない


いきなりこれだけ言われてもピンとこないと思うので以下では具体的に掘り下げていきます。

## OpenTelemetryの前提

OpenTelemetryを学んでいく前に前提知識を確認します。

### そもそもObservabilityとは

https://opentelemetry.io/docs/concepts/observability-primer/#what-is-observability

Observabilityとは、システムの内部を知ることなくシステムについて理解できること。トラブルシュートや新しい問題("unknown unknowns")が起きた際になにが起きているかがわかること。

システムを調査するには、アプリケーションが適切にinstrumentedされている必要がある。instrumentedされているとは、、アプリケーションがsignals(traces, metrics, logs等)を発していること。適切にinstrumentedされているときアプリケーションに追加の変更を加えることなく問題の調査が可能になる。なぜなら、必要な情報は全て収集されているから。  
OpenTelemetryとは、アプリケーションをinstrumentedにするための仕組み。  

InstrumentedはRustに引きつけていうと、application/libraryの各処理に`info!()`や`info_span!()`,`#[instrument]`等が書かれているということです。

### Telemetry

システムから出力されるその挙動に関するデータ。trace, metrics, logs等。


### Metrics

applicationやinfrastructureに関するnumeric dataを一定期間に渡って集約したもの。error rate, CPU使用率等。


### Distributed Tracing

Distributed tracingを理解するにはまず、logsとspansから見ていきます。  
Logはtimestampが付与されたシステムのcomponentから出力されるメッセージ。Logはcontextualな情報が付与されることで真価を発揮します。

Spanはunit of work(operation)を表したもので典型的なのは1 http requestの処理。  
Spanはname, time-related data, structured log message, attributes等のmetadataを含み、operationに関する情報を提供します。  
Attributesの具体例としては、`net.peer.ip=10.244.0.1`,`http.route=/cart`等々。

Distributed Traceはapplicationやend-userからのrequestが通過するmicroserviceやserverless application実行経路を記録します。
Distributed systemにおいて、tracingなしではパフォーマンス上の問題の原因を特定するのは容易ではなく
また、localで再現させることが難しい問題が発生するのでtracingは不可欠とされています。

Traceは一つ以上のspanから構成されており、最初のspanをroot spanと言います。  
Root spanはrequest全体を表しており、子spanはそれぞれの処理の詳細を表しています。


{{ figure(caption="spanの具体例", images=["images/otel_span.png"] )}}


## [OpenTelemetryの構成要素](https://opentelemetry.io/docs/concepts/components/)

OpenTelemetryは以下の主要なcomponentから構成されます。

* プログラミング言語に依存しない(Cross-language) specification
* telemetry dataを収集、加工、公開するためのtool群(collector,kubernetes operator)
* 言語ごとのSDK

公式docには上記の様なことが述べられているのですが、具体例を見ないといまいちわかりづらいと思うので補足していきます。  


### [Specification](https://opentelemetry.io/docs/concepts/components/#specification)

ここがOpenTelemetryの核のところで、実装に対する仕様(requirements and expectations)を定義しています。  
用語の定義にと止まらず以下の点についても仕様を定めています。

* API
* SDK
* Data

APIはなんとなく想像ができました。例えば、`Span`というデータ構造(型)にはこんなmethodがあって引数の型はこれで、以下の場合はエラーになる等をプログラミング言語に依存しない形で定義しているんだろうなと考えました。  
実際のSpanの定義は[こちら](https://opentelemetry.io/docs/reference/specification/trace/api/#span)です。  
最初に疑問だったのが、SDKの仕様というところでした。APIが仕様で決まっていてそれを各言語の実装に落とし込んで実装するのがSDKという理解だったので、SDKの仕様を言語に依存しない形で定義ってどういう意味だろうと思いました。  
この疑問に対する答えは[specification overview](https://opentelemetry.io/docs/reference/specification/overview/#sdk)に書いてありました。

> Note that the SDK includes additional public interfaces which are not considered part of the API package, as they are not cross-cutting concerns. These public interfaces are defined as constructors and plugin interfaces. Application owners use the SDK constructors; plugin authors use the SDK plugin interfaces. Instrumentation authors MUST NOT directly reference any SDK package of any kind, only the API.

自分の理解では、SDKの仕様といってもAPIと同様に型やメソッドについてである点は同じで、約束の相手方がlibrary実装者なのがAPIでapplication開発者なのがSDKという感じです。要はlibraryにopentelemetryを導入する場合はAPIのみに依存して、applicationはAPIとSDKに依存してよいということだと思います。また後述しますが、Rust(tracing)の場合はtracing-opentelemetryでopentelemetry-sdkをさらに抽象化するのであまり意識することはないのかなと思っています。  

(余談ですが、[仕様](https://opentelemetry.io/docs/reference/specification/sdk-environment-variables/#parsing-empty-value)で参照する環境変数が空の場合(`ENV_XXX=""`)にどうするかも決まっています。ここまで決まっていて運用する人によりそってるなと感じました。)

### [Collector](https://opentelemetry.io/docs/concepts/components/#collector)

https://raw.githubusercontent.com/open-telemetry/opentelemetry.io/main/iconography/Otel_Collector.svg

公式docでは

> The OpenTelemetry Collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data.

と説明されています。実態としては[goのbinary](https://github.com/open-telemetry/opentelemetry-collector)です。  
一例としてはrustのapplicationからcollectorにgRPCで接続してtrace情報を送り、collectorがそのtrace情報をelasticsearchに送るといった使い方が挙げられます。td-agent(fluentd)的なcomponentで、podのsidecarやdaemonsetとしてdeployします。  
仕様策定までがscopeで実装はscope外というprojectもありますが、collectorの実装まで提供しているのがopentelemetry projectの特徴の一つだなと感じました。collectorの存在によって各言語ではtelemetry dataをexportするgRPC clientを実装しておけばよくその後の共通処理は言語共通でcollectorに委譲できます。
Collectorはretry, batch処理、暗号化、sensitive data filtering等を実施してくれるようです。  
実際の使い方は後述します。


## Signals (Categories of telemetry)

OpenTelemetryにおけるSignalsとは、仕様で定められているtelemetryのcategoriesのことです。  
現在のところsignalsは以下の4つから成ります。

* Traces
* Metrics
* Logs
* Baggage

ここではそれぞれのsignalについての概要を見ていきます。

### [Traces](https://opentelemetry.io/docs/concepts/signals/traces/)

> Traces give us the big picture of what happens when a request is made by user or an application.

https://opentelemetry.io/docs/concepts/signals/traces/

Traceはリクエスト処理に際して何が起きたかを教えてくれるもの。  
Docに載っているSample Traceを再掲します。

```json
{
    "name": "Hello-Greetings",
    "context": {
        "trace_id": "0x5b8aa5a2d2c872e8321cf37308d69df2",
        "span_id": "0x5fb397be34d26b51",
    },
    "parent_id": "0x051581bf3cb55c13",
    "start_time": "2022-04-29T18:52:58.114304Z",
    "end_time": "2022-04-29T18:52:58.114435Z",
    "attributes": {
        "http.route": "some_route1"
    },
    "events": [
        {
            "name": "hey there!",
            "timestamp": "2022-04-29T18:52:58.114561Z",
            "attributes": {
                "event_attributes": 1
            }
        },
        {
            "name": "bye now!",
            "timestamp": "2022-04-29T22:52:58.114561Z",
            "attributes": {
                "event_attributes": 1
            }
        }
    ],
}
{
    "name": "Hello-Salutations",
    "context": {
        "trace_id": "0x5b8aa5a2d2c872e8321cf37308d69df2",
        "span_id": "0x93564f51e1abe1c2",
    },
    "parent_id": "0x051581bf3cb55c13",
    "start_time": "2022-04-29T18:52:58.114492Z",
    "end_time": "2022-04-29T18:52:58.114631Z",
    "attributes": {
        "http.route": "some_route2"
    },
    "events": [
        {
            "name": "hey there!",
            "timestamp": "2022-04-29T18:52:58.114561Z",
            "attributes": {
                "event_attributes": 1
            }
        }
    ],
}
{
    "name": "Hello",
    "context": {
        "trace_id": "0x5b8aa5a2d2c872e8321cf37308d69df2",
        "span_id": "0x051581bf3cb55c13",
    },
    "parent_id": null,
    "start_time": "2022-04-29T18:52:58.114201Z",
    "end_time": "2022-04-29T18:52:58.114687Z",
    "attributes": {
        "http.route": "some_route3"
    },
    "events": [
        {
            "name": "Guten Tag!",
            "timestamp": "2022-04-29T18:52:58.114561Z",
            "attributes": {
                "event_attributes": 1
            }
        }
    ],
}
```

`Hello-Greetings`,`Hello-Salutations`,`Hello`の3つのspanからなるtraceを表しています。  
`context.span_id`が自身のidで、`context.trace_id`が紐づくtraceです。  
3つとも、`context.trace_id: "0x5b8aa5a2d2c872e8321cf37308d69df2"`となっています。  
`parent_id`が親spanを表していて、`null`の場合がroot spanです。`Hello`以外は`parent_id: "0x051581bf3cb55c13"`となっており、`Hello`が親であることがわかります。  

OpenTelemetryにおけるtracingの動作を理解するために、instrumentingに関わるcomponentには以下があります。

* Tracer
* Tracer Provider
* Trace Exporter
* Trace Context

なんか急に実装よりの話になりました。tracer providerはtracerのfactoryであると説明されているのですが、あるデータを作るうえで、`Tracer::new()`するのか、`TraProvider::provide()`するのかってtracingのconceptの説明docにはいらないんじゃないかなと思いました。ただ実装(`opentelemetry_{api,sdk}`)を読むとこれらの型が出てきます。


#### [Span](https://opentelemetry.io/docs/concepts/signals/traces/#spans-in-opentelemetry)

Traceの構成要素で、unit of workを表現するspanはOpenTelemetryにおいて以下の情報を持ちます。

* Name
* Parent span ID (rootの場合はもたない)
* Start and End Timestamps
* Span Context
* Attributes
* Span Events
* Span Links
* Span Status

Spanの具体例。

```json
{
  "trace_id": "7bba9f33312b3dbb8b2c2c62bb7abe2d",
  "parent_id": "",
  "span_id": "086e83747d0e381e",
  "name": "/v1/sys/health",
  "start_time": "2021-10-22 16:04:01.209458162 +0000 UTC",
  "end_time": "2021-10-22 16:04:01.209514132 +0000 UTC",
  "status_code": "STATUS_CODE_OK",
  "status_message": "",
  "attributes": {
    "net.transport": "IP.TCP",
    "net.peer.ip": "172.17.0.1",
    "net.peer.port": "51820",
    "net.host.ip": "10.177.2.152",
    "net.host.port": "26040",
    "http.method": "GET",
    "http.target": "/v1/sys/health",
    "http.server_name": "mortar-gateway",
    "http.route": "/v1/sys/health",
    "http.user_agent": "Consul Health Check",
    "http.scheme": "http",
    "http.host": "10.177.2.152:26040",
    "http.flavor": "1.1"
  },
  "events": [
    {
      "name": "",
      "message": "OK",
      "timestamp": "2021-10-22 16:04:01.209512872 +0000 UTC"
    }
  ]
}
```

Tracesにのっていたtraceの具体例と、`trace_id`や`span_id`が`context`のfieldかどうかで違うはどうしてか疑問です。

### [Logs](https://opentelemetry.io/docs/concepts/signals/logs/)

OpenTelemetryにおけるLogとは、traceやmetricに含まれないデータはlogであると消極的に定義されています。  
重要な点として、LogのAPIとSDKに関する仕様は2022年12月現在ではdraft状態です。したがって、RustではlogsについてNot yet implementedとして使えません。じゃあapplicationのlogはどうするのかというとtraceにspan eventとして含めるしかないというのが現状の自分の理解です。具体的にrustのlog(`info!()`の出力)がどのように見えるかは後述します。  

また、opentelemetryではlogについてはtraceやmetricsとは違いlogについては既存のlog ecosystemとの統合を重視するアプローチをとっているようです。

> Our approach with logs is somewhat different. For OpenTelemetry to be successful in logging space we need to support existing legacy of logs and logging libraries, while offering improvements and better integration with the rest of observability world where possible.

[https://opentelemetry.io/docs/reference/specification/logs/](https://opentelemetry.io/docs/reference/specification/logs/)

{{ figure(caption="telemetry ecosystemの分断", images=["images/otel_log_overview.png"] )}}

Logに関するopentelemetryの問題意識として以下の点が挙げられていました。

* 既存のlogはobservability signalsとweakly integratedな状態
* log,trace,metricsでagent,protocol, data modelが違う

自分の経験としても、log出力しないapplicationはないので、loggingは前提。次にapplicationのmetricsを収集したいので、CloudWatchのCustom metricsやPrometheusのmetricsを発行できるようにする。1 requestを完了するためにbackendからさらに複数のbackendのapiを叩くのでそれらのlogを集約できるようにtraceできるようにする。の流れでそれぞれが独立して処理されるというのがありました。またその問題に対してdatadogを導入してvendor依存を受け入れたり。

これらに対して以下の図がopentelemetryの目指す解決です。

{{ figure(caption="collectorによる統一的なtelemetry dataの処理", images=["images/otel_to_be.png"] )}}

Logとtrace,metricsの関係性を標準化しInfra/Applicationが統一されたformatでlog,trace,metricsを出力して、すべてCollectorで処理できる世界はpromisingに思えます。自分が運用する環境をこうしたいと思えたのが自分がopentelemetryを導入したいと思ったきっかけでした。



### [Baggage](https://opentelemetry.io/docs/concepts/signals/baggage/)

metrics,traces,logsに付与するname/valueのpair。  
いまいち使い所が理解できておらず本記事の具体例でも登場しないです。今後の課題。

## Rustでopentelemetryを動かす

ここまで抽象的な話ばかりだったので具体的に見ていきます。  
ゴールはrustのapplicationからtelemetry dataを出力して、elasticsearch,jaeger,prometheusで確認するまでです。

### tracing-opentelemetry

telemetry dataを出力するrustを動かします。

`Cargo.toml`

```toml
[dependencies]
opentelemetry = { version = "0.18.0", default-features = false, features = ["trace", "rt-tokio", "metrics"] }
opentelemetry-otlp = { version = "0.11.0", default-features = false, features = ["grpc-tonic", "trace", "metrics"] }
tokio = { version = "1.23.0", features = ["full"] }
tracing = "0.1.37"
tracing-futures = "0.2.5"
tracing-opentelemetry = { version = "0.18.0", default-features = false, features = ["tracing-log", "metrics"] }
tracing-subscriber = "0.3.16"
opentelemetry_sdk = "0.18.0"
```

`main.rs`
```rust
use opentelemetry::sdk::metrics::controllers::BasicController;
use opentelemetry_otlp::WithExportConfig;
use tracing::{info, info_span, error};
use tracing_futures::Instrument;

// https://github.com/open-telemetry/opentelemetry-rust/blob/d4b9befea04bcc7fc19319a6ebf5b5070131c486/examples/basic-otlp/src/main.rs#L35-L52
fn build_metrics_controller() -> BasicController {
    opentelemetry_otlp::new_pipeline()
        .metrics(
            opentelemetry::sdk::metrics::selectors::simple::histogram(Vec::new()),
            opentelemetry::sdk::export::metrics::aggregation::cumulative_temporality_selector(),
            opentelemetry::runtime::Tokio,
        )
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://localhost:4317"),
        )
        .build()
        .expect("Failed to build metrics controller")
}

fn init_tracing() {
    // Configure otel exporter.
    let tracer = opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://localhost:4317"),
        )
        .with_trace_config(
            opentelemetry::sdk::trace::config()
                .with_sampler(opentelemetry::sdk::trace::Sampler::AlwaysOn)
                .with_id_generator(opentelemetry::sdk::trace::RandomIdGenerator::default())
                .with_resource(opentelemetry::sdk::Resource::new(vec![opentelemetry::KeyValue::new(
                    "service.name",
                    "sample-app",
                )]))
            ,
        )
        .install_batch(opentelemetry::runtime::Tokio)
        .expect("Not running in tokio runtime");

    // Compatible layer with tracing.
    let otel_trace_layer = tracing_opentelemetry::layer().with_tracer(tracer);
    let otel_metrics_layer = tracing_opentelemetry::MetricsLayer::new(build_metrics_controller());

    use tracing_subscriber::layer::SubscriberExt;
    use tracing_subscriber::util::SubscriberInitExt;

    tracing_subscriber::Registry::default()
        .with(tracing_subscriber::fmt::Layer::new().with_ansi(true))
        .with(otel_trace_layer)
        .with(otel_metrics_layer)
        .with(tracing_subscriber::filter::LevelFilter::INFO)
        .init();
}

async fn start() {
    let user = "ymgyt";

    operation().instrument(info_span!("auth", %user)).await;
    operation_2().instrument(info_span!("db")).await;
}

async fn operation() {
    // trace
    // https://docs.rs/tracing-opentelemetry/latest/tracing_opentelemetry/struct.MetricsLayer.html#usage
    info!(
        ops = "xxx",
        counter.ops_count = 10,
        "successfully completed"
    );
}

async fn operation_2() {
    info!(arg = "xyz", "fetch resources...");
    error!("something went wrong");
}

#[tokio::main]
async fn main() {
    init_tracing();

    let version = env!("CARGO_PKG_VERSION");

    start().instrument(info_span!("request", %version)).await;

    tokio::time::sleep(std::time::Duration::from_secs(60)).await;

    opentelemetry::global::shutdown_tracer_provider();
}
```

結構長いです。`tracing_opentelemetry`だけで完結すると思いきや、`opentelemetry_sdk`や`opentelemetry_otlp`等もでてきます。
実行すると以下のlogが出力されます。

```sh
❯ cargo run --quiet
2022-12-18T07:01:01.837895Z  INFO request{version=0.1.0}:auth{user=ymgyt}: opentelemetry_handson: successfully completed ops="xxx" counter.ops_count=10
BatchSpanProcessor: flush messages
2022-12-18T07:01:01.838090Z  INFO request{version=0.1.0}:db: opentelemetry_handson: fetch resources... arg="xyz"
2022-12-18T07:01:01.838115Z ERROR request{version=0.1.0}:db: opentelemetry_handson: something went wrong
```

意外と長いのでそれぞれ解説していきます。  
まず`init_tracing()`でtracing_subscriberを初期化します。

```rust
fn init_tracing() {
    // Configure otel exporter.
    let tracer = { 
        opentelemetry_otlp::new_pipeline()
        // ...
    };

    // Compatible layer with tracing.
    let otel_trace_layer = tracing_opentelemetry::layer().with_tracer(tracer);
    let otel_metrics_layer = tracing_opentelemetry::MetricsLayer::new(build_metrics_controller());

    use tracing_subscriber::layer::SubscriberExt;
    use tracing_subscriber::util::SubscriberInitExt;

    tracing_subscriber::Registry::default()
        .with(tracing_subscriber::fmt::Layer::new().with_ansi(true))
        .with(otel_trace_layer)
        .with(otel_metrics_layer)
        .with(tracing_subscriber::filter::LevelFilter::INFO)
        .init();
}
```

`tracer = { /.../ }`の箇所は後述します。行っていることは以下です。  

1. `opentelemetry_otlp::new_pipeline()`でtraceをcollectorに出力するgRPC設定を行う
2. `tracing_opentelemetry::layer()`でtracing-subscriberにcomposeする
3. `tracing_opentelemetry::MetricsLayer::new()`でmetricsに関しても同様に設定する
4. `tracing_subscriber`でRegistryを初期化する
5. Registryに必要な機能(layer)をcomposeしていく

`tracing_opentelemetry`がtracingとopentelemetryをつなぐlayerを提供してくれています。  
tracingをどうcollectorに渡すかは以下の箇所で設定しています。

```rust
let tracer = opentelemetry_otlp::new_pipeline()
    .tracing()
    .with_exporter(
        opentelemetry_otlp::new_exporter()
            .tonic()
            .with_endpoint("http://localhost:4317"),
    )
    .with_trace_config(
        opentelemetry::sdk::trace::config()
            .with_sampler(opentelemetry::sdk::trace::Sampler::AlwaysOn)
            .with_id_generator(opentelemetry::sdk::trace::RandomIdGenerator::default())
            .with_resource(opentelemetry::sdk::Resource::new(vec![opentelemetry::KeyValue::new(
                "service.name",
                "sample-app",
            )]))
        ,
    )
    .install_batch(opentelemetry::runtime::Tokio)
    .expect("Not running in tokio runtime");
```

今回はhttpではなくgRPC接続(tonic)を選択しました。  
`install_batch()`を行うと`opentelemetry_sdk::BatchSpanProcessorInternal::run()`が`tokio::spawn`で実行され、5秒に一回(もしくは最大trace数に達したい場合)にgRPC requestでcollectorに送信されます。  
https://github.com/open-telemetry/opentelemetry-rust/blob/d4b9befea04bcc7fc19319a6ebf5b5070131c486/opentelemetry-sdk/src/trace/span_processor.rs#L461  
ちなみに5秒に一回の設定値はdefault値として[仕様](https://opentelemetry.io/docs/reference/specification/sdk-environment-variables/#batch-span-processor)で定められています。  
このあたりのSDKの挙動まで仕様で決めているので、Rustだと5秒に一回だけど他の言語だと間隔が違うみたいな話がなさそうで安心感あります。

metricsに関する設定項目は以下です。

```rust
use opentelemetry::sdk::metrics::controllers::BasicController;

// https://github.com/open-telemetry/opentelemetry-rust/blob/d4b9befea04bcc7fc19319a6ebf5b5070131c486/examples/basic-otlp/src/main.rs#L35-L52
fn build_metrics_controller() -> BasicController {
    opentelemetry_otlp::new_pipeline()
        .metrics(
            opentelemetry::sdk::metrics::selectors::simple::histogram(Vec::new()),
            opentelemetry::sdk::export::metrics::aggregation::cumulative_temporality_selector(),
            opentelemetry::runtime::Tokio,
        )
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://localhost:4317"),
        )
        .build()
        .expect("Failed to build metrics controller")
}
```

Controllerだったり、selector,aggregationといったmetricsの概念を把握する必要があり、まだ実装を読めておらず今後の課題です。

### opentelemetry-collector

次はrustから出力したtraceを受け取ってbackendにexportするcollectorを動かします。  
以下がdocker-composeの設定です。

```yaml
version: '3.9'

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.66.0
    command: [ "--config=/etc/otel-collector-config.yaml" ]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
      - certs:/usr/share/otel/config/certs
    ports:
      - "4317:4317"   # OTLP gRPC receiver
    depends_on:
      elasticsearch:
        condition: service_healthy
```

設定fileの`otel-collector-config.yaml`は以下です。


```yaml
# https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md
receivers:
  otlp:
    # Disable http
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"

processors:
  batch:

# https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/README.md
exporters:
  # https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/loggingexporter/README.md
  # Exports data to the console via zap.Logger
  logging:
    # loglevel is deprecated in favor of verbosity
    # detailed | normal | basic
    verbosity: detailed
    sampling_initial: 5
  otlp/elastic:
    endpoint: "apm-server:8200"
    tls:
      ca_file: /usr/share/otel/config/certs/ca/ca.crt
  # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusexporter
  prometheus:
    endpoint: "0.0.0.0:8889"
  jaeger:
    endpoint: "jaeger:14250"
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, otlp/elastic, jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, otlp/elastic, prometheus]
```

設定fileの読み方ですがtop levelでは

```yaml
receivers:

processors:

exporters:
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, otlp/elastic, jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging, otlp/elastic, prometheus]
```

のように`receivers`, `processors`, `exportes`, `service`を定義します。  
signalの箇所でも言及したようにopentelemetryではtrace,metrics,logsを分けて考えます。collectorではそれぞれのsignalをどう処理するかをそれぞれ設定します。これを設定するのが、`service.pipelines.{traces,metrics}`です。  
上記の設定は、traceはotlp(gRPC)で入力を受け付け、batch処理したのち、logging, elasticsearch, jaegerに出力する。  
metricsもotlpで受け付けるが出力先は、logging,elasticsearch, prometheusと読みます。  
そして、pipelinesで参照されたreceivers, processors, exporterのそれぞれを設定を`exporter.otlp/elastic`のように行います。またここで、`otlp/elastic`となっていますがこれは`otlp` exporterの設定で`elastic`の部分は識別子です。traceとmetricsでexport先が違ったりする場合には`otlp/aaa`と`otlp/bbb`のようにできますが識別子は必要ないなら付与しなくても問題ないです。  

上記の設定では`exporters.prometheus`のように設定しているので、collectorのbinaryにはprometheus用の処理が組み込まれているんだなと思いますが、他にはどんなexporterがいるのかや、運用するうえで不要な依存は取り除きたいと思いました。  

collectorは[opentelemetry-collector-releases](https://github.com/open-telemetry/opentelemetry-collector-releases) repositoryで管理されています。  
ここに`distributions`という形で`otelcol`と`otelcol-contrib`の二つの形態があります。それぞれ`manifest.yaml`をもっておりそこにreceiverやexporterで何が使えるかが定義されています。  
例えば、`otelcol`の`manifest.yaml`は以下のようになっています。

```yaml
dist:
  module: github.com/open-telemetry/opentelemetry-collector-releases/core
  name: otelcol
  description: OpenTelemetry Collector
  version: 0.67.0
  output_path: ./_build
  otelcol_version: 0.67.0

receivers:
  - gomod: go.opentelemetry.io/collector/receiver/otlpreceiver v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/jaegerreceiver v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/kafkareceiver v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/opencensusreceiver v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/prometheusreceiver v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/zipkinreceiver v0.67.0

exporters:
  - gomod: go.opentelemetry.io/collector/exporter/loggingexporter v0.67.0
  - gomod: go.opentelemetry.io/collector/exporter/otlpexporter v0.67.0
  - gomod: go.opentelemetry.io/collector/exporter/otlphttpexporter v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/fileexporter v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/jaegerexporter v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/kafkaexporter v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/opencensusexporter v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/prometheusexporter v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/prometheusremotewriteexporter v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/zipkinexporter v0.67.0

extensions:
  - gomod: go.opentelemetry.io/collector/extension/zpagesextension v0.67.0
  - gomod: go.opentelemetry.io/collector/extension/ballastextension v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/extension/healthcheckextension v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/extension/pprofextension v0.67.0

processors:
  - gomod: go.opentelemetry.io/collector/processor/batchprocessor v0.67.0
  - gomod: go.opentelemetry.io/collector/processor/memorylimiterprocessor v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/attributesprocessor v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/resourceprocessor v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanprocessor v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/probabilisticsamplerprocessor v0.67.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/filterprocessor v0.67.0
```

[https://github.com/open-telemetry/opentelemetry-collector-releases/blob/v0.67.0/distributions/otelcol/manifest.yaml](https://github.com/open-telemetry/opentelemetry-collector-releases/blob/v0.67.0/distributions/otelcol/manifest.yaml)

ここから、exporterとして、loggingやprometheusが使えることがわかります。

#### logging exporter

collectorの設定で

```yaml
exporters:
  # https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/loggingexporter/README.md
  # Exports data to the console via zap.Logger
  logging:
    # loglevel is deprecated in favor of verbosity
    # detailed | normal | basic
    verbosity: detailed
    sampling_initial: 5
```
と設定したので、collectorのlogが出力されます。さきほどrustから出力したdataについては以下のようなlogが確認できました。  
冗長なのは`verbosity: detailed`を設定しているためです。


```
opentelemetry-handson-otel-collector-1       | 2022-12-18T07:01:06.906Z info    TracesExporter  {"kind": "exporter", "data_type": "traces", "name": "logging", "#spans": 3}
opentelemetry-handson-otel-collector-1       | 2022-12-18T07:01:06.908Z info    ResourceSpans #0
opentelemetry-handson-otel-collector-1       | Resource SchemaURL: 
opentelemetry-handson-otel-collector-1       | Resource attributes:
opentelemetry-handson-otel-collector-1       |      -> service.name: Str(sample-app)
opentelemetry-handson-otel-collector-1       | ScopeSpans #0
opentelemetry-handson-otel-collector-1       | ScopeSpans SchemaURL: 
opentelemetry-handson-otel-collector-1       | InstrumentationScope opentelemetry-otlp 0.11.0
opentelemetry-handson-otel-collector-1       | Span #0
opentelemetry-handson-otel-collector-1       |     Trace ID       : cb313713eb127ffe1be402e90114e6a3
opentelemetry-handson-otel-collector-1       |     Parent ID      : fb0a1f530e69c856
opentelemetry-handson-otel-collector-1       |     ID             : c4e1ff17ebe3b90b
opentelemetry-handson-otel-collector-1       |     Name           : auth
opentelemetry-handson-otel-collector-1       |     Kind           : Internal
opentelemetry-handson-otel-collector-1       |     Start time     : 2022-12-18 07:01:01.837864 +0000 UTC
opentelemetry-handson-otel-collector-1       |     End time       : 2022-12-18 07:01:01.838038 +0000 UTC
opentelemetry-handson-otel-collector-1       |     Status code    : Unset
opentelemetry-handson-otel-collector-1       |     Status message : 
opentelemetry-handson-otel-collector-1       | Attributes:
opentelemetry-handson-otel-collector-1       |      -> user: Str(ymgyt)
opentelemetry-handson-otel-collector-1       |      -> thread.id: Int(1)
opentelemetry-handson-otel-collector-1       |      -> code.namespace: Str(opentelemetry_handson)
opentelemetry-handson-otel-collector-1       |      -> thread.name: Str(main)
opentelemetry-handson-otel-collector-1       |      -> idle_ns: Int(43166)
opentelemetry-handson-otel-collector-1       |      -> busy_ns: Int(117000)
opentelemetry-handson-otel-collector-1       |      -> code.lineno: Int(64)
opentelemetry-handson-otel-collector-1       |      -> code.filepath: Str(src/main.rs)
opentelemetry-handson-otel-collector-1       | Events:
opentelemetry-handson-otel-collector-1       | SpanEvent #0
opentelemetry-handson-otel-collector-1       |      -> Name: successfully completed
opentelemetry-handson-otel-collector-1       |      -> Timestamp: 2022-12-18 07:01:01.837949 +0000 UTC
opentelemetry-handson-otel-collector-1       |      -> DroppedAttributesCount: 0
opentelemetry-handson-otel-collector-1       |      -> Attributes::
opentelemetry-handson-otel-collector-1       |           -> level: Str(INFO)
opentelemetry-handson-otel-collector-1       |           -> target: Str(opentelemetry_handson)
opentelemetry-handson-otel-collector-1       |           -> ops: Str(xxx)
opentelemetry-handson-otel-collector-1       |           -> counter.ops_count: Int(10)
opentelemetry-handson-otel-collector-1       |           -> code.filepath: Str(src/main.rs)
opentelemetry-handson-otel-collector-1       |           -> code.namespace: Str(opentelemetry_handson)
opentelemetry-handson-otel-collector-1       |           -> code.lineno: Int(71)
```

### backend

最後にcollectorがtrace情報をexportするbackendを立ち上げます。  
以下が`docker-compose.yaml`です。

```yaml
version: '3.9'

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.66.0
    command: [ "--config=/etc/otel-collector-config.yaml" ]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
      - certs:/usr/share/otel/config/certs
    ports:
      - "4317:4317"   # OTLP gRPC receiver
    depends_on:
      elasticsearch:
        condition: service_healthy

  setup_elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.2
    volumes:
      - certs:/usr/share/elasticsearch/config/certs
    user: "0"
    command: >
      bash -c '
        if [ ! -f config/certs/ca.zip ]; then
          echo "Creating CA";
          bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip;
          unzip config/certs/ca.zip -d config/certs;
        fi;
        if [ ! -f config/certs/certs.zip ]; then
          echo "Creating certs";
          echo -ne \
          "instances:\n"\
          "  - name: elasticsearch\n"\
          "    dns:\n"\
          "      - elasticsearch\n"\
          "      - localhost\n"\
          "    ip:\n"\
          "      - 127.0.0.1\n"\
          > config/certs/instances.yml;
          bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs.zip --in config/certs/instances.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key;
          unzip config/certs/certs.zip -d config/certs;
        fi;
        if [ ! -f config/certs/certs-apm.zip ]; then
          echo "Creating certs for apm";
          echo -ne \
          "instances:\n"\
          "  - name: apm-server\n"\
          "    dns:\n"\
          "      - apm-server\n"\
          "      - localhost\n"\
          "    ip:\n"\
          "      - 127.0.0.1\n"\
          > config/certs/instances-apm.yml;
          bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs-apm.zip --in config/certs/instances-apm.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key;
          unzip config/certs/certs-apm.zip -d config/certs;
        fi;
        echo "Setting file permissions"
        chown -R root:root config/certs;
        find . -type d -exec chmod 750 \{\} \;;
        find . -type f -exec chmod 640 \{\} \;;
        echo "Waiting for Elasticsearch availability";
        until curl -s --cacert config/certs/ca/ca.crt https://elasticsearch:9200 | grep -q "missing authentication credentials"; do sleep 30; done;
        echo "Setting kibana_system password";
        until curl -s -X POST --cacert config/certs/ca/ca.crt -u elastic:password -H "Content-Type: application/json" https://elasticsearch:9200/_security/user/kibana_system/_password -d "{\"password\":\"password\"}" | grep -q "^{}"; do sleep 10; done;
        echo "All done!";
      '
    healthcheck:
      test: ["CMD-SHELL", "[ -f config/certs/elasticsearch/elasticsearch.crt ]"]
      interval: 10s
      timeout: 10s
      retries: 120

  elasticsearch:
    depends_on:
      setup_elasticsearch:
        condition: service_healthy
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.2
    volumes:
      - certs:/usr/share/elasticsearch/config/certs
    ports:
      - "9200:9200"
    environment:
      - ELASTIC_PASSWORD=password
      - bootstrap.memory_lock=true
      - xpack.security.enabled=true
      - xpack.security.authc.api_key.enabled
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.key=certs/elasticsearch/elasticsearch.key
      - xpack.security.http.ssl.certificate=certs/elasticsearch/elasticsearch.crt
      - xpack.security.http.ssl.certificate_authorities=certs/ca/ca.crt
      - xpack.security.http.ssl.verification_mode=certificate
      - discovery.type=single-node
    ulimits:
      memlock:
        soft: -1
        hard: -1
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl -s --cacert config/certs/ca/ca.crt https://localhost:9200 | grep -q 'missing authentication credentials'",
        ]
      interval: 10s
      timeout: 10s
      retries: 120

  kibana:
    depends_on:
      elasticsearch:
        condition: service_healthy
    image: docker.elastic.co/kibana/kibana:8.5.2
    volumes:
      - certs:/usr/share/kibana/config/certs
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=https://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=password
      - ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=config/certs/ca/ca.crt

  apm-server:
    image: docker.elastic.co/apm/apm-server:8.5.2
    cap_add: ["CHOWN", "DAC_OVERRIDE", "SETGID", "SETUID"]
    cap_drop: ["ALL"]
    volumes:
      - certs:/usr/share/apm-server/config/certs
    ports:
      - "8200:8200"
    command: >
      apm-server -e
        -E apm-server.rum.enabled=true
        -E setup.kibana.host=kibana:5601
        -E setup.template.settings.index.number_of_replicas=0
        -E apm-server.kibana.enabled=true
        -E apm-server.kibana.host=kibana:5601
        -E apm-server.kibana.username=kibana_system
        -E apm-server.kibana.password=password
        -E output.elasticsearch.hosts=["https://elasticsearch:9200"]
        -E output.elasticsearch.username=elastic
        -E output.elasticsearch.password=password
        -E output.elasticsearch.ssl.certificate_authorities=["config/certs/ca/ca.crt"]
        -E apm-server.ssl.enabled=true
        -E apm-server.ssl.certificate="config/certs/apm-server/apm-server.crt"
        -E apm-server.ssl.key="config/certs/apm-server/apm-server.key"
    healthcheck:
      interval: 10s
      retries: 12
      test: curl --write-out 'HTTP %{http_code}' --fail --silent --output /dev/null http://localhost:8200/

  prometheus:
    image: prom/prometheus:v2.40.5
    command: ["--config.file=/etc/prometheus/prometheus.yaml"]
    volumes:
      - ./prometheus.yaml:/etc/prometheus/prometheus.yaml
    ports:
      - "9090:9090"

  jaeger:
    image: jaegertracing/all-in-one:1.40.0
    ports:
      - "16686:16686" # UI

volumes:
  certs:
    driver: local
```

export先として

* elasticsearch
  * apm-server, elasticsearch, kibana
* prometheus
* jaeger
を設定しています。

それぞれのUIも立ち上げているので、以下どんな感じで見れたかのSSを貼ります。

#### elasticsearch

`localhost:5601`にkibanaが立ち上がっています。loginのcredentialは`elastic/password`です。  
APM AgentをUIからinstallしたのち(この設定がKibanaのGUIからしか行えないのが大変なマイナスポイントでなんとかならないかと思っています)

Observability > APM > Tracesを選択すると

{{ figure(images=["images/otel_kibana_ss_1.png"]) }}

request traceがでているので選択します。

{{ figure(images=["images/otel_kibana_ss_2.png"]) }}

{{ figure(images=["images/otel_kibana_ss_3.png"]) }}


無事traceがexportされていることがわかりました。


#### jaeger

jaegerは`localhost:16686`から確認できます

{{ figure(images=["images/otel_jaeger.png"]) }}
#### prometheus

prometheusのUIは`localhost:9090`から確認できます。

{{ figure(images=["images/otel_prometheus.png"]) }}

```rust
info!(
    ops = "xxx",
    counter.ops_count = 10,
    "successfully completed"
);
```
のように出力すると、`counter` prefixがmetricsとして変換されるのが`tracing_opentelemetry`の仕様のようです。  
このあたりの変換の仕組みの理解は今後の課題です。  
prometheusから`ops_count` metricsが確認できました。

## まとめ

Opentelemetryの概要を理解できました。  
log,trace,metricsがinfra/application共通で処理でき、application codeからvendor依存の処理が(otel以外)取り除けるのはとても魅力的です。  
例えばobservability基盤をelasticsearch <-> datadogに変更のようなことがcollectorの設定fileだけで対応できますし、並行稼働も容易そうです。  
Rustにおける導入はtracing ecosystemを前提にtracing-opentelemetryで行うのがベストというのが自分の考えですが、metricsの表現力等が実運用に耐えるかまだ見えていません。  
結局はotel + αになってしまっては管理するコストを下げる狙いが果たせないのでecosystemの充実がポイントだと思います。  
この点についてはただ期待するのではなくtracing projectにcontributeできないかと思っていたりします。  
tracingのexport処理については実装を読んで概要は理解できたのですがここに書くと記事の長さが2倍になりそうだったので、metricsとあわせて別の機会にしようと思っています。

ちなみにopentelemetryの略称は`OTel`と[仕様](https://opentelemetry.io/docs/reference/specification/#project-naming)で決まっていました。(ここまで仕様で決めるの好きです)


