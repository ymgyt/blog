+++
title = "🗼 Mini-Redis Tutorialからはじめるtokio"
slug = "mini_redis_tutorial_to_get_started_with_tokio"
date = "2020-10-25"
draft = false
[taxonomies]
tags = ["rust"]
[extra]
image = "images/emoji/tokyo_tower.png"
+++

この記事ではRustの非同期runtimeのひとつ[tokio](https://github.com/tokio-rs/tokio)の[公式Tutorial](https://tokio.rs/tokio/tutorial)を通じてtokioのAPIに入門していきます。  
Tutorialでは[Mini-Redis](https://github.com/tokio-rs/mini-redis)という[Redis](https://redis.io/)のclient/serverを実装したlibraryを通してtokioとfuture/asyncの概念を学んでいきます。Redisについての前提知識は必要とされていません。  
Rustでasync/awaitが使えるになりましたが、実際にアプリケーションを書くにはruntimeを選択する必要があります。今だとtokioか[async-std](https://github.com/tokio-rs/tokio/releases/tag/tokio-0.3.0)が現実的な選択肢なのでしょうか。非同期のruntimeを選択すると基本的にI/Oをともなう処理はすべて(?)選択したruntimeのAPIを利用することになると思います。そのため、Rustの非同期ecosystemの恩恵にあずかるにはruntime/tokioのAPIになれておく必要があります。  

## まとめ

本tutorialを通して以下のことを学べました。

* `std::sync::Mutex`と`tokio::sync::Mutex`の使い分け方
* `.await`と書いたときにどんなことがおきるかのメンタルモデルができる
* `Mutex`による状態共有から`mpsc`と`oneshot`channelを利用したパターンへの移行
* `Frame`という概念(byte stream -> frame -> protocol)
* `bytes::{BytesMut,Bytes}`の利用例
* futureを`poll`するexecutorの概要
* `select!`でgoっぽく書ける
* `Stream`には`pin`どめが必要

サンプルコードが豊富でgithubではより細かくコメントが書いてあります。


## 準備

rustは1.47を利用しました、最新であれば特に問題ないと思います。minimumは`1.39.0`です。
`rustc 1.47.0 (18bf6b4f0 2020-10-07)`

この記事を書いている1週間ほど前に[tokio v0.3.0](https://github.com/tokio-rs/tokio/releases/tag/tokio-0.3.0)がリリースされました。~~ですがmini-redisはtokioの0.2に依存しているので0.2で進めていきます。~~
~~[`bytes` crateへの依存がpublic APIから削除された](https://github.com/tokio-rs/tokio/releases/tag/tokio-0.3.0)ので、`read_buf()` -> `read()`に変更する以外は特に影響ないです。~~  
[mini-redisもtokio v0.3を利用するようになりました。](https://github.com/tokio-rs/mini-redis/commit/77df32d15e9645fec1483523d5a519f7c494e461)


### Mini-Redis server

client側のコードを書く際にserverが起動していると便利なのでmini-redisを動かせるようにします。
```
$ cargo install mini-redis
$ mini-redis-server
```
`cargo install`でもってくることもできますが、ソースから動かすことにします。

```
git clone https://github.com/tokio-rs/mini-redis
cd mini-redis
cargo run --bin mini-redis-server
```
別terminalで
```
cargo run --bin mini-redis-cli --quiet set xxx xxx
cargo run --bin mini-redis-cli --quiet get xxx 
"xxx"
```
とできればOKです。

### My-Redis

```
cargo new my-redis
cd my-redis
```

`Cargo.toml`
```yaml
[dependencies]
tokio = {version = "0.3.1", features = ["full"]}
mini-redis = "0.3"
```

projectを作成して、tokioとmini-redisを依存先に追加します。  
楽をしてfeaturesに`full`を指定していますが、実際には利用する機能にあわせて`net`, `fs`, `rt-threaded`のように指定します。API documentに利用するために必要なfeatureが記載されています。  
`v0.3`では`rt-core`と`rt-util`が`rt`に、`tcp`, `udp`, `dns`が`net`にまとめられる等して整理されています。[^tokio030]

これで準備が整ったので早速コードを書いていきましょう!  
[Sourceはこちら](https://github.com/ymgyt/mini-redis-handson) (branchがmasterからmainになっています。)

## Hello Tokio

tutorialでは`main.rs`に書いていますが残しておきたいので`examples/hello-redis.rs`を作成します。

```rust
use mini_redis::{client, Result};

#[tokio::main]
pub async fn main() -> Result<()>{
    let mut client = client::connect("127.0.0.1:6379").await?;

    client.set("hello", "world".into()).await?;

    let result = client.get("hello").await?;

    println!("got value from the server; result = {:?}", result);

    Ok(())
}
```

別terminalでmini-redisが起動してある前提で
```
$ cargo run --quiet --example hello-redis
got value from the server; result = Some(b"world")
```
となれば成功です。

### Attribute Macro `tokio::main`

まずいきなりうっ..となったのが`tokio::main`macroです。main関数からいきなり隠蔽されるのは抵抗ないでしょうか。ということで`cargo expand`で展開内容をみていきます。

```rust
#![feature(prelude_import)]
#[prelude_import]
use std::prelude::v1::*;
#[macro_use]
extern crate std;
use mini_redis::{client, Result};
pub fn main() -> Result<()> {
    tokio::runtime::Builder::new()
        .basic_scheduler()
        .threaded_scheduler()
        .enable_all()
        .build()
        .unwrap()
        .block_on(async {
            {
                let mut client = client::connect("127.0.0.1:6379").await?;
                client.set("hello", "world".into()).await?;
                let result = client.get("hello").await?;
                {
                    ::std::io::_print(::core::fmt::Arguments::new_v1(
                        &["got value from the server; result = ", "\n"],
                        &match (&result,) {
                            (arg0,) => {
                                [::core::fmt::ArgumentV1::new(arg0, ::core::fmt::Debug::fmt)]
                            }
                        },
                    ));
                };
                Ok(())
            }
        })
}
```

このような展開結果となりました。概要としてはruntimeをBuilder patternで設定してユーザのコードをasync blockでwrapしたうえで`block_on()`に渡している感じです。  
 documentによると`Runtime`のセットアップをユーザが`Runtime`や`Builder`を直接利用することなくできるようにするためのhelperという位置づけのようです。  
`v0.3.0`では
```
#[tokio::main(flavor = "multi_thread", worker_threads = 10)]
#[tokio::main(flavor = "current_thread")]
```
のようにmulti/single threadの切り替えやworker thread数を制御できるようです。  
このruntimeがなにをやってくれているかは後述します。  
ちなみに`v0.3.0`では以下のように展開されました。

```rust
  tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap()
        .block_on(async { /* ...*/ }
```

[runtimeの設定処理](https://github.com/tokio-rs/tokio/blob/43d071489837a154dd56b42176c637b635e1891f/tokio/src/runtime/builder.rs#L489)の理解を試みたのですが歯がたちませんでした。  
worker thread数は指定しない場合[seanmonstar先生](https://github.com/seanmonstar)の[num_cpus](https://github.com/seanmonstar/num_cpus)が利用され論理コア数が使われているようです。


### `await`のメンタルモデル

`async` fn/blockの中で`await`を書いたらなにが起きるのピンと来ていませんでした。なのでせめて概念的にでも`.await`書いたら実はこうなってるというメンタルモデル(あくまで自分の)を得るのが目標でしたが、本tutorialを行い現状では以下のように考えています。

1. async fn/blockは`Future::poll`[^Future::Poll]の実装に変換される。
1. `Future`を実装したanonymous structは最終的にはtaskという形でruntimeに渡されて`poll()`を呼んでもらえる。
1. `future_a.await`と書いたコードは以下のように変換される。(詳しくは後述します)
```rust
let value = match future_as_mut().poll(cx) {
  Poll::Ready(value) => {
    self.state = self.State::FutureAComplete;
    value
  }
  Poll::Pending => return Poll::Pending,
}
```
1. 結果的にユーザはfutureが完了したあとの処理だけを記述すればよく、非同期処理が同期処理っぽく書ける。


## Spawning

client側のコードを書いたので次はserver側のコードを書いていきます。こちらは`src/main.rs`に記述します。

```rust
use tokio::net::{TcpListener, TcpStream};
use mini_redis::{Connection, Frame};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        let (socket, _) = listener.accept().await.unwrap();
        process(socket).await;
    }
}

async fn process(socket: TcpStream) {
    let mut connection = Connection::new(socket);

    if let Some(frame) = connection.read_frame().await.unwrap() {
        println!("GOT: {:?}", frame);

        let response = Frame::Error("unimplemented".to_string());
        connection.write_frame(&response).await.unwrap();
    }
}
```

 このコードでは、`process`が完了するまで次の接続を受け付けていないので同時に1つの接続しか処理されません。`process`を**concurrent**におこなうには以下のようにします。

```rust
use tokio::net::TcpListener;

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        let (socket, _) = listener.accept().await.unwrap();
        tokio::spawn(async move {
            process(socket).await;
        });
    }
}
```

`process`をawaitしているfutureを`tokio::spawn`に渡します。`tokio::spawn`はfutureの実行単位で自分は`go func() { ... }`のようなgoroutineと考えています。ただし、goroutineと違うのは戻り値を取得できるところです。(goroutineの場合はchan等を使う必要がある)  

```rust
#[tokio::main]
async fn main() {
    let handle = tokio::spawn(async {
        "return value"
    });
    let out = handle.await.unwrap();
    println!("GOT {}", out);
}
```

> Tasks in Tokio are very lightweight. Under the hood, they require only a single allocation and 64 bytes of memory. Applications should feel free to spawn thousands, if not millions of tasks.

ということでたった64bytesのallocationしか必要とせず、ある程度は気にせずに`spawn`してもいいみたいです。


### Concurrency and Parallelism

いわゆる並行と並列の違いについても言及があります。

> Concurrency and parallelism is not the same thing. If you alternate between two tasks, then you are working on both tasks concurrently, but not in parallel. For it to qualify as parallel, you would need two people, one dedicated to each task.

concurrentとparallelの違いについては[Go言語による並行処理](https://www.oreilly.co.jp/books/9784873118468/) 2章並行性をどうモデル化するかで書かれている以下の文がいちばんわかりやすいと思っています。

> 並行性はコードの性質を指し、並列性は動作しているプログラムの性質を指します。

この本は本当に名著だと思い原文の[Concurrency in Go](https://www.oreilly.com/library/view/concurrency-in-go/9781491941294/)も読みました。原文では以下のように書かれています。

> Concurrency is a property of the code; parallelism is a property of the running program 

そして 

> The first is that we do not write parallel code, only concurrent code that we hope will be run in parallel. Once again, parallelism is a property of the runtime of our program, not the code. 

というわけで、コードでは並行かそうでないかだけが制御できるという姿勢でいるようになりました。


### `'static` bound

[`tokio::spawn`の定義](https://docs.rs/tokio/0.3.1/tokio/fn.spawn.html)は以下のようになっています。
```rust
pub fn spawn<T>(task: T) -> JoinHandle<T::Output>ⓘ 
where
    T: Future + Send + 'static,
    T::Output: Send + 'static, 
```

　ここで`T: 'static`となっているとそれは"lives forever"と[よく誤解されている](https://github.com/pretzelhammer/rust-blog/blob/master/posts/common-rust-lifetime-misconceptions.md)がそうではないという注意があります。(このCommon Rust Lifetime Misconceptionsは非常に参考になったので別で記事を書こうと思っています。)   
　`T: 'static`はTの所有者はTを保持している限りデータが無効になることはないと保証されているので、プログラムの終了までを含めて無期限にデータを保持できると読めて、"T is bounded by a 'static lifetime"と読むべきで、"T has a 'static lifetime"と読まないと自分は理解しています。  
　要は`T: 'static`だったらTはowned typeか`'static lifetime`の参照しかfieldにもたない型ということ。


### Send bound

`tokio::spawn`に渡されるfutureは`Send`をimplementしている必要がある。taskが`Send`になるには、**`.await`をまたぐすべてのデータが`Send`**である必要がある。逆にいうと`.await`またがなければ`Send`でないデータでも使える。

```rust
tokio::spawn(async {
  {  
     let rc = std::rc::Rc::new("ok");
     println!("{}", rc);
   }
   tokio::task::yield_now().await;
});
```

これはOK。

```rust
tokio::spawn(async {
   let rc = std::rc::Rc::new("ok");
   
   tokio::task::yield_now().await;

   println!("{}", rc);
});
```

 これは`Rc`が`Send`でないのでコンパイルエラー。

## Shared state

redis serverを実装するにあたって状態を保持する必要があります。状態を共有する方法として例えば以下の2つが考えられます。

1. `Mutex`でガードして保持する。
1. stateを管理する専用のtaskをspawnしてchannelを通じてやりとりする。

シンプルなデータでは最初の方法が適していて、I/O等の非同期処理が必要になってくると2つ目の方式が適している。  
今回の実装では状態は`HashMap`でメモリに保持するので`Mutex`を利用した方式で実装している。(channelを使う方式はのちのちふれる)

### `bytes` crate

byte streamを表現するのに`Vec<u8>`でなく`Bytes`を利用するために`bytes` crateを依存先に追加します。tokioのversionが0.3にあがったので、`0.6`を指定します。  

Cargo.toml
```toml
bytes = "0.6"
```

### `HashMap`の共有

```rust
use tokio::net::TcpListener;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    println!("Listening");

    let db = Arc::new(Mutex::new(HashMap::new()));

    loop {
        let (socket, _) = listener.accept().await.unwrap();
        let db = db.clone();

        println!("Accepted");
        tokio::spawn(async move {
            process(socket, db).await;
        });
    }
}
```

`HashMap`に`Mutex`でinterior mutabilityを付与して、`Arc`で複数threadでownできるようにします。  
`tokio::sync::Mutex`ではなく`std::sync::Mutex`を利用していることに注意してください。  
`tokio::sync::Mutex`は取得したlockが`.await`をまたぐ際に利用するそうです。  `std`と`tokio`の`Mutex`の使い分けがずっとわかっていなかったので疑問点がひとつ解消できてうれしいです。  
競合が少なく、取得したロックが`.await`をまたがない場合はasync内でsynchronous mutexを利用してもよいそうです。  
ただし注意点としてロック取得によるblockはそのtaskだけでなくtaskを実行しているthreadにscheduleされている他のtaskもブロックするので注意が必要です。これはmutexに限った話ではなくasync内でblockするAPI呼ぶ場合の一般的注意事項といえそうです。  
また、[`parking_lot::Mutex`](https://docs.rs/parking_lot/0.10.2/parking_lot/type.Mutex.html)の利用も選択肢にあるそうなのですが、よくわかっていません。Rustで時々でてくる`parking`についてはいずれ調べていきたいです。



mutexのロックが問題になった場合の選択肢として

* 共有していたstateの管理専用のtaskを用意して、message passingを利用する。
* mutexを分割する
* そもそもmutexを利用しないようにする

たとえば以下のようにして`HashMap`を分割してロックの競合する頻度をさげることができるそうです。また[dashmap](https://docs.rs/dashmap)がsharded hash mapの機能を提供しています。

```rust
type ShardedDb = Arc<Vec<Mutex<HashMap<String, Vec<u8>>>>>;

let shard = db[hash(key) % db.len()].lock().unwrap();
shard.insert(key, value);
```

## Channels

クライアントサイドからみていきます。まず書きたいのは以下のような処理だとします。

```rust
use mini_redis::client;

#[tokio::main]
async fn main() {
    // Establish a connection to the server
    let mut client = client::connect("127.0.0.1:6379").await.unwrap();

    // Spawn two tasks, one gets a key, the other sets a key
    let t1 = tokio::spawn(async {
        let res = client.get("hello").await;
    });

    let t2 = tokio::spawn(async {
        client.set("foo", "bar".into()).await;
    });

    t1.await.unwrap();
    t2.await.unwrap();
}
```

このコードはコンパイルできません。`client`はcopyでないので所有権の問題がありますし、`Client::set`は`&mut self`を要求するので排他制御が必要になってきます。  
そこでmessage passingというパターンを利用します。`client` リソースを管理する専用のtaskをspawnして、clientに処理を依頼したいtaskはclient taskに処理を依頼するmessageを送る形にします。  
このパターンを使うと、接続するconnectionは1本で済みclientをmanageするtaskはclientに排他的にアクセスできます。またchannelはbufferとしても機能するので処理のproducerとconsumerの速度差を吸収してくれます。

### tokioのchannel primitives

tokioは目的ごとに以下のchannel primitiveを用意してくれています。

* [`mpsc`](https://docs.rs/tokio/0.3/tokio/sync/mpsc/index.html): multi-producer, single consumer用channel
* [`oneshot`](https://docs.rs/tokio/0.3/tokio/sync/oneshot/index.html): 一度だけの値の通知に利用できる
* [`broadcast`](https://docs.rs/tokio/0.3/tokio/sync/broadcast/index.html): 送ったmessageはそれぞれのreceiverに届く
* [`watch`](https://docs.rs/tokio/0.3/tokio/sync/watch/index.html): single-producer, multi-consumer.receiverは最新の値だけうけとれる。

`std::sync::mpsc`や`crossbeam::channel`はthreadをblockしてしまうのでasyncで使うには適さないそうです。以下では`mpsc`と`oneshot`を利用していきます。

```rust
use bytes::Bytes;
use mini_redis::client;
use tokio::sync::{mpsc, oneshot};

#[derive(Debug)]
enum Command {
    Get {
        key: String,
        resp: Responder<Option<Bytes>>,
    },
    Set {
        key: String,
        val: Vec<u8>,
        resp: Responder<()>,
    },
}

type Responder<T> = oneshot::Sender<mini_redis::Result<T>>;

#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel(32);
    let tx2 = tx.clone();

    let manager = tokio::spawn(async move {
        let mut client = client::connect("127.0.0.1:6379").await.unwrap();

        while let Some(cmd) = rx.recv().await {
            match cmd {
                Command::Get { key, resp } => {
                    let res = client.get(&key).await;
                    let _ = resp.send(res);
                }
                Command::Set { key, val, resp } => {
                    let res = client.set(&key, val.into()).await;
                    let _ = resp.send(res);
                }
            }
        }
    });

    // Spawn two tasks, each setting a value
    let t1 = tokio::spawn(async move {
        let (resp_tx, resp_rx) = oneshot::channel();
        let cmd = Command::Get {
            key: "hello".to_string(),
            resp: resp_tx,
        };

        // Send the GET request
        if tx.send(cmd).await.is_err() {
            eprintln!("connection task shutdown");
            return;
        }

        // Await the response
        let res = resp_rx.await;
        println!("GOT = {:?}", res);
    });

    let t2 = tokio::spawn(async move {
        let (resp_tx, resp_rx) = oneshot::channel();
        let cmd = Command::Set {
            key: "foo".to_string(),
            val: b"bar".to_vec(),
            resp: resp_tx,
        };

        // Send the SET request
        if tx2.send(cmd).await.is_err() {
            eprintln!("connection task shutdown");
            return;
        }

        // Await the response
        let res = resp_rx.await;
        println!("GOT = {:?}", res);
    });

    t1.await.unwrap();
    t2.await.unwrap();
    manager.await.unwrap();
}
```
ポイントはclient taskに処理を依頼する`Command`に結果を通知するためのfiledが用意してあるところでしょうか。  
`Responder<T> = oneshot::Sender<mini_redis::Result<T>>;`と定義して、依頼したコマンドの結果をうけとれるようになっています。  
処理を依頼するchannelと結果をつけとるchannelで別のprimitiveを利用するこのパターンは非常に参考になりました。Goだと両方とも`chan`になりますが、`oneshot`のほうが意図がでていいなと思います。

## I/O

### `AsyncRead`/`AsyncWrite`

Futureの`poll`を直接呼ぶようなコードを書かないように`AsyncRead`/`AsyncWrite` traitを直接よぶことは基本的になく、それぞれに対応している`AsyncReadExt`/`AsyncWriteExt`を利用します。

```rust
use tokio::io::{self, AsyncReadExt};
use tokio::fs::File;

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut f = File::open("foo.txt").await?;
    let mut buffer = Vec::new();

    // read the whole file
    f.read_to_end(&mut buffer).await?;
    Ok(())
}
```
```rust
use tokio::io::{self, AsyncWriteExt};
use tokio::fs::File;

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::create("foo.txt").await?;

    // Writes some prefix of the byte string, but not necessarily all of it.
    let n = file.write(b"some bytes").await?;

    println!("Wrote the first {} bytes of 'some bytes'.", n);
    Ok(())
}
```
fileの内容をすべて読んだり、書き込んだりするのはこのようになります。同期的な書き方と同じですね。


### Echo server

ということでI/Oといえばechoということでecho serverを実装していきます。  
server sideは以下のようになります

```rust
#![allow(dead_code)]
use tokio::io;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:6142").await.unwrap();

    loop {
        let (socket, _) = listener.accept().await?;

        // echo_io_copy(socket).await;
        echo_manual_copy(socket).await;
    }
}

async fn echo_manual_copy(mut socket: tokio::net::TcpStream) {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    tokio::spawn(async move {
        let mut buf = vec![0; 1024];

        loop {
            match socket.read(&mut buf).await {
                // return value of Ok(0) signified that the remote has closed.
                Ok(0) => return,
                Ok(n) => {
                    if socket.write_all(&buf[..n]).await.is_err() {
                        eprintln!("write error");
                        return;
                    }
                }
                Err(_) => {
                    return;
                }
            }
        }
    });
}

async fn echo_io_copy(mut socket: tokio::net::TcpStream) {
    tokio::spawn(async move {
        let (mut rd, mut wr) = socket.split();

        if io::copy(&mut rd, &mut wr).await.is_err() {
            eprintln!("failed to copy");
        }
    });
}
```
自分でbufferを確保してloopでreadする方法と`tokio::io::copy`を利用する方法があります。    `io::copy`はreaderとwriterそれぞれに`&mut`を要求するので
```
io::copy(&mut socket, &mut socket).await
```
としたいところですが、参照の制約からそれができません。そこで、`io::split`を利用します。(ただし`TcpStream`は自前で用意している)  
`split` APIをみるといつかtwitterで流れてきたこの画像がいつも思い出されます。  
[電車でDのmeme](https://knowyourmeme.com/memes/multi-track-drifting)みたいです。

{{ figure(caption="複線ドリフト", images=["images/denshaded.jpeg"]) }}

clientは以下のようになります。
```rust
use tokio::io::{self, AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;

#[tokio::main]
async fn main() -> io::Result<()> {
    let socket = TcpStream::connect("127.0.0.1:6142").await?;
    let (mut rd, mut wr) = io::split(socket);

    let _write_task = tokio::spawn(async move {
        wr.write_all(b"hello\r\n").await?;
        wr.write_all(b"world\r\n").await?;

        Ok::<_, io::Error>(())
    });

    let mut buf = vec![0; 128];

    loop {
        let n = rd.read(&mut buf).await?;

        if n == 0 {
            break;
        }

        println!("GOT {:?}", String::from_utf8_lossy(&buf[..n]));
    }

    Ok(())
}
```

`split`でwriterをmoveで渡しています。

## Framing

次に`TcpStream`をwrapしてbyte streamからredisの各種コマンドAPIを提供している`Connection`を実装していきます。
ここでいうframeとはclient/server間で送られるデータの単位という感じでしょうか。(A frame is a unit of data transmitted between two peers.)  
1つ以上のframeでprotocolにおけるmessageになると考えています。
今回実装しようとしているRedis wire protocolについては[こちら](https://redis.io/topics/protocol)  
実装に必要な範囲でまとめると以下のようになります。

### RESP(REdis Serialization Protocol)

https://redis.io/topics/protocol

first byteでdataのtypeを判定できる

* `+` Simple Strings
* `-` Errors
* `:` Integers
* `$` Bulk Strings
* `*` Arrays

protocolは常に`\r\n`(CRLF)でterminated

#### RESP Simple Strings

`+`に続いてCRとLFを含まない文字列で構成される。  
成功を表すOKは以下のように5byte。  
`+OK\r\n`

## RESP Errors

エラー用のdata type. 実体としてはSimple Stringsだがprefixが`-`で区別される。  
clientに例外として扱われ、内容はエラーメッセージ。  
`-Error message\r\n`

```
-ERR unknown command 'foobar'
-WRONGTYPE Operation against a key holding the wrong kind of value
```

`ERR`のあとに`WRONGTYPE`のような具体的なエラー種別を返すのはRedisの慣習でRESPのError Formatではない。

#### RESP Integers

CRLF terminatedなstringでintegerにparseできる。prefixは`:`。  
signed 64bit integerのrangeであることが保証されている。

* `:0\r\n`
* `:1000\r\n`

#### RESP Bulk Strings

　512MBまでの任意のbyte列を保持できるデータ。redisのdocumentではbinary safeと言われている。  
binary safe stringの意味については予め長さが分かっていて特定の文字による終端を前提にしておらず、任意のbyte列を保持できるということだと思う。

* `$6\r\nfoobar\r\n` : "foobar".
* `$0\r\n\r\`        : empty string.
* `$-1\r\n`          : non-existenceを表現。

#### RESP Arrays

複数のdata typeを表すdata type.要素数はprefix`*`のあとに明示される。

* `*0\r\n` : empty array.
* `*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n` : "foo", "bar"を表す。
* `*-1\r\n` : Null Array.


#### Sending commands to a Redis Server

clientからserverに`LLEN mylist`を送るリクエストは以下のようになる。  
`*2\r\n$4\r\nLLEN\r\n$6\r\nmylist\r\n`

```markdown
Array: 2 element
  - String(len:4) LLEN
  - String(len:6) mylist
```

### frameの実装

上記のredis data typeをRustで表現すると
```rust
use bytes::Bytes;

enum Frame {
    Simple(String),
    Error(String),
    Integer(u64),
    Bulk(Bytes),
    Null,
    Array(Vec<Frame>),
}
```
のようになります。シンプルですね。RedisのCommandは複数Frame(`Frame::Array`)で表現されているので、ユーザとしてはtcp socket(reader)を渡してコマンドを返してくれるような処理が欲しくなります。  
server sideのframeを読む処理は以下のようになります。

```rust
use bytes::Bytes;
use mini_redis::Frame;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::net::{TcpListener, TcpStream};

mod connection;
use connection::Connection;

async fn process(socket: TcpStream, db: Db) {
    use mini_redis::Command::{self, Get, Set};
    let mut connection = Connection::new(socket);

    while let Some(frame) = connection.read_frame().await.unwrap() {
        let response = match Command::from_frame(frame).unwrap() {
            Set(cmd) => {
                let mut db = db.lock().unwrap();
                db.insert(cmd.key().to_string(), cmd.value().clone());
                Frame::Simple("OK".to_string())
            }
            Get(cmd) => {
                let db = db.lock().unwrap();
                if let Some(value) = db.get(cmd.key()) {
                    Frame::Bulk(value.clone())
                } else {
                    Frame::Null
                }
            }
            cmd => panic!("unimplemented {:?}", cmd),
        };

        connection.write_frame(&response).await.unwrap();
    }
}
```
`Connection::read_frame()`が`Frame::Array`を返し、`Frame::Array`からRedisの`Command`に変換しています。  
ということで、byte streamから`Frame::Array`に変換する処理を見ていきます。

#### Buffered reads

```rust
use std::io::{self, Cursor};

use bytes::{Buf, BytesMut};
use mini_redis::frame::Error::Incomplete;
use mini_redis::{Frame, Result};
use tokio::io::{AsyncReadExt, AsyncWriteExt, BufWriter};
use tokio::net::TcpStream;

pub struct Connection {
    stream: BufWriter<TcpStream>,
    buffer: BytesMut,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream: BufWriter::new(stream),
            buffer: BytesMut::with_capacity(4096),
        }
    }

    pub async fn read_frame(&mut self) -> Result<Option<Frame>> {
        loop {
            if let Some(frame) = self.parse_frame()? {
                return Ok(Some(frame));
            }

            if 0 == self.stream.read_buf(&mut self.buffer).await? {
                if self.buffer.is_empty() {
                    return Ok(None);
                } else {
                    return Err("connection reset by peer".into());
                }
            }
        }
    }

    fn parse_frame(&mut self) -> Result<Option<Frame>> {
        // Create the T: Buf type.
        let mut buf = Cursor::new(self.buffer.as_ref());

        match Frame::check(&mut buf) {
            Ok(_) => {
                // Frame::check set cursor position at end of frame.
                let len = buf.position() as usize;

                // Reset the internal cursor for the call to parse.
                buf.set_position(0);

                // Parse the frame.
                let frame = Frame::parse(&mut buf)?;

                // Discard the frame from the buffer.
                self.buffer.advance(len);

                // Return the frame to the caller.
                Ok(Some(frame))
            }
            // Not enough data has been buffered.
            Err(Incomplete) => Ok(None),

            // An error was encountered.
            Err(e) => Err(e.into()),
        }
    }
```

`Connection`は`TcpStream`とframeをparseするためのbufferを保持しています。bufferの型として`bytes::BytesMut`を利用しています。  
`impl<W: AsyncWrite + AsyncRead> AsyncRead for BufWriter<W>`が定義されているので、`Connection.stream`は`AsyncReader`として利用できます。
`read_frame`が呼ばれると読み込んだbufferからFrameが生成できればFrameを返しbufferを更新します。Frameを生成するまでのbufferが足りなければtcp streamからreadします。  
なにかをparseする際は先読みすることが必要となることが多いと思いますが、ここでは`std::io::Cursor`でwrapしてから`Frame::check`にbufferを渡すことでbufferのpositionを変更することなくparse処理を委譲できています。`Cursor`のこのような使い方は非常に参考になります。  

#### buffered writes

```rust
    pub async fn write_frame(&mut self, frame: &Frame) -> io::Result<()> {
        match frame {
            Frame::Array(val) => {
                // Encode the frame type prefix. For an array, it is `*`.
                self.stream.write_u8(b'*').await?;

                // Encode the length of the array.
                self.write_decimal(val.len() as u64).await?;

                // Iterate and encode each entry in the array.
                for entry in &**val {
                    self.write_value(entry).await?;
                }
            }
            _ => self.write_value(frame).await?,
        }

        // Ensure the encoded frame is written to the socket.
        // The calls above are to the buffered stream and writes.
        // Calling `flush` writes the remaining contents of the buffer to the socket.
        self.stream.flush().await
    }

    async fn write_value(&mut self, frame: &Frame) -> io::Result<()> {
        const DELIMITER: &[u8] = b"\r\n";

        match frame {
            Frame::Simple(val) => {
                self.stream.write_u8(b'+').await?;
                self.stream.write_all(val.as_bytes()).await?;
                self.stream.write_all(DELIMITER).await?;
            }
            Frame::Error(val) => {
                self.stream.write_u8(b'-').await?;
                self.stream.write_all(val.as_bytes()).await?;
                self.stream.write_all(DELIMITER).await?;
            }
            Frame::Integer(val) => {
                self.stream.write_u8(b':').await?;
                self.write_decimal(*val).await?;
            }
            Frame::Null => {
                self.stream.write_all(b"$-1\r\n").await?;
            }
            Frame::Bulk(val) => {
                let len = val.len();

                self.stream.write_u8(b'$').await?;
                self.write_decimal(len as u64).await?;
                self.stream.write_all(val).await?;
                self.stream.write_all(DELIMITER).await?;
            }

            // Encoding an `Array` from within a value cannot be done using a
            // recursive strategy. In general, async fns do not support
            // recursion. Mini-redis has not needed to encode nested arrays yet,
            // so for now it is skipped.
            Frame::Array(_val) => unimplemented!(),
        }

        self.stream.flush().await?;

        Ok(())
    }
```

write処理はRedisのprotocolにしたがって`Frame`をencodeして書き込んでいきます。`BytesMut`はsystem callの回数を抑えるために書き込みをbufferするので、最後に`flush`を呼びます。このあたりは同期処理と同じですね。  
APIの設計上`Connection`の呼び出し側にいつ`flush`するかを制御させる設計もありえると言及されていました。

## Async in depth

ここまででasyncとtokioの一通りの機能に触れたのでfutureについてもう少し見ていきます。  
まず指定された期間が経過したらstdoutに挨拶を表示するfutureを実装してみます。

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>)
        -> Poll<&'static str>
    {
        if Instant::now() >= self.when {
            println!("Hello world");
            Poll::Ready("done")
        } else {
            // Ignore this line for now.
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    }
}

#[tokio::main]
async fn main() {
    let when = Instant::now() + Duration::from_millis(10);
    let future = Delay { when };

    let out = future.await;
    assert_eq!(out, "done");
}
```
このコードはこんな感じに展開されるそうです。

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};

enum MainFuture {
    // Initialized, never polled
    State0,
    // Waiting on `Delay`, i.e. the `future.await` line.
    State1(Delay),
    // The future has completed.
    Terminated,
}

impl Future for MainFuture {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>)
        -> Poll<()>
    {
        use MainFuture::*;

        loop {
            match *self {
                State0 => {
                    let when = Instant::now() +
                        Duration::from_millis(10);
                    let future = Delay { when };
                    *self = State1(future);
                }
                State1(ref mut my_future) => {
                    match Pin::new(my_future).poll(cx) {
                        Poll::Ready(out) => {
                            assert_eq!(out, "done");
                            *self = Terminated;
                            return Poll::Ready(());
                        }
                        Poll::Pending => {
                            return Poll::Pending;
                        }
                    }
                }
                Terminated => {
                    panic!("future polled after completion")
                }
            }
        }
    }
}
```

このコードをみて`.await`の挙動だったり、`.await`またぐときの制約だったりがいろいろ腹落ちしました。futureはstate machinesだ、みたいな記述はこのことを言わんとしていたんですね。  
async block内で`.await`を使うたびに`enum`で定義されたStateが増えていくことになるんですね。"zero cost abstractions"はだてじゃない。  

### Mini Tokio Executor

async block/fnが`poll`に変換されるということは誰かがこの`poll`を呼び出す必要があります。それがtokio(runtime)が提供しているexecutorです。

```rust
use crossbeam::channel;
use futures::task::{self, ArcWake};
use std::cell::RefCell;
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};
use std::thread;
use std::time::{Duration, Instant};

fn main() {
    let mini_tokio = MiniTokio::new();

    // Spawn root task.
    // No work happens until `mini_tokio.run()` is called.
    mini_tokio.spawn(async {
        spawn(async {
            Delay::with(Duration::from_millis(100)).await;
            println!("world");
        });

        spawn(async {
            println!("hello");
        });

        Delay::with(Duration::from_millis(200)).await;
        std::process::exit(0);
    });

    mini_tokio.run();
}

struct MiniTokio {
    // Receives scheduled tasks. When a task is scheduled, the associated future is ready to make progress.
    // This usually happens when a resource the task uses becomes ready to perform an operation.
    // For example, a socket received data and read call will succeed.
    scheduled: channel::Receiver<Arc<Task>>,

    // Send half ot the scheduled channel.
    sender: channel::Sender<Arc<Task>>,
}

impl MiniTokio {
    fn new() -> MiniTokio {
        let (sender, scheduled) = channel::unbounded();

        MiniTokio { scheduled, sender }
    }

    fn spawn<F>(&self, future: F)
    where
        F: Future<Output = ()> + Send + 'static,
    {
        Task::spawn(future, &self.sender);
    }

    fn run(&self) {
        CURRENT.with(|cell| {
            *cell.borrow_mut() = Some(self.sender.clone());
        });

        while let Ok(task) = self.scheduled.recv() {
            task.poll();
        }
    }
}

pub fn spawn<F>(future: F)
where
    F: Future<Output = ()> + Send + 'static,
{
    CURRENT.with(|cell| {
        let borrow = cell.borrow();
        let sender = borrow.as_ref().unwrap();
        Task::spawn(future, sender);
    });
}

struct Delay {
    // When to complete the delay.
    when: Instant,
    // The waker to notify once the delay has completed.
    // The waker must be accessible by both the timer thread and future so it is wrapped with `Arc<Mutex>>`
    waker: Option<Arc<Mutex<Waker>>>,
}

impl Future for Delay {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        // First, if this is the first time the future is called, spawn the timer thread.
        // If the timer thread is already running, ensure the stored `Waker` matches the current task's waker.
        if let Some(waker) = &self.waker {
            let mut waker = waker.lock().unwrap();

            // Check if the stored waker matches the current tasks' waker.
            if !waker.will_wake(cx.waker()) {
                *waker = cx.waker().clone();
            }
        } else {
            let when = self.when;
            let waker = Arc::new(Mutex::new(cx.waker().clone()));
            self.waker = Some(waker.clone());

            // This is the first time `poll` is called, spawn the timer thread.
            thread::spawn(move || {
                let now = Instant::now();

                if now < when {
                    thread::sleep(when - now);
                }

                let waker = waker.lock().unwrap();
                waker.wake_by_ref();
            });
        }

        if Instant::now() >= self.when {
            Poll::Ready(())
        } else {
            // The duration has not elapsed, the future has not completed so return `Poll::Pending`.
            Poll::Pending
        }
    }
}

impl Delay {
    async fn with(dur: Duration) {
        let future = Delay {
            when: Instant::now() + dur,
            waker: None,
        };

        future.await;
    }
}

thread_local! {
    static CURRENT: RefCell<Option<channel::Sender<Arc<Task>>>> = RefCell::new(None);
}

struct Task {
    future: Mutex<Pin<Box<dyn Future<Output = ()> + Send>>>,
    executor: channel::Sender<Arc<Task>>,
}

impl Task {
    fn spawn<F>(future: F, sender: &channel::Sender<Arc<Task>>)
    where
        F: Future<Output = ()> + Send + 'static,
    {
        let task = Arc::new(Task {
            future: Mutex::new(Box::pin(future)),
            executor: sender.clone(),
        });

        sender.send(task).unwrap();
        //let _ = sender.send(task);
    }

    fn poll(self: Arc<Self>) {
        let waker = task::waker(self.clone());
        let mut cx = Context::from_waker(&waker);

        let mut future = self.future.try_lock().unwrap();

        let _ = future.as_mut().poll(&mut cx);
    }
}

impl ArcWake for Task {
    fn wake_by_ref(arc_self: &Arc<Self>) {
        let _ = arc_self.executor.send(arc_self.clone());
    }
}
```

executorとして`MiniTokio`を定義しています。`MiniTokio::spawn`で渡されたfutureを`Task`でwrapしてchannelのSenderをcloneして保持させています。  
`Delay`のfuture実装では別threadを起動して指定期間経過後にwakerをwakeします。  
`futures::task::ArcWake` traitを実装してあると、`impl ArcWake` -> `Waker` -> `Context`と作成できVTableを自分で作らなくても`poll`できるようになるようです。  
この実装では`wake_ by_ref`では単純に自分を再度channelにsendしてexecutorの`poll`対象になるようにしています。  
ものすごく簡易的な実装だと思いますがExecutorの雰囲気はつかめたような気がします。
tokioの`Runtime::block_on`の実装をおってみたところまったくわかりませんでしたが(特にparkの概念)、以下のように確かにfutureを`poll`しているloopがありました。  
https://github.com/tokio-rs/tokio/blob/c30ce1f65c5befb2a4b48eb4c16b7da3c0eafbd1/tokio/src/park/thread.rs#L263
```rust
loop {
            if let Ready(v) = crate::coop::budget(|| f.as_mut().poll(&mut cx)) {
                return Ok(v);
            }

            self.park()?;
}
```

## Select 

`tokio::spawn`がgoroutineの生成に対応するならgoっぽく書けるんじゃと思っていましたがそのためにはひとつ重要な予約語がたりません。そう`select`です。  
これがないと最初のシグナルハンドリングがそもそも書けないです。(都度チェックする以外)  
ということで、`tokio::select!`を見ていきます。マクロなのはしょうがないです。(cargo expandするとformatされていないコードが出力されてしまったので載せるのはあきらめました)

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async {
        let _ = tx1.send("one");
    });

    tokio::spawn(async {
        let _ = tx2.send("two");
    });

    tokio::select! {
        val = rx1 => {
            println!("rx1 completed first with {:?}", val);
        }
        val = rx2 => {
            println!("rx2 completed first with {:?}", val);
        }
    }
}
```
ふたつのchannelの結果を待機するコードはこのようになります。  
```
<pattern> = <async expression> => <handler>,
```
`select!`のsyntaxはこのように表されます。  
すべての`<async expression>`はひとつにまとめられてconcurrentに実行され、あるexpressionの実行が完了して、結果が`<pattern>`にマッチすると`<handler>`が実行されます。  
結果的に実行される`<handler>`は必ずひとつのbranchです。  
また、`<async expression>`は同じtaskとして実行されるので同時に実行されることはない(はず)です。(task内concurrency)  
このあたりの仕様はRustのborrow checkerに影響してきます。(handlerではmutable borrowをとれる)  
これでsignalのような終了処理を伝播させるような処理もかけそうです。
```rust
use tokio::net::TcpStream;
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx, rx) = oneshot::channel();

    // Spawn a task that sends a message over the oneshot
    tokio::spawn(async move {
        tx.send("done").unwrap();
    });

    tokio::select! {
        socket = TcpStream::connect("localhost:3465") => {
            println!("Socket connected {:?}", socket);
        }
        msg = rx => {
            println!("received message first {:?}", msg);
        }
    }
}
```
ただしtokioの[signal API](https://docs.rs/tokio/0.3.1/tokio/signal/index.html)をみてみるとsignalの種類ごとにfutureを生成する必要がありそうなので複数種類のsignal処理を書く場合はそれぞれ生成しておく必要がありそうです。
```rust
use tokio::signal::unix::{signal, SignalKind};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // An infinite stream of hangup signals.
    let mut stream = signal(SignalKind::hangup())?;

    // Print whenever a HUP signal is received
    loop {
        stream.recv().await;
        println!("got signal HUP");
    }
}
```

## Streams

駆け足でtutorialの各項目をさらってきましたが最後はStreamです。  
`Future<Output = T>`がasyncな`T`だとしたら`Stream<Item = T>`はasyncな`Iterator<Item = T>`という関係のようです。(https://docs.rs/futures-core/0.3.6/futures_core/stream/trait.Stream.html)  
I/Oと同様に`futures_core::stream::Stream`は`poll_next`しか定義しておらず、iteratorのような各種APIを利用するには`tokio::stream::StreamExt`を利用します。
redisのpub/subっぽいことをするコードは以下のようになります。(`mini-redis-server`を起動しておきます)  
```rust
use mini_redis::client;
use tokio::stream::StreamExt;

async fn publish() -> mini_redis::Result<()> {
    let mut client = client::connect("127.0.0.1:6379").await?;

    client.publish("numbers", "1".into()).await?;
    client.publish("numbers", "two".into()).await?;
    client.publish("numbers", "3".into()).await?;
    client.publish("numbers", "four".into()).await?;
    client.publish("numbers", "5".into()).await?;

    Ok(())
}

async fn subscribe() -> mini_redis::Result<()> {
    let client = client::connect("127.0.0.1:6379").await?;
    let subscriber = client.subscribe(vec!["numbers".to_owned()]).await?;
    let messages = subscriber
        .into_stream()
        .filter(|msg| match msg {
            Ok(msg) if msg.content.len() == 1 => true,
            _ => false,
        })
        .map(std::result::Result::unwrap)
        .take(3);

    tokio::pin!(messages);

    while let Some(msg) = messages.next().await {
        println!("got = {:?}", msg);
    }

    Ok(())
}

#[tokio::main]
async fn main() -> mini_redis::Result<()> {
    tokio::spawn(async { publish().await });

    subscribe().await?;

    println!("DONE");

    Ok(())
}
```
`subscriber.into_stream`でsubscriberをconsumeしたあと、`StreamExt`を利用してadaptor処理を追加しています。このあたりの使用感はiteratorと同じですね。  
注意が必要なのは`next`を呼ぶ前に`tokio::pin!`という見慣れないマクロをよんでいることです。  
`next`を呼ぶためにはstreamが`pinned`されている必要があり、`into_stream`は`pin`されていない`Stream`を返しています。この`tokio::pin!`を忘れるとものすごいコンパイルエラーメッセージとともに、`pin`する必要があるとコンパイラーから注意してもらえます。(`.... cannot be unpined`)  

`pin`については[async book](https://rust-lang.github.io/async-book/04_pinning/01_chapter.html)や[OPTiMさんのPinチョットワカル](https://tech-blog.optim.co.jp/entry/2020/03/05/160000)を参考にさせていただきました。  
自分の理解では`Pin<T>`としておくとメモリ上で動かしてはいけない型(Futureを実装したstruct)が`&mut self`をとれなくなり結果的に`std::mem::replace`等が使えなくなり安全になるという感じです。  
なぜFutureの実装をメモリから動かせないかというと`.await`をまたいた変数はstructのfieldに変換されるからとういことでしょうか。

## 終わりに

tokio tutorialを写しながら動かしていってだいぶasync/tokioのAPIに慣れてきました。まだまだはまりどころありそうですが少なくとも今まで書いていた同期処理のコードをtokioを使って書き直すとかはできるようなきがしてきました。また、Mini-Redisの実装では触れられなかったところでも参考になりそうな箇所が多くあり(protocolのparseのところ等)参考にしていきたいと思っています。  

[tokioのblog記事 Announcing Tokio 0.3 and the path to 1.0](https://tokio.rs/blog/2020-10-tokio-0-3)では2020年12月の終わり頃に1.0のリリースを計画していることが書かれています。  
tokio1.0では  
* A minimum of 5 years of maintenance.  
* A minimum of 3 years before a hypothetical 2.0 release.  
というstability guaranteesへのcommitが宣言されています。すごいですね、オープンソースで5年メンテします!と宣言しているものはかなり少ないのではないでしょうか。  
これなら安心してtokio使っていけますね。



## 参考document

* [async book](https://rust-lang.github.io/async-book/). TODOが目立つがExecutorの簡易的な実装例がのっている。  
* [keen先生のblog](https://keens.github.io/blog/2019/07/07/rustnofuturetosonorunnerwotsukuttemita/). `RawWakrVTable`からContextを作っている。
* [非同期Rustの動向調査](https://qiita.com/legokichi/items/53536fcf247143a4721c)  
* OPTiMさんのtech blog
  * [RustのPinチョットワカル](https://tech-blog.optim.co.jp/entry/2020/03/05/160000)
  * [Rustの非同期プログラミングをマスターする](https://tech-blog.optim.co.jp/entry/2019/11/08/163000)
* Writing As OS in Rustの[async/awaitの章](https://os.phil-opp.com/async-await/)  


[^tokio030]: https://github.com/tokio-rs/tokio/releases/tag/tokio-0.3.0  
[^Future::Poll]: https://doc.rust-lang.org/std/future/trait.Future.html#tymethod.poll