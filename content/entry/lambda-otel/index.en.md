+++
title = "🔭 Instrumenting OpenTelemetry with Lambda"
slug = "instrument-opentelemetry-with-lambda"
description = "How to design OpenTelemetry export around the Lambda lifecycle"
date = "2026-05-07"
draft = false
[taxonomies]
tags = ["rust","opentelemetry"]
[extra]
image = "images/emoji/telescope.png"
+++

This post is about the lifecycle-related issues I ran into while instrumenting a Rust Lambda with OpenTelemetry.

In a regular server process, you typically hand telemetry export off to a background task and flush at process shutdown. On Lambda, that approach does not really work:

* The execution environment can freeze after each invocation, so background tasks are not guaranteed to run.
* `lambda_runtime` does not return control once it enters its main loop, so there is no hook to flush at process shutdown.

In the end I settled on a design where the function process exports to localhost at each invocation boundary, and delivery to the remote backend is delegated to a Lambda extension. The rest of the post walks through why this design follows from the constraints, and how to implement it.

## Prerequisites

The versions used in this post:

```toml
lambda_runtime = "1.1.3"
opentelemetry = "0.31.0"
opentelemetry_sdk = "0.31.0"
opentelemetry-otlp = "0.31.1"
opentelemetry-appender-tracing = "0.31.1"
tracing-opentelemetry = "0.32.1"
```

Terminology

* **function process**: a process that acts as a Runtime API client and runs the handler.
* **extension process**: a helper process that acts as an Extensions API client and runs in the same execution environment as the function process.
* **Lambda service**: the Lambda control plane that exposes the Runtime API and Extensions API.
* **telemetry**: observability data emitted by the application — logs, traces, and metrics.


## When to export telemetry

Let's look at the two constraints I listed in the introduction (freeze stopping background tasks / `lambda_runtime` not returning control) and see why they hold, by walking through the Lambda runtime model.


### Lambda Runtime

Lambda gives the impression that you write a function and the Lambda service drives invocations, but in reality it is a pull model in which the user-side process polls for requests.

The Lambda service exposes an API at `/2018-06-01/runtime/invocation/next`. The function process calls this and receives an `EventResponse` representing a Lambda invocation.
After transforming the `EventResponse` and passing it to the handler, the function process POSTs the result to `/2018-06-01/runtime/invocation/{AwsRequestId}/response`.
Conceptually, the implementation looks like this:

```rust
fn lambda_runtime_main_loop() {
    loop {
        // wait for the next invocation (long-poll)
        let event = http_get("/runtime/invocation/next").await;

        // run the handler
        let result = handler(event).await;

        // notify the Lambda service of the result (id taken from the event)
        match result {
            Ok(response) => http_post("/runtime/invocation/{id}/response", response).await,
            Err(err) => http_post("/runtime/invocation/{id}/error", err).await,
        }
    }
}
```

Implementing the Runtime API calls and event conversion yourself is tedious, so AWS provides the [lambda-runtime][] crate.
[lambda-runtime][] is built on `tower::Service` and is designed so that a user-defined handler `Service<LambdaEvent<EventPayload>>` composes naturally with it. Nice.

The actual loop is implemented like this (`process_invocation` is where the handler is called):
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

### Freeze and Shutdown

This is the gotcha: once you call `Runtime::run()`, control never returns.

> The runtime and each extension indicate completion by sending a Next API request. Lambda freezes the execution environment when the runtime and each extension have completed and there are no pending events.

[environment-lifecycle][]

The freeze and the implicit shutdown are the key parts of Lambda's behavior.
The execution environment may freeze the moment the function process (`Runtime`) calls `/runtime/invocation/next`, so background async tasks are not guaranteed to make progress.
And once the environment is frozen and then shut down, `Drop` and friends never run, so there is no opportunity to flush.

You could just run the telemetry export inside the handler itself, but export usually involves a network call, which delays the response by exactly that amount of time. And when Lambda is invoked back-to-back, batching exports together would be more efficient — but that is also off the table.


### Lambda Extension

To summarize the problem so far: we need a mechanism that runs in a context separate from the function process (the handler), is not frozen until it is done with its own work, and offers a hook to flush at termination.

