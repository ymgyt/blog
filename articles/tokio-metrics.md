---
title: "tokio-metricsでruntimeとtaskのmetricsを取得する"
emoji: "🔭"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["rust"]
published: false
publication_name: "fraim"
---

本記事では、[tokio-metrics]を利用してtokioのruntimeとtaskのmetricsを取得する方法について書きます。  
Versionは[0.3.1](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/index.html)です。

```toml
[dependencies]
tokio-metrics      = { version = "0.3.1", default-features = false, features = ["rt"] }
```

# Task Metrics

```rust
async fn my_task() {
    // ...
}

#[tokio::main]
async fn main() {
    tokio::spawn(my_task()).await.ok();
}
```

上記の処理で、`my_task()`が遅いとわかった場合、以下の理由が考えられます。  

1. CPU bound
2. I/Oの完了を待っている
3. Runtimeのqueueにいる時間が長い

特に3が厄介で、`my_task`が問題ではなく、問題は他のtaskにあるケースなのでこれらのmetricsを取得できると調査の際に有用だと思いました。  
tokio_metricsの[`TaskMonitor`]を利用すると各種metricsから上記1,2,3の影響の程度を計測することができます。

## Taskの計装方法

計測したいtaskのmetricsを取得する方法は簡単で

```rust
use std::time::Duration;
use tokio_metrics::TaskMonitor;

async fn my_task() {
    // ...
}

async fn run(monitor: TaskMonitor) {
    monitor.instrument(my_task()).await;
}

#[tokio::main]
async fn main() {
    let monitor = TaskMonitor::new();

    {
        let monitor = monitor.clone();
        tokio::spawn(async move {
            for interval in monitor.intervals() {
                // handle metrics
                println!("{:?}", interval);

                tokio::time::sleep(Duration::from_secs(10)).await;
            }
        });
    }

    run(monitor).await;
}
```

[`TaskMonitor`]を生成したのち、計測したいtaskを`TaskMonitor::instrument()`に渡します。

```rust
#[derive(Clone, Debug)]
pub struct TaskMonitor {
    metrics: Arc<RawMetrics>,
}
```

[`TaskMonitor`]はArcで内部のデータ構造をwrapしているので`clone()`できます。  
instrumentしたtaskのmetricsを取得するには`TaskMonitor::intervals()`でmetricsを返すiteratorを取得して、loop内でmetricsを処理します。


## Task metricsのtemporality

[`TaskMonitor`]はtaskのmetricsをcumulative(起動時からの合計)な値とdelta(前回の計測からの差分)の二つの方法で提供してくれます。  

