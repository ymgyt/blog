+++
title = "🗼 Key Value Storeを作りながら学ぶtokio"
slug = "key_value_store_with_tokio"
date = "2020-12-24"
draft = false
[taxonomies]
tags = ["rust"]
+++

本エントリーではKey Value Storeを[tokio](https://github.com/tokio-rs/tokio)で作るうえで学んだことを書いていきます。  
RustのLT会 [Shinjuku.rs #13](https://forcia.connpass.com/event/194229/)で話させていただいた内容です。

発表時のスライド  

<iframe src="https://docs.google.com/presentation/d/e/2PACX-1vR-AmvaVFQFeMI79HorEznJo8eK0ipPnVUVXtQcT3IEy-s1pprD9MANe0eBwceqXm7Xuavhe9dP6NYY/embed?start=false&loop=false&delayms=3000" frameborder="0" width="960" height="569" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>

[source code](https://github.com/ymgyt/kvsd)


## 作ったもの

TCP(TLS)でremoteに接続してKey/ValueをCRUDするだけのserverです。


```console
❯ export KVSD_HOST=kvsd.ymgyt.io

❯ kvsd set hello rust
OK

❯ kvsd get hello
rust

❯ kvsd set hello 'rust!!!'
OK

❯ kvsd delete hello
OK old value: rust!!!
```


## TCP Server

{{ figure(caption="概要", images=["images/kvsd_tcp_server.jpeg"]) }}


ClientからのTCP接続ごとにtaskを`tokio::spawn()`して専用のHandlerを生成します。  
Key/Valueを保存するFileごとにもtaskを生成しておき、共有resourceの処理でlock等が必要ないようにします。
(図の四角が`tokio::spawn()`したtaskを表しています)


### Max Connection

tokioを利用することで、clientごとにthreadを生成する必要がなくなったのですが無制限にtaskを生成するわけにもいかないので最大connection数を制御したいです。  
最大connectionに達したときは`TcpListener.accept()`をよびださないように実装します。

```rust
struct SemaphoreListener {
    inner: TcpListener,
    max_connections: Arc<Semaphore>,
}

impl SemaphoreListener {
    fn new(listener: TcpListener, max_connections: u32) -> Self {
        Self {
            inner: listener,
            max_connections: Arc::new(Semaphore::new(max_connections as usize)),
        }
    }

    async fn accept(&mut self) -> std::io::Result<(TcpStream, std::net::SocketAddr)> {
        self.max_connections.acquire().await.forget();
        self.inner.accept().await
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L494](https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L494)

`tokio::sync::Semaphore`で`TcpListener`をwrapして`accept()`時に`acquire()`をよぶことで最大connectionに達したときはblockするようにします。  
所有権の関係で`forget()`を呼んでいるので、Clientとの接続が終了したときのHandlerのdrop処理で帳尻をあわせる必要があります。

```rust
struct Handler {
    // ...
    max_connections: Arc<Semaphore>,
}


impl Drop for Handler {
    fn drop(&mut self) {
        self.max_connections.add_permits(1);
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L488]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L488])


### Graceful shutdown

{{ figure(caption="Shutdownの通知", images=["images/kvsd_graceful_shutdown_1.jpeg"]) }}

{{ figure(caption="Shutdownの待機", images=["images/kvsd_graceful_shutdown_2.jpeg"]) }}


終了処理時(SIGINT等)にすべてのClientとの接続が切れるまで待機する必要があります。  
Graceful shutdownに必要な処理はそれぞれ以下のtokioのAPIを利用することで実現できました。

* Signal handling => `tokio::signal::ctrl_c()`
* Shutdownの通知 => `tokio::sync::broadcast::channel()`
* Shutdownの待機 =>`tokio::sync::mpsc::channel()`

```rust
impl Server {
    pub(crate) async fn run(
        mut self,
        listener: TcpListener,
        shutdown: impl Future,
    ) -> Result<()> {
        tokio::select! {
            result = self.serve(listener) => {
                if let Err(err) = result {
                    error!(cause = %err, "Failed to accept");
                }
            }
            _ = shutdown => {
                info!("Shutdown signal received");
            }
        }

        info!("Notify shutdown to all handlers");

        self.graceful_shutdown.shutdown().await;

        info!("Shutdown successfully completed");

        Ok(())
    }
}

struct GracefulShutdown {
    notify_shutdown: broadcast::Sender<ShutdownSignal>,
    shutdown_complete_tx: mpsc::Sender<ShutdownCompleteSignal>,
    shutdown_complete_rx: mpsc::Receiver<ShutdownCompleteSignal>,
}

impl GracefulShutdown {
    fn new() -> Self {
        let (notify_shutdown, _) = broadcast::channel(1);
        let (shutdown_complete_tx, shutdown_complete_rx) = mpsc::channel(1);

        Self {
            notify_shutdown,
            shutdown_complete_tx,
            shutdown_complete_rx,
        }
    }

    // Notify handlers of the shutdown and wait for it to be completed.
    async fn shutdown(mut self) {
        // Notify shutdown to all handler.
        drop(self.notify_shutdown);

        // Drop final Sender so the Receiver below can complete.
        drop(self.shutdown_complete_tx);

        // Wait for all handler to finish.
        let _ = self.shutdown_complete_rx.recv().await;
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L204](https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L204)  
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L159](https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L204)

`tokio::select!`を利用することで、task内で２つのfutureを同時に`await`することができるようになります。  
`impl Future`としておくことでtest時には`tokio::sync::Notify`を利用することでできます。  
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/tests/integration_test.rs#L38](https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/tests/integration_test.rs#L38)


### Stream read/write

TCP上で自分で定義したデータ構造での通信を目指します。  
`Message`はClient-Server間でやりとりする単位です(`Authenticate`, `Set`, `Success`,...)  
`Frame`は`Message`の構成要素です(`String`, `Bytes`,`Null`,...)  
実体はredis serialization protocolの劣化版みたいなものです。  

`TcpStream`/`TlsStream`をwrapした構造体を定義して、client/serverにprotocol実装を提供します。

```rust

use bytes::{Buf, BytesMut};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, BufWriter};

pub struct Connection<T = TcpStream> {
    stream: BufWriter<T>,
    // The buffer for reading frames.
    buffer: BytesMut,
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L12]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L12])

