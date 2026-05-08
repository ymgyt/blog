+++
title = "🔭 OpenTelemetry を Lambda に計装する"
slug = "instrument-opentelemetry-with-lambda"
description = "Lambda lifecycle を踏まえて OpenTelemetry export をどう設計するか"
date = "2026-05-08"
draft = false
[taxonomies]
tags = ["rust","opentelemetry"]
[extra]
image = "images/emoji/telescope.png"
+++

本記事では、Rust で書いた Lambda に OpenTelemetry を計装する上で自分が直面した、Lambda lifecycle に起因する問題について書きます。

通常の server process では、telemetry の export は background task に任せて process 終了時に flush するのが定石ですが、Lambda ではこれが素直に動きません。

* invocation 後に execution environment が freeze されるため、background task の実行が保証されない
* `lambda_runtime` は main loop に入ると制御を返さないため、process 終了時に flush する hook がない

結論としては、function process では invocation 境界で localhost に export し、remote backend への delivery は Lambda extension に寄せる、という構成にしました。以下、なぜそうなるかと実装を順に見ていきます。

## 前提

本記事では以下の version を利用しました。

```toml
lambda_runtime = "1.1.3"
opentelemetry = "0.31.0"
opentelemetry_sdk = "0.31.0"
opentelemetry-otlp = "0.31.1"
opentelemetry-appender-tracing = "0.31.1"
tracing-opentelemetry = "0.32.1"
```

用語

* **function process**: Runtime API の client として handler を実行するプロセス
* **extension process**: Extensions API の client として function process と同じ execution environment で動く補助プロセス
* **Lambda service**: Runtime API / Extensions API を提供する Lambda の control plane
* **telemetry**: logs, traces, metrics といったアプリケーションが出力する観測データ


## Telemetry をいつ export するか

冒頭で挙げた 2 つの制約 (freeze による非同期タスクの停止 / `lambda_runtime` が制御を返さない) について、なぜそうなるのかを Lambda runtime の挙動から順に見ていきます。


### Lambda Runtime

Lambda というと利用者は関数(function)を書いて、Lambda service が呼び出しを制御してくれるように思えますが、実体としては利用者側でリクエストを polling する pull 型です。

Lambda service は `/2018-06-01/runtime/invocation/next` という API を公開しており、function process はこれを呼び出して、Lambda invocation を表現する `EventResponse` を取得します。
`EventResponse` を加工して handler に渡し、結果を取得したのちに、`/2018-06-01/runtime/invocation/{AwsRequestId}/response` へ POST して結果を Lambda service に返します。
イメージとしては、以下のような実装です。

```rust
fn lambda_runtime_main_loop() {
    loop {
        // 次の invocation を待つ (long-poll)
        let event = http_get("/runtime/invocation/next").await;

        // handler を実行
        let result = handler(event).await;

        // 結果を Lambda service に通知(id は eventから取得)
        match result {
            Ok(response) => http_post("/runtime/invocation/{id}/response", response).await,
            Err(err) => http_post("/runtime/invocation/{id}/error", err).await,
        }
    }
}
```

ただ、Runtime API の呼び出しや invocation event の変換等を利用者側で実装するのは大変なので、[lambda-runtime][] crate が AWS から提供されています。
[lambda-runtime][] は `tower::Service` ベースの実装となっており、利用者側が定義する handler `Service<LambdaEvent<EventPayload>>` と自然に compose できる設計になっています。素晴らしいですね。

