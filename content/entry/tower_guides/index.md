+++
title = "🗼 tower::Service traitを理解する"
slug = "tower_guides"
date = "2022-07-08"
draft = false
[taxonomies]
tags = ["rust"]
+++

[f:id:yamaguchi7073xtt:20220708234744p:plain]

[`tower::Service`] traitについての[公式のGuide](https://github.com/tower-rs/tower/tree/master/guides)がとてもがとてもわかりやすかったです。  
そこで本記事ではこれを辿りながら[`tower::Service`]がなにを抽象化しようとしているかの理解を試みます。(libraryのAPIがどうして今のsignatureに至ったのかをここまで丁寧に一歩ずつ解説してくれているのはなかなか見られないのではないでしょうか)  
versionは現時点の最新版(`0.4.13`)を対象にしています。

`axum`や`tonic`を動かす際にmiddlewareを追加しようとすると[`tower::Layer`]や[`tower::Service`] traitがでてくるかと思います。  
例えば、gRPC serverを実行する以下のようなコードです。

```rust
fn trace_layer() -> tower_http::trace::TraceLayer { todo!() }

tonic::transport::Server::builder()
    .layer(trace_layer())
    .add_service(svc)
    .serve_with_shutdown(addr, shutdown)
    .await?;
```

[`tower::Service`]をみてみると以下のように定義されています。

```rust
pub trait Service<Request> {
    type Response;
    type Error;
    type Future: Future
    where
        <Self::Future as Future>::Output == Result<Self::Response, Self::Error>;

    fn poll_ready(
        &mut self, 
        cx: &mut Context<'_>
    ) -> Poll<Result<(), Self::Error>>;
    
    fn call(&mut self, req: Request) -> Self::Future;
}
```

このtrait定義を理解するのが目標です💪  
まず、いきなり`Service` traitの解説にはいらず、自分でHTTP frameworkを作るとしたらどうなるかを考えていきます。  
frameworkの起動は以下のようになるかもしれません。

```rust
// Create a server that listens on port 3000
let server = Server::new("127.0.0.1:3000").await?;

// Somehow run the user's application
server.run(the_users_application).await?;
```

ここで、`the_users_application`は
```rust
fn handle_request(request: HttpRequest) -> HttpResponse {
    // ...
}
```
のように、なるのがもっともシンプルな形です。  
`Server::run`を実装すると
```rust
impl Server {
    async fn run<F>(self, handler: F) -> Result<(), Error>
    where
        F: Fn(HttpRequest) -> HttpResponse,
    {
        let listener = TcpListener::bind(self.addr).await?;

        loop {
            let mut connection = listener.accept().await?;
            let request = read_http_request(&mut connection).await?;

            task::spawn(async move {
                // Call the handler provided by the user
                let response = handler(request);

                write_http_response(connection, response).await?;
            });
        }
    }
}
```
のように書けます。  
ユーザが利用する場合は

```rust
fn handle_request(request: HttpRequest) -> HttpResponse {
    if request.path() == "/" {
        HttpResponse::ok("Hello, World!")
    } else {
        HttpResponse::not_found()
    }
}

// Run the server and handle requests using our `handle_request` function
server.run(handle_request).await?;
```
のように、`HttpRequest`の処理に集中できます。  
しかし、現在の実装にはひとつ問題があります、`F: Fn(HttpRequest) -> HttpResponse`だと、`await`がclosureの中に書けないので、処理の中でapiやnetwork callの際にblockingしてしまいます。(しかも`tokio::spawn`の中で)  
そこで、以下のように`Future`を返すように修正します。

```rust
impl Server {
    async fn run<F, Fut>(self, handler: F) -> Result<(), Error>
    where
        // `handler` now returns a generic type `Fut`...
        F: Fn(HttpRequest) -> Fut,
        // ...which is a `Future` whose `Output` is an `HttpResponse`
        Fut: Future<Output = HttpResponse>,
    {
        let listener = TcpListener::bind(self.addr).await?;

        loop {
            let mut connection = listener.accept().await?;
            let request = read_http_request(&mut connection).await?;

            task::spawn(async move {
                // Await the future returned by `handler`
                let response = handler(request).await;

                write_http_response(connection, response).await?;
            });
        }
    }
}
```

これで、処理の中で`await`できるようになりました。 
```rust
// Now an async function
async fn handle_request(request: HttpRequest) -> HttpResponse {
    if request.path() == "/" {
        HttpResponse::ok("Hello, World!")
    } else if request.path() == "/important-data" {
        // We can now do async stuff in here
        let some_data = fetch_data_from_database().await;
        make_response(some_data)
    } else {
        HttpResponse::not_found()
    }
}

// Running the server is the same
server.run(handle_request).await?;
```
ただ、このままだとどんなエラーが発生してもユーザはなんらかのHttpResponseを作る必要があるので、エラーも返せるようにします。(`tower::Service`によせる布石)

```rust
impl Server {
    async fn run<F, Fut>(self, handler: F) -> Result<(), Error>
    where
        F: Fn(HttpRequest) -> Fut,
        // The response future is now allowed to fail
        Fut: Future<Output = Result<HttpResponse, Error>>,
    {
        let listener = TcpListener::bind(self.addr).await?;

        loop {
            let mut connection = listener.accept().await?;
            let request = read_http_request(&mut connection).await?;

            task::spawn(async move {
                // Pattern match on the result of the response future
                match handler(request).await {
                    Ok(response) => write_http_response(connection, response).await?,
                    Err(error) => handle_error_somehow(error, connection),
                }
            });
        }
    }
}
```

Release It!に全てのnetwork callにはtimeoutが設定されていなければならないとあります通り、当然timeoutが設定したくなります。timeoutといえば、`tokio::time::timeout()`があるので、これを利用します。

```rust
async fn handler_with_timeout(request: HttpRequest) -> Result<HttpResponse, Error> {
    let result = tokio::time::timeout(
        Duration::from_secs(30),
        handle_request(request)
    ).await;

    match result {
        Ok(Ok(response)) => Ok(response),
        Ok(Err(error)) => Err(error),
        Err(_timeout_elapsed) => Err(Error::timeout()),
    }
}
```

さらに今実装しているのはJSONを返すAPIなので、response headerに`Content-Type: application/json`を設定したくなります。

```rust
async fn handler_with_timeout_and_content_type(
    request: HttpRequest,
) -> Result<HttpResponse, Error> {
    let mut response = handler_with_timeout(request).await?;
    response.set_header("Content-Type", "application/json");
    Ok(response)
}
```

これまでで、handlerの呼び出しは以下のようになっています。  
`handler_with_timeout_and_content_type`  
-> `handler_with_timeout`  
-> `handle_request`  
今後も機能は追加されていくことが予想されるので(auth,body limit, rate limit, trace,CORS,...)、必要な機能を[compose](https://en.wikipedia.org/wiki/Function_composition)できるようにしたいです。  
具体的には

```rust
let final_handler = with_content_type(with_timeout(handle_request));

server.run(final_handler).await?;
```
と書きたいわけです。  
そこで、以下のようなcodeを書いてみます。

```rust
fn with_timeout<F,Fut>(duration: Duration,f: F) -> impl Fn(HttpRequest) -> impl Future<Output = Result<HttpResponse,Error>>
where
    F: Fn(HttpRequest) -> Fut,
    Fut: Future<Output = Result<HttpResponse, Error>>,
{ todo!() }
```

このコードは現状のexistential typeの制約でcompileできません。

```text
error[E0562]: `impl Trait` only allowed in function and inherent method return types, not in `Fn` trait return
  --> src/main.rs:54:76
   |
54 | fn with_timeout<F,Fut>(duration: Duration,f: F) -> impl Fn(HttpRequest) -> impl Future<Output = Result<HttpResponse,Error>>
   |                                                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

また、のちにふれるhandlerを呼び出し以外の機能も追加しづらいです。  
そこで、`Server::run`をclosureでうけるのではなく、traitでうけるようにしてみます。
これは以前に書いた[again](https://blog.ymgyt.io/entry/again)でも採られていたアプローチですね。(closureにimplを書いておけばユーザは以前としてclosureを渡せるわけです)

## `Hanlder` trait

このtraitを`Handler` traitとして以下のように定義してみます。

```rust
trait Handler {
    async fn call(&mut self, request: HttpRequest) -> Result<HttpResponse, Error>;
}
```
しかしながら、Rustでは現状(`1.62`) async traitはサポートされていません。  
選択肢としては二つあります。

1. [`async-trait`](https://crates.io/crates/async-trait)を利用して、`Pin<Box<dyn Future<Output = Result<HttpResponse, Error>>>`を返すようにする。

2. `Handler` traitに`type Future`をassociated typeとして追加する。

ここでは選択肢2を採ります。concrete future typeを返せるユーザは`Box`のcostをさけることができるし、`Pin<Box<...>>`を使いたければ使えるからです。

```rust
trait Handler {
    type Future: Future<Output = Result<HttpResponse, Error>>;

    fn call(&mut self, request: HttpRequest) -> Self::Future;
}
```

`call`が`&mut self`ではなく、`Pin<&mut self>`にするべきかどうかについては[議論](https://github.com/tower-rs/tower/issues/319)があるようです。

handler functionをstructにして、`Handler`を以下のように実装できます。

```rust
struct RequestHandler;

impl Handler for RequestHandler {
    // We use `Pin<Box<...>>` here for simplicity, but could also define our
    // own `Future` type to avoid the overhead
    type Future = Pin<Box<dyn Future<Output = Result<HttpResponse, Error>>>>;

    fn call(&mut self, request: HttpRequest) -> Self::Future {
        Box::pin(async move {
            // same implementation as we had before
            if request.path() == "/" {
                Ok(HttpResponse::ok("Hello, World!"))
            } else if request.path() == "/important-data" {
                let some_data = fetch_data_from_database().await?;
                Ok(make_response(some_data))
            } else {
                Ok(HttpResponse::not_found())
            }
        })
    }
}
```

今までhard codeしていたtimeoutは以下のように書けます。
```rust
struct Timeout<T> {
    // T will be some type that implements `Handler`
    inner_handler: T,
    duration: Duration,
}

impl<T> Handler for Timeout<T>
    where
        T: Handler,
{
    type Future = Pin<Box<dyn Future<Output = Result<HttpResponse, Error>>>>;

    fn call(&mut self, request: HttpRequest) -> Self::Future {
        Box::pin(async move {
            let result = tokio::time::timeout(
                self.duration,
                self.inner_handler.call(request),
            ).await;

            match result {
                Ok(Ok(response)) => Ok(response),
                Ok(Err(error)) => Err(error),
                Err(_timeout) => Err(Error::timeout()),
            }
        })
    }
}
```
ただし、このままだとcompileが通りません。

```text
error[E0759]: `self` has an anonymous lifetime `'_` but it needs to satisfy a `'static` lifetime requirement
  --> src/main.rs:84:29
   |
83 |       fn call(&mut self, request: HttpRequest) -> Self::Future {
   |               --------- this data with an anonymous lifetime `'_`...
84 |           Box::pin(async move {
   |  _____________________________^
85 | |             let result = tokio::time::timeout(
86 | |                 self.duration,
87 | |                 self.inner_handler.call(request),
...  |
94 | |             }
95 | |         })
   | |_________^ ...is used and required to live as long as `'static` here
```

そこで、`&mut self`を`self`にするために`Clone`を利用します。
```rust
// this must be `Clone` for `Timeout<T>` to be `Clone`
#[derive(Clone)]
struct RequestHandler;

impl Handler for RequestHandler {
    // ...
}

#[derive(Clone)]
struct Timeout<T> {
    inner_handler: T,
    duration: Duration,
}

impl<T> Handler for Timeout<T>
where
    T: Handler + Clone,
{
    type Future = Pin<Box<dyn Future<Output = Result<HttpResponse, Error>>>>;

    fn call(&mut self, request: HttpRequest) -> Self::Future {
        // Get an owned clone of `&mut self`
        let mut this = self.clone();

        Box::pin(async move {
            let result = tokio::time::timeout(
                this.duration,
                this.inner_handler.call(request),
            ).await;

            match result {
                Ok(Ok(response)) => Ok(response),
                Ok(Err(error)) => Err(error),
                Err(_timeout) => Err(Error::timeout()),
            }
        })
    }
}
```
ここでのcloneのコストは問題になりません。`RequestHandler`はfieldをもっていないですし、`Timeout`の`Duration`は`Copy`でからです。  
これでエラーは次のようにかわりました。

```text
error[E0310]: the parameter type `T` may not live long enough
  --> src/main.rs:86:9
   |
86 | /         Box::pin(async move {
87 | |             let result = tokio::time::timeout(
88 | |                 this.duration,
89 | |                 this.inner_handler.call(request),
...  |
96 | |             }
97 | |         })
   | |__________^ ...so that the type `impl Future<Output = Result<HttpResponse, Error>>` will meet its required lifetime bounds
   |
help: consider adding an explicit lifetime bound...
   |
80 |         T: Handler + Clone + 'static,
   |                            +++++++++
```

`T`は`Vec<&'a str>`のような参照型の場合もあるので、`T`には`'static'`が必要です。

```rust
impl<T> Handler for Timeout<T>
    where
        T: Handler + Clone + 'static,
{  }
```
とすることでcompileが通るようになりました。  
`Content-Type`を設定するhandlerは以下のようになります。

```rust
#[derive(Clone)]
struct JsonContentType<T> {
    inner_handler: T,
}

impl<T> Handler for JsonContentType<T>
where
    T: Handler + Clone + 'static,
{
    type Future = Pin<Box<dyn Future<Output = Result<HttpResponse, Error>>>>;

    fn call(&mut self, request: HttpRequest) -> Self::Future {
        let mut this = self.clone();

        Box::pin(async move {
            let mut response = this.inner_handler.call(request).await?;
            response.set_header("Content-Type", "application/json");
            Ok(response)
        })
    }
}
```

handlerに`new()`を実装しておくと、`Server::run`はこのようにかけます

```rust
impl Server {
    async fn run<T>(self, mut handler: T) -> Result<(), Error>
        where
            T: Handler,
    {}
}

let handler = RequestHandler;
let handler = Timeout::new(handler, Duration::from_secs(30));
let handler = JsonContentType::new(handler);

// `handler` has type `JsonContentType<Timeout<RequestHandler>>`

server.run(handler).await
```

## `Handler`をさらに抽象化する

今のところ、`Hanlder`は`HttpRequest`と`HttpResponse`をあつかっていましたが、`HttpRequest`に依存するところは、response headerの設定のみでリクエストが`GrpcRequest`でも機能しそうです。そこで、`Handler` traitからプロトコルを抽象化してみましょう。

```rust
trait Handler<Request> {
    type Response;

    // Error should also be an associated type. No reason for that to be a
    // hardcoded type
    type Error;

    // Our future type from before, but now it's output must use
    // the associated `Response` and `Error` types
    type Future: Future<Output = Result<Self::Response, Self::Error>>;

    // `call` is unchanged, but note that `Request` here is our generic
    // `Request` type parameter and not the `HttpRequest` type we've used
    // until now
    fn call(&mut self, request: Request) -> Self::Future;
}
```

`Request`に対してはgenericですが、`Response`はassociated typeになっています。  
これは`Handler<HttpRequest,GrpcResponse>`という型が意味をなさず、requestに対してはresponseの型が1:1で決まることを型があらわしていると読めます。  
さきほどの`RequestHandler`の実装は以下のように変わります。

```rust
impl Handler<HttpRequest> for RequestHandler {
    type Response = HttpResponse;
    type Error = Error;
    type Future = Pin<Box<dyn Future<Output = Result<HttpResponse, Error>>>>;

    fn call(&mut self, request: Request) -> Self::Future {
        // same as before
    }
}
```

`Timeout<T>`はどうでしょうか。timeout処理はhttp protocolに依存していないので、`Request`に対してgenericな実装ができます。ただし、Errorについては、`tokio::time::error::Elapsed`が発生するので、ユーザのエラー型にこれの変換を要求します。


```rust
// `Timeout` accepts any request of type `R` as long as `T`
// accepts the same type of request
impl<R, T> Handler<R> for Timeout<T>
where
    // The actual type of request must not contain
    // references. The compiler would tell us to add
    // this if we didn't
    R: 'static,
    // `T` must accept requests of type `R`
    T: Handler<R> + Clone + 'static,
    // We must be able to convert an `Elapsed` into
    // `T`'s error type
    T::Error: From<tokio::time::error::Elapsed>,
{
    // Our response type is the same as `T`'s, since we
    // don't have to modify it
    type Response = T::Response;

    // Error type is also the same
    type Error = T::Error;

    // Future must output a `Result` with the correct types
    type Future = Pin<Box<dyn Future<Output = Result<T::Response, T::Error>>>>;

    fn call(&mut self, request: R) -> Self::Future {
        let mut this = self.clone();

        Box::pin(async move {
            let result = tokio::time::timeout(
                this.duration,
                this.inner_handler.call(request),
            ).await;

            match result {
                Ok(Ok(response)) => Ok(response),
                Ok(Err(error)) => Err(error),
                Err(elapsed) => {
                    // Convert the error
                    Err(T::Error::from(elapsed))
                }
            }
        })
    }
}
```

`JsonContentType`は`Response`に制約を課します。

```rust
// Again a generic request type
impl<R, T> Handler<R> for JsonContentType<T>
where
    R: 'static,
    // `T` must accept requests of any type `R` and return
    // responses of type `HttpResponse`
    T: Handler<R, Response = HttpResponse> + Clone + 'static,
{
    type Response = HttpResponse;

    // Our error type is whatever `T`'s error type is
    type Error = T::Error;

    type Future = Pin<Box<dyn Future<Output = Result<Response, T::Error>>>>;

    fn call(&mut self, request: R) -> Self::Future {
        let mut this = self.clone();

        Box::pin(async move {
            let mut response = this.inner_handler.call(request).await?;
            response.set_header("Content-Type", "application/json");
            Ok(response)
        })
    }
}
```

新しい`Handler` traitでも`Server::run`は同様に機能します!

```rust
impl Server {
    async fn run<T>(self, mut handler: T) -> Result<(), Error>
    where
        T: Handler<HttpRequest, Response = HttpResponse>,
    {
        // ...
    }
}

let handler = RequestHandler;
let handler = Timeout::new(handler, Duration::from_secs(30));
let handler = JsonContentType::new(handler);

server.run(handler).await
```

## Client側でもtimeout使いたい

これまでのところ、`Handler`はなんらかのprotocolのrequestを処理してresponseを返す機能を抽象化したものといえます。  　
また、`JsonContentType`は専らserver側で必要な機能ですが、`Timeout`はprotocolのclient側でも利用したい機能です。そこで`Handler`をclient/serverの側面からもさらに抽象化させてみます。  
requestを送る側のclientからみると、`Handler`は少々ミスリードな名前です。(handleするのはserver)  
そこで、`Hanlder`を`Service`に改名します。

```rust
trait Service<Request> {
    type Response;
    type Error;
    type Future: Future<Output = Result<Self::Response, Self::Error>>;

    fn call(&mut self, request: Request) -> Self::Future;
}
```

これは[`tower::Service`]の定義とほとんど同じです。(`poll_ready`以外)。  
さきほどみた`Timeout`以外にも、towerでは[`Retry`](https://docs.rs/tower/latest/tower/retry/index.html)や[`RateLimit`](https://docs.rs/tower/latest/tower/limit/rate/index.html)が提供されています。

というわけで、[`tower::Service`] traitがどうしてこのようなAPIになっているのかがわかりました。  
`Fn(HttpRequest) -> HttpResponse`のclosureから始まって、async対応、protocol,client/serverを抽象化した結果このような型になったんですね。

## `poll_ready`

[`tower::Service`] traitを理解したといいたいところですが、まだ`poll_ready`については触れていませんでした。  
これがどうして必要なのかも気になる所ですが、guideは当然説明してくれています!  
さっそく見ていきましょう。

まず、`poll_ready`が必要になるmotivationを理解するために、`ConcurrencyLimit`を実装したくなったとします。  
いくら`tokio::spawn`が軽量だからといって、無制限に利用していれば、Podのリソース制限や、backend(AWS ratelimit, db connection)等を使い果たしてしまいます。  

```rust
impl<R, T> Service<R> for ConcurrencyLimit<T> {
    fn call(&mut self, request: R) -> Self::Future {
        // 1. Check a counter for the number of requests currently being
        //    processed.
        // 2. If there is capacity left send the request to `T`
        //    and increment the counter.
        // 3. If not somehow wait until capacity becomes available.
        // 4. When the response has been produced, decrement the counter.
    }
}
```
`ConcurrencyLimit`の上限に達した場合でも、`call`され続けるとrequestをメモリに保持する必要があります。  
そこで、serviceの呼び出しと、処理のためのresource確保を別のものととらえて、`Service` traitに以下のmethodを追加してみます。

```rust
trait Service<R> {
    async fn ready(&mut self);
}
```
`Service`の呼び出し側は、`call`する前に`ready`を呼ぶようにします。  
ただし、`call`同様にasync traitは書けないので、associated typeが必要ですが、そうするとlifetime関連に対処しないといけなくなります。そこで、`Future` traitを参考に以下のように定義します。

```rust
use std::task::{Context, Poll};

trait Service<R> {
    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<()>;
}
```

`Poll::Ready(())`がcapacityの確保をあらわし、`Poll::Pending`がcapacityが確保できていないことを表現します。  
型としては、`call`を呼ぶ前に`poll_ready`がよばれる保証はないですが、これはAPI contractとします。(したがって、Serviceはreadyでない場合にcallされたときpanicすることが許されます)  
また、[`tower::ServiceExt`](https://docs.rs/tower/0.4.7/tower/trait.ServiceExt.html#method.ready)を利用すれば`ready`をasyncにもできます。

このような呼び出し側と呼び出され側がcapacityについて連携することを"backpressure propagation"というそうです。  
backpressureについての参考として以下があげられていました。

* [Backpressure explained — the resisted flow of data through software](https://medium.com/@jayphelps/backpressure-explained-the-flow-of-data-through-software-2350b3e77ce7)
* [Using load shedding to avoid overload](https://aws.amazon.com/builders-library/using-load-shedding-to-avoid-overload/)

こうしてついに[`tower::Service`] traitの定義にたどり着きました。

```rust
pub trait Service<Request> {
    type Response;
    type Error;
    type Future: Future<Output = Result<Self::Response, Self::Error>>;

    fn poll_ready(
        &mut self,
        cx: &mut Context<'_>,
    ) -> Poll<Result<(), Self::Error>>;

    fn call(&mut self, req: Request) -> Self::Future;
}
```

多くのServiceは自前ではcapacity管理をせずに、たんにinnerの`poll_ready`にdelegateします。  
`poll_ready`のasync版である`ready`を利用するために、`ServiceExt`をuseするとserviceのcallは以下のように書けます。

```rust
use tower::{
    Service,
    // for the `ready` method
    ServiceExt,
};

let response = service
    // wait for the service to have capacity
    .ready().await?
    // send the request
    .call(request).await?;
```

## `Pin<Box<dyn Future<...>>>` 

ここで終わらないのが本guideの素晴らしいところです。  
さきほどまでの`Service`の実装では、associated typeのFutureに`Pin<Box<dyn Future<...>>>`が利用されていますが、`tower`の実装がこのcostを許容するはずありません。というわけで以降では、実際の[`tower::time::Timeout`](https://docs.rs/tower/latest/tower/timeout/struct.Timeout.html) middlewareの実装をみていきます。

まずは`Timeout` structを定義します。

```rust
use std::time::Duration;

#[derive(Clone, Debug)]
struct Timeout<T> {
    inner: T,
    timeout: Duration,
}

impl <S> Timeout<S> {
    pub fn new(inner: S, timeout: Duration) -> Self {
        Timeout { inner, timeout }
    }
}
```

`Service::call`に`&mut self`を`async move`できるようにするために、`self`に変換したいので、`Clone`を要求します。

次に`Service`を実装していきます。まずはなにもせず、単にinnerにdelegateするだけの実装をします。

```rust
use tower::Service;
use std::task::{Context, Poll};

impl<S, Request> Service<Request> for Timeout<S>
where
    S: Service<Request>,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = S::Future;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, request: Request) -> Self::Future {
        self.inner.call(request)
    }
}
```

次に、`self.duration`以内にinnerがReadyを返さない場合にエラーを返すFutureをかえしたいのですがどうすればいいでしょうか。

```rust
    fn call(&mut self, request: Request) -> Self::Future {
        let response_future = self.inner.call(request);

        let sleep = tokio::time::sleep(self.timeout);
        
        // ...
    }
```
ここで、`Pin<Box<dyn Future<...>>>`は避けたいです。多くのnestしたmiddlewareそれぞれがallocationを発生させることによるperformanceへの影響を避けたいからです。  
というわけで自前の`Future`を実装した`ResponseFuture`を定義してみます。

```rust
use tokio::time::Sleep;

pub struct ResponseFuture<F> {
    response_future: F,
    sleep: Sleep,
}

impl<S, Request> Service<Request> for Timeout<S>
where
    S: Service<Request>,
{
    type Response = S::Response;
    type Error = S::Error;
    // Use our new `ResponseFuture` type.
    type Future = ResponseFuture<S::Future>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, request: Request) -> Self::Future {
        let response_future = self.inner.call(request);
        let sleep = tokio::time::sleep(self.timeout);
        
        ResponseFuture {
            response_future,
            sleep,
        }
    }
}
```

associated typeの`Future`に自前の`ResponseFuture`を返すようになりました。  
次に`ResponseFuture`に`Future`を実装します。

```rust
use tokio::time::Sleep;
use pin_project::pin_project;

#[pin_project]
pub struct ResponseFuture<F> {
    #[pin]
    response_future: F,
    #[pin]
    sleep: Sleep,
}

use std::{pin::Pin, future::Future};

impl<F, Response, Error> Future for ResponseFuture<F>
where
    F: Future<Output = Result<Response, Error>>,
{
    type Output = Result<Response, Error>;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        // Call the magical `project` method generated by `#[pin_project]`.
        let this = self.project();

        // `project` returns a `__ResponseFutureProjection` but we can ignore
        // the exact type. It has fields that matches `ResponseFuture` but
        // maintain pins for fields annotated with `#[pin]`.

        // `this.response_future` is now a `Pin<&mut F>`.
        let response_future: Pin<&mut F> = this.response_future;

        // And `this.sleep` is a `Pin<&mut Sleep>`.
        let sleep: Pin<&mut Sleep> = this.sleep;

        match response_future.poll(cx) {
            Poll::Ready(result) => return Poll::Ready(result),
            Poll::Pending => {}
        }

        match sleep.poll(cx) {
            Poll::Ready(()) => todo!(),
            Poll::Pending => {}
        }

        Poll::Pending
    }
}
```

`self.response_future`をpollするために、pin_projectを利用して、`Pin<&mut Self>`から`Pin<&mut F>`の変換を行います。  

次に問題になるのが、timeout durationが経過した際に返すerrorの型です。選択肢としては以下の3つが考えられます。

1. `Box<dyn std::error::Error + Send + Sync>`のようなboxed error trait objectを返す
2. service errorとtimeout errorをvariantsにもつenumを返す
3. `TimeoutError`を定義して、`TimeoutError: Into<Error>`のような制約を課してユーザに変換の定義を要求する

選択肢3がもっともflexibleですが、middlewareが増えてくるとユーザはすべてのエラーにたいして変換を書く必要がでてきてしまいます。   
選択肢2は以下のようなenumを定義するものです。

```rust
enum TimeoutError<Error> {
    Timeout(InnerTimeoutError),
    Service(Error),
}
```

型の情報を失わない点で魅力的ですが、以下の欠点があります。

1. 実用的には、middlewareはnestするので、`BufferError<RateLimitError<TimeoutError<MyError>>>`のような型に対してpattern matchingを書く必要がでてくる。(例えばretry-ableかどうかの判定の際)
2. middlewareの適用の順番を変えるとエラーの型も変わるのでpattern matchの箇所も追従させる必要がある
3. 最終的なエラーの型が非常に大きくなり、stackを大きく占有してしまうかもしれない

選択肢1はinner serviceのエラーを`Box<dyn std::error::Error + Send + Sync>`に変換するもので、複数のエラー型が一つのエラー型に変換されることになる。  
これには以下のメリットがあります。

1. middlewareの適用順序がかわっても影響をうけない(less fragile)
2. middlewareの適用数に関わらずエラー型は一定のsizeになる
3. 巨大なmatchではなく、`error.downcast_ref::<Timeout>()`を利用してerrorの情報を取得することになる

デメリットは

1. dynamic downcastingを利用するので、compilerがすべての起きうるerrorが捕捉されているかを確かめられない
2. error時にallocationが発生する。ただし、errorはinfrequentと考えられるので許容できる。

towerでは選択肢1が採用されました。元の議論は[こちら](https://github.com/tower-rs/tower/issues/131)

最終的な`Timeout` middlewareの実装は以下のようになりました。  
実際のtowerのcodeは[こちら](https://github.com/tower-rs/tower/blob/master/tower/src/timeout/mod.rs)

```rust
use std::fmt;
use std::fmt::Formatter;
use std::task::{Context, Poll};
use std::time::Duration;
use std::{future::Future, pin::Pin};

use pin_project::pin_project;
use tokio::time::Sleep;
use tower::Service;

#[derive(Clone, Debug)]
struct Timeout<T> {
    inner: T,
    timeout: Duration,
}

impl<S> Timeout<S> {
    pub fn new(inner: S, timeout: Duration) -> Self {
        Timeout { inner, timeout }
    }
}

impl<S, Request> Service<Request> for Timeout<S>
    where
        S: Service<Request>,
        S::Error: Into<BoxError>,
{
    type Response = S::Response;
    type Error = BoxError;
    type Future = ResponseFuture<S::Future>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx).map_err(Into::into)
    }

    fn call(&mut self, request: Request) -> Self::Future {
        let response_future = self.inner.call(request);
        let sleep = tokio::time::sleep(self.timeout);

        ResponseFuture {
            response_future,
            sleep,
        }
    }
}

#[pin_project]
pub struct ResponseFuture<F> {
    #[pin]
    response_future: F,
    #[pin]
    sleep: Sleep,
}


impl<F, Response, Error> Future for ResponseFuture<F>
    where
        F: Future<Output = Result<Response, Error>>,
        Error: Into<BoxError>,
{
    type Output = Result<Response, BoxError>;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        let this = self.project();
        match this.response_future.poll(cx) {
            Poll::Ready(result) => {
                let result = result.map_err(Into::into);
                return Poll::Ready(result);
            }
            Poll::Pending => {}
        }

        match this.sleep.poll(cx) {
            Poll::Ready(()) => {
                let error = Box::new(TimeoutError(()));
                return Poll::Ready(Err(error));
            }
            Poll::Pending => {}
        }

        Poll::Pending
    }
}

#[derive(Debug, Default)]
pub struct TimeoutError(());

impl fmt::Display for TimeoutError {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        f.pad("request time out")
    }
}

impl std::error::Error for TimeoutError {}

pub type BoxError = Box<dyn std::error::Error + Send + Sync>;
```

というわけでついに実際の`Timeout`の実装にたどり着きました。


## `tower::Layer`も理解できる

[`tower::Service`]が理解できたので、[`tower::Layer`]がどういう役割なのかもすぐにわかります。  

```rust
pub trait Layer<S> {
    type Service;

    fn layer(&self, inner: S) -> Self::Service;
}
```
`Layer`はこのように定義されています。まず`Layer`と`Service`は1:1の関係で、上記の`Timeout` serviceにたいして`TimeoutLayer`があります。  
そのことがassociated typeの`Service`に現れています。genericsの`S`は`Layer`が対応する`Service`のinnerのserviceです。  
`TimeoutLayer`は以下のように定義されています。

```rust
/// Applies a timeout to requests via the supplied inner service.
#[derive(Debug, Clone)]
pub struct TimeoutLayer {
    timeout: Duration,
}

impl TimeoutLayer {
    /// Create a timeout from a duration
    pub fn new(timeout: Duration) -> Self {
        TimeoutLayer { timeout }
    }
}

impl<S> Layer<S> for TimeoutLayer {
    type Service = Timeout<S>;

    fn layer(&self, service: S) -> Self::Service {
        Timeout::new(service, self.timeout)
    }
}
```

`Layer`は`Service`のdelegate先のServiceをもらって、対応する`Service`を作成する責務をもつので、そのfieldには`Service`を作るための情報が必要です。  
`TimeoutLayer`の場合は、timeoutの`Duration`を保持しています。


## まとめ

初見では、Genericsやassociated typeに圧倒されてしまっていましたが、Guideが一歩ずつ丁寧に解説してくれているおかげで、tower ecosystemの理解が一歩深まりました。  
axumやtonicといったhttp/gRPC protocolの違いに関わらず同じmiddlewareが使えるのは非常にありがたいので、towerのecosystemを使いこなせるようになっていきたいです。


[`tower::Service`]: https://docs.rs/tower/latest/tower/trait.Service.html  
[`tower::Layer`]: https://docs.rs/tower/latest/tower/trait.Layer.html