`buffer`はtcpからreadしてMessageを構成するために利用します。

#### write

client/serverから通信したい`Message`をうけとるとそれを`Frames`に分解してそれぞれserializationしていきます。  

```rust
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, BufWriter};

impl<T> Connection<T>
where
    T: AsyncWrite + AsyncRead + Unpin,
{
    pub(crate) async fn write_message(&mut self, message: impl Into<MessageFrames>) -> Result<()> {
        let frames = message.into();

        self.stream.write_u8(frameprefix::MESSAGE_FRAMES).await?;
        self.write_decimal(frames.len()).await?;

        for frame in frames {
            self.write_frame(frame).await?
        }

        self.stream.flush().await?;
        Ok(())
    }

    async fn write_frame(&mut self, frame: Frame) -> Result<()> {
        match frame {
            Frame::MessageType(mt) => {
                self.stream.write_u8(frameprefix::MESSAGE_TYPE).await?;
                self.stream.write_u8(mt.into()).await?;
            }
            Frame::String(val) => {
                self.stream.write_u8(frameprefix::STRING).await?;
                self.stream.write_all(val.as_bytes()).await?;
                self.stream.write_all(DELIMITER).await?;
            }
            Frame::Bytes(val) => {
                self.stream.write_u8(frameprefix::BYTES).await?;
                self.write_decimal(val.len() as u64).await?;
                self.stream.write_all(val.as_ref()).await?;
                self.stream.write_all(DELIMITER).await?;
            }
            Frame::Time(val) => {
                self.stream.write_u8(frameprefix::TIME).await?;
                self.stream.write_all(val.to_rfc3339().as_bytes()).await?;
                self.stream.write_all(DELIMITER).await?;
            }
            Frame::Null => {
                self.stream.write_u8(frameprefix::NULL).await?;
            }
        }

        Ok(())
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L29]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L29])

`AsyncWriteExt`にはendianを考慮したwrite methodが定義されているので便利です。


#### read

<figure class="figure-image figure-image-fotolife" title="readの概要">[f:id:yamaguchi7073xtt:20201224185344j:plain]<figcaption>readの概要</figcaption></figure>

```rust
impl<T> Connection<T>
    where
        T: AsyncWrite + AsyncRead + Unpin,
{
    pub(crate) async fn read_message_with_timeout(
        &mut self,
        duration: Duration,
    ) -> Result<Option<Message>> {
        match tokio::time::timeout(duration, self.read_message()).await {
            Ok(read_result) => read_result,
            Err(elapsed) => Err(Error::from(elapsed)),
        }
    }

    pub(crate) async fn read_message(&mut self) -> Result<Option<Message>> {
        match self.read_message_frames().await? {
            Some(message_frames) => Ok(Some(Message::from_frames(message_frames)?)),
            None => Ok(None),
        }
    }

    async fn read_message_frames(&mut self) -> Result<Option<MessageFrames>> {
        loop {
            if let Some(message_frames) = self.parse_message_frames()? {
                return Ok(Some(message_frames));
            }

            if 0 == self.stream.read_buf(&mut self.buffer).await? {
                return if self.buffer.is_empty() {
                    Ok(None)
                } else {
                    Err(ErrorKind::ConnectionResetByPeer.into())
                };
            }
        }
    }

    fn parse_message_frames(&mut self) -> Result<Option<MessageFrames>> {
        use FrameError::Incomplete;

        let mut buf = Cursor::new(&self.buffer[..]);

        match MessageFrames::check_parse(&mut buf) {
            Ok(_) => {
                let len = buf.position() as usize;
                buf.set_position(0);
                let message_frames = MessageFrames::parse(&mut buf)?;
                self.buffer.advance(len);

                Ok(Some(message_frames))
            }
            Err(Incomplete) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L73]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L73])