上記の loop は実際には以下のように実装されています。(`process_invocation` が handler 呼び出し)
[`lambda-runtime/src/runtime.rs`](https://github.com/aws/aws-lambda-rust-runtime/blob/e397be4ab03645fec8474ee8a26461ff035dd051/lambda-runtime/src/runtime.rs#L364)

```rust
impl<S> Runtime<S>
where
    S: Service<LambdaInvocation, Response = (), Error = BoxError>,
{
    pub async fn run(self) -> Result<(), BoxError> {
        /* ... */
        let incoming = incoming(&self.client);
        Self::run_with_incoming(self.service, self.config, incoming).await
    }

    pub(crate) async fn run_with_incoming(
        mut service: S,
        config: Arc<Config>,
        incoming: impl Stream<Item = Result<http::Response<hyper::body::Incoming>, BoxError>> + Send,
    ) -> Result<(), BoxError> {
        tokio::pin!(incoming);
        while let Some(next_event_response) = incoming.next().await {
            trace!("New event arrived (run loop)");
            let event = next_event_response?;
            process_invocation(&mut service, &config, event, true).await?;
        }
        Ok(())
    }
}

fn incoming(
    client: &ApiClient,
) -> impl Stream<Item = Result<http::Response<hyper::body::Incoming>, BoxError>> + Send + '_ {
    async_stream::stream! {
        loop {
            trace!("Waiting for next event (incoming loop)");
            let req = NextEventRequest.into_req().expect("Unable to construct request");
            let res = client.call(req).await;
            yield res;
        }
    }
}
```

### Freeze と Shutdown

ここがハマりポイントなのですが、`Runtime::run()` は呼び出すと制御を返しません。

> The runtime and each extension indicate completion by sending a Next API request. Lambda freezes the execution environment when the runtime and each extension have completed and there are no pending events.

[environment-lifecycle][]

この freeze と 暗黙的な shutdown が Lambda のポイントです。
function process(`Runtime`) が `/runtime/invocation/next` を呼んだ時点で実行環境が freeze する可能性があるので、background の非同期タスクの実行が保証されません。
freeze してからそのまま shutdown してしまうと、Drop 等が走らないので、flush 処理のタイミングがないことが課題です。

handler 処理の中で telemetry export まで実行してしまえばよいのですが、export は通常 network call を伴いますし、その時間分だけ response を返す時間が遅れてしまいます。また、Lambda が連続して呼び出される場合、ある程度まとめてから export したほうが効率的ですがそれもできません。


### Lambda Extension

ここまでの問題をまとめると、function process (handler) とは別のコンテキストで動き、handler の処理が完了するまで freeze されず、終了時に flush できる仕組みが必要、ということになります。

この仕組みを提供してくれるのが extension です。
Extension は Lambda の実行 image の `/opt/extensions` に置く binary で、Lambda service が起動してくれます。
Extension 用の API も用意されており、`/extension/register` で extension を登録し、`/extension/event/next` を呼び出すと、function process 同様、Lambda service が event を返してくれます。
この event には、`Invoke` と `Shutdown` の 2 種類があり、それぞれ function process の起動時と shutdown 時にレスポンスが返ってきます。
そしてさきほど引用したように

> Lambda freezes the execution environment when the runtime and each extension have completed and there are no pending events.

Lambda service は extension の完了を待って freeze してくれます。
また、function process と extension は localhost で通信できるので、extension が localhost で OTLP server を listen しておけば、function process は localhost へ OTLP export できます。

Shutdown 時は `/extension/event/next` が `Shutdown` event を返してくれるのでそのタイミングで flush できます。これにより、function process からの telemetry をある程度 extension で queue 等に保持しておいて 非同期で export することも可能です。

Runtime API のハンドリングを [lambda-runtime][] が実装してくれていたように、Extensions API のハンドリングは [lambda-extension][] crate が実装してくれています。
例によってこちらも user が `Invoke`, `Shutdown` を処理する `tower::Service` を渡せばよい設計になっています。

## SDK の設定

function process は invoke 毎に localhost の extension に telemetry を export し、extension は一定数 queueing したのちに remote backend に export して、`Shutdown` 時に flush するという方針が立ちました。

次に実際に function process 側を計装していきます。
各 signal について以下の方針をとります。

* Logs: tracing -> tracing_subscriber -> opentelemetry-appender-tracing
* Traces: tracing -> tracing_subscriber -> tracing-opentelemetry
* Metrics: opentelemetry_sdk

まず、全体像としては以下のような責務分担を考えています。

```text
+------------------------+           +-------------------------+
| function process       |  OTLP     | extension process       |
|------------------------| --------> |-------------------------|
| tracing_subscriber     | localhost | local otlp receiver     |
| trace/log provider     |           | batch queue             |
| meter provider         |           | remote exporter         |
| handler                |           | shutdown flush          |
+------------------------+           +-------------------------+
```

function process 側は invoke の hot path にいるので、ここでは signal を生成して localhost に投げるところまでに責務を限定します。
一方で extension process 側は invoke の完了後もしばらく動けるので、network 越しの export や retry, `Shutdown` 時の flush はすべてこちらに寄せます。

### Logs

Logs については、公式が [opentelemetry-appender-tracing](https://github.com/open-telemetry/opentelemetry-rust/tree/main/opentelemetry-appender-tracing) で提供している [`OpenTelemetryTracingBridge`](https://github.com/open-telemetry/opentelemetry-rust/blob/f744509915e6e3b4fc2b551fd0c83f6a96e1fc71/opentelemetry-appender-tracing/src/layer.rs#L348) が [`impl tracing_subscriber::Layer`](https://github.com/open-telemetry/opentelemetry-rust/blob/f744509915e6e3b4fc2b551fd0c83f6a96e1fc71/opentelemetry-appender-tracing/src/layer.rs#L430) しているので、tracing_subscriber と compose できます。
これは Logs signal の設計思想に沿ったものです。

> Our approach with logs is somewhat different. For OpenTelemetry to be successful in logging space we need to support existing legacy of logs and logging libraries, while offering improvements and better integration with the rest of observability world where possible.
>
> [OpenTelemetry Logging](https://opentelemetry.io/docs/specs/otel/logs/)

ということで、Logs に関しては log 用 API を用意してそれを叩いてもらうのではなく、既存の logging ecosystem に接続していくという設計方針のようです。

### Traces

Traces も同じく tracing ecosystem を利用しますが、tracing_opentelemetry は公式から提供されているものではなく、tracing project でホストされています。
したがって、traces に関しても bridge アプローチを取るのは設計思想に反するとも思えます。この点に関してはすでに issue [OpenTelemetry Tracing API vs Tokio-Tracing API for Distributed Tracing](https://github.com/open-telemetry/opentelemetry-rust/issues/1571) で議論されています。要するにこの議論は、traces を生成する際に、opentelemetry-rust として tracing と OpenTelemetry Trace API のどちらを推奨するかというものです。この issue は 2026-03-18 にクローズされて、現在 [docs: start doc for distributed tracing and logs guidance](https://github.com/open-telemetry/opentelemetry-rust/pull/3122/changes) で document が制作中です。

また、traces 関連では仕様に大きな変更がありました。
[Deprecating Span Events API](https://opentelemetry.io/blog/2026/deprecating-span-events/) で

> OpenTelemetry is deprecating the Span Event API. 

として、span event api が deprecate になりました。
これまで span の中で logging すると、span event としても logs としても記録され、同じ情報が 2 重に生成されていました。
個人的には冗長で分かりづらいと感じつつ、span は sampling されうるので両方残すのは仕方ないとも考えていました。
今後は logs 一本に集約できそうです。

### Metrics

最後に Metrics です。ここまで tracing ecosystem を利用してきましたが、metrics に関しては、opentelemetry api をそのまま使うのがよいかなというのが現時点の結論です。tracing-opentelemetry にも [`MetricsLayer`](https://github.com/tokio-rs/tracing-opentelemetry/blob/91c4faa0082a3bfe2b3e9e59ed1db295830f55ec/src/metrics.rs#L372) があり

```rust
tracing::info!(counter.foo = 1);
```

のような tracing event として counter を表現できます。
内部的には、`MetricsLayer` が特定の event field をみて、metrics の命名規約に一致していると、[初回の event 処理に instrument を生成](https://github.com/tokio-rs/tracing-opentelemetry/blob/91c4faa0082a3bfe2b3e9e59ed1db295830f55ec/src/metrics.rs#L57)します。

この実装は counter のようなシンプルな instrument では便利なのですが、instrument の初期化は実際にはもうすこし複雑だと考えています。例えば counter については、description と unit を指定したいところですし、histogram に関しては boundary として `Vec<f64>` を渡す必要があります。

つまり、tracing-opentelemetry で metrics を扱う方法は、instrument の生成と状態変更の責務が一体化されていることが問題であると考えています。

なので今のところは、application 初期化時に、instrument を初期化して、global 変数にセットするほうが使いやすいかなと考えています。

```rust
pub static FOO_COUNTER: LazyLock<Counter<u64>> = LazyLock::new(|| {
    METER
        .u64_counter("foo")
        .with_description("description")
        .with_unit("{foo}")
        .build()
});

fn process() {
  FOO_COUNTER.add(1, &[KeyValue::new("key", "val")]);
}
```

ということで、logs, traces, metrics それぞれで利用する crate が異なってしまうのが、自分の現状です。将来的には、tracing, opentelemetry 間の関係が整理されるか、統一的な layer がでてきてくれることに期待しています。

## Function process の計装

ここから function process 側の計装を実装していきます。
前述の通り、Lambda では handler の外で動く background task や process 終了時の Drop に export 完了を期待できません。
したがって function process 側では、OpenTelemetry SDK が用意している標準の batch processor / periodic reader にはそのまま乗らず、invocation の境界で明示的に flush できる構成にします。

具体的には、logs / traces は manual processor で process 内の queue に積み、metrics は manual reader で collect できるようにします。
handler の実行中は signal を記録するだけにして、handler が result を返した後、`tower::Layer` で localhost の extension に flush します。
remote backend への batch export や retry、`Shutdown` 時の flush は extension process 側の責務にします。

### Resource

まず、logs / traces / metrics に共通で付与する `Resource` を組み立てます。
`service.name` や `deployment.environment.name` のような情報は各 log record や span attribute に毎回付けるのではなく、provider 初期化時に resource attribute としてまとめて設定します。

```rust
use opentelemetry::KeyValue;
use opentelemetry_sdk::{Resource, resource::EnvResourceDetector};
use opentelemetry_semantic_conventions::{
    SCHEMA_URL,
    resource::{
        DEPLOYMENT_ENVIRONMENT_NAME,
        SERVICE_NAME,
        SERVICE_NAMESPACE,
        SERVICE_VERSION,
    },
};

fn build_resource() -> Resource {
    Resource::builder_empty()
        .with_detector(Box::new(EnvResourceDetector::new()))
        .with_schema_url(
            [
                KeyValue::new(SERVICE_NAMESPACE, "example"),
                KeyValue::new(SERVICE_NAME, env!("CARGO_PKG_NAME")),
                KeyValue::new(SERVICE_VERSION, env!("CARGO_PKG_VERSION")),
                KeyValue::new(DEPLOYMENT_ENVIRONMENT_NAME, "development"),
            ],
            SCHEMA_URL,
        )
        .build()
}
```


### Logs pipeline

Logs の入口は先ほど書いた通り `opentelemetry-appender-tracing` の `OpenTelemetryTracingBridge` を使います。
ただし、`SdkLoggerProvider` に標準の batch processor を設定して background export させるのではなく、自前の processor で一旦 queue に積むようにします。

構造としては以下のようになります。

```text
tracing::event!
  -> tracing_subscriber
  -> OpenTelemetryTracingBridge
  -> SdkLoggerProvider
  -> ManualLogProcessor
  -> in-memory queue
```

`ManualLogProcessor` の hot path でやることは、`SdkLogRecord` と `InstrumentationScope` を clone して queue に push するだけです。
ここでは OTLP HTTP request を実行しません。

```rust
use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
    time::Duration,
};

use opentelemetry::InstrumentationScope;
use opentelemetry_sdk::{
    error::OTelSdkResult,
    logs::{LogBatch, LogProcessor, SdkLogRecord},
};

#[derive(Clone)]
struct ManualLogProcessor {
    queue: Arc<Mutex<VecDeque<(SdkLogRecord, InstrumentationScope)>>>,
}

impl LogProcessor for ManualLogProcessor {
    fn emit(&self, record: &mut SdkLogRecord, scope: &InstrumentationScope) {
        let Ok(mut queue) = self.queue.lock() else {
            return;
        };
        queue.push_back((record.clone(), scope.clone()));
    }

    fn force_flush(&self) -> OTelSdkResult {
        Ok(())
    }

    fn shutdown_with_timeout(&self, _timeout: std::time::Duration) -> OTelSdkResult {
        Ok(())
    }
}
```

`force_flush` や `shutdown_with_timeout` は no-op にしています。
ここで同期的に export しようとすると、結局 handler path に network I/O を戻してしまうからです。
flush は別に持つ handle から async に実行します。

```rust
struct LogState {
    provider: SdkLoggerProvider,
    flush: LogFlushHandle,
}

#[derive(Clone)]
struct LogFlushHandle {
    queue: Arc<Mutex<VecDeque<(SdkLogRecord, InstrumentationScope)>>>,
    exporter: Arc<LogExporter>,
}

impl LogFlushHandle {
    async fn flush(&self, timeout: Duration) {
        let drained = {
            let Ok(mut queue) = self.queue.lock() else {
                return;
            };
            queue.drain(..).collect::<Vec<_>>()
        };

        if drained.is_empty() {
            return;
        }

        let records = drained
            .iter()
            .map(|(record, scope)| (record, scope))
            .collect::<Vec<_>>();
        let batch = LogBatch::new(&records);

        match tokio::time::timeout(timeout, self.exporter.export(batch)).await {
            Ok(Ok(())) => {}
            Ok(Err(err)) => eprintln!("failed to export logs: {err}"),
            Err(_) => eprintln!("log export timed out"),
        }
    }
}
```

`LogState::build` では、manual processor と flush handle が同じ queue を見るように組み立てます。
`LogExporter` は localhost extension の `/v1/logs` に向けます。

```rust
impl LogState {
    fn build(resource: Resource, endpoint: &str) -> Result<Self, Error> {
        let queue = Arc::new(Mutex::new(VecDeque::new()));

        let mut exporter = LogExporter::builder()
            .with_http()
            .with_endpoint(format!("{endpoint}/v1/logs"))
            .build()?;
        exporter.set_resource(&resource);
        let exporter = Arc::new(exporter);

        let processor = ManualLogProcessor {
            queue: queue.clone(),
        };
        let provider = SdkLoggerProvider::builder()
            .with_resource(resource)
            .with_log_processor(processor)
            .build();

        Ok(Self {
            provider,
            flush: LogFlushHandle { queue, exporter },
        })
    }
}
```

実際には queue の上限、overflow 時の drop counter、flush timeout なども必要になります。
ただ、設計上の要点は `emit` では network I/O をせず、invocation の末尾でまとめて localhost の extension に export することです。

なお export 失敗時の通知に `tracing::warn!` を使うと、`OpenTelemetryTracingBridge` 経由で再び logs queue に入ってしまい、自己参照になります。ここでは `eprintln!` で stderr に出して CloudWatch Logs から拾う方針にしています。

### Traces pipeline

Traces についても考え方は Logs と同じです。
`tracing-opentelemetry` の `OpenTelemetryLayer` を使って `tracing::span!` から OpenTelemetry span を生成しますが、`SdkTracerProvider` には `BatchSpanProcessor` を設定しません。
`BatchSpanProcessor` は background worker に export を任せる設計なので、Lambda の freeze と相性が悪いためです。

構造としては以下のようになります。

```text
tracing::span!
  -> tracing_subscriber
  -> tracing_opentelemetry::OpenTelemetryLayer
  -> SdkTracerProvider
  -> ManualSpanProcessor
  -> in-memory queue
```

`ManualSpanProcessor` では、span 終了時に呼ばれる `on_end` で `SpanData` を queue に積みます。

```rust
use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
    time::Duration,
};

use opentelemetry::Context;
use opentelemetry_sdk::{
    error::OTelSdkResult,
    trace::{Span, SpanData, SpanProcessor},
};

#[derive(Clone)]
struct ManualSpanProcessor {
    queue: Arc<Mutex<VecDeque<SpanData>>>,
}

impl SpanProcessor for ManualSpanProcessor {
    fn on_start(&self, _span: &mut Span, _cx: &Context) {
    }

    fn on_end(&self, span: SpanData) {
        if !span.span_context.is_sampled() {
            return;
        }

        let Ok(mut queue) = self.queue.lock() else {
            return;
        };
        queue.push_back(span);
    }

    fn force_flush(&self) -> OTelSdkResult {
        Ok(())
    }

    fn shutdown_with_timeout(&self, _timeout: std::time::Duration) -> OTelSdkResult {
        Ok(())
    }
}
```

`force_flush` と `shutdown_with_timeout` を no-op にする理由は Logs と同じく、export を invocation 末尾の flush handle に集約するためです。

```rust
struct TraceState {
    provider: SdkTracerProvider,
    flush: SpanFlushHandle,
}

#[derive(Clone)]
struct SpanFlushHandle {
    queue: Arc<Mutex<VecDeque<SpanData>>>,
    exporter: Arc<SpanExporter>,
}

impl SpanFlushHandle {
    async fn flush(&self, timeout: Duration) {
        let spans = {
            let Ok(mut queue) = self.queue.lock() else {
                return;
            };
            queue.drain(..).collect::<Vec<_>>()
        };

        if spans.is_empty() {
            return;
        }

        match tokio::time::timeout(timeout, self.exporter.export(spans)).await {
            Ok(Ok(())) => {}
            Ok(Err(err)) => eprintln!("failed to export spans: {err}"),
            Err(_) => eprintln!("span export timed out"),
        }
    }
}
```

`TraceState::build` の構造は `LogState::build` と同じで、processor と flush handle が同じ queue を共有し、`SpanExporter` は localhost extension の `/v1/traces` に向けます。

```rust
impl TraceState {
    fn build(resource: Resource, endpoint: &str) -> Result<Self, Error> {
        let queue = Arc::new(Mutex::new(VecDeque::new()));

        let mut exporter = SpanExporter::builder()
            .with_http()
            .with_endpoint(format!("{endpoint}/v1/traces"))
            .build()?;
        exporter.set_resource(&resource);
        let exporter = Arc::new(exporter);

        let processor = ManualSpanProcessor {
            queue: queue.clone(),
        };
        let provider = SdkTracerProvider::builder()
            .with_resource(resource)
            .with_sampler(Sampler::ParentBased(Box::new(
                Sampler::TraceIdRatioBased(0.1),
            )))
            .with_span_processor(processor)
            .build();

        Ok(Self {
            provider,
            flush: SpanFlushHandle { queue, exporter },
        })
    }

    fn tracer(&self) -> Tracer {
        self.provider.tracer("lambda-app")
    }
}
```

実装上は sampler の扱いもここで決めます。
例えば `ParentBased(TraceIdRatioBased)` を使う場合でも、sampling 判定自体は SDK 側に任せ、processor では sampled な span だけを queue に積む、という責務分担にしています。

### Metrics pipeline

Metrics では `PeriodicReader` を使いません。
`PeriodicReader` は名前の通り background task / timer で定期的に collect + export するため、Lambda の freeze 中に動くことを期待できないからです。
代わりに `ManualReader` を `SdkMeterProvider` に登録し、invocation 末尾で明示的に collect します。

構造としては以下のようになります。

```text
Counter::add / Histogram::record
  -> SdkMeterProvider
  -> ManualReader
  -> ResourceMetrics
  -> MetricExporter
```

```rust
use std::{
    sync::{Arc, Weak},
    time::Duration,
};

use opentelemetry_sdk::{
    error::OTelSdkResult,
    metrics::{
        InstrumentKind, ManualReader, Pipeline, Temporality,
        data::ResourceMetrics,
        reader::MetricReader,
    },
};

#[derive(Clone, Debug)]
struct SharedManualReader(Arc<ManualReader>);

impl MetricReader for SharedManualReader {
    fn register_pipeline(&self, pipeline: Weak<Pipeline>) {
        self.0.register_pipeline(pipeline);
    }

    fn collect(&self, rm: &mut ResourceMetrics) -> OTelSdkResult {
        self.0.collect(rm)
    }

    fn force_flush(&self) -> OTelSdkResult {
        self.0.force_flush()
    }

    fn shutdown_with_timeout(&self, timeout: Duration) -> OTelSdkResult {
        self.0.shutdown_with_timeout(timeout)
    }

    fn temporality(&self, kind: InstrumentKind) -> Temporality {
        match kind {
            InstrumentKind::Counter | InstrumentKind::Histogram => Temporality::Delta,
            _ => Temporality::Cumulative,
        }
    }
}
```

`temporality` は metrics の値をどういう意味で export するかを決めます。
`Cumulative` は「開始時点から現在までの累積値」を送り、`Delta` は「前回 collect してから今回 collect するまでの増分」を送ります。

通常の long-running process では `Cumulative` でも扱いやすいです。
process が長く生きるので、counter の start time が安定しており、backend 側も同じ process から伸び続ける時系列として解釈できます。

一方で Lambda では execution environment が cold start / warm start によって増減します。
同じ Lambda function でも、裏側では複数の execution environment が並行して存在し、それぞれが別々の start time を持ちます。
また、しばらく invoke が無ければ environment は破棄され、次の cold start で counter は 0 から始まります。

例えば `request.count` counter を `Cumulative` で送ると、次のような値になります。

```text
env A: 1, 2, 3, 4
env B: 1, 2
env C: 1
```

これはそれぞれの execution environment 内では正しい累積値ですが、backend で Lambda function 全体の request 数として扱うには、時系列の identity や reset を正しく解釈する必要があります。
backend が start time や resource attribute の扱いに敏感だと、environment ごとに別 series になったり、reset をまたいだ増分計算が期待通りにならなかったりします。

`Delta` にすると、各 flush が「この invocation で増えた分」に近い値になります。

```text
env A: 1, 1, 1, 1
env B: 1, 1
env C: 1
```

Lambda では invocation 境界で flush する設計にしているので、`Delta` は function 全体で集計しやすい形になります。
もちろん backend や reader の仕様に依存する部分はありますが、Lambda のように process lifetime が安定しない実行環境では、counter / histogram は `Delta` として送るほうが運用上わかりやすいと考えています。

flush 側では `ManualReader::collect` で `ResourceMetrics` を作り、それを localhost の extension に export します。

```rust
struct MeterState {
    provider: SdkMeterProvider,
    flush: MeterFlushHandle,
}

#[derive(Clone)]
struct MeterFlushHandle {
    reader: SharedManualReader,
    exporter: Arc<MetricExporter>,
}

impl MeterFlushHandle {
    async fn flush(&self, timeout: Duration) {
        let mut metrics = ResourceMetrics::default();

        if let Err(err) = self.reader.collect(&mut metrics) {
            eprintln!("failed to collect metrics: {err}");
            return;
        }

        if metrics.scope_metrics().all(|scope| scope.metrics().count() == 0) {
            return;
        }

        match tokio::time::timeout(timeout, self.exporter.export(&metrics)).await {
            Ok(Ok(())) => {}
            Ok(Err(err)) => eprintln!("failed to export metrics: {err}"),
            Err(_) => eprintln!("metric export timed out"),
        }
    }
}
```

`MeterState::build` では、`SdkMeterProvider` に登録する reader と、flush 側で `collect` する reader を同じものにします。
`MetricExporter` は localhost extension の `/v1/metrics` に向けます。

```rust
impl MeterState {
    fn build(resource: Resource, endpoint: &str) -> Result<Self, Error> {
        let reader = SharedManualReader(Arc::new(
            ManualReader::builder().build(),
        ));

        let exporter = Arc::new(
            MetricExporter::builder()
                .with_http()
                .with_endpoint(format!("{endpoint}/v1/metrics"))
                .build()?,
        );

        let provider = SdkMeterProvider::builder()
            .with_resource(resource)
            .with_reader(reader.clone())
            .build();

        Ok(Self {
            provider,
            flush: MeterFlushHandle { reader, exporter },
        })
    }
}
```

これで handler 側は `Counter::add` や `Histogram::record` を呼ぶだけになります。
metrics の collect / export は reader 側に閉じ込め、handler の business logic からは見えないようにします。

### Subscriber / Provider の初期化

ここまでで logs / traces / metrics それぞれの provider と flush handle を作れるようになりました。
次に、それらを application の入口で一度だけ初期化します。

Logs と Traces は `tracing_subscriber` の layer として接続します。
Logs は `OpenTelemetryTracingBridge`、Traces は `tracing_opentelemetry::OpenTelemetryLayer` を使います。
Metrics は `global::set_meter_provider` で global provider として登録します。

```rust
struct Providers {
    logs: LogState,
    traces: TraceState,
    metrics: MeterState,
}

impl Providers {
    fn flush_handle(&self) -> FlushHandle {
        FlushHandle {
            logs: self.logs.flush.clone(),
            traces: self.traces.flush.clone(),
            metrics: self.metrics.flush.clone(),
        }
    }
}

fn init_telemetry() -> Result<Providers, Error> {
    let resource = build_resource();
    let endpoint = "http://127.0.0.1:4318";

    let logs = LogState::build(resource.clone(), endpoint)?;
    let traces = TraceState::build(resource.clone(), endpoint)?;
    let metrics = MeterState::build(resource, endpoint)?;

    let log_layer =
        OpenTelemetryTracingBridge::new(&logs.provider);
    let trace_layer =
        tracing_opentelemetry::layer().with_tracer(traces.tracer());

    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(trace_layer)
        .with(log_layer)
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    global::set_meter_provider(metrics.provider.clone());

    Ok(Providers {
        logs,
        traces,
        metrics,
    })
}
```

ここでも export 先は remote backend ではなく localhost の extension です。
function process は observability backend の URL や認証情報を知らず、`http://127.0.0.1:4318/v1/logs` などに OTLP HTTP で投げるだけにしておきます。
remote backend への接続設定は extension process 側に閉じ込めます。

`fmt::layer()` も残しているのは、Lambda の標準出力に出た log は CloudWatch Logs に流れるためです。
OTLP 側の疎通を確認している間は、stdout と OTLP の両方に出しておくほうがデバッグしやすいです。
最終的に stdout を残すかどうかは運用方針次第です。

### Invocation 末尾で flush

ここまでの構成では、handler が実行されている間に logs / traces / metrics はそれぞれ process 内に貯まります。
ただし、貯めただけでは extension には届きません。
そこで invocation の末尾で、各 pipeline の flush handle を明示的に呼び出します。

handler の中に直接 `flush().await` を書くこともできますが、business logic と telemetry delivery の責務が混ざってしまいます。
`lambda_runtime` は `tower::Service` ベースなので、flush は `tower::Layer` として差し込むほうが扱いやすいです。

```rust
#[derive(Clone)]
struct FlushLayer {
    handle: FlushHandle,
    timeout: Duration,
}

struct FlushService<S> {
    inner: S,
    handle: FlushHandle,
    timeout: Duration,
}

impl<S> tower::Layer<S> for FlushLayer {
    type Service = FlushService<S>;

    fn layer(&self, inner: S) -> Self::Service {
        FlushService {
            inner,
            handle: self.handle.clone(),
            timeout: self.timeout,
        }
    }
}
```

`FlushService` は handler の result を待った後に flush します。
handler が `Ok` を返した場合も `Err` を返した場合も、telemetry はできるだけ extension に渡したいので、`result` の中身に関係なく flush を試みます。

```rust
impl<S, T, R> Service<LambdaEvent<T>> for FlushService<S>
where
    S: Service<LambdaEvent<T>, Response = R>,
    S::Future: Future<Output = Result<R, S::Error>> + Send + 'static,
    S::Error: Send + 'static,
    R: Send + 'static,
{
    type Response = R;
    type Error = S::Error;
    type Future = Pin<Box<dyn Future<Output = Result<R, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, event: LambdaEvent<T>) -> Self::Future {
        let handle = self.handle.clone();
        let timeout = self.timeout;
        let fut = self.inner.call(event);

        Box::pin(async move {
            let result = fut.await;
            handle.flush_all(timeout).await;
            result
        })
    }
}
```

`flush_all` では logs -> traces -> metrics の順に flush します。
flush 先は localhost の extension なので remote backend へ直接送るよりは軽いですが、それでも HTTP request なので timeout は必ず設定します。

```rust
#[derive(Clone)]
struct FlushHandle {
    logs: LogFlushHandle,
    traces: SpanFlushHandle,
    metrics: MeterFlushHandle,
}

impl FlushHandle {
    async fn flush_all(&self, timeout: Duration) {
        self.logs.flush(timeout).await;
        self.traces.flush(timeout).await;
        self.metrics.flush(timeout).await;
    }
}
```

これで application code から見ると、handler では `tracing::info!` や `Counter::add` を呼ぶだけです。
signal の delivery は service layer に閉じ込められるので、各 handler に flush 処理を書き忘れる問題も避けられます。

最後に、`main` では初期化した `Providers` から flush handle を取り出して、handler service に layer を重ねます。

```rust
#[tokio::main]
async fn main() -> Result<(), Error> {
    let providers = init_telemetry()?;

    let handler = service_fn(handler);
    let service = ServiceBuilder::new()
        .layer(FlushLayer {
            handle: providers.flush_handle(),
            timeout: Duration::from_millis(500),
        })
        .service(handler);

    Runtime::new(service).run().await?;
    Ok(())
}
```

ここで `providers` は main scope に保持し続けます。
`FlushHandle` は内部の `Arc` を clone して layer に渡しますが、provider 自体の lifetime は `providers` が持ちます。
flush のタイミングはあくまで `FlushLayer` が管理し、Drop や process shutdown には頼らないようにします。

## Lambda extension の実装

ここまでで、function process は invocation の末尾で localhost の extension に telemetry を渡すだけになりました。
次に、その受け口になる Lambda extension を実装します。

extension process の責務は以下です。

1. Extensions API で extension を登録し、`Invoke` / `Shutdown` event を受け取れるようにする
2. localhost で OTLP receiver を listen し、function process から送られてくる telemetry を受け取る
3. 受け取った telemetry を extension process 内で buffer し、必要な単位で remote backend に export する
4. `Shutdown` event を受け取ったら、残っている telemetry を flush する

function process では background worker や process shutdown に頼らないようにしました。
一方で extension process は Extensions API の event loop を持っているため、`Shutdown` event を明示的に処理できます。
そのため remote backend への batch export、retry、shutdown flush は extension process 側に寄せます。

実装上は、OTLP receiver と Extensions API の event loop を同時に動かす必要があります。
receiver は function process からの `/v1/logs`、`/v1/traces`、`/v1/metrics` を受け付けます。
event loop は `/extension/event/next` で次の `Invoke` または `Shutdown` event を待ちます。

このとき、extension 側の receiver は最初の invocation が始まる前に listen できている必要があります。
function process は invocation の末尾で extension に flush するため、receiver の起動が遅れると最初の telemetry を受け取れません。
したがって extension の初期化では、Extensions API への登録を済ませたうえで、最初の event polling に入る前に receiver を listen しておく、という順序にします。

イメージとしては以下のような実装です。

```rust
async fn extension_main_loop() -> Result<(), Error> {
    let extension = register_extension().await?;

    let telemetry = TelemetryBuffer::new();
    let receiver = start_otlp_receiver("127.0.0.1:4318", telemetry.clone()).await?;
    let exporter = RemoteExporter::new();

    loop {
        let event = extension.next_event().await?;

        match event {
            ExtensionEvent::Invoke { .. } => {
                telemetry.export_ready_batch(&exporter).await?;
            }
            ExtensionEvent::Shutdown { .. } => {
                receiver.shutdown().await?;
                telemetry.flush_all(&exporter).await?;
                break;
            }
        }
    }

    Ok(())
}
```

実際の実装では、`Invoke` event を受け取った時点では function の処理はまだ完了していません。
そのため、`Invoke` event は「この invocation の telemetry を flush するタイミング」というより、前回までに溜まっている telemetry を backend に送る機会として扱います。
現在実行中の invocation で発生した telemetry は、function process が handler の終了後に localhost receiver へ送ってきます。

参照実装として、[lambda-observability](https://github.com/djvcom/lambda-observability/tree/main) の [opentelemetry-lambda-extension](https://github.com/djvcom/lambda-observability/tree/main/crates/opentelemetry-lambda-extension) があります。
この実装でも、Extensions API のハンドリングには [lambda-extension][] が利用されています。

[`ExtensionRuntime::run()`](https://github.com/djvcom/lambda-observability/blob/c92d1e7e0746adbf50a7791e0c6eea7b59f130cd/crates/opentelemetry-lambda-extension/src/runtime.rs#L66) では、OTLP receiver の起動と `Extension::run()` が組み合わされています。
自分の要件では、flush の判定や、依存 crate (特に `opentelemetry` や `tokio`) のバージョンを自分で制御したかったので直接利用はしませんでしたが、構成を考えるうえで非常に参考になりました。

## まとめ

Lambda の lifecycle に合わせて OpenTelemetry を計装するには、background task や Drop に export を任せず、manual processor / reader で invocation 境界に flush を集約し、remote backend への delivery は extension に寄せる、という構成になりました。

そのおかげで extension の仕組みや manual processor / reader について学べた一方、signal ごとに利用する crate がばらけてしまうのは現状の課題です。Rust の opentelemetry は [着実に stable release](https://github.com/open-telemetry/opentelemetry-rust?tab=readme-ov-file#project-status) に向かっているので、tracing ecosystem と共存してもうすこしシンプルになるとうれしいと思っています。


## Links 

* [Using the Lambda runtime API for custom runtimes][runtime-api]
* [Using the Lambda Extensions API to create extensions][extensions-api]
* [Understanding the Lambda execution environment lifecycle][environment-lifecycle]

[runtime-api]: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html
[extensions-api]: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-extensions-api.html#runtimes-extensions-api-lifecycle
[environment-lifecycle]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html
[lambda-runtime]: https://github.com/aws/aws-lambda-rust-runtime/tree/main/lambda-runtime
[lambda-extension]: https://github.com/aws/aws-lambda-rust-runtime/tree/main/lambda-extension