Cumulativeな値を利用する場合は[`TaskMonitor::cumulative()`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMonitor.html#method.cumulative)を利用します。  

Delataを利用する場合は上記の例のように[`TaskMonitor::intervals()`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMonitor.html#method.intervals)を利用します。  

どちらを利用しても取得できるmetricsは[`TaskMetrics`]です。(`intervals()`はそのiterator)

内部の実装はsimpleで

```rust
pub fn cumulative(&self) -> TaskMetrics {
    self.metrics.metrics()
}

pub fn intervals(&self) -> impl Iterator<Item = TaskMetrics> {
    let latest = self.metrics.clone();
    let mut previous: Option<TaskMetrics> = None;

    std::iter::from_fn(move || {
        let latest: TaskMetrics = latest.metrics();
        let next = if let Some(previous) = previous {
            TaskMetrics {
                instrumented_count: latest
                    .instrumented_count
                    .wrapping_sub(previous.instrumented_count),
                dropped_count: latest.dropped_count.wrapping_sub(previous.dropped_count),
                // Construct metrics...
            }
        } else {
            latest
        };

        previous = Some(latest);

        Some(next)
    })
}
```

`cumulative()`は実はなにもしておらず保持している値をそのまま返していて、`intervals()`は前回の値をiterator側で保持していて、最新(cumulative)の値から前回の値を引いて返してくれています。


## `TaskMetrics`のmetrics

taskへの計装方法とmetricsの取得方法がわかったので次に具体的に取得できるmetricsについて見ていきます。  
全てのmetricsや詳細についてはdocumentを確認してください。ここでは実際に自分が利用したmetricsについて述べます。

まずtaskのlifecycleの概要としては自分は以下のように理解しています。  
task(future)が生成されると、runtimeから`poll`される。その中で`.await`した際にI/Oが発生すると、taskはidle(I/O待ち)になる。この際、OSのthreadはyieldされず、[mio](https://github.com/tokio-rs/mio)等のI/O driverに登録され、runtimeは別のtaskを実行する。I/Oが完了すると、`Waker`によってtaskはruntimeのqueueに入り、再び`poll`されるまで待機する。(このあたりは[Asynchronous Programming in Rust](https://blog.ymgyt.io/entry/asynchronous-programming-in-rust/)がわかりやすいのでオススメです。)

ということで最初の出発点として、taskの`poll`に掛かっている時間、I/Oを待機している時間、queueで再scheduleを待っている時間を計測できるようにしようと思いました。

### `poll`のmetrics

pollのmetricsとして以下を利用しました

* [`mean_poll_duration`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMetrics.html#method.mean_poll_duration)
* [`mean_slow_poll_duration`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMetrics.html#method.mean_slow_poll_duration)

pollの平均期間と"slow"なpollの平均時間です。  
これらのmetricsが増加した場合、CPU boundな処理か、誤ってblockingな処理(stdのI/O等)を実行してしまっているか疑います。pollが"slow"と判定される閾値は[`DEFAULT_SLOW_POLL_THRESHOLD`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMonitor.html#associatedconstant.DEFAULT_SLOW_POLL_THRESHOLD)で50μsとなっていました。  
また、slow pollの比率を[`slow_poll_ratio`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMetrics.html#method.slow_poll_ratio)から取得できます。

### I/Oのmetrics

I/O(外部event)の完了を待機している時間については

* [`mean_idle_duration`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMetrics.html#method.mean_idle_duration)

を利用しました。このmetricsは`poll`が完了してから(`Poll::Pending`を返してから)、awokernされるまでの期間という認識です。この値が増加した場合はそのtask内で実行しているI/Oをさらに調査します。


### Queueのmetrics

Runtimeのqueueに入ってから再実行までの期間のmetricsについては

* [`mean_first_poll_delay`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMetrics.html#method.mean_first_poll_delay)
* [`mean_scheduled_duraion`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMetrics.html#method.mean_scheduled_duration)

を利用しました。それぞれ、最初にpollされるまでの時間、queueに入ってから再度`poll`されるまでの時間を表しています。  
これ以外にもslow poll同様に`long_delay_ratio`と`mean_long_delay_duration`も用意されています。

このmetricsを取得することで、`poll`も速くて、I/Oでもなく、他のtaskが詰まっていると判断できるようになると思っています。

Taskのmetricsの概要は以上です。

# Runtime Metrics

tokio-metricsでは個々のtaskだけでなく、tokio runtime自体のmetricsも取得できます。  
**runtimeのmetricsを取得するには、`tokio_unstable`と`rt` featureを有効にする必要があります。**
tokio-metircsの`rt` featureを有効にし、projectの`.cargo/config.toml`に以下を追加しました。

```toml
[build]
rustflags = ["--cfg", "tokio_unstable"]
```

## Runtimeの計装方法

```rust
use tokio_metrics::RuntimeMonitor;

#[tokio::main]
async fn main() {
      let handle = tokio::runtime::Handle::current();
      let runtime_monitor = RuntimeMonitor::new(&handle);

      tokio::spawn(async move {
          for interval in runtime_monitor.intervals() {
              // handle metrics
              println!("{:?}", interval);

              tokio::time::sleep(Duration::from_secs(10)).await;
          }
      });
}
```

[`RuntimeMonitor`]は特定のtaskに紐づける必要はなく、`tokio::runtime::Handle::current()`の値を渡すだけで良いようです。内部的に各workerのmetricsを合計してくれているので、どのworker threadで実行するかは気にしなくて良いと思っています。

## `RuntimeMetrics`のmetrics

Runtimeに関してはどの様なケースで、どのmetricsが役に立つか手探りの状態です。  
自分は以下のmetricsの取得から始めました。

* [`total_polls_count`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.RuntimeMetrics.html#structfield.total_polls_count)
* [`total_busy_duration`](https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.RuntimeMetrics.html#structfield.total_busy_duration)

Runtimeの内部構造についてもっと知れたらこのmetricsが欲しいとなると思うので調べていきたいです。

# 実際の利用例

ここまではsample codeで概要の話でしたので、次に実際の利用例について見ていきます。  
今回は趣味で作っている[TUIのfeed viewer][syndicationd]のgraphql backendにtokio-metricsを組み込んだ例を見ていきます。 
利用しているlibraryは`axum`と`async-graphql`です。  

最初の出発点として、graphql taskのmetricsを取得することにしました。  
特定のresolverにしようかと迷ったのですが、どちらにせよgraphql全体のmetricsがあったほうが、特定のresolverに計装した際に比較できて便利だと、考えまずはgraphqlの取得から始めました。

```rust
pub async fn serve(
    listener: TcpListener,
    dep: Dependency,
    shutdown: Shutdown,
) -> anyhow::Result<()> {
    let Dependency {
        // ...
        monitors,
    } = dep;

    let cx = Context {
        gql_monitor: monitors.gql.clone(),
        schema: gql::schema_builder().finish(),
    };

    tokio::spawn(monitors.monitor(config::metrics::MONITOR_INTERVAL));

    let service = Router::new()
        .route("/graphql", post(gql::handler::graphql))
        .layer(Extension(cx))

    // serve ...
```
[source](https://github.com/ymgyt/syndicationd/blob/e5177160ace15c54a17c8bad070a1767a4fb76b8/crates/synd_api/src/serve/mod.rs#L61C1-L88C30)

```rust
pub async fn graphql(
      Extension(Context {
          schema,
          gql_monitor,
      }): Extension<Context>,
      req: GraphQLRequest,
  ) -> GraphQLResponse {
      TaskMonitor::instrument(&gql_monitor, schema.execute(req).instrument(foo_span!()))
          .await
          .into()
  }
```
[source](https://github.com/ymgyt/syndicationd/blob/e5177160ace15c54a17c8bad070a1767a4fb76b8/crates/synd_api/src/gql/mod.rs#L29C5-L42C6)

概要としては、axumの仕組みでrequestの度に実行されるgraphqlの処理(handler)に[`TaskMonitor`]を渡しています。  
(`TaskMonitor::instrument`と`tracing::Instrument`が衝突してしまったので、わかりづらい形となってしまっています。)

Metricsの生成については`tokio::spawn(monitors.monitor(config::metrics::MONITOR_INTERVAL))`で行なっています。  
Metricsに関しては上記で述べたmetricsを取得しているだけです。

```rust
impl Monitors {
    pub fn new() -> Self {
        Self {
            gql: TaskMonitor::new(),
        }
    }

    pub async fn monitor(self, interval: Duration) {
        let handle = tokio::runtime::Handle::current();
        let runtime_monitor = RuntimeMonitor::new(&handle);
        let intervals = runtime_monitor.intervals().zip(self.gql.intervals());

        for (runtime_metrics, gql_metrics) in intervals {
            // Runtime metrics
            metric!(monotonic_counter.runtime.poll = runtime_metrics.total_polls_count);
            metric!(
                monotonic_counter.runtime.busy_duration =
                    runtime_metrics.total_busy_duration.as_secs_f64()
            );

            // Tasks poll metrics
            metric!(
                monotonic_counter.task.graphql.mean_poll_duration =
                    gql_metrics.mean_poll_duration().as_secs_f64()
            );
            metric!(
                monotonic_counter.task.graphql.mean_slow_poll_duration =
                    gql_metrics.mean_slow_poll_duration().as_secs_f64()
            );

            // Tasks schedule metrics
            metric!(
                monotonic_counter.task.graphql.mean_first_poll_delay =
                    gql_metrics.mean_first_poll_delay().as_secs_f64(),
            );
            metric!(
                monotonic_counter.task.graphql.mean_scheduled_duration =
                    gql_metrics.mean_scheduled_duration().as_secs_f64(),
            );

            // Tasks idle metrics
            metric!(
                monotonic_counter.task.graphql.mean_idle_duration =
                    gql_metrics.mean_idle_duration().as_secs_f64(),
            );

            tokio::time::sleep(interval).await;
        }
    }
}
```
[source](https://github.com/ymgyt/syndicationd/blob/e5177160ace15c54a17c8bad070a1767a4fb76b8/crates/synd_api/src/monitor.rs#L17)

> `let intervals = runtime_monitor.intervals().zip(self.gql.intervals());`

runtimeとtaskそれぞれ、`intervals()`でiteratorを返すので、zipして、一つのiteratorにしました。

Metricsの出力はtracing -> tracing_opentelemetry::MetricsLayer -> opentelemetry-collectorとしています。

ここで実際にserverにrequestを行いました。feedを取得するtoolなので登録しているfeedの数だけ、http requestが実行される処理です。

実際に試してみると以下のようなmetricsを取得できました。  
青がidle、黄色がslow poll, 緑がpoll, 赤がscheduleを表しています。

Task metrics

![Task metrics](/images/tokio-metrics/task-metrics-ss.png)

idleのmetricsが上昇しており、I/Oを待機していることがわかります。　

処理のtraceは以下のようになっています。

![Trace](/images/tokio-metrics/trace-ss.png)

`fetch_feed` spanが1 Feedの取得処理を表しており、http requestの待機をmetricsで表現できていそうです。


Runtime poll

![Runtime poll](/images/tokio-metrics/runtime-metrics-ss-1.png)

Runtime busy

![Runtime poll](/images/tokio-metrics/runtime-metrics-ss-2.png)

Runtimeのmetricsも増加を確認できました。

requestされたfeedはserver側で一定時間cacheしています。連続してさきほど行なったfeed取得をrequestした場合、cacheにhitするので、http requestは行われません。

![Task metrics](/images/tokio-metrics/task-metrics-ss-2.png)

Metricsをみてみると今度は、idleが低くなっていることがわかります。

![Trace](/images/tokio-metrics/trace-ss-2.png)

Traceを確認するとfeedはcacheから取得しているので、確かにI/Oは行われていなさそうです。

## まとめ

tokio-metricsを利用して、taskとruntimeのmetricsの取得を始めることができました。  
まだまだ生かしきれていないmetricsがあるので、運用しながらいろいろなmetricsを試していきたいと思っています。  
ここまでお読みいただきありがとうございました。


[tokio-metrics]: https://github.com/tokio-rs/tokio-metrics
[`TaskMonitor`]: https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMonitor.html#
[`TaskMetrics`]: https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.TaskMetrics.html
[`RuntimeMonitor`]: https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.RuntimeMonitor.html
[`RuntimeMetrics`]: https://docs.rs/tokio-metrics/0.3.1/tokio_metrics/struct.RuntimeMetrics.html
[syndicationd]: https://github.com/ymgyt/syndicationd