This is exactly what extensions provide.
An extension is a binary placed under `/opt/extensions` in the Lambda execution image, which the Lambda service launches.
There is also an Extensions API: register the extension via `/extension/register`, then call `/extension/event/next` and the Lambda service returns events the same way it does for the function process.
These events come in two kinds, `Invoke` and `Shutdown`, returned at function process startup and shutdown respectively.
And as the earlier quote says:

> Lambda freezes the execution environment when the runtime and each extension have completed and there are no pending events.

The Lambda service waits for the extension to finish before freezing.
Function process and extension can also talk over localhost, so if the extension listens for OTLP on localhost, the function process can simply OTLP-export to localhost.

On shutdown, `/extension/event/next` returns a `Shutdown` event, which is the cue to flush. This means the extension can buffer telemetry from the function process for a while and export asynchronously.

Just as [lambda-runtime][] handles the Runtime API for us, the [lambda-extension][] crate handles the Extensions API.
And as you might expect, this one is also designed so that the user supplies a `tower::Service` that processes `Invoke` and `Shutdown` events.

## SDK configuration

The plan: the function process exports to the localhost extension on every invocation, the extension queues up some number of items, exports them to the remote backend, and flushes on `Shutdown`.

Now let's instrument the function process side. For each signal:

* Logs: tracing -> tracing_subscriber -> opentelemetry-appender-tracing
* Traces: tracing -> tracing_subscriber -> tracing-opentelemetry
* Metrics: opentelemetry_sdk

The overall responsibility split looks like this:

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

The function process sits on the invoke hot path, so it is limited to producing signals and shipping them to localhost.
The extension process can keep running for a while after invoke completes, so network-bound export, retries, and `Shutdown` flushing all live there.

### Logs

