+++
title = "📕 Asynchronous Programming in Rustを読んだ感想"
slug = "asynchronous-programming-in-rust"
description = "CF Samson先生のFuture解説がついに本になった"
date = "2024-03-14"
draft = false
[taxonomies]
tags = ["rust", "book"]
[extra]
image = "images/emoji/closed_book.png"
+++

## 読んだ本

{{ figure(images=["images/apir-book.jpg"], caption="Asynchronous Programming in Rust", href="https://www.packtpub.com/product/asynchronous-programming-in-rust/9781805128137") }}

著者: [Carl Fredrik Samson](https://github.com/PacktPublishing/Asynchronous-Programming-in-Rust/tree/main?tab=readme-ov-file#get-to-know-the-author)  
[Sample code Repository](https://github.com/PacktPublishing/Asynchronous-Programming-in-Rust/tree/main?tab=readme-ov-file#get-to-know-the-author)

今はもう読めなくなってしまった[Futures Explained in 200 Lines of Rust](http://web.archive.org/web/20230324130904/https://cfsamson.github.io/books-futures-explained/)や[Exploring Async Basics with Rust](http://web.archive.org/web/20220814154139/https://cfsamson.github.io/book-exploring-async-basics/introduction.html)を書かれたCF Samson先生Async解説本がついに出版されました。  

本記事では本書を読んだ感想について書きます。


## まとめ

RustのFuture,async/awaitの解説として非常に参考になりました。
最終的に[mio]のみの依存で以下のコードが動くruntimeを作れます。

```rust
fn main() {
    let mut executor = runtime::init();
    executor.block_on(async_main());
}

async fn async_main() {
    let txt = Http::get("/600/HelloAsyncAwait").await;
    println!("{txt}");
    let txt = Http::get("/400/HelloAsyncAwait").await;
    println!("{txt}");
}
```

本書が素晴らしいのは、Futureを説明するためにassembly,ISA,thread,systemcall,epoll,calling convention, green thread, coroutineといった概念から説明してくれる点です。1章から5章まではRustをやっていなくても参考になると思います。


## Chapter 1: Concurrency and Asynchronous Programming: a Detailed Overview

本書の前提となるMultitaskingの歴史や言葉の定義、OSとCPUの関係等が説明されます。  
Preemptiveの概念や本書におけるconcurrencyとparallelismの違いが取り上げられます。　　
Efficiency(無駄を避ける能力)という観点からみると、parallelism(並列)はefficiencyには一切寄与せず、concurrency(並行)こそが、それを高めるという説明がおもしろかったです。  
Concurrency,parallelism,resource,task,asynchronous programmingといったともすれば多義的で文脈依存な用語を本書の範囲で、きちんと定義してくれるところもよかったです。   
一方で、

> On the other hand, if you fancy heated internet debates, this is a good place to start. Just claim someone else’s definition of concurrent is 100 % wrong or that yours is 100 % correct, and off you go.  

(ネット上での議論が好きなら、誰かのconcurrentの定義はまったくの誤りで、正しくはこうと主張してみるといいだろう)

という冗談もあり、もろもろの定義はあくまで本書の理解を助けるためにしているというスタンスです。
(日本以外でも並列/並行警察っているんですね)

ReadのI/Oを行う場合に3つの選択肢があり、それぞれthreadをsuspendするかだったりの違いが図で解説されているところもわかりやすかったです。epoll等については3章で詳しく説明してくれます。  

Rustの本なのにFutureの話がでてくるのが6章なのが素晴らしいです。また、firmwareにはmicrocontroller(small CPU)が備わっており、concurrencyとは効率性を上げることなのだから、同じ仕事をプログラムにさせないという話はとても参考になりました。  
知っている人にとっては当たり前なのかもしれませんが、このあたりを説明してくれるのは珍しいと思いました。


## Chapter 2: How Programming Languages Model Asynchronous Program Flow

OSのthreadという機構があるのになぜ、さらにもう1つ抽象化のレイヤーを設けるのか、 
Thread,future,goroutine, promise等がなにを抽象化しているかについて説明されます。  
Cooperativeやstackfulといった分類の観点の説明もあります。  
OS threadとuser-lebel thread(green thread)の共通点や違いの説明もわかりやすかったです。  
Green threadではprogram(runtime)でgreen threadごとのstackを管理しますが、最初の割り当てが足りなくなった場合に新しい領域を割り当てて移動させることの難しさについての言及はなるほどでした。(stackを単純に移動させるとpointerが壊れてしまいますが、garbage collectorでどのみちpointerを管理するコストを払っている等)

Green thread, fiber, future, promiseがどういった関係にあるのか整理されており、本章もRust関係なく参考になると思います。green threadいまいちピンときていない方も5章で実際に作りながら詳しく解説してくれるので大丈夫です。  


## Chapter 3: Understanding OS-Backed Event Queues, System Calls, and Cross-Platform Abstractions

[mio](https://github.com/tokio-rs/mio)や[polling](https://github.com/smol-rs/polling),[libuv](https://libuv.org/)等で利用されているOS-backed event queueについて。

Blocking I/Oを行うと、そのOS threadはsuspendされ、dataが到着すると再び起こされ、CPUのstateを復元したのち、実行が再開される。I/Oの完了を待っている間に他にすることがなければこの仕組みは効率的だが、そうでない場合は新たにthreadを起動させるしかない。  
そこで、threadをsuspendさせないsyscallを行い、blockする代わりにeventの状態を問い合わせるためのhandleを取得する。(polling)。ただし、この手法だと、pollの間隔が短すぎるとCPUを浪費してしまうし、長すぎるとthroughputが落ちてしまう。そこで、epoll,kqueue,IOCP等のevent queueを利用する。

event queueには、I/Oの準備ができたことを通知するReadiness basedとbuffer等を渡してI/Oの完了を通知するCompletion basedなものがある。epollとinput/output completion port(IOCP)を具体例に両者の説明もある。cross platformなevent queue apiを作る際はどちらをベースにするか決める必要があり、不一致を埋めるのはなかなか大変という説明もあります。

後半ではsyscallの解説があります。ABIやcalling conventionも説明してくれます。  
Rustからsystem callを行う方法として、以下のような`asm!` macroやFFIが紹介されます。  
`asm!` macroについては詳しい解説もあります。

```rust
#[inline(never)]
fn syscall(message: String) {
    let msg_ptr = message.as_ptr();
    let len = message.len();
    unsafe {
        asm!(
            "mov rax, 1",
            "mov rdi, 1",
            "syscall",
            in("rsi") msg_ptr,
            in("rdx") len,
            out("rax") _,
            out("rdi") _,
            lateout("rsi") _,
            lateout("rdx") _
        );
    }
}
```

## Chapter 4: Create Your Own Event Queue

本章では、epollを用いて、簡単なevent queueを実装していきます。  
この例は[mio]に基づいていて、mioの理解にも繫る親切設計です。

具体的には以下のように実際にepollを利用した`Poll`を実装しながら、epollの仕組みが解説されます。  
また、`#[repr(packed)]`やbitflags, level-triggerとedge-trigger, `TcpStream::set_nodelay`といった関連する前提についての説明もあります。

```rust

#[link(name = "c")]
extern "C" {
    // ...
    pub fn epoll_wait(epfd: i32, events: *mut Event, maxevents: i32, timeout: i32) -> i32;
}

impl Poll {
    pub fn poll(&mut self, events: &mut Events, timeout: Option<i32>) -> Result<()> {
        // ...
        let res = unsafe { epoll_wait(fd, events.as_mut_ptr(), max_events, timeout) };
        // ...
    }
}
```

上記のepollを利用した具体例の他にも同じ処理を[mio]を利用したversionの具体例も載っており、[mio]よくわからないと思っていた自分にとっては非常にありがたい章となっておりました。




## Chapter 5: Creating Our Own Fibers

本章では、fiber, green threadといわれるstackful coroutineを作ります。  
green threadとは要するに、programでassemblyを書いて、CPUのregister特にstack pointerやinstruction pointerを書き換えて実行する命令流を切り替えるというのが自分の理解です。  

具体的には以下のようにthreadのデータ構造を定義。

  ```rust
#[derive(PartialEq, Eq, Debug)]
enum State {
    Available,
    Running,
    Ready,
}

struct Thread {
    stack: Vec<u8>,
    ctx: ThreadContext,
    state: State,
}

#[derive(Debug, Default)]
#[repr(C)]
struct ThreadContext {
    rsp: u64,
    r15: u64,
    // ...
}
```

現在の`ThreadContext`と実行を切り替えたい`ThreadContext`を引数(`rdi`,`rsi`)でもらって、切り替えるassemblyを

```rust
unsafe extern "C" fn switch() {
    asm!(
        "mov [rdi + 0x00], rsp",
        // ...
        "mov [rdi + 0x30], rbp",
        "mov rsp, [rsi + 0x00]",
        // ...
        "mov rbp, [rsi + 0x30]",
        "ret",
        options(noreturn)
    );
}

Runtimeが呼び出すという感じです。

fn yield(&mut self) {
  // ...
  unsafe {
      let old: *mut ThreadContext = &mut self.threads[old_pos].ctx;
      let new: *const ThreadContext = &self.threads[pos].ctx;
      asm!("call switch", in("rdi") old, in("rsi") new, clobber_abi("C"));
  }
  // ...
}
```

この説明をしながら、ISAであったり、calling convention、`asm!` macroを解説してくれます。


## Chapter 6: Futures in Rust

6章はRustのFutureの概要についての短い章です。  
Rustではbuiltinのruntimeは提供されていないであったり、stdが提供しているもの(Future trait, Waker type)の説明があります。  
また、async runtimeのmental modelとして、Reactor, Executor,Futureの関係が解説されます。


## Chapter 7: Coroutines and async/await

Green threadはtaskを停止/再開させるための情報をstackに保持できるが、stackless coroutine(Future)は停止/再開のための情報をstateごとに保持するstate machineとして実装されている。  
ただ、このstateを直接書くようなことはせずに、`.await`を書くたびにそこが、停止/再開のポイントとなり、stateが定義される。  
というような、async/awaitは内部的にはStateになっているというような説明はrustのfutureの説明でよくみかけると思います。本書のユニークなところは、async/awaitを書いてしまうとこの変換処理がrustのcompiler側で行われてしまうので、独自にcoroutine/waitを定義して、stateへの変換処理を自作の`corofy`で行う点です。

具体的には以下のようなcodeを

```rust
coroutine fn async_main() {
    let txt = Http::get(&get_path(0)).wait;
    println!("{txt}");
    let txt = Http::get(&get_path(1)).wait;
    // ...
}
```

`corofy`で変換して以下のようなcodeを出力します。

```rust
fn async_main() -> impl Future<Output=String> {
    Coroutine0::new()
}
        
enum State0 {
    Start,
    Wait1(Box<dyn Future<Output = String>>),
    Wait2(Box<dyn Future<Output = String>>),
    // ...
    Resolved,
}

struct Coroutine0 {
    state: State0,
}

impl Coroutine0 {
    fn new() -> Self {
        Self { state: State0::Start }
    }
}

impl Future for Coroutine0 {
    type Output = String;

    fn poll(&mut self) -> PollState<Self::Output> {
        loop {
        match self.state {
            State0::Start => {
              // ...
            }

            State0::Wait1(ref mut f1) => {
              / ...
            }
        }
    }
}
```

動く具体例があるので、`.await`を書くたびにstateが定義されるというのがとてもわかりやすいと思いました。また、変換処理を自作することで後述のself referenceの問題のわかりやすさにも繋がっていると思いました。


## Chapter 8: Runtimes, Wakers, And The Reactor-Executor Pattern

7章では、作っていなかったRuntimeを作ります。reactorにはmioを使います。
自分はruntimeはfutureをpollしてくれているくらいの理解で、reactor(mio)をどのように利用するのかがピンときていなかったので本章はとてもありがたかったです。最初はexecutorが直接reactorに依存する形で実装したのち、executorとreactorを疎結にするために、`Waker`を利用した形にしていくという流れなのもわかりやすかったです。  
`Waker`のwake処理は`Thread::unpark()`を利用します。threadのpark関連は[Rustアトミック操作とロック](https://blog.ymgyt.io/entry/rust-atomics-and-locks-ja/)で詳しく説明してくれていたので、すんなり理解できたのがうれしかったです。  
(なお、本章の例ではwork stealまでは実装されません。)


## Chapter 9: Coroutines, Self-Referential Struct, And Pinning

RustのFutureといえば、Pinみたいなところがありますが、実はこれまでの例では巧妙にPinの問題を避けていました。  
本章では以下のようにwaitをまたいで関数内の変数(`counter`)の参照を追加することで、生成されるstateにlocal変数を保持できるような対応を追加します。

```rust
coroutine fn async_main() {
    let mut counter = 0;
    let txt = http::Http::get("/600/HelloAsyncAwait").wait;
    counter += 1;
    let txt = http::Http::get("/400/HelloAsyncAwait").wait;
    counter += 1;
    // ...
}
```

これによって、async(coroutine)内で書いたlocal変数がどのように変換されるかを理解したあとに本命のself referenceの問題が紹介されます

```rust
coroutine fn async_main() {
    let mut buffer = String::from("\nBUFFER:\n----\n");
    let writer = &mut buffer;
    let txt = http::Http::get("/600/HelloAsyncAwait").wait;
    let txt = http::Http::get("/400/HelloAsyncAwait").wait;
    writeln!(writer, "{txt}").unwrap();
}
```

上記のように、`&mut buffer`のような参照をlocal変数とすると

```rust
#[derive(Default)]
struct Stack0 {
    buffer: Option<String>,
    writer: Option<*mut String>,
}

struct Coroutine0 {
    stack: Stack0,
    state: State0,
    _pin: PhantomPinned,
}
```

生成されるstate(`Coroutine0`)で自身のfieldへの参照(保持できないのでpointer)を保持する必要があり、このstructをmoveするとpointerの参照が壊れてしまうとつながります。  
ここから、`Pin`や`Unpin`の解説があります。`Pin`の説明は図が豊富で、local変数の参照をstruct fieldに変換する処理を実際に動くコードにしてくれているので、具体的でわかりやすいです。


## Chapter 10: Creating Your Own Runtime

これまで利用してきた自作のWakerであったりFuture traitであったりをrustのstdのものにしてyour own runtimeを完成させます。 

```toml
[dependencies]
mio = { version = "0.8", features = ["net", "os-poll"] }
```

mioだけの依存で、以下のコードが動くようになります!

```rust
fn main() {
    let mut executor = runtime::init();
    executor.block_on(async_main());
}

async fn async_main() {
    println!("Program starting");
    let txt = Http::get("/600/HelloAsyncAwait").await;
    println!("{txt}");
    let txt = Http::get("/400/HelloAsyncAwait").await;
    println!("{txt}");
}
```

現状のRustの非同期エコシステムの課題の説明もあります。
tokioでasync_stdの違いとしてreactorの明示的な起動を要求するかどうかであったり、Ascyn dropについてが解説されます。


[mio]: https://github.com/tokio-rs/mio