futureにtimeoutを設定するには`tokio::time::timeout`を利用します。  
`tokio::time::timeout()`でwrapするとtimeoutつきのfutureを作れ、timeoutすると`tokio::time::Elapsed`を返してくれます。

tcpからreadしたときに意味ある単位でreadできているとは限らないのでbufferに読み込んだタイミングで一度parseを試みます。  
parse時の実装をsimpleにするために`std::io::Cursor`でwrapしておくことで、parse側では必要な単位でbufferを読み込めます。  
bufferに`Message`を構成するに十分な`Frame`がない場合はloopでtcpのreadを繰り返します。  
bufferに十分な`Frames`がある場合は、呼び出し元に`Message`を返して、bufferをclearします。

#### `TcpStream`のtestには`tokio::io::duplex()`が便利

`TcpStream`をwrapしたような型のtestでは`tokio::io::duplex()`が便利でした。

```rust
#[test]
fn message_frames() {
    tokio_test::block_on(async move {
        let (client, server) = tokio::io::duplex(1024);
        let mut client_conn = Connection::new(client, None);
        let mut server_conn = Connection::new(server, None);

        let messages: Vec<Message> = vec![
            Message::Authenticate(Authenticate::new("user", "pass")),
            Message::Ping(Ping::new().record_client_time()),
            // ...
        ];
        let messages_clone = messages.clone();

        let write_handle = tokio::spawn(async move {
            for message in messages {
                client_conn.write_message(message).await.unwrap();
            }
        });

        let read_handle = tokio::spawn(async move {
            for want in messages_clone {
                let got = server_conn.read_message().await.unwrap().unwrap();
                assert_eq!(want, got);
            }
        });

        write_handle.await.unwrap();
        read_handle.await.unwrap();
    })
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L147]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/protocol/connection/mod.rs#L147])

このような感じでtcp listenerを用意せずにメモリ上でtestが完結できました。  
async codeのtestではruntimeを起動しておく必要があるので、`tokio_test`を利用しました。

### TLS

TCPをTLSで保護するには`tokio_rustls`を利用できます。

#### server

```rust
use tokio_rustls::rustls;
use tokio_rustls::server::TlsStream;
use tokio_rustls::TlsAcceptor;

let mut tls_config = rustls::ServerConfig::new(rustls::NoClientAuth::new());
let certs: Vec<rustls::Certificate> = self.config.load_certs();
let mut keys: Vec<rustls::PrivateKey> = self.config.load_keys();

tls_config.set_single_cert(certs, keys.remove(0)).unwrap();

let tls_acceptor = TlsAcceptor::from(Arc::new(tls_config));

let tls_stream: TlsStream<TcpStream> = acceptor.accept(stream).await?;
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L251]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L251])

設定を生成して、鍵と証明書をloadして、`TcpStream`をwrapします。

#### client

```rust
use tokio_rustls::client::TlsStream;
use tokio_rustls::{rustls, webpki, TlsConnector};

// tokio-rustls = { version = "0.20.0", features = ["dangerous_configuration"] }

let mut tls_config = rustls::ClientConfig::new();
tls_config
  .dangerous()
  .set_certificate_verifier(Arc::new(DangerousServerCertVerifier::new()));

let connector = TlsConnector::from(Arc::new(tls_config));

let domain = webpki::DNSNameRef::try_from_ascii_str(host)
  .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "invalid host"))?;

let stream = tokio::net::TcpStream::connect(addr).await?;

let tls_stream: TlsStream<TcpStream> = connector.connect(domain, stream).await?;
```

clientも同様に設定を生成して`TcpStream`をwrapしてやります。  
local環境ではオレオレ証明書を使いたかったので`dangerous_configuration` featureを有効にして証明書検証処理を自分で定義することができます。

