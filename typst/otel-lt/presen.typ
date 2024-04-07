#import "@preview/polylux:0.3.1": *
#import themes.bipartite: *

#show: bipartite-theme.with(aspect-ratio: "16-9")

#set text(
  size: 25pt,
  font: (
    // "Noto Color Emoji",
    // "JetBrainsMono Nerd Font",
    "Noto Sans CJK JP",
))

#title-slide(
  title: [RustでOpenTelemetry],
  subtitle: [tracingと一緒に使ってわかった課題と学び],
  author: [ymgyt],
  date: [2024-04-10],
)

#west-slide(title: "自己紹介")[
  ```toml
  [speaker]
  name = "Yamaguchi Yuta"
  x    = "@YAmaguchixt"

  [company]
  name = "FRAIM Inc."
  ```
]

#west-slide(title: "概要")[
  - RustにOpenTelemetryを導入して、Traces, Metrics, Logsを取得した
  - tracingというlibからOpenTelemetry APIを利用した 
]

#west-slide(title: "最初の課題")[
  OpenTelemetry APIを直接利用するか\
  lib(tracing)経由で利用するか
]

#west-slide(title: "OpenTelemetry APIを直接利用するか")[
  #figure(
    image("./images/library-design.png", width: 80%,height: 80%, fit: "contain"),
    numbering: none,
    caption: [#link("https://opentelemetry.io/docs/specs/otel/library-guidelines/")[OpenTelemetry Client Generic Design]]
  )
]

#west-slide(title: "OpenTelemetry APIを直接利用するか")[
  tracing経由でOpenTelemetryを利用することにした
  - 既にtracingを計装済だった
  - 利用しているlibの多くがtracingで計装されている
  - #link("https://github.com/tokio-rs/tracing-opentelemetry")[tracing-opentelemetry]が#link("https://github.com/tokio-rs")[tokio]から提供されていた
]

#west-slide(title: "OpenTelemetry APIを直接利用するか")[
  RustのOpenTelemetry projectでもtracingとの関係が#link("https://github.com/open-telemetry/opentelemetry-rust/issues/1571")[OpenTelemetry Tracing API vs Tokio-Tracing API for Distributed Tracing]で議論されている
  #figure(
    image("./images/otel-vs-tracing-ss-2.png", width: 100%,height: 50%, fit: "contain"),
    numbering: none,
  )
]

#west-slide(title: "Resource")[
#set text(size: 16pt)
#show raw: it => stack(dir: ttb, ..it.lines)
#show raw.line: it => {
  box(
    width: 100%,
    height: 1.3em,
    inset: 0.25em,
    align(horizon, stack(
      dir: ltr,
      box(width: 15pt)[#it.number],
      it.body,
    ))
  )
}
```rust
use opentelemetry_sdk::{resource::EnvResourceDetector, Resource};
use opentelemetry_semantic_conventions::{
    resource::{SERVICE_NAME, SERVICE_NAMESPACE, SERVICE_VERSION},
    SCHEMA_URL,
};

pub fn resource(
    service_name: impl Into<Cow<'static, str>>,
    service_version: impl Into<Cow<'static, str>>,
) -> Resource {
    Resource::from_schema_url(
        [
            (SERVICE_NAME, service_name.into()),
            (SERVICE_VERSION, service_version.into()),
            (SERVICE_NAMESPACE, "foo".into()),
        ]
        .into_iter()
        .map(|(key, value)| KeyValue::new(key, value)),
        SCHEMA_URL, // https://opentelemetry.io/schemas/1.21.0
    )
    .merge(&Resource::from_detectors(
        Duration::from_millis(200),
        // Detect "OTEL_RESOURCE_ATTRIBUTES" environment variables
        vec![Box::new(EnvResourceDetector::new())],
    ))
}
```
]

#west-slide(title: "Traces")[
#set text(size: 18pt)
```rust
#[tracing::instrument(
  skip_all, fields(%url)
)]
async fn fetch_feed(&self, url: Url) -> Result<Feed,Error> 
{ /* ... */ }
```
\
関数にSpanを設定するには`#[tracing::instrument]` annotationを利用する\
`fields()`に値を指定するとSpanのattributeになる
]

#west-slide(title: "Traces")[
  #figure(
    image("./images/trace-ss-1.png", width: 100%,height: 90%, fit: "contain"),
    numbering: none,
    caption: [Span attributesにurlが記録される]
  )
]

#west-slide(title: "Traces")[
```rust
async fn run() {
  // ...
  info!(
    "enduser.id"= user_id,
    "operation" = operation,
  );
  // ...
```

関数の中で行ったlogging(`info`や`error`)はSpanのEventsとして記録される
]

#west-slide(title: "Traces")[
  #figure(
    image("./images/trace-ss-2.png", width: 100%,height: 90%, fit: "contain"),
    numbering: none,
    caption: [SpanのEventsに記録される]
  )
]

#west-slide(title: "Tracesの課題")[
Context propagationではOpenTelemetryの仕組みを利用するので、OpenTelemetryのContextやBaggageを意識する必要がある。\
(ApplicationがOpenTelemetryをまったく意識しなくていいことにならない)

