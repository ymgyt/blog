---
title: "tracingからAttributesを付与してmetricsを出力できるようにtracing-opentelemetryにPRを送った"
emoji: "🔭"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["rust", "opentelemetry", "tracing"]
published: true
publication_name: "fraim"
---

現在、[FRAIM]では[OpenTelemetry]の導入を進めています。  
BackendはRustで書かれており、Applicationから出力するMetricsに関しても[OpenTelemetry]の[Metrics]を利用したいと考えています。  
既に[tracing]を導入しているので、[tracing-opentelemetry]を利用することでApplicationに[Metrics]を組み込めないか検討していました。  
その際に必要な機能があったので[PR](https://github.com/tokio-rs/tracing-opentelemetry/pull/43)を[tracing-opentelemetry]に送ったところマージしてもらえました。  
本記事ではその際に考えたことや学びについて書いていきます。 

# TL;DR

Rustのapplicationで[OpenTelemetry]の[Metrics]を[tracing]から出力するために[tracing-opentelemetry]を利用している。  
その際に[Attribute]を[Metrics]に関連づける[機能](https://www.cncf.io/blog/2023/08/03/streamlining-observability-the-journey-towards-query-language-standardization/)が必要だったので、[tracing-subscriber]の[Per-Layer Filtering]を利用して[実装](https://github.com/tokio-rs/tracing-opentelemetry/pull/43)した。


# 前提

まず前提として[tracing-opentelemetry]の[`MetricsLayer`]を利用すると、[tracing]の[`Event`]を利用して[OpenTelemetry]の[Metrics]を出力することができます。  
例えば  
```rust
let provider = MeterProvider::builder().build();
tracing_subscriber::registry().with(MetricsLayer::new(provider)).init();

tracing::info!(monotonic_counter.foo = 1);
```

とすると、`foo` [Counter]をincrementすることができます。

[tracing-opentelemetry]のversionは`0.20.0`です。 
その他の関連crateは以下の通りです。 

```toml
[dependencies]
opentelemetry = "0.20.0"
tracing = "0.1.35"
tracing-subscriber = "0.3.0"
```

# PRで実装した機能の概要

[tracing]から[Metrics]を出力する際に、[Attribute]を付与できないといった制約がありました。 
[Attribute]とは、[OpenTelemetry]におけるkey valueのペアです。  

例えば

```rust
tracing::info!(
  monotonic_counter.request_count = 1,
  http.route = "/foo",
  http.response.status_code = 200,
);
```

とした場合に、`request_count` [Counter]は出力されるのですが、`http.route="/foo"`や`http.response.sattus_code=200`といった情報をmetricsに付与できませんでした。  
この点については、[feature requestのissue](https://github.com/tokio-rs/tracing-opentelemetry/issues/32)も上がっており、[`MetricsLayer`]に[`Event`]のkey valueをmetricsに紐付ける機能がリクエストされていました。  
この機能については自分も必要だったので、やってみることにしました。

# [`MetricsLayer`]の仕組み

まず[`MetricsLayer`]の仕組みについてみていきます。  
[`tracing_subscriber::layer::Layer`](https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/trait.Layer.html) traitを実装して、tracing-subscriberとcomposeすることで、Userは[`Event`]の各種lifecycle時に任意の処理を実行することができます。  
例えば、[`on_event()`]は`tracing::info!()`等で[`Event`]が作成された際に呼ばれます。
tracing/tracing-subscriberの詳細な仕組みについては以前[ブログ](https://blog.ymgyt.io/entry/how-tracing-and-tracing-subscriber-write-events/)に書いたのでよければ読んでみてください。  
[`MetricsLayer`]はSpanを処理しないので、以下のように[`on_event()`]のみを実装しています。  

```rust
impl<S> Layer<S> for MetricsLayer
where
    S: Subscriber + for<'span> LookupSpan<'span>,
{
    fn on_event(&self, event: &tracing::Event<'_>, _ctx: Context<'_, S>) {
        let mut metric_visitor = MetricVisitor {
            instruments: &self.instruments,
            meter: &self.meter,
        };
        event.record(&mut metric_visitor);
    }
}
```
[source](https://github.com/tokio-rs/tracing-opentelemetry/blob/d9b18f2aeddbab1b26c2794503a2c6423a2426e0/src/metrics.rs#L346)  
`S: Subscriber + for<'span> LookupSpan<'span>`として`Layer<S>`でLayerに渡している`S`はLayerがtracing_subscriberの[`Registry`]にcomposeされることを表現しており、これによってEvent処理時に今いるSpanの情報を利用できます。が、今回は特に利用しないので気にしなくて大丈夫です。  
[tracing]は[`Event`]に格納された[`Field`]にアクセスする手段として[`Visit`] traitを用意してくれています。  
この仕組みにより、`tracing::info!(key = "foo")`のようにstr型のfieldを使うと、[tracing]側で、`Visit::record_str()`を呼んでくれます。

```rust
impl<'a> Visit for MetricVisitor<'a> {
    fn record_debug(&mut self, _field: &Field, _value: &dyn fmt::Debug) {
        // Do nothing
    }
    fn record_u64(&mut self, field: &Field, value: u64) {
      /* ... */
    }
    fn record_f64(&mut self, field: &Field, value: f64) {
      /* ... */
    }
    fn record_i64(&mut self, field: &Field, value: i64) {
      /* ...*/
    }
}
```
[source](https://github.com/tokio-rs/tracing-opentelemetry/blob/d9b18f2aeddbab1b26c2794503a2c6423a2426e0/src/metrics.rs#L136)

`MetricVisitor`でもこのように`Visit`が定義されています。  
[Metrics]は数値なので、`record_bool()`や`record_str()`は実装されていないこともわかります。  
さらに処理を追っていきます。例として、`record_i64()`をみてみると

```rust
const METRIC_PREFIX_MONOTONIC_COUNTER: &str = "monotonic_counter.";
const METRIC_PREFIX_COUNTER: &str = "counter.";
const METRIC_PREFIX_HISTOGRAM: &str = "histogram.";

impl<S> Layer<S> for MetricsLayer
where
    S: Subscriber + for<'span> LookupSpan<'span>,
{
    fn record_i64(&mut self, field: &Field, value: i64) {
        if let Some(metric_name) = field.name().strip_prefix(METRIC_PREFIX_MONOTONIC_COUNTER) {
            self.instruments.update_metric(
                self.meter,
                InstrumentType::CounterU64(value as u64),
                metric_name,
            );
        } else if let Some(metric_name) = field.name().strip_prefix(METRIC_PREFIX_COUNTER) {
          self.instruments.update_metric(/* ... */);
        } else if let Some(metric_name) = field.name().strip_prefix(METRIC_PREFIX_HISTOGRAM) {
          self.instruments.update_metric(/* ... */);
        }
    }
}
```
[source](https://github.com/tokio-rs/tracing-opentelemetry/blob/d9b18f2aeddbab1b26c2794503a2c6423a2426e0/src/metrics.rs#L194C4-L194C4)

となっており、field名に[`MetricsLayer`]が処理の対象とするprefix(`monotonic_counter,counter,histogram`)が利用されている場合のみ、`self.instruments.update_metric()`でmetricsの処理を実施していることがわかりました。

## [`Instruments`]の仕組み

というわけで次に[`Instruments`]について見ていきます。[`Instruments`]は以下のように定義されています。

```rust
use opentelemetry::metrics::{Counter, Histogram, Meter, MeterProvider, UpDownCounter};

type MetricsMap<T> = RwLock<HashMap<&'static str, T>>;

#[derive(Default)]
pub(crate) struct Instruments {
    u64_counter: MetricsMap<Counter<u64>>,
    f64_counter: MetricsMap<Counter<f64>>,
    i64_up_down_counter: MetricsMap<UpDownCounter<i64>>,
    f64_up_down_counter: MetricsMap<UpDownCounter<f64>>,
    u64_histogram: MetricsMap<Histogram<u64>>,
    i64_histogram: MetricsMap<Histogram<i64>>,
    f64_histogram: MetricsMap<Histogram<f64>>,
}
```
[source](https://github.com/tokio-rs/tracing-opentelemetry/blob/d9b18f2aeddbab1b26c2794503a2c6423a2426e0/src/metrics.rs#L17)

[Metrics]の種別([Instrument])ごとにmetrics名とmetricsの実装(`Counter`等)を`HashMap`で保持しています。  
`opentelemetry::metrics`から利用している、`{Counter, UpDownCounter, Histogram}`はmetricsの実装です。  
`opentelemetry_{api,sdk}` crateでmetricsがどう実装されているかについても書きたいのですがかなり複雑なので、今回はふれません。  
(以下はMetrics関連の処理を読んでいて、metricsが生成されてからexportされるまでの流れを追う際のメモです)  

![metrics pipeline](https://storage.googleapis.com/zenn-user-upload/99fd1a21adc4-20230813.png)
*Metricsの生成からexportまでの流れ*

![opentelemetry metrics overview](https://storage.googleapis.com/zenn-user-upload/2489bfdb2dcc-20230813.png)
*Metrics関連のstructの関係*

`Counter`はメモリに現在の値を保持して、incrementしつつ、定期的にexportしていくだけなのでシンプルかと考えていたのですが思ったより色々なコンポーネントが関与していました。  
なので本記事では`Counter::add()`したら、[Metrics]が出力されるくらいの理解でいきます。

```rust
use opentelemetry::metrics::Meter;
type MetricsMap<T> = RwLock<HashMap<&'static str, T>>;

impl Instruments {
    pub(crate) fn update_metric(
        &self,
        meter: &Meter,
        instrument_type: InstrumentType,
        metric_name: &'static str,
    ) {
        fn update_or_insert<T>(
            map: &MetricsMap<T>,
            name: &'static str,
            insert: impl FnOnce() -> T,
            update: impl FnOnce(&T),
        ) {
            {
                let lock = map.read().unwrap();
                if let Some(metric) = lock.get(name) {
                    update(metric);
                    return;
                }
            }

            // that metric did not already exist, so we have to acquire a write lock to
            // create it.
            let mut lock = map.write().unwrap();
            // handle the case where the entry was created while we were waiting to
            // acquire the write lock
            let metric = lock.entry(name).or_insert_with(insert);
            update(metric)
        }

        match instrument_type {
            InstrumentType::CounterU64(value) => {
                update_or_insert(
                    &self.u64_counter,
                    metric_name,
                    || meter.u64_counter(metric_name).init(),
                    |ctr| ctr.add(value, &[]),
                );
            }
            /* ...*/
        }
    }
}
```
[source](https://github.com/tokio-rs/tracing-opentelemetry/blob/d9b18f2aeddbab1b26c2794503a2c6423a2426e0/src/metrics.rs#L40)

[`MetricsLayer`]がmetricsを処理する際によばれる`self.instruments.update_metric()`は上記のような処理となっています。概ね以下のことがわかります。  

* 毎回`RwLock::read()`によるlockが発生する
* 初回は`Meter`によるInstrument(Counter等)の生成処理が実行される
* `Counter::add()`する際の第二引数には空sliceが渡されている(今回の変更点に関連する)

この処理を確認したことで、[`MetricsLayer`]のdocumentの説明がより理解できます。  
例えば

> No configuration is needed for this Layer, as it's only responsible for
  pushing data out to the `opentelemetry` family of crates.

とあるように[`MetricsLayer`]は特に実質的な処理を行っておらず[tracing-opentelemetry]というcrate名の通り、tracingとopentelemetryのecosystemをつなぐ役割のみを担っています。  
また

>  \# Implementation Details
   `MetricsLayer` holds a set of maps, with each map corresponding to a
   type of metric supported by OpenTelemetry. These maps are populated lazily.
   The first time that a metric is emitted by the instrumentation, a `Metric`
   instance will be created and added to the corresponding map. This means that
   any time a metric is emitted by the instrumentation, one map lookup has to
   be performed.
   In the future, this can be improved by associating each `Metric` instance to
   its callsite, eliminating the need for any maps.

(意訳: `MetricLayer`はOpenTelemetryでサポートされているmetricの種別ごとにmapを保持している。metricsが出力される際に`Metric`インスタンスが生成され、これらのmapに追加される。これはmetricsが出力されるたびにmapのlookupが実行されることを意味する。将来的には`Metric`インスタンスをcallsiteに紐付けることでmapが必要なくなり改善することができるかもしれない。)
という説明もなるほどと理解できます。  
ちなみにcallsiteというのは、`tracing::info!()` macro呼び出し時にstaticで生成されるmacro呼び出し時の情報を指しています。

というわけで、[`MetricsLayer`]がmetricsを出力する方法の概要が理解できました。

# 機能を追加する上での問題点

まず今回追加したい機能を整理します。  
[Counterに関する仕様](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.24.0/specification/metrics/api.md#counter-operations)では以下のように定められています。  

> Counter operations
  Add
  This API MUST accept the following parameter:
    * A numeric increment value.
    * Attributes to associate with the increment value.  
      Users can provide attributes to associate with the increment value, but it is up to their discretion. Therefore, this API MUST be structured to accept a variable number of attributes, including none.

として、Counterをincrementする際に[Attributes]を渡せなければならないとされています。  
これを受けて、RustのOpenTelemetryの実装でも

```rust
impl<T> Counter<T> {
    /// Records an increment to the counter.
    pub fn add(&self, value: T, attributes: &[KeyValue]) {
        self.0.add(value, attributes)
    }
}
```
[source](https://github.com/open-telemetry/opentelemetry-rust/blob/dfeac078ff7853e7dc814778524b93470dfa5c9c/opentelemetry-api/src/metrics/instruments/counter.rs#L28)

のようにincrement時にattributeとして、[`KeyValue`]を渡せるようになっています。  
ということで、追加したい機能は[`MetricsLayer`]で[`KeyValue`]を作って、`Counter:add()`時に渡せば良さそうです。  
そんなに難しくなさそうと思い、数行の変更でいけるのではと思っていました。

## Visitorパターンと相性が悪い

着手してわかったことですが、`Counter::add()`呼び出し時にmetrics(`counter.foo`)以外のfieldを[`KeyValue`]に変換して渡すというのはVisitorパターンと相性が悪いということでした。  
というのも、例えば以下のような[`Event`]を考えます。

```rust
tracing::info!(monotonic_counter.foo = 1, bar = "baz", qux = 2)
```
この[`Event`]を処理する際、さきほどみた`MetricVisitor`は`monotonic_counter.foo`を処理する際はまだ、`bar,qux` fieldを処理していないので、`Counter::add()`を呼び出せないということです。  
そのため、visit時に対象のfieldが処理対象なら処理するのではなく、一度、すべてのfieldのvisitを完了させたのちに、`Counter::add()`を呼び出す必要があります。
そうなると、visit時に`Vec`等にmetricsの情報や変換した[`KeyValue`]を保持する必要があります。  
しかしながら、そうしてしまうと以下のようにmetricsを含まない[`Event`]を処理する際に問題があります。

```rust
tracing::info!(
  http.route = "/foo",
  http.response.status_code = 200,
  "Handle request"  
);

```

[`Event`]としては、metricsを含まない方が多いのが自然ですが、[`MetricsLayer`]としては、visitしている途中ではその[`Event`]にmetricsが含まれているかわからないので、`Vec`の確保やpush等を行う必要があります。  
(まずvisitしたのち、metricsが含まれている場合はもう一度visitする方法も考えられますが非効率)

## [`Event`]初期化時に判定する

問題としては、あるLayerは特定の[`Event`]にのみ関心があり、その判定を[`Event`]処理時ではなく、いずれかの初期化時に一度だけ行いたいという状況です。  
これは特定の機能を提供するLayerとしては一般に必要になりそうなので、[`Layer`] traitにそういったmethodがないかみていたところ、それらしきものがありました。

```rust
fn register_callsite(&self, metadata: &'static Metadata<'static>) -> Interest
```
[docs](https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/trait.Layer.html#method.register_callsite)

> Registers a new callsite with this layer, returning whether or not the layer is interested in being notified about the callsite, similarly to Subscriber::register_callsite.

とあるので、`tracing::info!()`を呼び出すと一度だけ、`MetricsLayer::register_callsite()`を呼んでくれそうです。  
また[`Metadata::callsite() -> Identirifer`](https://docs.rs/tracing-core/0.1.30/tracing_core/metadata/struct.Metadata.html#method.callsite)から、[`Event`]の識別子も取得できるので[`Event`]がmetricsかどうか事前に一度だけ判定したいという機能は実現できそうに思われました。  
もっとも、注意が必要なのは

> Note: This method (and Layer::enabled) determine whether a span or event is globally enabled, not whether the individual layer will be notified about that span or event. This is intended to be used by layers that implement filtering for the entire stack. Layers which do not wish to be notified about certain spans or events but do not wish to globally disable them should ignore those spans or events in their on_event, on_enter, on_exit, and other notification methods.

(意訳: このメソッドはspanやeventがグローバルで有効かを判定するもので、レイヤー単位でspanやeventの通知を制御するものではない。これはスタック全体のフィルタリングを実装するレイヤーを意図したもの。特定のspanやeventを処理の対象とはしないが、グローバルで無効にしたくないレイヤーは単にon_eventでそれらを無視すればよい。)

とあるように、`register_callsite()`を利用しても、[`MetricsLayer`]でmetrics以外のeventで`on_event()`が呼ばれなくなるわけではないということです。(そのような仕組みは別であり、のちほど言及します。) 
この仕組みは[`Event`]や[`Span`]を特定のLevelでfilterする(DEBUGを無視する等) [`LevelFilter`](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.LevelFilter.html)向けであると思われます。
ということで、ある[`Event`]がmetricsを含んでおり処理対象かどうかは自前で管理する必要がありそうということがわかりました。

こうした背景から、最初のPRでは以下のように、callsiteごとの判定結果を`RwLock`で保持する[実装](https://github.com/tokio-rs/tracing-opentelemetry/pull/43/commits/c0357cb7726548f4bb822ce2b433e7c96c75e5e2)を行いました。

```rust
use tracing::callsite::Identifier;

struct Callsites {
    callsites: RwLock<HashMap<Identifier, CallsiteInfo>>,
}

#[derive(Default)]
struct CallsiteInfo {
    has_metrics_fields: bool,
}

impl Callsites {
    fn new() -> Self {
        Callsites {
            callsites: Default::default(),
        }
    }

    fn register_metrics_callsite(&self, callsite: Identifier, info: CallsiteInfo) {
        self.callsites.write().unwrap().insert(callsite, info);
    }

    fn has_metrics_field(&self, callsite: &Identifier) -> bool {
        self.callsites
            .read()
            .unwrap()
            .get(callsite)
            .map(|info| info.has_metrics_fields)
            .unwrap_or(false)
    }
}

impl<S> Layer<S> for MetricsLayer
where
    S: Subscriber + for<'span> LookupSpan<'span>,
{
     fn register_callsite(&self, metadata: &'static tracing::Metadata<'static>) -> Interest {
        if metadata.is_event() && self.has_metrics_fields(metadata.fields()) {
            self.callsites.register_metrics_callsite(
                metadata.callsite(),
                CallsiteInfo {
                    has_metrics_fields: true,
                },
            );
        }

        Interest::always()
    }

    fn on_event(&self, event: &tracing::Event<'_>, _ctx: Context<'_, S>) {
         if self
            .callsites
            .has_metrics_field(&event.metadata().callsite())
        {/* ...*/ }
    }
}
```

自分としても[`Event`]毎に`RwLocl::read()`が走る実装は厳しいだろうなと思いつつ、[レビュー](https://github.com/tokio-rs/tracing-opentelemetry/pull/43/commits/c0357cb7726548f4bb822ce2b433e7c96c75e5e2#r1284671386)をお願いしましたが、やはり別の方法を考える必要がありました。 
![PR review](https://storage.googleapis.com/zenn-user-upload/44ec2fbf187b-20230813.png)
*jtescherさんはtracing-opentelemetryのmaintainer*


# [Per-Layer Filtering]

なにか良い方法がないかと思い[`Layer`]の[doc](https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/index.html)を読んでいると、[Per-Layer Filtering]というものを見つけました。  

> Sometimes, it may be desirable for one Layer to record a particular subset of spans and events, while a different subset of spans and events are recorded by other Layers. 

(意訳: 時に、あるレイヤーで特定のspanやeventsのみを処理しつつ、他のレイヤーには影響をあたえたくない場合がある)

まさに、今この状況なのでこの機能使えるのではと思いました。  
さらにこの機能は[tracing-subscriber]の`registry` featureが必要なのですが[tracing-opentelemetry]は既にこのfeatureに依存しているので、breaking changeともならなそうでした。  
Metricsを含む[`Event`]に限定できれば、`on_event()`の処理開始時に[`Field`]にmetricsが含まれていることがわかるので、visit時にそれぞれの値を保持しておくアプローチがとれるので、この機能を組み込んでみようと思いました。

## [`Filter`]と[`Filtered`]

まず考えたのが、[`MetricsLayer`]に[`Filter`] traitを実装するということでした。  
しかしながら、docを読んだり手元で動かしてみたりしてわかったのですが、ある[`Layer`]に[`Filter`]を実装して、tracing subscriberにcomposeしても意図した効果は得られないということでした。  
というのも、tracing subscriberへのcomposeは実装的には、`Layered`という型に変換されてそれらが全体として、tracingの`Subscriber` traitを実装するという形になっているのですが、その実装の中で、[`Filter`] traitは特に参照されていません。  
[tracing-subscriber]のAPI設計的に、[`Filter`]の実装を渡して、[`Filtered`]という[`Layer`]を使う必要があることがわかりました。  
それがなぜかといいますと

```rust
thread_local! {
    pub(crate) static FILTERING: FilterState = FilterState::new();
}

impl<S, L, F> Layer<S> for Filtered<L, F, S>
where
    S: Subscriber + for<'span> registry::LookupSpan<'span> + 'static,
    F: layer::Filter<S> + 'static,
    L: Layer<S>,
{
        fn enabled(&self, metadata: &Metadata<'_>, cx: Context<'_, S>) -> bool {
            let cx = cx.with_filter(self.id());
            let enabled = self.filter.enabled(metadata, &cx);
            FILTERING.with(|filtering| filtering.set(self.id(), enabled));

            if enabled {
                // If the filter enabled this metadata, ask the wrapped layer if
                // _it_ wants it --- it might have a global filter.
                self.layer.enabled(metadata, cx)
            } else {
                // Otherwise, return `true`. The _per-layer_ filter disabled this
                // metadata, but returning `false` in `Layer::enabled` will
                // short-circuit and globally disable the span or event. This is
                // *not* what we want for per-layer filters, as other layers may
                // still want this event. Returning `true` here means we'll continue
                // asking the next layer in the stack.
                //
                // Once all per-layer filters have been evaluated, the `Registry`
                // at the root of the stack will return `false` from its `enabled`
                // method if *every* per-layer  filter disabled this metadata.
                // Otherwise, the individual per-layer filters will skip the next
                // `new_span` or `on_event` call for their layer if *they* disabled
                // the span or event, but it was not globally disabled.
                true
            }
        }

        fn on_event(&self, event: &Event<'_>, cx: Context<'_, S>) {
            self.did_enable(|| {
                self.layer.on_event(event, cx.with_filter(self.id()));
            })
        }
    }
}

impl<L, F, S> Filtered<L, F, S> {
    fn did_enable(&self, f: impl FnOnce()) {
        FILTERING.with(|filtering| filtering.did_enable(self.id(), f))
    }
}
```
[source](https://github.com/tokio-rs/tracing/blob/tracing-subscriber-0.3.17/tracing-subscriber/src/filter/layer_filters/mod.rs)

あまり実装の詳細には踏み込みませんが、概ね以下の点がわかります。
* `Filtered`は[`Layer`]を実装しているので、Layerとして振る舞う
* `enabled()`では例え、wrapしている[`Filter`]の実装がfalseを返しても戻り値としてはtrueを返す(Globalで無効にならない)
* Thread localとはいえGlobalに値を保持している(`FILTERING`)
* `on_event()`実装時にGlobalの`FILTERING`を参照してPer Filter機能を実現

と中々hack的な実装となっており、自前で[`Filter`]を実装するだけではだめで、あくまで[`Filtered`]を使わないといけないということがわかりました。  

ということで、[`MetricsLayer`]から[`Filtered`]を利用することが次の目標です。  
[`Filtered`]の生成については[tracing-subscriber]が[`with_filter()`](https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/trait.Layer.html#method.with_filter)を用意してくれているのですが、問題は返り値が[`Filtered`]ということです。  
どういうことかといいますと、今やりたいことは、`Filtered<MetricsLayer,F,S>`という型を[tracing-opentelemetry]のuserに返したいということなのですが  
[tracing-opentelemetry]としては`MetricsLayer::new()`がpublicなAPIなのでここを変えてしまうと破壊的変更となってしまうことです。  

```rust
pub type MetricLayer<S> = Filtered<MetricLayerInner,Filter,S>`
```

上記のようにaliasを使うかも考えたのですが、これにも問題があります。たとえば将来的に、[`MetricsLayer`]に追加の設定が必要となり  

```rust
let layer = MetricsLayer::new(meter_provider).with_foo();
```
のように`with_`で設定できるAPIが必要になった場合、`Filtered`は外部の型なので、methodは追加できないということです。  

ここで思ったのが、実体としては[tracing-subscriber]の[`Filtered`]なのだけど、型としてはuserにそれをみせたくないという状況どこかでみたことあるということでした。  
そうです、[tracing-subscriber]の[`Subscriber`](https://docs.rs/tracing-subscriber/0.3.17/src/tracing_subscriber/fmt/mod.rs.html#225-232)です。

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
[source](https://docs.rs/tracing-subscriber/0.3.17/src/tracing_subscriber/fmt/mod.rs.html#225-232)

Genericsは無視して、着目したいのが、実体としては、`Layered`なのですが、それをinnerとしてwrapした型をuserにみせているということです。  
この時初めて、[tracing-subscriber]がどうしてこうのように実装しているかの気持ちがわかりました(勝手に)。  

ということで、[`MetricsLayer`]に[`Filtered`]を組み込んだ結果以下のような実装となりました。

```rust
pub struct MetricsLayer<S> {
    inner: Filtered<InstrumentLayer, MetricsFilter, S>,
}
```
[source](https://github.com/tokio-rs/tracing-opentelemetry/blob/e9148988fc053c617cc50f957599e5dc943c3811/src/metrics.rs#L335C1-L337C2)

形としては同じです。今までの[`MetricsLayer`]の責務は`InstrumentLayer`が担い、[`Filter`]は`MetricsFilter`に実装する形にしました。  
デメリットとして、すべてinnerに移譲する形で、[`Layer`]を実装する必要がありますが、Subscriberもそうしていたので受け入れることにしました。

これで、破壊的変更を行うことなく、[Per-Layer Filtering]の機能を取り込むことができました。

# Allocationも避けたい

ここまでで、機能的には目標を達成できたのですが、1点不満がありました。  
それは以下のように、[`Event`] visit前に、`Vec`のallocationが発生してしまう点です。

```rust
impl<S> Layer<S> for InstrumentLayer
where
    S: Subscriber + for<'span> LookupSpan<'span>,
{
    fn on_event(&self, event: &tracing::Event<'_>, _ctx: Context<'_, S>) {
        let mut attributes = Vec::new();        // 👈 ココ
        let mut visited_metrics = Vec::new();   // 👈
        let mut metric_visitor = MetricVisitor {
            attributes: &mut attributes,
            visited_metrics: &mut visited_metrics,
        };
        event.record(&mut metric_visitor);

        // associate attrivutes with visited metrics
        visited_metrics
            .into_iter()
            .for_each(|(metric_name, value)| {
                self.instruments.update_metric(
                    &self.meter,
                    value,
                    metric_name,
                    attributes.as_slice(),
                );
            })
    }
}
```
[source](https://github.com/tokio-rs/tracing-opentelemetry/blob/e9148988fc053c617cc50f957599e5dc943c3811/src/metrics.rs#L399C1-L424C2)

`Vec`が必要なのは、`tracing::info!()`の中にmetricsと他のfieldがいくつあるかわからないからです。例えば、以下のような入力は可能です。  

```rust
tracing::info!(
    counter.foo = 1,
    counter.bar = 2,
    abc = "abc",
    xyz = 123,
);
```

一応、[tracing]側で、最大field数の制限(32)があるのですが、その分のArrayを確保するのもresourceの効率的な利用の観点から後退してしまうように思われました。また最大field数が増える可能性もあります。  
ここでの問題は、多くの場合、高々数個だが、例外に対応できるように個数制限は設けられないという状態です。  
こういうケースにはまるものないかなと調べていてみつけたのが[smallvec] crateです。  
[smallvec]の説明には

> Small vectors in various sizes. These store a certain number of elements inline, and fall back to the heap for larger allocations. This can be a useful optimization for improving cache locality and reducing allocator traffic for workloads that fit within the inline buffer.

とあるので、自分の理解が正しければ、指定の数まではstack上に確保され、それを超えた場合のみ、通常の`Vec`のようにheapのallocationが発生するというものです。  

ということで、`SmallVec`をvisit時に利用することにしました。

```rust
pub(crate) struct MetricVisitor<'a> {
    attributes: &'a mut SmallVec<[KeyValue; 8]>,
    visited_metrics: &'a mut SmallVec<[(&'static str, InstrumentType); 2]>,
}
```

```rust
 fn on_event(&self, event: &tracing::Event<'_>, _ctx: Context<'_, S>) {
        let mut attributes = SmallVec::new();
        let mut visited_metrics = SmallVec::new();
        let mut metric_visitor = MetricVisitor {
            attributes: &mut attributes,
            visited_metrics: &mut visited_metrics,
        };
        event.record(&mut metric_visitor);
        /* ...*/
}        
```

このあとテストを追加し、無事レビューが通りました。


# Benchmark

trace用のlayerのbenchmarkはあったのですが[`MetricsLayer`]のbenchmarkはなかったので、追加しました。  
![Metricslayer Benchmark](https://storage.googleapis.com/zenn-user-upload/aebd6e928416-20230814.png)  
本来は旧実装と比較したかったのですが、benchmarkするには、なんらかの形で旧実装を公開する必要があったので断念しました。  
こういうときどうすればいいんですかね?

# Flamegraph

criterionのbenchmarkにpprofを設定できるのは知りませんでした。利用してみたところ以下のような結果を得られました。
![Metricslayer Flame Graph](https://storage.googleapis.com/zenn-user-upload/dbb8b2dc8703-20230814.png)
Metrics更新時のlock処理に時間を使っていることがわかります。


# まとめ

[tracing-opentelemetry]にPRを出してみた際考えたことを書いてみました。  
[Per-Layer Filtering]の仕組みを知れたことや、[OpenTelemetry]のmetrics関連の実装についての学びがありました。  
今後も[OpenTelemetry]や[tracing] ecosystemへの理解を深められればと思っております。


[tracing]: https://github.com/tokio-rs/tracing
[tracing-opentelemetry]: https://github.com/tokio-rs/tracing-opentelemetry
[tracing-subscriber]: https://github.com/tokio-rs/tracing/tree/tracing-subscriber-0.3.17/tracing-subscriber
[`MetricsLayer`]: https://docs.rs/tracing-opentelemetry/0.20.0/tracing_opentelemetry/struct.MetricsLayer.html
[OpenTelemetry]: https://opentelemetry.io/
[Metrics]: https://github.com/open-telemetry/opentelemetry-specification/tree/v1.24.0/specification/metrics
[Counter]: https://github.com/open-telemetry/opentelemetry-specification/blob/v1.24.0/specification/metrics/api.md#counter
[Attribute]: https://github.com/open-telemetry/opentelemetry-specification/tree/v1.24.0/specification/common#attribute
[Attributes]: https://github.com/open-telemetry/opentelemetry-specification/tree/v1.24.0/specification/common#attribute
[FRAIM]: https://fraim.co.jp/
[`on_event()`]: https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/trait.Layer.html#method.on_event
[`Registry`]: https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/registry/struct.Registry.html
[`Event`]: https://docs.rs/tracing/0.1.37/tracing/struct.Event.html
[`Span`]: https://docs.rs/tracing/0.1.37/tracing/struct.Span.html
[`Field`]: https://docs.rs/tracing/0.1.37/tracing/field/struct.Field.html
[`Visit`]: https://docs.rs/tracing/0.1.37/tracing/field/trait.Visit.html
[`Instruments`]: https://github.com/tokio-rs/tracing-opentelemetry/blob/d9b18f2aeddbab1b26c2794503a2c6423a2426e0/src/metrics.rs#L17
[Instrument]: https://github.com/open-telemetry/opentelemetry-specification/blob/v1.24.0/specification/metrics/api.md#instrument
[`KeyValue`]: https://docs.rs/opentelemetry/latest/opentelemetry/struct.KeyValue.html
[`Layer`]: https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/trait.Layer.html 
[Per-Layer Filtering]: https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/index.html#per-layer-filtering
[`Filter`]: https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/layer/trait.Filter.html
[`Filtered`]: https://docs.rs/tracing-subscriber/0.3.17/tracing_subscriber/filter/struct.Filtered.html
[smallvec]: https://docs.rs/smallvec/latest/smallvec/