+++
title = "📕 Rust Atomics and Locksを読んだ感想"
slug = "rust_atomics_and_locks"
date = "2022-12-31"
draft = false
description = "Rust Atomics and Locksが非常によかったので感想を書いた"
[taxonomies]
tags = ["rust","book"]
[extra]
image = "images/emoji/closed_book.png"
+++

## 読んだ本

{{ figure(images=["images/rust_atomics_and_locks_book.jpeg"], href="https://marabos.nl/atomics/") }}

[Rust Atomics and Locks](https://marabos.nl/atomics/)  
著者: [Mara Bos](https://m-ou.se/)

楽しみにしていたRust Atomics and Locksを読んだので感想を書いていきます。  
Kindle版の 2022-12-14 First Releaseを読みました。


## まとめ

非常におもしろく是非おすすめしたい本です。  
なんといっても、一冊まるごとAtomicとLockについて書かれており[`std::sync::atomic::Ordering`](https://doc.rust-lang.org/std/sync/atomic/enum.Ordering.html)がわからない自分のために書かれたのではと錯覚してしまうほどに刺さりました。    
また、説明の後には必ず具体例をつけてくれるので理解を確かめられながら読み進められる点もうれしいです。  
特に以下のような方におすすめしたいです。(全て自分のことなのですが)

* `atomic` api(`AtomicI32::{compare_exchange,load,...}`)を使う際の`Ordering`(`Relaxed`,`Acquire`,`SeqCst`,...)に自信がなかったり、その意図がわからない
    * `Ordering`よくわからないが、困ったら`SeqCst`渡しておけばよいと思っている
    * [`compare_exchange`](https://doc.rust-lang.org/std/sync/atomic/struct.AtomicBool.html#method.compare_exchange)のapi documentの説明を読んでもピンとこない
* happens-before relationshipsという用語を聞いたことはあるがよくわかっていない
* [`qnighy先生のアトミック変数とメモリ順序`](https://qiita.com/qnighy/items/b3b728adf5e4a3f1a841#)が難しかった
* Building Our Own `{Spin Lock,Oneshot Channel,Arc,Condvar,Mutex,RwLock}`をやってみたい



## Chapter 1 Basics of Rust Concurrency

本書で登場するRustの型や概念について説明されます。  
具体的には以下です。

* `std::thread`の`spawn()`や`scope()`の使い方
* `Rc`、`Arc`やInterior mutability(`RefCell`,`Mutex`,...)
* thread safety(`Send`,`Sync`)
* `std::sync::{Mutex, Condvar}`の基本
* `thread::park()`や`Thread::unpark()`の使い方

Rustについての本でありがちな[the book](https://doc.rust-lang.org/book/)に書かれていることと同じ内容が数章に渡って続き、traitの解説が終わってようやくその本独自のコンテンツみたいなことはないです。  
[`1.63.0`でstableになった](https://blog.rust-lang.org/2022/08/11/Rust-1.63.0.html)`std::thread::scope`も沢山でてきます。 

### Interior mutability

Interior Mutabilityのところで、今まで`&`はimmutable referenceと説明されてきたが、`Arc`等のinterior mutabilityが出てくるとこの表現は混乱を招くと言及されています。  
この点は[dtolnay先生のessay](https://docs.rs/dtolnay/latest/dtolnay/macro._02__reference_types.html#accurate-mental-model-for-rusts-reference-types)でも言及されており、immutable/mutable referenceという表現はRust初学者には直感的だが、shared reference/exclusive referenceという名称がより好ましいとしています。(essayをrust docとして公開する発想が最高だと思います)
ということで自分も、`&`はshared referenceで基本的には変更されないが例外もある、`&mut`はexclusive referenceでexclusive borrowingであることが保証されるという理解でいこうと思います。

### UnsafeCell

`UnsafeCell`はinterior mutability(`&self`で自身の状態を変更する)のprimitive building blockであるとされ、このあとのLockやArcを実装の具体例でも必ず登場します。役割は、`UnsafeCell<T>`として、`get()`で`T`のraw pointer(`*mut`)を提供することです。raw pointerのdereferenceはunsafe blockの中でしかできないので、実装者がundefined behaviorを避けなければならないです。  
Rustでinterior mutabilityを提供している型はすべて`UnsafeCell`のwrapperです。

### Thread parking

thread parkについては使ったことがなく、知りませんでした。  
taskを複数のthreadに分割すると、どこかで結果を受け取るthreadにtaskの完了を通知したくなります、thread parkingはそんな時に利用できるthread間の通信機構です。

```rust
use std::collections::VecDeque;
use std::sync::Mutex;
use std::thread;
use std::time::Duration;

fn main() {
    let queue = Mutex::new(VecDeque::new());

    thread::scope(|s| {
        // Consuming thread
        let t = s.spawn(|| loop {
            let item = queue.lock().unwrap().pop_front();
            if let Some(item) = item {
                dbg!(item);
            } else {
                thread::park();
            }
        });

        // Producing thread
        for i in 0.. {
            queue.lock().unwrap().push_back(i);
            t.thread().unpark();
            thread::sleep(Duration::from_secs(1));
        }
    });
}
```

[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch1-11-thread-parking.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch1-11-thread-parking.rs)

consuming threadはqueueからmessageを受け取り、consume(`dbg!()`)します。queueが空の場合は、`thread::park()`を呼び出し、sleepします。  
producing threadは定期的にqueueにmessageをenqueueします。enqueueしたあとに`Thread::unpark()`を呼び出します。`thread::spawn()`の戻り値の`JoinHandle`を保持することでunparkするthreadを指定します。  

thread parkingで重要なのは、thread-1が`park()`する前にthread-2が`unpark()`を呼び出しても、`unpark()`が呼び出されたという情報が保持され、thread-1が`park()`してもsleepすることなくすぐにreturnしてくれることです。この特性のおかげで、`unpark()`する側のthreadは対象のthreadが実際に`park()`でsleepしているかどうかを気にしなくてよくなります。ただし、`unpark()`を複数回呼び出しても、一度`park()`が呼ばれると、次の`park()`ではsleepします。


### `std::sync::Condvar`

`std::sync::Condvar`についての解説もあります。

```rust
use std::collections::VecDeque;
use std::sync::Condvar;
use std::sync::Mutex;
use std::thread;
use std::time::Duration;

fn main() {
    let queue = Mutex::new(VecDeque::new());
    let not_empty = Condvar::new();

    thread::scope(|s| {
        s.spawn(|| {
            loop {
                let mut q = queue.lock().unwrap();
                let item = loop {
                    if let Some(item) = q.pop_front() {
                        break item;
                    } else {
                        q = not_empty.wait(q).unwrap();
                    }
                };
                drop(q);
                dbg!(item);
            }
        });

        for i in 0.. {
            queue.lock().unwrap().push_back(i);
            not_empty.notify_one();
            thread::sleep(Duration::from_secs(1));
        }
    });
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch1-12-condvar.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch1-12-condvar.rs)

thread parkingと同様の例で、queueが空の場合に`Condvar`を利用して同期します。  

```rust
let mut q = queue.lock().unwrap();
let item = loop {
    if let Some(item) = q.pop_front() {
        break item;
    } else {
        q = not_empty.wait(q).unwrap();
    }
};
```
`Condvar::wait`は事前に`Mutex::lock()`で取得した`MutexGuard`を渡して、待機して条件が満たされると再び、戻り値として`MutexGuard`が返され処理を再開できる、最初にみると不思議なapiをしています。`wait()`の中で渡した`MutexGuard`がdropされ`Mutex`がunlockされるので、lockを保持したままsleepするわけではないのですが、そのあたりの挙動がわかりづらいです。  
Chapter 9で実際にOwn `Condvar`を実装していくので、どうしてこのようなapiになっているかの理解が深まります。


## Chapter 2 Atomics

いよいよ本題のatomicについてです。  
Rustにおけるatomic operationは`std::sync::atomic::Ordering`を引数にとります。  
これはoperationのorderに関してどのような保証が必要かを宣言するために必要です。  
Chapter 2ではorderingとして`Relaxed`だけを使います。`Relaxed`は二つの変数に関するoperationの順番を保証してくれません。thread-1が変数a->bと変更した場合でも、thread-2からは変更前の変数aと変更後の変数bがみえる場合がありえるという意味です。  
ただ`Relaxed`で足りる場面ももちろんあり、Chapter 2ではorderingの話をおいておいてatomic apiに慣れていきます。この章構成は非常にわかりやすいと感じました。

```rust
use std::sync::atomic::AtomicUsize;
use std::sync::atomic::Ordering::Relaxed;
use std::thread;
use std::time::Duration;

fn main() {
    let num_done = &AtomicUsize::new(0);

    thread::scope(|s| {
        // Four background threads to process all 100 items, 25 each.
        for t in 0..4 {
            s.spawn(move || {
                for i in 0..25 {
                    process_item(t * 25 + i); // Assuming this takes some time.
                    num_done.fetch_add(1, Relaxed);
                }
            });
        }

        // The main thread shows status updates, every second.
        loop {
            let n = num_done.load(Relaxed);
            if n == 100 { break; }
            println!("Working.. {n}/100 done");
            thread::sleep(Duration::from_secs(1));
        }
    });

    println!("Done!");
}

fn process_item(_: usize) {
    thread::sleep(Duration::from_millis(123));
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch2-06-progress-reporting-multiple-threads.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch2-06-progress-reporting-multiple-threads.rs)

`Relaxed`で問題ない場合の一例として、thread間で共有される変数が1つの場合があります。上記では`num_done`だけが関心の対象なので`Relaxed`で特に問題が生じません。

### Compare-and-Exchange Operations

今後も頻繁に登場し、最もflexibleなatomic operationである`compare_exchange`について。  

```rust
impl AtomicI32 {
    pub fn compare_exchange(
        &self,
        expected: i32,
        new: i32,
        success_order: Ordering,
        failure_order: Ordering
    ) -> Result<i32, i32>;
}
```
Bos, Mara. Rust Atomics and Locks (p. 80). O'Reilly Media. Kindle Edition.

`compare_exchange`は自身の値が`expected`で指定された値と同じ場合に限って、`new`の値を書き込み、書き込み前の値を返します。戻り値は以前の値で、exchangeが成功した場合はこれは`expected`と一致します。  
難しいのは、`Ordering`を二つ渡す必要があるところです。失敗時(現在の値と`expected`が一致しない)には、現在の値をloadする処理のみが走るはずなので、`Ordering`の指定は一つだと思いますが、成功時はloadして、storeするはずなのに、`Ordering`の指定は1つなところが粒度があっていなくてピンときていませんでした。

```rust
use std::sync::atomic::AtomicU32;
use std::sync::atomic::Ordering::Relaxed;

fn increment(a: &AtomicU32) {
    let mut current = a.load(Relaxed);
    loop {
        let new = current + 1;
        match a.compare_exchange(current, new, Relaxed, Relaxed) {
            Ok(_) => return,
            Err(v) => current = v,
        }
    }
}

fn main() {
    let a = AtomicU32::new(0);
    increment(&a);
    increment(&a);
    assert_eq!(a.into_inner(), 2);
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch2-11-increment-with-compare-exchange.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch2-11-increment-with-compare-exchange.rs)

上記は、`compare_exchange`を利用して変数aをincrementする例です。失敗した場合の戻り値を`current`に代入してloopを再開しているところがポイントです。  

`compare_exchage`には`compare_exchange_weak`という似ている処理があります。  
これは現在の値と`expected`が一致する場合でも、exchangeが失敗する場合がある処理です。  
上記のincrementの例は失敗した場合でのretryのcostが安いのでweakのほうが好ましいとされています。

```rust
use std::sync::atomic::AtomicU64;
use std::sync::atomic::Ordering::Relaxed;

fn get_key() -> u64 {
    static KEY: AtomicU64 = AtomicU64::new(0);
    let key = KEY.load(Relaxed);
    if key == 0 {
        let new_key = generate_random_key();
        match KEY.compare_exchange(0, new_key, Relaxed, Relaxed) {
            Ok(_) => new_key,
            Err(k) => k,
        }
    } else {
        key
    }
}

fn generate_random_key() -> u64 {
    123
    // TODO
}

fn main() {
    dbg!(get_key());
    dbg!(get_key());
    dbg!(get_key());
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch2-13-lazy-one-time-init.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch2-13-lazy-one-time-init.rs)

`compare_exchange_weak`では適さず、`compare_exchange`を使うべき場面の一例として、lazy initializationの例が挙げられていました。  
`get_key`はapplicationで利用するkeyを返す処理で、最初に取得を要求したときに生成されます。(lazy)  
ただし、一度生成された場合は必ず同じ値を返す必要があり、同時に二つのthreadから呼ばれた場合に同時に生成処理が走り、異なる値を返すといったことは許容されないケースです。  
この場合でも関心の対象の変数は1つなので`Relaxed`で問題ないのですが、生成時に、`compare_exchange`で必ず現在の値が初期化されていない(0)ことを厳密に確かめたいのでここではweakが使えません。

この他にもoverflowへの対処の仕方等おもしろい話がのっています。  
compare_exchangeの使い方もわかったので次はいよいよMemory Orderingです。


## Chapter 3 Memory Ordering

いよいよmemory orderingについてです。  
この章だけでも本書を買う価値があると思います。

### Reordering

まず前提としてcompilerもcpu processorもprogramを書かれた通りの順番で実行してくれるとは限りません。  
この点は[なぜ違う値を見たのかーー並列実行におけるCPUの動作](https://tech.unifa-e.com/entry/2018/07/24/120258)で

> 1. コンパイル
> 1. CPUで実行する
> 1. CPUのキャッシュによるreorderような現象

というCPU側でも2段階あるという説明がわかりやすかったです。  
CPUのキャッシュによるreorderのような現象に関しては上記ブログで参照されていた[Memory Barriers: a Hardware View for Software Hackers](http://www.rdrop.com/users/paulmck/scalability/paper/whymb.2010.07.23a.pdf)の説明を読んで確かにreorderされますね..という気持ちになりました。  

そしてRustにおいてcompilerとprocessorにreorderに関して制約を伝えたい場合に利用できるのは

* `Relaxed`
* `Release, Acquire, AcqRel`
* `SeqCst`

の3種類です。C++ではconsume orderingというものもあるとのことですが、Rustにはありません。

### Happens-Before Relationship

processorの様々な機構によりreorderは起きるのですが、それらをすべて抽象化して、要は他のthreadで行われた変数への変更が現在実行中のthreadから見えるのか見えないのかをhappens-before relationshipという概念で定義します。  
はっきり書かれていませんが、"happen"というのはthreadから見えるという意味で理解しています。  

まず当たり前に思えるかもしれませんが、同一thread内ではすべてin orderにhappenします。  
このルールがあるのでsingle threadのprogrammingの文脈ではreorderを意識しなくてよく、したがってatomicのorderも考えなくてよいわけでした。

threadの`spawn()`,`join()`でもそれぞれのthread間でhappens-beforeの関係が結ばれます。  
具体的には`thread::spawn()`でできたthreadからはその前の変数の変更が見え、そのthreadをjoinするとthread内で行われた変数の変更が見えることが保証されます。

[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch3-02-spawn-join.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch3-02-spawn-join.rs)

### Release and Acquire Ordering

Releaseとacquire orderingはhappens-before relationshipを生じさせるためにpairで使い、releaseはstore operationに、acquireはload operationに指定するというのがまず、前提。  

> A happens-before relationship is formed when an acquire-load operation observes the result of a release-store operation. In this case, the store and everything before it, happened before the load and everything after it.

Bos, Mara. Rust Atomics and Locks (p. 101). O'Reilly Media. Kindle Edition.

この説明が本当にわかりやすかったです。thread-1があるatomic変数にreleaseでstoreして、その結果を別のthread-2がacquireでloadすると、happens-beforeの関係がなりたち、thread-1の当該atomic変数以外の変更もthread-2から見えるようになると、理解しています。

具体例でみたほうがわかりやすいですね。

```rust
static DATA: AtomicU64 = AtomicU64::new(0);
static READY: AtomicBool = AtomicBool::new(false);

fn main() {
    thread::spawn(|| {
        DATA.store(123, Relaxed);
        READY.store(true, Release); // Everything from before this store ..
    });
    while !READY.load(Acquire) { // .. is visible after this loads `true`.
        thread::sleep(Duration::from_millis(100));
        println!("waiting...");
    }
    println!("{}", DATA.load(Relaxed));
}
```
https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch3-06-release-acquire.rs

`READY.store(true,Release)`でrelease storeした結果を、`!READY.load(Acquire)`で読んでいるので、happens-beforeの関係が成立し、`DATA.store(123,Relaxed)`の結果がmain threadから見えることが保証されるので、上記の出力結果が123になることが保証されます。  
また、この点が重要なのですが、上記では同期したい変数が`DATA: AtomicU64`のようにatoimc変数でしたが、happens-before relationshipの対象になるのにatomic変数である必要はありません、ただthread間で共有するために`Sync`である必要があるので、`AtomicU64`だっただけです。

```rust
static mut DATA: u64 = 0;
static READY: AtomicBool = AtomicBool::new(false);

fn main() {
    thread::spawn(|| {
        // Safety: Nothing else is accessing DATA,
        // because we haven't set the READY flag yet.
        unsafe { DATA = 123 };
        READY.store(true, Release); // Everything from before this store ..
    });
    while !READY.load(Acquire) { // .. is visible after this loads `true`.
        thread::sleep(Duration::from_millis(100));
        println!("waiting...");
    }
    // Safety: Nothing is mutating DATA, because READY is set.
    println!("{}", unsafe { DATA });
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch3-07-release-acquire-unsafe.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch3-07-release-acquire-unsafe.rs)

つまり、上記の例のように同期の対象を`u64`にしてもunsafeを伴うものの、`AtomicU64`同様に123が出力されることが保証されます。

いやー、本当にわかりやすいですね。要は他のthreadに見せたい変更を実施したのち制御用のatomic変数にreleaseでstoreすると、当該変数をacquireでloadしたthreadに変更が見えるようになるという理解です。  
より複雑なケースでも理解できるかあやしいですが、これくらいなら自分でも理解できました、もしかしてhappens-before relationshipわかりやすいのか。

ということで次の例はちょっとだけ応用編です。

```rust
fn get_data() -> &'static Data {
    static PTR: AtomicPtr<Data> = AtomicPtr::new(std::ptr::null_mut());

    let mut p = PTR.load(Acquire);

    if p.is_null() {
        p = Box::into_raw(Box::new(generate_data()));
        if let Err(e) = PTR.compare_exchange(
            std::ptr::null_mut(), p, Release, Acquire
        ) {
            // Safety: p comes from Box::into_raw right above,
            // and wasn't shared with any other thread.
            drop(unsafe { Box::from_raw(p) });
            p = e;
        }
    }

    // Safety: p is not null and points to a properly initialized value.
    unsafe { &*p }
}

struct Data([u8; 100]);

fn generate_data() -> Data {
    Data([123; 100])
}

fn main() {
    println!("{:p}", get_data());
    println!("{:p}", get_data()); // Same address as before.
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch3-09-lazy-init-box.rs](https://github.com/m-ou-se/rust-atomics-and-locks/blob/main/examples/ch3-09-lazy-init-box.rs)

前回は扱っていたdataは1変数でしたが、今回は`Data([u8; 100])`でatomicに書き換えができません。  
そこで、そのdataを扱うpointerをatomicにすることで、データの初期化処理をatomicに切り替えられるようにします。  
今回の`compare_exchange`は以下のようになっています。

```rust
p = Box::into_raw(Box::new(generate_data()));
if let Err(e) = PTR.compare_exchange(
    std::ptr::null_mut(), p, Release, Acquire
) {
    // Safety: p comes from Box::into_raw right above,
    // and wasn't shared with any other thread.
    drop(unsafe { Box::from_raw(p) });
    p = e;
}
```

`compare_exchange`の第一引数には`Release`を指定します。これは処理が成功した場合に後続のload処理に対して  
`p = Box::into_raw(Box::new(generate_data()));`を見えるようにしておくためです。  
ポイントは第二引数の`Acquire`です。この`compare_exchage`が失敗するということは`get_data()`が同時に複数のthreadから呼ばれ、既に、`Data`が初期化された場合です。その際には`Err(e)`にその初期化された`Data`のpointerが入るのですがそのpointerの先の初期化処理も確実にみえている必要があるので、`Acquire`を指定していると考えています。  
本書では上記のようなhappens-beforeの例が図で示されており非常に直感的なので是非読んでみて欲しいです。


### Fences

`std::sync::atomic::fence`という関数があり、release storeやacquire loadは`fence`を使って以下のように書き直すことができることが説明されます。

```rust
a.store(1, Release);

// 👇

fence(Release);
a.store(1, Relaxed);
```

```rust
a.load(Acquire);

// 👇

a.load(Relaxed);
fence(Acquire);
```

releaseやacquireをfenceに分割した際の利点としてif等のconditionと併用できる点があります。  
具体的な使い方はこのあとの実装ででてきます。

### Common Misconceptions

memory orderingに関してよくみられる誤解について説明されます。  
似たような誤解をもっていておもしろかったです。  
例えば

> Myth: I need strong memory ordering to make sure changes are “immediately” visible.

Bos, Mara. Rust Atomics and Locks (p. 124). O'Reilly Media. Kindle Edition.

なんか`Relaxed`使うと値の反映が遅くなる感を自分をもっていましたが、そんなことはないそうです。  
その他にも`Relaxed` operation are freeであったり、`SeqCst`を使っておけばいつでも正しいといったものもあります。


## Chapter 4 Building Our Own Spin Lock

これまでの知識を使って、SpinLockを実装していきます。  
SpinLockとは、lockの取得を試み、既にlockされていた場合はsleep等で待機してなんらかの機構でlockの再取得のタイミングを通知してもらうのではなく、loopでlockを取得できるまでtryし続けるLockです。

本書の素晴らしい点は、いきなり完成品を提示して数行解説という流れではなく、step by stepで実装を改善しながら解説をすすめてくれる点です。  
具体的には

```rust
pub struct SpinLock {
    locked: AtomicBool,
}

impl SpinLock {
    pub const fn new() -> Self {
        Self { locked: AtomicBool::new(false) }
    }

    pub fn lock(&self) {
        while self.locked.swap(true, Acquire) {
            std::hint::spin_loop();
        }
    }

    pub fn unlock(&self) {
        self.locked.store(false, Release);
    }
}
```

このような最小限の実装から、`UnsafeCell`の導入 -> `unlock()`をlockを取得したthreadから確実に呼ばれるapiにするために`Guard`の導入のように進んでいきます。  
chapter 3で見てきたhappens-beforeの具体例のみならずrustの勉強にもなってとても参考になりました。


## Chapter 5 Build Our Own Channels

続いてthread間でdataを送るchannelを作っていきます。channelもusecaseに応じていろいろな形があるのですが、この章では[`tokio::sync::oneshot`](https://docs.rs/tokio/latest/tokio/sync/oneshot/index.html)のような一度だけ値をsendできるchannelを作っていきます。  
`UnsafeCell`に加えてunsafe版の`Option`として`MaybeUninit`がでてきます。  
最初は間違った使い方をされた際はpanicしていく実装から初めてそこから型を通じてapiを安全していく過程が参考になりました。またatomicの話とは逸れますが、Arcを使ってallocationを受け入れる実装からborrowしてallocationを避ける実装への変更の仕方もRustの勉強になりました。

## Chapter 6 Building Our Own "Arc"

本章では自前の`std::sync::Arc`を作っていきます。  

```rust
use std::ptr::NonNull;

struct ArcData<T> {
    ref_count: AtomicUsize,
    data: T,
}

pub struct Arc<T> {
    ptr: NonNull<ArcData<T>>,
}
```

`Arc`には[`Arc::get_mut()`](https://doc.rust-lang.org/std/sync/struct.Arc.html#method.get_mut)という、現在の参照数が1のときに`&mut T`を返す処理があるのですが、この処理の実装でさきほどのfenceがでてきます。

```rust
impl<T> Arc<T> {
    // ...
    pub fn get_mut(arc: &mut Self) -> Option<&mut T> {
        if arc.data().ref_count.load(Relaxed) == 1 {
            fence(Acquire);
            // Safety: Nothing else can access the data, since
            // there's only one Arc, to which we have exclusive access.
            unsafe { Some(&mut arc.ptr.as_mut().data) }
        } else {
            None
        }
    }
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/c5f3bbaac5b01acc05870a7e0ab6aef1ab441f3b/src/ch6_arc/s1_basic.rs#L33](https://github.com/m-ou-se/rust-atomics-and-locks/blob/c5f3bbaac5b01acc05870a7e0ab6aef1ab441f3b/src/ch6_arc/s1_basic.rs#L33)

また、dropされた`Arc`が最後の一つだった場合に、確保したallocationをdropする処理を走らせたいのですがその際にもfenceを利用していました。

```rust
impl<T> Drop for Arc<T> {
    fn drop(&mut self) {
        if self.data().ref_count.fetch_sub(1, Release) == 1 {
            fence(Acquire);
            unsafe {
                drop(Box::from_raw(self.ptr.as_ptr()));
            }
        }
    }
}
```
[https://github.com/m-ou-se/rust-atomics-and-locks/blob/c5f3bbaac5b01acc05870a7e0ab6aef1ab441f3b/src/ch6_arc/s1_basic.rs#L64](https://github.com/m-ou-se/rust-atomics-and-locks/blob/c5f3bbaac5b01acc05870a7e0ab6aef1ab441f3b/src/ch6_arc/s1_basic.rs#L64)

これはdropされる前の変更処理がallocationのdrop時(ref_countが1->0)のときにだけ見えている必要があるためと理解しています。  
さらにこの後、循環参照を行えるように`Weak`の実装も追加していき、その後`Weak`のcostを必要なときだけ払うようにoptimizeしていきます。`Arc`の`Weak`は最初わかりづらかったのですが、実装していく中で内部構造の理解が進みました。

## Chapter 7 Understanding the Processor

本章ではatomic operationが実際にはどんな命令にcompileされるのかを見ていきます。  
対象となるCPU architectureはx86-64とARM64です。target tripleでいうと`x86_64-unknown-linux-musl`と`aarch64-unknown-linux-musl`です。  
Programからcompileされたcodeのassemblyを得る方法として、[cargo-show-asm](https://github.com/pacak/cargo-show-asm)と[Compiler Explorer](https://godbolt.org/)が紹介されています。  

cargo-show-asmに関しては`cargo install cargo-show-asm`でinstallしたのち 

`lib.rs`に

```rust
use std::sync::atomic::AtomicI64;
use std::sync::atomic::Ordering::Relaxed;

pub fn a(x: &AtomicI64) {
    x.fetch_add(10, Relaxed);
}
```

上記のような関数を定義した状態で

```sh
❯ cargo asm --lib a
    Finished release [optimized] target(s) in 0.02s

.section __TEXT,__text,regular,pure_instructions
        .build_version macos, 11, 0
        .globl  rust_atomics_and_locks_handson::a
        .p2align        2
rust_atomics_and_locks_handson::a:
Lfunc_begin0:
        .cfi_startproc
        mov w8, #10
        ldadd x8, x8, [x0]
        ret
```

のように関数名を引数で渡して実行するとassemblyを表示することができました。  
M1 Mac(aarch64)では、Relaxedのfetch_addは`ldadd`命令になることがわかりました。  

Compiler Explorerではcompilerへのoptionに`--target=aarch64-unknown-linux-musl -O`を渡すことでaarch64をtargetにすることができました。 https://godbolt.org/z/64vo1cvTj

`load()`,`store()`, `fetch_add()`や`compare_exchange()`等の命令が各種Orderを指定した場合にx86とarm64でそれぞれどういった命令になるかが解説されます。それぞれのCPU architectureの命令等を知っているとより深く理解できると思います。  
arm64のLoad-Linked and Store-Conditional Instructionsについては[並行プログラミング入門](https://www.oreilly.co.jp/books/9784873119595/)に解説が載っていました。

### Caching

本書の発売自体は[2022年の4月くらいには予告](https://twitter.com/YAmaguchixt/status/1515098396981608449)されており、そこでの目次でCPUの内部構造にも触れそうとわかっていたので、すこしでもCPUについて詳しくなりたいと思っていました。  
そこで自分が本書を読む前に予習として以下のCPU関連の本を読みました。

* [もっとCPUの気持ちが知りたいですか?](https://peaks.cc/cpu_no_kimochi) ([感想](https://blog.ymgyt.io/entry/cpu_no_kimochi)も書きました)
* [プロセッサを支える技術](https://www.amazon.co.jp/dp/4774145211/)
* ~~パタヘネ6版も挑戦しましたが難しかったです~~

そこでわかった(自分にとっての)驚愕の事実としては、CPUはコアごとにcacheを保持しており、cache間の整合性を保つためのプロトコルがある。例えば、コア-1が今から変数aに値を書き込むから他のコア達に変数aのcacheもっていたら無効化してねというリクエストを送信し、他のコアはそれをうけとって自身が保持している変数aのcacheを無効にしたりしているというものです。  
さらに(恐ろしいのは),cacheへの書き込みをsystem callの回数を抑えるためにBufferにwriteするのと同じようにbufferする機構(Store Buffer)があったり、無効化リクエストを専用のqueue(invalidate queue)で受け付けていたりするというものでした。もうCPUが一つの分散システムのようです。

というくらいの前提で本章を読みました。本書でもMESI protocolというcacheの整合性(coherence)を保つためのprotocolについての解説がでてきます。 本章がおもしろいのはそれらの概念をRustのcodeで実際に検証していくところです。

まずは以下のコードを実行してみましょう。

```rust
static A: AtomicU64 = AtomicU64::new(0);

fn main() {
    let start = Instant::now();
    for _ in 0..1_000_000_000 {
        A.load(Relaxed);
    }
    println!("{:?}", start.elapsed());
}
```

atomic変数を10億回loadするprogramです。この処理がどれくらいかかると思いますか？
答えは0msでした。

```sh
❯  cargo run --example ch7_bench --release --quiet
0ns
```

理由はcompilerがこのloopはなにもしていないとして最適化してしまうからとあります。なので意図通りにするには

```rust
use std::hint::black_box;

static A: AtomicU64 = AtomicU64::new(0);

fn main() {
    black_box(&A);
    let start = Instant::now();
    for _ in 0..1_000_000_000 {
        black_box(A.load(Relaxed));
    }
    println!("{:?}", start.elapsed());
}
```

`std::hint::black_box()`を利用してcompilerの最適化を調整します。  
自分の環境では概ね320ms前後の実行時間がかかりました。

```sh
❯  cargo run --example ch7_bench --release --quiet
317.6865ms
```

ここから他threadを動かしたらどうなるかや、わざとcache line(cacheの単位)に乗らないようにしてみたらどの程度性能が劣化するか等を検証していきます。cache lineの実在を体感できます。


## Chapter 8 Operating System Primitives

効率的にthreadをblockするには、OSの助けを借りる必要があります。  
そこで本章ではLinux, macOS, Windowsでどういった仕組みが提供されているのかについて解説してくれます。またここで解説されるfutexについては[atomic-wait](https://github.com/m-ou-se/atomic-wait) crateを使ってchapter 9で実際に利用します。

## Chapter 9 Building Our Own Locks

本章ではchapter 8で紹介されたfutexの機能を抽象化して提供してくれている[atomic-wait](https://github.com/m-ou-se/atomic-wait)をベースにして`Mutex`, `Condvar`, `RwLock`を実装していきます。これまでのようにまずはシンプルな形からスタートして徐々に改良していくアプローチが採られています。  
system callを減らすためにまずはspin lockを試してからwaitしたりととても勉強になります。  
`Condvar`も作ってみるとどうして`wait()`が`MutexGuard`をつけとって、`MutexGuard`を返すようなapiになるのか納得できました。またここでもhappens-beforeの図を示してくれるのでとてもわかりやすいです。


## Chapter 10 Ideas and Inspiration

最終章ではこれまでに扱えなかった、concurrency related topicsが紹介されます。 
SemaphoreやLock-Free Linked List等々紹介されます。  
Lockにもいろいろな実装があるのだと知りました。  

最後の後書きがとても素敵なので是非読んでみてください!


## 最後に

簡単にではありますがとてもよい本だったので勢いで感想を書いてしまいました。
たまたま去年の12/31日は、[Rust for Rustaceans](https://blog.ymgyt.io/entry/books/rust_for_rustaceans)の感想を書いていました。  
この本もおすすめです🦀

それでは皆様良いお年を🎍  

## 参考

* [本書のページ](https://marabos.nl/atomics/)
    * [Errata](https://www.oreilly.com/catalog/errata.csp?isbn=0636920635048)
* [Github code example](https://github.com/m-ou-se/rust-atomics-and-locks)
* [アトミック変数とメモリ順序](https://qiita.com/qnighy/items/b3b728adf5e4a3f1a841#)
* なぜ違う値をみたのか
    * [https://tech.unifa-e.com/entry/2019/03/04/130455](https://tech.unifa-e.com/entry/2019/03/04/130455)
    * [https://tech.unifa-e.com/entry/2018/07/24/120258](https://tech.unifa-e.com/entry/2018/07/24/120258)
    * [http://www.rdrop.com/users/paulmck/scalability/paper/whymb.2010.07.23a.pdf](http://www.rdrop.com/users/paulmck/scalability/paper/whymb.2010.07.23a.pdf)