- inject時は`tracing::Span` -> `opentelemetry::Context` -> `http::Header` 
- extract時は`http::Header` -> `opentelemetry::Context` -> `tracing::Span`
]

#west-slide(title: "Tracesの課題")[
OpenTelemetryのtraceは1 layer(plugin)という位置づけなので、samplingしない場合でもtracing側でrespectされない\

あくまでtracing側の機構でspanのsamplingを制御する必要がある\
\
`RUST_LOG=app=info,
lib_b[request{path="foo"}]=trace`\
(一方で、アプリケーションはinfo、lib_bのrequest spanのpathが"foo"はtraceといった制御ができる)
]

#west-slide(title: "Metrics")[
3つの選択肢があった
\
- Prometheus Metrics
- OpenTelemetry Metrics API
- tracing-opentelemetry MetricsLayer
]

#west-slide(title: "Metrics")[
Prometheus Metrics\
\
Applicationからはprometheus形式のmetricsをexportして
OpenTelemetry collectorでOpenTelemetry形式に変換する

#pause => Signalを関連づける重要性が謳われていたので採用しなかった
]

#west-slide(title: "Metrics")[
OpenTelemetry Metrics API\

#set text(size: 20pt)
```rust
fn main() {
  let meter = opentelemetry::global::meter("foo");
  let counter = meter.u64_counter("counter").init();
  counter.add(
    10, 
    &[opentelemetry::KeyValue::new("key","value")],
  );
}
```
#pause => tracesとの一貫性を重視して、metricsもtracing経由で操作することにした

]

#west-slide(title: "Metrics")[
tracing-opentelemetry MetricsLayer

#set text(size: 20pt)
```rust
info!(
    monotonic_counter.http.server.request = 1,
    http.response.status.code = status
);
```

tracingでは、info!のloggingはEventのdispatchになる\
layer側で、`monotonic_counter` prefixがついたeventを受け取ったら、attribute(`http.response.status.code`)を付与して、counter metricsを生成する
]

#west-slide(title: "Metricsの課題")[
Prometheus/Mimirを利用している場合\
OpenTelemetry -> Prometheusの変換を意識する必要がある
]

#west-slide(title: "Metricsの課題")[
例えば、OpenTelemetryのUpDownCounterはPrometheusのGaugeになる

> If the aggregation temporality is cumulative and the sum is non-monotonic, it MUST be converted to a Prometheus Gauge.

#link("https://opentelemetry.io/docs/specs/otel/compatibility/prometheus_and_openmetrics/#sums")
]

#west-slide(title: "Metricsの課題")[
Prometheusとの互換性に関してはPrometheusの
#link("https://prometheus.io/blog/2024/03/14/commitment-to-opentelemetry/")[Our commitment to OpenTelemetry]というブログで互換性向上の取り組みが紹介されていた

- `http.server.request.duration` -> `http_server_requrest_duration`の変換をなくす
- Native support for resource attributes(prometheusはmetrics attributesとresourceをflatなlabelにする)
- OTLPのsupport
]

#west-slide(title: "Metricsの課題")[
  Elastic stack(elasticsearch, kibana)を使っていた際もOpneTelemetryのresourceやattributesが変換されてしまっていたが\
  #link("https://opentelemetry.io/blog/2023/ecs-otel-semconv-convergence/")[Announcing the Elastic Common Schema(ECS) and OpenTelemetry Semantic Convention Convergence]で、両者の統合が発表されていた

  > The goal is to achieve convergence of ECS and OTel Semantic Conventions into a single open schema that is maintained by OpenTelemetry
]

#west-slide(title: "Metricsの課題")[
Eventのfield(key,value)だけで表現できないmetricsも\

valueにはprimitive型(i64,f64,bool,..)やfmt::Display等の文字列表現しか利用できない \

=> Histogramでboundariesを指定したい場合に対応できない
]

#west-slide(title: "Metricsの課題")[
#set text(size: 15pt)
```rust
use opentelemetry_sdk::metrics::{Instrument, Stream,View};

fn view() -> impl View {
    |instrument: &Instrument| -> Option<Stream> {
        match instrument.name.as_ref() {
            "graphql.duration" => Some(
                Stream::new()
                    .name(instrument.name.clone())
                    .aggregation(
                        opentelemetry_sdk::metrics::Aggregation::ExplicitBucketHistogram {
                            boundaries: vec![
                                0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5,
                                5.0, 7.5, 10.0,
                            ],
                            record_min_max: false,
                        },
                    )
                    .unit(Unit::new("s")),
            ),
            name => {
                None
            }
        }
    }
}
```
]

#west-slide(title: "Metricsの課題")[
MetricsのViewという仕組みで、SDK初期化時に変換処理を追加することで対処した\

- Metrics生成箇所とSDK初期化処理でcodeが別れてしまった
- 名前(Instrument.name)で一致させているので型/compile時の保証がない
]
#west-slide(title: "リンク")[
  - #link("https://github.com/tokio-rs")
  - #link("https://github.com/tokio-rs/tracing-opentelemetry")
  - #link("https://github.com/open-telemetry/opentelemetry-rust/discussions/1032")
  - #link("https://github.com/open-telemetry/opentelemetry-rust/issues/1571")[OpenTelemetry Tracing API vs Tokio-Tracing API for Distributed Tracing]
]