```rust
struct DangerousServerCertVerifier {}

impl DangerousServerCertVerifier {
    fn new() -> Self {
        Self {}
    }
}

impl rustls::ServerCertVerifier for DangerousServerCertVerifier {
    fn verify_server_cert(
        &self,
        _roots: &rustls::RootCertStore,
        _presented_certs: &[rustls::Certificate],
        _dns_name: webpki::DNSNameRef<'_>,
        _oscp_response: &[u8],
    ) -> Result<rustls::ServerCertVerified, rustls::TLSError> {
        Ok(ServerCertVerified::assertion())
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/client/tcp.rs#L168]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/client/tcp.rs#L168])


## Shared stateをMutexからchannelで管理

[f:id:yamaguchi7073xtt:20201224185418j:plain]

Shared state(file)を排他的に利用したい場合にMutex等でlockするのではなく専用のtaskを生成してchannel経由で処理を依頼します。  
処理の依頼をchannelに書き込むのはいいのですが、結果をどう受け取るのかが問題になってきます。  
ここでは`tokio::sync::oneshot`を利用しました。

```rust
use tokio::sync::oneshot;

pub(crate) struct Work<Req, Res> {
    // ...
    pub(crate) request: Req,
    // Wrap with option so that response can be sent via mut reference.
    pub(crate) response_sender: Option<oneshot::Sender<Result<Res>>>,
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/core/uow.rs#L27]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/client/tcp.rs#L168])

処理を依頼する型のfieldに`oneshot::Sender<T>`を定義しておき呼び出し元で保持している`Receiver`で結果をうけとります。  
serverがclientから`Message`をうけとって、Key/Valueを取得する処理は以下のようになりました。  

```rust
Message::Get(get) => {
    let (work: Uow, rx: Receiver<Result<_>>) = UnitOfWork::new_get(get);
    self.sender.send(work).await?;

    match rx.await? {
        Ok(Some(value)) => {
            connection.write_message(Success::with_value(value)).await?
        }
        Ok(None) => connection.write_message(Success::new()).await?,
        _ => unreachable!(),
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L444]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L444])

## Fileへのappend onlyな保存

<figure class="figure-image figure-image-fotolife" title="Key Valueの持ち方">[f:id:yamaguchi7073xtt:20201224185446j:plain]<figcaption>Key Valueの持ち方</figcaption></figure>

ようやくKey/Valueの話に。  
永続化するKey/Valueはfileにappend onlyで保存していきます。メモリ上ではKeyとoffsetを保持しておきます。  
Key/Valueをfileから読み込む処理はいかのようになりました。

```rust
use tokio::sync::mpsc::Receiver;
use tokio::io::{AsyncRead, AsyncSeek, AsyncSeekExt, AsyncWrite, SeekFrom};

pub(crate) struct Table<File = fs::File> {
    file: File,
    index: Index, // HashMap<String,usize>,
    receiver: Receiver<UnitOfWork>,
}

impl<File> Table<File>
where
    File: AsyncWrite + AsyncRead + AsyncSeek + Unpin,
{
    async fn lookup_entry(&mut self, key: &Key) -> Result<Option<Entry>> {
        let offset = match self.index.lookup_offset(key){
Some(offset) => offset,
            	None => return Ok(None),
 };

        let current = self.file.seek(SeekFrom::Current(0)).await?;

        self.file.seek(SeekFrom::Start(offset as u64)).await?;
        let (_, entry) = Entry::decode_from(&mut self.file).await?;
        self.file.seek(SeekFrom::Start(current)).await?;

        Ok(Some(entry))
    }
}
```
[https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/core/table/table.rs#L135]([https://github.com/ymgyt/kvsd/blob/6b40c6a3edad0f416631f7ae66674fb5d7922cd7/src/server/tcp.rs#L444])

`tokio::io::AsyncSeek`があるのでoffsetにseekする処理も同期と同じように書けました。


## まとめ

* はじめてtokioを利用しようと思ったとき[mini redis](https://github.com/tokio-rs/mini-redis)の実装が非常に参考になりました。コメントもたくさんあり親切でした。  
* tokioを利用してremoteと通信してデータを保存するまでを自分で作れて楽しかったです
* tokioのAPIを利用してGoに近い形でconcurrentな処理書けそうと思いました。
  * `tokio::select!` (`select`)
  * `tokio::spawn()` (goroutine)
  * `sync::{mpsc,oneshot,broadcast}` (`chan`)   


この記事を書いている日にtokio [`v1.0.0`](https://github.com/tokio-rs/tokio/releases/tag/tokio-1.0.0)がreleaseされました。  
[最低でも5年はメンテしていく旨](https://tokio.rs/blog/2020-12-tokio-1-0)も発表されておりtokioを利用しはじめるにはちょうどいい時期なのではないでしょうか。