For logs, the official [opentelemetry-appender-tracing](https://github.com/open-telemetry/opentelemetry-rust/tree/main/opentelemetry-appender-tracing) crate provides [`OpenTelemetryTracingBridge`](https://github.com/open-telemetry/opentelemetry-rust/blob/f744509915e6e3b4fc2b551fd0c83f6a96e1fc71/opentelemetry-appender-tracing/src/layer.rs#L348), which [`impl tracing_subscriber::Layer`](https://github.com/open-telemetry/opentelemetry-rust/blob/f744509915e6e3b4fc2b551fd0c83f6a96e1fc71/opentelemetry-appender-tracing/src/layer.rs#L430), so it composes with `tracing_subscriber`.
This is in line with the design philosophy of the Logs signal.

> Our approach with logs is somewhat different. For OpenTelemetry to be successful in logging space we need to support existing legacy of logs and logging libraries, while offering improvements and better integration with the rest of observability world where possible.
>
> [OpenTelemetry Logging](https://opentelemetry.io/docs/specs/otel/logs/)

So for logs, rather than offering a dedicated logging API and asking users to call into it, the design is to plug into the existing logging ecosystem.

### Traces

Traces also rely on the tracing ecosystem, but `tracing_opentelemetry` is not an official offering — it is hosted under the tracing project.
That arguably makes the bridge approach for traces inconsistent with the official design philosophy. This has already been discussed in the issue [OpenTelemetry Tracing API vs Tokio-Tracing API for Distributed Tracing](https://github.com/open-telemetry/opentelemetry-rust/issues/1571). The crux of that discussion is whether opentelemetry-rust should recommend tracing or the OpenTelemetry Trace API for producing traces. The issue was closed on 2026-03-18 and a document is currently being written in [docs: start doc for distributed tracing and logs guidance](https://github.com/open-telemetry/opentelemetry-rust/pull/3122/changes).

There has also been a major specification change on the traces side.
[Deprecating Span Events API](https://opentelemetry.io/blog/2026/deprecating-span-events/) announced:

> OpenTelemetry is deprecating the Span Event API.

Up to now, logging inside a span produced both a span event and a log record, so the same information was generated twice.
I always found that redundancy a bit hard to deal with, but I also figured that since spans can be sampled, it was probably necessary to keep both.
Going forward, we should be able to consolidate on logs only.

### Metrics

Finally, Metrics. So far we have leaned on the tracing ecosystem, but for metrics my current take is that using the OpenTelemetry API directly is the better choice. tracing-opentelemetry does have a [`MetricsLayer`](https://github.com/tokio-rs/tracing-opentelemetry/blob/91c4faa0082a3bfe2b3e9e59ed1db295830f55ec/src/metrics.rs#L372), so you can express a counter as a tracing event:

```rust
tracing::info!(counter.foo = 1);
```

Internally, `MetricsLayer` watches for specific event fields, and if they match the metrics naming convention, [it creates the instrument the first time the event is processed](https://github.com/tokio-rs/tracing-opentelemetry/blob/91c4faa0082a3bfe2b3e9e59ed1db295830f55ec/src/metrics.rs#L57).

This is convenient for simple instruments like a counter, but in practice instrument initialization tends to be a bit more involved. For a counter you usually want to set a description and unit, and for a histogram you have to provide bucket boundaries as a `Vec<f64>`.

In other words, my issue with using tracing-opentelemetry for metrics is that instrument creation and state mutation end up in the same code path.

So for now I prefer initializing instruments at application startup and storing them in globals:

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

The end result is that I currently use a different crate for each of logs, traces, and metrics. I am hoping that, in the future, the relationship between tracing and opentelemetry will be tidied up, or a unified layer will appear.

## Instrumenting the function process

Now to the function process implementation.
As covered above, on Lambda we cannot rely on background tasks running outside the handler or on `Drop` at process shutdown to finish exports.
So instead of plugging directly into the SDK's standard batch processor / periodic reader, we set things up so we can explicitly flush at invocation boundaries.

Concretely: logs and traces use a manual processor that pushes records into an in-process queue, and metrics use a manual reader that we collect from on demand.
During the handler run we only record signals; once the handler returns a result, a `tower::Layer` flushes them to the localhost extension.
Batching exports to the remote backend, retries, and `Shutdown` flushing are all the extension process's responsibility.

### Resource

First, the `Resource` shared by logs / traces / metrics.
Information like `service.name` or `deployment.environment.name` shouldn't be added to every log record or span attribute individually; instead we set them once as resource attributes when the providers are initialized.

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

As mentioned earlier, the entry point for logs is `OpenTelemetryTracingBridge` from `opentelemetry-appender-tracing`.
However, instead of attaching a standard batch processor to `SdkLoggerProvider` and letting it export in the background, we use our own processor that pushes records into a queue.

Structure:

```text
tracing::event!
  -> tracing_subscriber
  -> OpenTelemetryTracingBridge
  -> SdkLoggerProvider
  -> ManualLogProcessor
  -> in-memory queue
```

All `ManualLogProcessor` does on the hot path is clone the `SdkLogRecord` and `InstrumentationScope` and push them into the queue.
It does not perform any OTLP HTTP requests.

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

`force_flush` and `shutdown_with_timeout` are no-ops.
Exporting synchronously here would just put network I/O back on the handler path.
Flushing happens asynchronously through a separate handle.

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

`LogState::build` wires the manual processor and the flush handle so they share the same queue.
`LogExporter` points at the localhost extension's `/v1/logs`.

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

In a real implementation you would also want a queue size limit, an overflow drop counter, a flush timeout, and so on.
But the design point is: `emit` does no network I/O, and at the end of an invocation everything is exported in bulk to the localhost extension.

One thing to note: using `tracing::warn!` to report export failures would route those messages right back into the logs queue through `OpenTelemetryTracingBridge` — a self-referential loop. So I use `eprintln!` instead and pick up the messages via CloudWatch Logs from stderr.

### Traces pipeline

Traces follow the same idea as logs.
We use `OpenTelemetryLayer` from `tracing-opentelemetry` to produce OpenTelemetry spans from `tracing::span!`, but we do not attach a `BatchSpanProcessor` to `SdkTracerProvider`.
`BatchSpanProcessor` is designed to delegate exports to a background worker, which does not work well with Lambda's freeze.

Structure:

```text
tracing::span!
  -> tracing_subscriber
  -> tracing_opentelemetry::OpenTelemetryLayer
  -> SdkTracerProvider
  -> ManualSpanProcessor
  -> in-memory queue
```

`ManualSpanProcessor` pushes `SpanData` into the queue from `on_end`, which is called when the span ends.

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

`force_flush` and `shutdown_with_timeout` are no-ops for the same reason as in logs: export is funneled into the flush handle invoked at the end of each invocation.

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

`TraceState::build` mirrors `LogState::build`: the processor and flush handle share the same queue, and `SpanExporter` points at the localhost extension's `/v1/traces`.

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

Sampler configuration also lives here. Even when using something like `ParentBased(TraceIdRatioBased)`, the sampling decision itself is left to the SDK; the processor only queues spans that have already been sampled.

### Metrics pipeline

For metrics we do not use `PeriodicReader`.
As the name suggests, `PeriodicReader` runs collect + export periodically on a background task / timer, and we cannot count on it making progress while the environment is frozen.
Instead, we register a `ManualReader` with `SdkMeterProvider` and explicitly collect at the end of each invocation.

Structure:

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

`temporality` decides what the exported metric value means.
`Cumulative` reports "the running total since the start time", while `Delta` reports "the increment since the previous collect".

For a regular long-running process, `Cumulative` is easy to work with.
The process lives long enough that the counter's start time is stable, and the backend can interpret the values as a single, ever-growing time series tied to that process.

On Lambda, however, execution environments come and go with cold starts and warm starts.
For the same Lambda function, multiple execution environments can exist in parallel, each with its own start time.
And if there are no invocations for a while, an environment is destroyed; the next cold start counter starts at 0 again.

For example, sending a `request.count` counter as `Cumulative` looks like this:

```text
env A: 1, 2, 3, 4
env B: 1, 2
env C: 1
```

Within each execution environment these are correct cumulative values, but to interpret them as the request count for the whole Lambda function, the backend needs to handle time-series identity and resets correctly.
If the backend is sensitive to start times or resource attributes, environments may be split into separate series, or delta computations across resets may not match expectations.

With `Delta`, each flush reports something close to "what was added during this invocation":

```text
env A: 1, 1, 1, 1
env B: 1, 1
env C: 1
```

Since we already flush at invocation boundaries on Lambda, `Delta` lines up with how aggregations work across the whole function.
Some details still depend on the backend or reader, but for execution environments with unstable process lifetimes — like Lambda — sending counters and histograms as `Delta` is, in my experience, easier to operate.

On the flush side, we use `ManualReader::collect` to produce `ResourceMetrics` and export them to the localhost extension.

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

`MeterState::build` makes sure the reader registered on `SdkMeterProvider` and the reader the flush side calls `collect` on are the same instance.
`MetricExporter` points at the localhost extension's `/v1/metrics`.

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

Now the handler side just calls `Counter::add` or `Histogram::record`.
Metric collect / export is contained on the reader side and stays out of the handler's business logic.

### Initializing subscriber and providers

At this point we can build a provider and a flush handle for each of logs, traces, and metrics.
Next, we initialize them once at the application entry point.

Logs and traces are wired in as `tracing_subscriber` layers.
Logs use `OpenTelemetryTracingBridge`, and traces use `tracing_opentelemetry::OpenTelemetryLayer`.
Metrics are registered as the global provider via `global::set_meter_provider`.

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

Again, the export target is the localhost extension, not the remote backend.
The function process knows nothing about the observability backend's URL or credentials — it just sends OTLP HTTP to things like `http://127.0.0.1:4318/v1/logs`.
Configuration for the remote backend is contained on the extension process side.

The `fmt::layer()` is kept because anything Lambda writes to stdout flows into CloudWatch Logs.
While verifying connectivity on the OTLP path, having both stdout and OTLP active is helpful for debugging.
Whether to keep stdout long term is an operational choice.

### Flushing at the end of each invocation

With everything set up, logs / traces / metrics accumulate inside the process while the handler runs.
But accumulating alone does not get them to the extension.
So at the end of each invocation, we explicitly call the flush handle on each pipeline.

You could write `flush().await` directly in the handler, but that mixes business logic with telemetry delivery.
Since `lambda_runtime` is `tower::Service` based, plugging flush in as a `tower::Layer` is cleaner.

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

`FlushService` waits for the handler's result and then flushes.
We want to deliver telemetry to the extension regardless of whether the handler returned `Ok` or `Err`, so the flush runs unconditionally on the result.

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

`flush_all` flushes in the order logs -> traces -> metrics.
The flush target is the localhost extension, so it is lighter than going to a remote backend directly, but it is still an HTTP request, so always set a timeout.

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

From the application code's point of view, the handler just calls `tracing::info!` or `Counter::add`.
Signal delivery is contained in the service layer, so there is no risk of forgetting flush logic in individual handlers.

Finally, in `main` we pull the flush handle out of the initialized `Providers` and stack the layer onto the handler service.

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

`providers` stays alive for the lifetime of `main`.
`FlushHandle` clones the inner `Arc`s into the layer, but the providers themselves are owned by `providers`.
Flush timing is driven by `FlushLayer`, never by `Drop` or process shutdown.

## Implementing the Lambda extension

At this point, the function process simply hands telemetry off to the localhost extension at the end of each invocation.
Now to implement the Lambda extension that receives it.

The extension process's responsibilities are:

1. Register itself via the Extensions API and receive `Invoke` / `Shutdown` events.
2. Listen on localhost as an OTLP receiver and accept telemetry pushed by the function process.
3. Buffer the received telemetry inside the extension process and export it to the remote backend in suitable chunks.
4. On `Shutdown`, flush remaining telemetry.

In the function process we explicitly avoided relying on background workers and process shutdown.
The extension process, on the other hand, owns the Extensions API event loop and can handle `Shutdown` events directly.
That is why batching to the remote backend, retries, and shutdown flushing all live there.

Implementation-wise, the OTLP receiver and the Extensions API event loop need to run concurrently.
The receiver accepts `/v1/logs`, `/v1/traces`, and `/v1/metrics` from the function process.
The event loop awaits the next `Invoke` or `Shutdown` event via `/extension/event/next`.

One subtle point: the receiver on the extension side has to be listening before the first invocation begins.
Since the function process flushes to the extension at the end of each invocation, if the receiver starts late we miss the first batch of telemetry.
So during extension initialization, register with the Extensions API first, get the receiver listening, and only then enter the event polling loop.

Conceptually:

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

In the actual implementation, the function's processing has not yet completed when the `Invoke` event arrives.
So an `Invoke` event is less "the moment to flush telemetry from this invocation" and more "an opportunity to send any telemetry that has accumulated up to now".
Telemetry from the currently running invocation is pushed to the localhost receiver by the function process after the handler returns.

For a reference implementation, see [opentelemetry-lambda-extension](https://github.com/djvcom/lambda-observability/tree/main/crates/opentelemetry-lambda-extension) in [lambda-observability](https://github.com/djvcom/lambda-observability/tree/main).
That implementation also uses [lambda-extension][] for the Extensions API.

[`ExtensionRuntime::run()`](https://github.com/djvcom/lambda-observability/blob/c92d1e7e0746adbf50a7791e0c6eea7b59f130cd/crates/opentelemetry-lambda-extension/src/runtime.rs#L66) combines starting the OTLP receiver with `Extension::run()`.
For my own use case, I wanted explicit control over flush conditions and the versions of dependent crates (notably `opentelemetry` and `tokio`), so I did not use it directly — but it was an excellent reference for thinking through the design.

## Summary

Aligning OpenTelemetry instrumentation with Lambda's lifecycle ended up meaning: do not delegate export to background tasks or `Drop`; instead, use a manual processor / reader to funnel flushes into the invocation boundary, and push delivery to the remote backend out to an extension.

That gave me a chance to learn about extensions and manual processors / readers, but the fact that each signal still ends up using a different crate is a real annoyance. Rust's opentelemetry is [steadily moving toward a stable release](https://github.com/open-telemetry/opentelemetry-rust?tab=readme-ov-file#project-status), and I am hoping that, in time, it will sit more cleanly alongside the tracing ecosystem.


## Links

* [Using the Lambda runtime API for custom runtimes][runtime-api]
* [Using the Lambda Extensions API to create extensions][extensions-api]
* [Understanding the Lambda execution environment lifecycle][environment-lifecycle]

[runtime-api]: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html
[extensions-api]: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-extensions-api.html#runtimes-extensions-api-lifecycle
[environment-lifecycle]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html
[lambda-runtime]: https://github.com/aws/aws-lambda-rust-runtime/tree/main/lambda-runtime
[lambda-extension]: https://github.com/aws/aws-lambda-rust-runtime/tree/main/lambda-extension
