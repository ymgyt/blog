+++
title = "🐇 RabbitMQ TutorialsをRustでやってみる"
slug = "rabbitmq_tutorials_with_rust"
date = "2022-08-12"
draft = false
[taxonomies]
tags = ["rust"]
+++

本記事では[RabbitMQ Tutorials](https://www.rabbitmq.com/getstarted.html)をRustでやっていきます。
RabbitMQは[AMQP 0-9-1](https://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf)というプロトコルの実装という位置づけなので、登場するコンセプトについてはAMQPに基づいて理解していきます。(以降AMQPはAMQP 0-9-1を前提にします)
Tutorialsは以下の7つから構成されているので順番にみていきます。

1. ["Hello World!"](https://www.rabbitmq.com/tutorials/tutorial-one-python.html)
2. [Work queues](https://www.rabbitmq.com/tutorials/tutorial-two-python.html)
3. [Publish/Subscribe](https://www.rabbitmq.com/tutorials/tutorial-three-python.html)
4. [Routing](https://www.rabbitmq.com/tutorials/tutorial-four-python.html)
5. [Topics](https://www.rabbitmq.com/tutorials/tutorial-five-python.html)
6. [RPC](https://www.rabbitmq.com/tutorials/tutorial-six-python.html)
7. [Publisher Confirms](https://www.rabbitmq.com/tutorials/tutorial-seven-java.html)


## 準備

Tutorialに入る前にRabbitMQをlocalに立ち上げて接続できるようにしていきます。

### docker-compose.yaml

```yaml
version: '3'

services:
  rabbitmq:
    image: rabbitmq:3.9.13-management-alpine
    ports:
    - "5672:5672"
    - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
```

`docker compose up [-d]`で起動できたらOKです。  
`5672`はApplicationが接続しにいくportです。AMQP 4.1に`5672`を利用すると定義されています。  
`15672`はRabbitMQのWebUIです。`localhost:15672`にブラウザでアクセスすると確認できます。  
`environment.RABBITMQ_DEFAULT_{USER,PASS}`はこのあとの接続時に利用します。

### `Cargo.toml`

利用するcrateは以下の通りです。

```toml
[dependencies]
anyhow = "1"
deadpool = "=0.8.0"
deadpool-lapin = "=0.8.0"
futures = "0.3.21"
tokio = { version = "1.17.0", features = ["full"] }
tracing = "0.1.35"

[dev-dependencies]
tracing-init = "0.1.0"
async-trait = "0.1.56"
```

async runtimeはtokioを利用します。  
RabbitMQのclientとしてはlapinをdeadpoolようにwrapしたdeadpool-lapinを利用します。  
deadpoolに関しては[以前の記事](https://blog.ymgyt.io/entry/deadpool)で使い方を調べたのでよかったら読んでみてください。

### 接続処理

ClientからRabbitMQ Serverへの接続処理について。Publisher/Consumerで共通です。

`lib.rs`

```rust
use deadpool::managed::{PoolConfig, Timeouts};
use deadpool_lapin::{lapin::Channel, Config};

pub fn config() -> Config {
    let config = Config {
        // vhostはuri encodeされるので%2f => "/"
        url: Some(String::from("amqp://guest:guest@localhost:5672/%2f")),
        pool: Some(PoolConfig {
            max_size: 100,
            runtime: deadpool::Runtime::Tokio1,
            timeouts: Timeouts::default(),
        }),
        ..Default::default()
    };

    config
}

pub async fn channel() -> anyhow::Result<Channel> {
    let pool = config().create_pool();
    let connection = pool.get().await?;
    let channel: Channel = connection.create_channel().await?;

    Ok(channel)
}
```

まずRabbitMQへのConnection Poolを作るために`deapool_lapin::Config`を作ります。
RabbitMQへの接続情報とConnection Poolに関する設定を渡すことができるので順番にみていきます。  
まず、 `url: Some(String::from("amqp://guest:guest@localhost:5672/%2f"))`のように接続先のServerの情報を渡します。  
formatは[RabbitMQ URI Specification](https://www.rabbitmq.com/uri-spec.html)に以下のように定義されています。

```sh
amqp_URI       = "amqp://" amqp_authority [ "/" vhost ] [ "?" query ]

amqp_authority = [ amqp_userinfo "@" ] host [ ":" port ]

amqp_userinfo  = username [ ":" password ]

username       = *( unreserved / pct-encoded / sub-delims )

password       = *( unreserved / pct-encoded / sub-delims )

vhost          = segment
```

ざっくり理解すると`amqp://<user>:<pass>@<host>:<port>/<vhost>`のようなformatです。  
user,passはdocker-compose.yamlで定義した`environment.RABBITMQ_DEFAULT_{USER,PASS}`でhost,portは接続先のnodeとTCP portだとわかるのですが、`vhost`が聞き慣れません。

#### `vhost`

`vhost`はkubernetesでいうところのnamespaceにあたる概念だと理解しています。

AMQP 0-9-1 3.1.2 Virtual Hostsには

> A virtual host comprises its own name space, a set of exchanges, message queues, and all associated
objects. Each connection MUST BE associated with a single virtual host.

とあります。  
上の例では`localhost:5672/%2f`と`%2f`を指定しているのですがここにはURL encodeされた値を渡すことになっており、`%2f`は`/`を表しています。RabbitMQの[Default Virtual Host and User](https://www.rabbitmq.com/access-control.html#default-state)では`/`がserverの起動時に作られるとあります。


#### Pool Config

```rust
pool: Some(PoolConfig {
    max_size: 100,
    runtime: deadpool::Runtime::Tokio1,
    timeouts: Timeouts::default(),
}),
```

lapinのConnectionPoolに関する設定については、最大で保持するConnection数、runtime(tokio or async-std),各種operationのtimeoutを指定します。`Timeouts::default()`だとtimeoutを指定しないことになるので、production時は必ず指定するようにします。

#### Channel

RabbitMQ Serverへの各種operationを実行するには、`Channel`を取得する必要があります。

```rust
pub async fn channel() -> anyhow::Result<Channel> {
    let pool = config().create_pool();
    let connection = pool.get().await?;
    let channel: Channel = connection.create_channel().await?;

    Ok(channel)
}
```

のように、ConnectionPoolConfig -> ConnectionPool -> Connection取得 -> Channel作成と進みます。　
ChannelはTCP Connectionを共有する仮想的なConnectionです。実態としてはAMQP protocolで規定されているData FrameにchannelIDを指定する箇所があり、あたかも複数の接続が同時に機能しているかのように振る舞います。

Channelが無事取得できれば準備完了です。以降の各tutorialではこのchannel取得から始めます。

## `"Hello World!"`

{{ figure(caption="Hello World!", images=["images/rabbitmq_hello_world.png"] )}}

まずはHello Worldから。Producerから1 messageをpublishしてconsumerがconsumeします。

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let channel = channel().await?;

    let _queue = channel
        .queue_declare(
            "hello",
            QueueDeclareOptions::default(),
            FieldTable::default(),
        )
        .await?;
    // ...
}
```

まず、publisherから。channelを作成後に最初に行うのは、`queue_declare`です。  
`queue_declare`は指定されたqueueが無ければ作成、存在してかつ指定された設定と一致していれば、なにもしないという挙動になります。  
ここでは、`hello`というqueueが作成されます。

次にconsumer。

```rust
async fn consumer(channel: Channel) -> anyhow::Result<()> {

    let mut consumer = channel
        .basic_consume(
            "hello",
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await?;

    if let Some(delivery) = consumer.next().await {
        if let Ok((_channel, delivery)) = delivery {
            let data = String::from_utf8_lossy(delivery.data.as_slice());

            tracing::info!("{data}");

            delivery
                .ack(BasicAckOptions::default())
                .await
                .expect("basic_ack");
        }
    }

    Ok(())
}
```

Queueからmessageを取得するには、`basic_consume`を利用します。対象のqueueは先ほど宣言した`hello`を指定します。  
`delivery.ack(BasicAckOptions::default())`を実行するとconsumerからRabbitMQ serverにmessageの処理が成功したことが伝わりqueueからmessageが削除されます。  
この処理をいれなくても動くのですが起動するたびにmessageが増えていってしまいます。

consumerを起動したらmessageのpublishを行います。

```rust
    let _publish_confirm = channel
        .basic_publish(
            "",
            "hello",
            BasicPublishOptions::default(),
            Vec::from("Hello World!"),
            BasicProperties::default(),
        )
        .await?;
```

messageのpublishは`basic_publish`で行います。  
第一引数には対象のexchange,第二引数にはrouting_keyを指定します。  
ここでexchangeがでてきたので、exchangeについて解説します。

AMQP 3.1.3には

> An exchange is a message routing agent within a virtual host. An exchange instance (which we commonly
call "an exchange") accepts messages and routing information - principally a routing key - and either
passes the messages to message queues, or to internal services.

とあります。RabbitMQではpublisherはmessageをpublishする際にqueueではなくこのexchangeを対象にmessageをpublishします。  
exchangeを対象にするといっておきながら上の例では第一引数で指定しているexchangeに空文字(`""`)を指定しています。
ここが少々暗黙的なところなのですが、exchangeに空文字を指定するとそれはdefault exchangeを指すことになっております。
さらにこのdefault exchangeはdirect exchangeという種類のexchangeで、publish時のrouting_keyを参照してそれと同名のqueueにmessageをroutingします。
なので結果的にはpublisherがexchangeを指定せずに、routing_keyにqueueを指定すると対象のqueueにmessageをpublishできるわけです。  
exchangeというlayerを用意して、publisherとqueueを直接結合させないようにしつつも、透過的にqueueにpublishできるようにもなっています。

この挙動はAMQP 3.1.3.1で以下のように指定されているものです。

> The direct exchange type works as follows:
1. A message queue binds to the exchange using a routing key, K.
2. A publisher sends the exchange a message with the routing key R.
3. The message is passed to the message queue if K = R.
The server MUST implement the direct exchange type and MUST pre-declare within each virtual host at
least two direct exchanges: one named amq.direct, and one with no public name that serves as the default
exchange for Publish methods

まとめると以下のようになります。  
`examples/tutorial_helo_worlds.rs`

```rust
use deadpool_lapin::lapin::{
    BasicProperties,
    Channel,
    options::{
        BasicAckOptions, BasicConsumeOptions, BasicPublishOptions,
        QueueDeclareOptions,
    }, types::FieldTable,
};
use futures::StreamExt;

use rabbitmq_handson::channel;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_init::init();

    let channel = channel().await?;

    let _queue = channel
        .queue_declare(
            "hello",
            QueueDeclareOptions::default(),
            FieldTable::default(),
        )
        .await?;

    // Spawn consumer task.
    let consumer_handle = tokio::spawn({
        let channel = channel.clone();
        async move {
            if let Err(err) = consumer(channel).await {
                tracing::error!("{err:?}");
            }
        }
    });


    let _publish_confirm = channel
        .basic_publish(
            "",
            "hello",
            BasicPublishOptions::default(),
            Vec::from("Hello World!"),
            BasicProperties::default(),
        )
        .await?;

    // Wait forever
    consumer_handle.await?;

    Ok(())
}

async fn consumer(channel: Channel) -> anyhow::Result<()> {

    let mut consumer = channel
        .basic_consume(
            "hello",
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await?;

    if let Some(delivery) = consumer.next().await {
        if let Ok((_channel, delivery)) = delivery {
            let data = String::from_utf8_lossy(delivery.data.as_slice());

            tracing::info!("{data}");

            delivery
                .ack(BasicAckOptions::default())
                .await
                .expect("basic_ack");
        }
    }

    Ok(())
}
```

実行してみると無事consumeできました。

```sh
❯ cargo run --quiet --example tutorial_hello_world
2022-08-10T10:52:58.05527Z  INFO examples/tutorial_hello_world.rs:69: Hello World!
```

## `Work queues`

{{ figure(caption="Work queues", images=["images/rabbitmq_work_queues.png"] )}}

次はいわゆるSingle Producer Multi Consumerのパターンを実装してみます。  
基本的には先ほどの例のconsumerを二つ起動するだけです。

```rust
use deadpool_lapin::lapin::{
    BasicProperties,
    Channel,
    options::{
        BasicAckOptions, BasicConsumeOptions, BasicPublishOptions, BasicQosOptions,
        QueueDeclareOptions,
    }, types::FieldTable,
};
use futures::StreamExt;

use rabbitmq_handson::channel;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let channel = channel().await?;

    let _queue = channel
        .queue_declare(
            "task_queue",
            QueueDeclareOptions {
                durable: true,
                ..Default::default()
            },
            FieldTable::default(),
        )
        .await?;

    // Spawn consumer tasks.
    let consumer1_handle = tokio::spawn({
        let channel = channel.clone();
        async move {
            if let Err(err) = consumer("worker1", channel).await {
                eprintln!("{err:?}");
            }
        }
    });

    let consumer2_handle = tokio::spawn({
        let channel = channel.clone();
        async move {
            if let Err(err) = consumer("worker2", channel).await {
                eprintln!("{err:?}");
            }
        }
    });

    for i in 0..10 {
        let _publish_confirm = channel
            .basic_publish(
                "",
                "task_queue",
                BasicPublishOptions::default(),
                Vec::from(format!("task {i}")),
                BasicProperties::default().with_delivery_mode(2),
            )
            .await?;
    }

    // Wait forever
    consumer1_handle.await?;
    consumer2_handle.await?;

    Ok(())
}

async fn consumer(name: &str, channel: Channel) -> anyhow::Result<()> {
    channel.basic_qos(1, BasicQosOptions::default()).await?;

    let mut consumer = channel
        .basic_consume(
            "task_queue",
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await?;

    while let Some(delivery) = consumer.next().await {
        if let Ok((_channel, delivery)) = delivery {
            let data = String::from_utf8_lossy(delivery.data.as_slice());
            println!("{name} {data}");
            delivery
                .ack(BasicAckOptions::default())
                .await
                .expect("basic_ack");
        }
    }

    Ok(())
}
```

consumerで新たに行っているのが

```rust
channel.basic_qos(1, BasicQosOptions::default()).await?;
```

のところです。`basic_qos`はconsumerがqueueからmessageを取得する際に一度にいくつを取得するかを指定します。ここでは1を指定しているので、queueのmessageはconsumer1,2に順番に振り分けられます。

実行してみると

```sh
❯ cargo run --quiet --example tutorial_work_queues
worker1 task 0
worker2 task 1
worker1 task 2
worker2 task 3
worker1 task 4
worker2 task 5
worker1 task 6
worker2 task 7
worker1 task 8
worker2 task 9
```

messageが均等に分散されていることがわかります。

## `Publish/Subscribe`

{{ figure(caption="PubSub", images=["images/rabbitmq_pubsub.png"] )}}

Worker queuesでは一つのqueueをconsumerが共有していました。今回はconsumerごとにqueueを独立させて、一つのmessageを複数のqueueに送る、いわゆるPub/Subパターンを実装します。

```rust
use deadpool_lapin::lapin::{
    BasicProperties,
    Channel,
    ExchangeKind, options::{
        BasicAckOptions, BasicConsumeOptions, BasicPublishOptions, ExchangeDeclareOptions,
        QueueBindOptions, QueueDeclareOptions,
    }, types::FieldTable,
};
use futures::StreamExt;
use tokio::sync::mpsc;

use rabbitmq_handson::channel;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_init::init();

    let channel: Channel = channel().await?;

    channel
        .exchange_declare(
            "logs",
            ExchangeKind::Fanout,
            ExchangeDeclareOptions::default(),
            FieldTable::default(),
        )
        .await?;

    let worker_count = 3;
    let (tx, mut rx) = mpsc::unbounded_channel();
    let mut worker_handles = Vec::with_capacity(worker_count);

    for i in 0..worker_count {
        let tx = tx.clone();
        let channel = channel.clone();
        let handle = tokio::spawn(consumer(format!("worker {i}"), channel, tx));
        worker_handles.push(handle);
    }

    for _ in 0..worker_count {
        rx.recv().await;
    }

    for i in 0..3 {
        channel
            .basic_publish(
                "logs",
                "",
                BasicPublishOptions::default(),
                Vec::from(format!("message {i}")),
                BasicProperties::default(),
            )
            .await?;
    }

    for handle in worker_handles {
        handle.await?;
    }

    Ok(())
}

async fn consumer(name: String, channel: Channel, ready: mpsc::UnboundedSender<()>) {
    let queue = channel
        .queue_declare(
            "",
            QueueDeclareOptions {
                exclusive: true,
                ..Default::default()
            },
            FieldTable::default(),
        )
        .await
        .unwrap();

    channel
        .queue_bind(
            queue.name().as_str(),
            "logs",
            "",
            QueueBindOptions::default(),
            FieldTable::default(),
        )
        .await
        .unwrap();

    let mut consumer = channel
        .basic_consume(
            queue.name().as_str(),
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await
        .unwrap();

    ready.send(()).unwrap();

    while let Some(delivery) = consumer.next().await {
        if let Ok((_channel, delivery)) = delivery {
            let message = String::from_utf8_lossy(delivery.data.as_slice());
            tracing::info!(?name, "{message}");

            delivery.ack(BasicAckOptions::default()).await.unwrap();
        }
    }
}
```

複数のqueueにmessageを送る場合にpublisher側でqueueの存在を意識する必要はなく、これまで同様exchangeを指定するだけです。  
今回のようなPub/Subのケースではexchange type fanoutを指定します。
また、consumer側でのqueue_declareですが以下のように行っています。

```rust
    let queue = channel
        .queue_declare(
            "",
            QueueDeclareOptions {
                exclusive: true,
                ..Default::default()
            },
            FieldTable::default(),
        )
        .await
        .unwrap();
```

queueの名前に空文字を指定するとRabbitMQ側で新規のqueueを作成しつつ名前を生成してかえしてくれます。また、exclusiveを指定することで当該consumer専用のqueueとなります。あとはこれまでどおりexchangeとqueueをbindすることでmessageがpublishされるようになります。

実行してみると

```sh
❯ cargo run --quiet --example tutorial_pub_sub    
2022-08-11T02:37:07.643985Z  INFO examples/tutorial_pub_sub.rs:102: message 0 name="worker 1"
2022-08-11T02:37:07.644035Z  INFO examples/tutorial_pub_sub.rs:102: message 0 name="worker 2"
2022-08-11T02:37:07.644006Z  INFO examples/tutorial_pub_sub.rs:102: message 0 name="worker 0"
2022-08-11T02:37:07.644526Z  INFO examples/tutorial_pub_sub.rs:102: message 1 name="worker 1"
2022-08-11T02:37:07.644581Z  INFO examples/tutorial_pub_sub.rs:102: message 1 name="worker 0"
2022-08-11T02:37:07.644689Z  INFO examples/tutorial_pub_sub.rs:102: message 1 name="worker 2"
2022-08-11T02:37:07.644879Z  INFO examples/tutorial_pub_sub.rs:102: message 2 name="worker 0"
2022-08-11T02:37:07.644899Z  INFO examples/tutorial_pub_sub.rs:102: message 2 name="worker 1"
2022-08-11T02:37:07.644908Z  INFO examples/tutorial_pub_sub.rs:102: message 2 name="worker 2"
```

messageがconsumerそれぞれにpublishされていることが確認できました。

## `Routing`

{{ figure(caption="Routing", images=["images/rabbitmq_routing.png"] )}}

Pub/Subの例ではconsumerはpublishされたmessageをすべて受け取っていました。Routingではこのユースケースをすこし修正して、consumerが関心のあるmessageだけをうけとれるようにします。  
例として、ロギングシステムを考えます。各messageにはlogのseverity(info,warn, error)が付与されておりconsumerはそれぞれ自身が関心のあるseverityをsubscribeできるようにします。
Pub/Subではfanout exchangeを利用していましたが、今回はdirect exchangeを利用します。consumerは自身専用のqueueを宣言したあと、関心のあるseverityでqueueをbindします。このとき、同じexchangeとqueueを異なるrouting keyで複数回bindすることができます。  
exampleのcodeではworker1はerrorのみを、worker2はinfo,warn,errorそれぞれをsubscribeします。

```rust
use deadpool_lapin::lapin::{BasicProperties, Channel, ExchangeKind, options::{BasicConsumeOptions, ExchangeDeclareOptions, QueueBindOptions, QueueDeclareOptions}, types::FieldTable};
use deadpool_lapin::lapin::options::BasicPublishOptions;
use futures::StreamExt;
use tokio::sync::mpsc::UnboundedSender;

use rabbitmq_handson::channel;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_init::init();

    let channel: Channel = channel().await?;

    channel
        .exchange_declare(
            "direct_logs",
            ExchangeKind::Direct,
            ExchangeDeclareOptions::default(),
            FieldTable::default(),
        )
        .await?;

    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    let consumer_handle1 = tokio::spawn({
        let channel = channel.clone();
        let tx = tx.clone();
        async move {
            consume("worker1".into(), channel, vec!["error".into()], tx).await;
        }
    });

    let consumer_handle2 = tokio::spawn({
        let channel = channel.clone();
        let tx = tx.clone();
        async move {
            consume("worker2".into(), channel, vec!["info".into(), "warn".into(), "error".into()], tx).await
        }
    });

    rx.recv().await;
    rx.recv().await;

    let messages = vec![
        ("info", "info message"),
        ("warn", "warn message"),
        ("error", "error message"),
    ];
    for (severity, message) in messages {
        let _publish_confirm = channel
            .basic_publish(
                "direct_logs",
                severity,
                BasicPublishOptions::default(),
                Vec::from(message),
                BasicProperties::default().with_delivery_mode(2),
            )
            .await?;
    }

    consumer_handle1.await?;
    consumer_handle2.await?;

    Ok(())
}

async fn consume(
    name: String,
    channel: Channel,
    severities: Vec<String>,
    tx: UnboundedSender<()>,
) {
    let queue = channel
        .queue_declare(
            "",
            QueueDeclareOptions {
                exclusive: true,
                ..Default::default()
            },
            FieldTable::default(),
        )
        .await
        .unwrap();

    for severity in severities {
        channel
            .queue_bind(
                queue.name().as_str(),
                "direct_logs",
                &severity,
                QueueBindOptions::default(),
                FieldTable::default(),
            )
            .await
            .unwrap();
    }

    tx.send(()).unwrap();

    let mut consume = channel
        .basic_consume(
            queue.name().as_str(),
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await
        .unwrap();

    while let Some(delivery) = consume.next().await {
        if let Ok((_consume, delivery)) = delivery {
            let msg = String::from_utf8_lossy(delivery.data.as_slice());
            tracing::info!("{name} {msg}");
        }
    }
}
```

実行してみると

```sh
❯ cargo run --quiet --example tutorial_routing
2022-08-12T02:05:15.350635Z  INFO examples/tutorial_routing.rs:113: worker2 info message
2022-08-12T02:05:15.351025Z  INFO examples/tutorial_routing.rs:113: worker2 warn message
2022-08-12T02:05:15.351074Z  INFO examples/tutorial_routing.rs:113: worker2 error message
2022-08-12T02:05:15.351099Z  INFO examples/tutorial_routing.rs:113: worker1 error message
```

worker1はerrorのみを、worker2は各種severityのmessageをconsumeできていることが確認できました。

## `Topics`

{{ figure(caption="Topics", images=["images/rabbitmq_topics.png"] )}}

queueにbindする際のrouting keyで選択的にmessageをsubscribeすることができました。  
しかしながらRoutingの例でみたようにmessageのrouting keyと完全一致させる必要があり、severityのような単純な例以外では使いづらい面があります。このfilteringの機能を拡張したのがTopic exchangeです。

Topic exchangeにおけるrouting keyはピリオド(`.`)をdelimiterとして任意の階層を表現できます。例えば`aaa.bbb.ccc`等です。  
bindする側はwildcardを利用でき、`*`は一階層にマッチし、`#`は任意の階層にマッチします。  
ここでは、あるeventをmessageとして、routing keyとして、`<domain>.<tenant>.<event>`のようなformatを利用します。

consumer1は`tracking.#`をbindします。これは任意のtracking domainのeventをsubscribeします。  
consumer2は`*.xxx.*`をbindします。domainやeventの種別に関わらずtenant xxxを対象にします。

```rust
use deadpool_lapin::lapin::{BasicProperties, Channel, ExchangeKind};
use deadpool_lapin::lapin::options::{
    BasicConsumeOptions, BasicPublishOptions, ExchangeDeclareOptions, QueueBindOptions,
    QueueDeclareOptions,
};
use deadpool_lapin::lapin::types::FieldTable;
use futures::StreamExt;
use tokio::sync::mpsc::UnboundedSender;

use rabbitmq_handson::channel;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_init::init();

    let channel = channel().await?;

    channel
        .exchange_declare(
            "topic_events",
            ExchangeKind::Topic,
            ExchangeDeclareOptions::default(),
            FieldTable::default(),
        )
        .await?;

    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    let consumer1_handle = tokio::spawn({
        let channel = channel.clone();
        let tx = tx.clone();
        async move {
            if let Err(err) = consumer_1(channel, tx).await {
                tracing::error!("{err}")
            }
        }
    });

    let consumer2_handle = tokio::spawn({
        let channel = channel.clone();
        let tx = tx.clone();
        async move {
            if let Err(err) = consumer_2(channel,tx).await {
                tracing::error!("{err}");
            }
        }
    });

    rx.recv().await;
    rx.recv().await;

    let events = vec![
        "tracking.aaa.arrived",
        "tracking.xxx.departed",
        "dispatch.aaa.delivered",
        "dispatch.xxx.delivered",
    ];

    for event in events {
        channel
            .basic_publish(
                "topic_events",
                event,
                BasicPublishOptions::default(),
                Vec::from(event),
                BasicProperties::default(),
            )
            .await?;

        tracing::info!("{event} published");
    }

    consumer1_handle.await?;
    consumer2_handle.await?;

    Ok(())
}

async fn consumer_1(channel: Channel, tx: UnboundedSender<()>) -> anyhow::Result<()> {
    let queue = channel
        .queue_declare(
            "",
            QueueDeclareOptions {
                exclusive: true,
                ..Default::default()
            },
            FieldTable::default(),
        )
        .await?;

    channel
        .queue_bind(
            queue.name().as_str(),
            "topic_events",
            "tracking.#",
            QueueBindOptions::default(),
            FieldTable::default(),
        )
        .await?;

    tx.send(())?;

    let mut consume = channel
        .basic_consume(
            queue.name().as_str(),
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await?;

    while let Some(delivery) = consume.next().await {
        if let Ok((_consume, delivery)) = delivery {
            let msg = String::from_utf8_lossy(delivery.data.as_slice());

            tracing::info!("consumer_1: {msg}");
        }
    }

    Ok(())
}

async fn consumer_2(channel: Channel, tx: UnboundedSender<()>) -> anyhow::Result<()> {
    let queue = channel
        .queue_declare(
            "",
            QueueDeclareOptions {
                exclusive: true,
                ..Default::default()
            },
            FieldTable::default(),
        )
        .await?;

    channel
        .queue_bind(
            queue.name().as_str(),
            "topic_events",
            "*.xxx.*",
            QueueBindOptions::default(),
            FieldTable::default(),
        )
        .await?;

    tx.send(())?;

    let mut consume = channel
        .basic_consume(
            queue.name().as_str(),
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await?;

    while let Some(delivery) = consume.next().await {
        if let Ok((_consume, delivery)) = delivery {
            let msg = String::from_utf8_lossy(delivery.data.as_slice());

            tracing::info!("consumer_2: {msg}");
        }
    }

    Ok(())
}
```

実行してみると

```sh
❯ cargo run --quiet --example tutorial_topic
2022-08-12T02:57:31.23669Z  INFO examples/tutorial_topic.rs:70: tracking.aaa.arrived published
2022-08-12T02:57:31.236836Z  INFO examples/tutorial_topic.rs:70: tracking.xxx.departed published
2022-08-12T02:57:31.23701Z  INFO examples/tutorial_topic.rs:70: dispatch.aaa.delivered published
2022-08-12T02:57:31.237143Z  INFO examples/tutorial_topic.rs:70: dispatch.xxx.delivered published
2022-08-12T02:57:31.239124Z  INFO examples/tutorial_topic.rs:116: consumer_1: tracking.aaa.arrived
2022-08-12T02:57:31.239151Z  INFO examples/tutorial_topic.rs:116: consumer_1: tracking.xxx.departed
2022-08-12T02:57:31.239212Z  INFO examples/tutorial_topic.rs:160: consumer_2: tracking.xxx.departed
2022-08-12T02:57:31.239245Z  INFO examples/tutorial_topic.rs:160: consumer_2: dispatch.xxx.delivered
```

consumer1は`tracing` domainのeventを, consumer2はxxx tenantのeventをそれぞれsubscribeできるいます。  
Topic exchangeは設計次第でいろいろなユースケースに対応できそうです。

## `RPC`

{{ figure(caption="RPC", images=["images/rabbitmq_rpc.png"] )}}

これまでの例はいわゆるfire and forgetで、publisherはpublishしたmessageについて気にしていませんでした。RPCの例では非同期ではあるものの、publishしたmessageの処理結果に関心がありconsumerは処理結果をpublisherに伝えます。

今までと異なる点は、messageをpublishする際にresponse用のqueueを`reply_to`で指定する点です。さらにresponseは非同期で返ってくるのでrequestとresponseの対応関係を`correlation_id`で表現します。  

これらのmessageのpropertiesに関しては[AMQP 0-9-1 Protocol Specification](https://www.rabbitmq.com/protocol.html)の[Generated Doc](https://www.rabbitmq.com/resources/specs/amqp-xml-doc0-9-1.pdf)に記載がありました。

```rust
use deadpool_lapin::lapin::{BasicProperties, Channel};
use deadpool_lapin::lapin::options::{BasicConsumeOptions, BasicPublishOptions, QueueDeclareOptions};
use deadpool_lapin::lapin::types::FieldTable;
use futures::StreamExt;

use rabbitmq_handson::channel;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_init::init();

    let channel = channel().await?;
    let rpc_queue = channel.queue_declare("rpc_queue", QueueDeclareOptions::default(), FieldTable::default()).await?;

    let response_queue = channel.queue_declare("", QueueDeclareOptions {
        exclusive: true,
        ..Default::default()
    }, FieldTable::default()).await?;

    tokio::spawn({
        let channel = channel.clone();
        async move {
            if let Err(err) = server(channel).await {
                tracing::error!("{err}");
            }
        }
    });

    channel.basic_publish("", rpc_queue.name().as_str(), BasicPublishOptions::default(),
                          Vec::from("10"), BasicProperties::default().with_reply_to(response_queue.name().clone()).with_correlation_id("1".into())).await?;

    let mut response_consumer = channel.basic_consume(response_queue.name().as_str(), "", BasicConsumeOptions::default(), FieldTable::default()).await?;

    let response = response_consumer.next().await;
    if let Some(response) = response {
        if let Ok((_channel, delivery)) = response {
            let response = String::from_utf8_lossy(delivery.data.as_slice());
            tracing::info!("fib(10) = {response}");
        }
    }

    Ok(())
}

fn fib(n: usize) -> u64 {
    (0..).into_iter().scan((0_u64, 1_u64), |state, _| {
        let &mut (a, b) = state;
        let next = (a, b);

        *state = (b, (a + b));
        Some(next)
    })
        .nth(n).map(|(a, _)| a).unwrap()
}

async fn server(channel: Channel) -> anyhow::Result<()> {
    let mut consumer = channel.basic_consume("rpc_queue", "", BasicConsumeOptions::default(), FieldTable::default()).await?;

    while let Some(delivery) = consumer.next().await {
        if let Ok((_channel, delivery)) = delivery {
            let msg = String::from_utf8_lossy(delivery.data.as_slice()).to_string();
            let response = fib(msg.parse().unwrap());
            let correlation_id = delivery.properties.correlation_id().clone().unwrap();

            channel.basic_publish("", delivery.properties.reply_to().clone().unwrap().as_str(), BasicPublishOptions::default(), Vec::from(response.to_string()), BasicProperties::default().with_correlation_id(correlation_id)).await?;
        }
    }

    Ok(())
}
```

fibonacciを返すserverをrpcで利用しています。  
response用のqueueはexclusiveにして名前はRabbitMQ側で生成しています。  

```sh
❯ cargo run --quiet --example tutorial_rpc
2022-08-12T08:49:10.864598Z  INFO examples/tutorial_rpc.rs:38: fib(10) = 55
```

実行してみると無事responseをうけとれました。

## `Publisher Confirms`


最後のtutorialはpublisher confirmについて。これはconsumerによるackのpublisher版で、RabbitMQのAMQPの拡張機能になります。tutorial自体ではbatchや非同期による性能比較について記載されているのですが、lapinのAPIでは非道でpublishごとにconfirmするようになっていたので、その方式のみを実装しました。(他にも方法があるかもしれません)

```rust
use anyhow::anyhow;
use async_trait::async_trait;
use deadpool_lapin::lapin::BasicProperties;
use deadpool_lapin::lapin::Channel;
use deadpool_lapin::lapin::options::{BasicPublishOptions, ConfirmSelectOptions};
use deadpool_lapin::lapin::publisher_confirm::Confirmation;

use rabbitmq_handson::channel;

#[async_trait]
trait Publish {
    async fn publish(&self, message: String) -> anyhow::Result<()>;
}

struct Confirm {
    channel: Channel,
}

#[async_trait]
impl Publish for Confirm {
    async fn publish(&self, message: String) -> anyhow::Result<()> {
        let confirm = self.channel.basic_publish("", "queue", BasicPublishOptions::default(), Vec::from(message), BasicProperties::default()).await?;

        match confirm.await? {
            Confirmation::Ack(_ack) => {
                Ok(())
            },
            Confirmation::Nack(_) => Err(anyhow!("confirmation failed")),
            Confirmation::NotRequested => Err(anyhow!("confirmation not requested")),
        }
    }
}


#[tokio::main]
async fn main() -> anyhow::Result<()> {
   tracing_init::init();

    let channel = channel().await?;
    channel.confirm_select(ConfirmSelectOptions::default()).await?;

    publish(Confirm { channel }).await?;

    Ok(())
}

async fn publish<P: Publish>(publisher: P) -> anyhow::Result<()> {
    let messages: Vec<String> = std::iter::repeat("message".to_owned()).take(500).collect();

    for message in messages {
        publisher.publish(message).await?;
    }

    Ok(())
}
```

`channel.confirm_select(ConfirmSelectOptions::default()).await?`のようにchannel作成後にpublisher confirmを有効にします。  
performance的に問題なければ基本的には有効にしとおけばよいのでしょうか。

## まとめ

簡単ではありますが、RabbitMQ tutorialsをRustでやってみました。  
実運用するにあたってはTTLやDead Letter Queue, Metrics等々まだまだ調べてみたいことがありますが、とりあえず触って動かしてみるという目的は達せられたのではないでしょうか。  
次は[RabbitMQ Essentials Second Edition](https://www.packtpub.com/product/rabbitmq-essentials-second-edition/9781789131666)を読んでみようと思っているので、読み終わったら感想を書くかもしれません。

