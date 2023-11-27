+++
title = "📕 詳解 Rustアトミック操作とロックを読んだ感想"
slug = "rust-atomics-and-locks-ja"
description = "std::sync::atomic::{Ordering,fence}がわかる本"
date = "2023-11-28"
draft = false
[taxonomies]
tags = ["rust","book"]
[extra]
image = "images/emoji/closed_book.png"
+++

## 読んだ本

{{ figure(images=["images/raal-ja-book.jpeg"]) }}

[詳解 Rustアトミック操作とロック](https://www.oreilly.co.jp/books/9784814400515/)  

著者: [Mara Bos](https://m-ou.se/)  
訳者: [中田秀基](https://twitter.com/hidemotoNakada)

あの、[Rust Atomics and Locks](https://marabos.nl/atomics/)の日本語翻訳がついに販売されました。  
Rust Atomics and Locksについては去年、[読んだ感想](https://blog.ymgyt.io/entry/rust_atomics_and_locks/)を書きました。  

本記事ではあらためて日本語訳を読んだ感想を書きます。  

## Rust Atomics and Locksを読んでから

Rust Atomics and Locksを読む前は、CPUはメモリから命令をfetchした後、実行して結果をregisterないしメモリに書き戻すというのが自分のメンタルモデルでした。  
CPUとメモリの間にはcacheがあるものの、performanceを考慮しなければプログラマーには透過的で意識しなくてよいものと思っていました。  
しかし、このメンタルモデルは誤っていることがわかりました。  実際はCPUコアごとに独立したcacheが存在している。CPUコアごとのcacheの整合性(cache coherence)を保つためにCPUコアはなんらかのprotocolでcacheの問い合わせや無効を行っている。cacheの更新自体もqueueでうけられて非同期。したがって、CPUコアAによる変数A,Bへの書き込みがなされても、CPUコアBには変数Bの変更しか観測されないという場合がありえる。   
と考えるようになりました。そのため、atomicについて知るにはもうすこしCPUのことがわかりたいと思うようになり、以下の本を読みました。  

* [もっとCPUの気持ちがしりたいですか?](https://blog.ymgyt.io/entry/cpu_no_kimochi/) 
* [プログラマーのためのCPU入門](https://blog.ymgyt.io/entry/what-a-programmer-should-know-about-the-cpu/)
* [プロセッサを支える技術](https://gihyo.jp/book/2011/978-4-7741-4521-1) 
* [RISC-V原典 オープンアーキテクチャのススメ](https://riscv.or.jp/risc-v-publication/)

これらの本を読んで、プログラムでは変数A,Bと変更してもそれがthread間でどう見えるかは

* Compilerによるreorder
* CPUのout of order実行
* CPUコアのcache coherence 

の影響をうけると考えるようになりました。  
つまり、ソースからは判断できない。  
そこでプログラマーが、変数AとBが、例えば、BがReadyを表し、BのReadyを確認してはじめてAを読んでよいというような変数間の依存関係を表現できるようにRustが、Platformに依存しない最大公約数的な保証が行える範囲でAPIを公開してくれている。それがstd::sync::atomicに現れている。という理解に至りました。 
あっているかわかりませんが、このような仮説をもって本書を読みました。
 
## まとめ

自分のように[`std::sync::atomic::Ordering`](https://doc.rust-lang.org/std/sync/atomic/enum.Ordering.html)や[`compare_exchange()`](https://doc.rust-lang.org/std/sync/atomic/struct.AtomicU32.html#method.compare_exchange)がよくわからないと思っている方に是非読んでみてほしいと思いました。  
`AtomicI32::store(Ordering::Release)`と`AtomicI32::load(Ordering::Acquire)`にどのような意図が込められているかわかるようになります。

また、具体例が豊富で、atomic関連だけでなくrust全般の理解も進むと思います。 


## 1章 Rust平行性の基本

本書で登場する型や各種概念について説明されます。  
具体的には

* `std::thread`の`spawn()`や`scope()`の使い方
* `Rc`、`Arc`やInterior mutability(`RefCell`,`Mutex`,...)
* thread safety(`Send`,`Sync`)
* `std::sync::{Mutex, Condvar}`の基本
* `thread::park()`や`Thread::unpark()`の使い方

[dtolnay先生のAccurate mental model for Rust's reference types](https://docs.rs/dtolnay/latest/dtolnay/macro._02__reference_types.html#accurate-mental-model-for-rusts-reference-types)でも述べられていますが、`&T`を不変ではなく共有参照、`&mut T`を可変でなく排他参照と考えるのがよいとされています。`Mutex`や`Atomic`変数がでてくると、`&T`でも内部のデータが変わるからです。

`Cell`が`Atomic`のsingle thread版、`RefCell`が`RwLock`のsingle thread版という説明はわかりやすいと思いました。  

条件変数の`Condvar`はいまいち使いどころがわかっていなかったのですが、threadのparkとの対比の説明がわかりやすかったです。  `Condvar::wait()`の引数に`Mutex`の`MutexGuard`が必要なのは、呼び出し側でunlockしてからwaitすると、その間の通知を逃してしまうからとわかり疑問がひとつ解消されてうれしかったです。

## 2章 アトミック操作

Atomic変数(`AtomicI32`等)の使い方が説明されます。  
具体例が豊富で親切です。 
英語版でも書きましたが、まず`Ordering::Relaxed`だけを説明してくれる構成がとてもわかりやすいと思います。  

具体例の1つに、globalでuniqueなIDを発行する処理が取り上げられるのですが、値をincrementするだけの処理でもmulti threadになると如何に複雑になるのかがわかります。

## 3章 メモリオーダリング

もし1章だけ読むとしたら、3章になると思います。 
なぜメモリオーダリング(`std::sync::atomic::Ordering`)が必要なのか。メモリオーダリングによってなにが保証されるのかがわかります。  

```rust
use std::{
    sync::atomic::{AtomicBool, AtomicU32, Ordering::*},
    thread,
    time::Duration,
};

static DATA: AtomicU32 = AtomicU32::new(0);
static READY: AtomicBool = AtomicBool::new(false);

fn main() {
    thread::spawn(|| {
        DATA.store(123, Relaxed);
        READY.store(true, Release); // 👈
    });

    while !READY.load(Acquire) { // 👈
        thread::sleep(Duration::from_millis(100));
        println!("waiting...");
    }

    assert_eq!(DATA.load(Relaxed), 123);
}
```

上記のcodeで、なぜ`Relase`と`Acquire`を指定すべきかがわかります。

自分は英語版でのhappens-before relationshipsの説明を理解できているか確かめたくて本書を読みました。  
また、`std::sync::atomic::fence`関数の説明もあります。fenceとhappens-before relationshipsの関係も解説されており非常にありがたいです。  

## 4章 スピンロックの実装

`AtomicBool`を利用して、lock機能を提供する`SpinLock`を実装していきます。  

```rust
struct SpinLock<T> {
    value: UnsafeCell<T>,
    locked: AtomicBool,
}

// ...
fn main() {
    let x = SpinLock::new(Vec::new());
    thread::scope(|s| {
        s.spawn(|| x.lock().push(1));
        s.spawn(|| {
            let mut g = x.lock();
            g.push(2);
            g.push(2);
        });
    });
    let g = x.lock();
    assert!(g.as_slice() == [1, 2, 2] || g.as_slice() == [2, 2, 1]);
}
```

lockを表現するGuard型がどうしてあらわれるのかがわかり、rustのapi全般の理解が進みました。

## 5章 チャンネルの実装

`UnsafeCell`と`MaybeUninit`を利用して、一度だけ値をsendできる、`tokio::sync::oneshot`のようなchannelを実装していきます。

```rust
struct Channel<T> {
    message: UnsafeCell<MaybeUninit<T>>,
    state: AtomicU8,
}

// ...

fn main() {
    let (sender, receiver) = Channel::split();
    thread::scope(move |s| {
        s.spawn(move || {
            sender.send("Hello");
        });
    });

    let m = receiver.receive();
    println!("{m}");
}
```

`Arc`を利用する例や、allocationを避けるパターン等がのっています。  

## 6章 Arcの実装

本章では`Arc`を実装します。  
`Arc`の実態は以下のように定義されたheap上に確保された`ArcData`ということがわかります。  

```rust
struct ArcData<T> {
    ref_count: AtomicUsize,
    data: T,
}

struct Arc<T> {
    ptr: NonNull<ArcData<T>>,
}
```

`Arc`をdropする際に、それが最後の`Arc`の場合に限って、orderingを変えたい際に`fence`が利用できる例の解説があります。
また、循環参照を表現できるように`Weak`も実装します。  
`Weak`もheap上の`ArcData`を参照しているはずなのに、`Arc`がなくなれば`Arc<T>`の`T`はdropされる一見不思議なapiがどのように実装されているかわかります。    

愚直に実装しようと思うと、`Arc`と`Weak`の数を別々のatomic変数で管理したくなります。しかしながら、２つのatomic変数が同時に0であることは確かめられないので、いかにWeakの数を管理するかが課題となります。最終的な実装はstdの実装とほぼ同じになるそうです。


## 7章 プロセッサを理解する

本章ではこれまで扱ってきたatomic操作がどのような機械語にcompileされるかを扱います。  
本書ではx86-64とARM64をtargetとして解説があります。  
自分は[Compiler Explorer](https://godbolt.org/)で、Target architectureとして`riscv64gc-unknown-linux-gnu`を利用しました。  


```rust
pub fn a(x: &mut i32) {
    *x = 0;
}
```
まず上記のように引数のpointerに0を代入する関数は以下のようにcompileされました。

```
example::a:
        sw      zero, 0(a0)
        ret  
```

`sw rs2 offset(rs1)`はstore word命令で、rs1+offsetのメモリアドレスにrs2の内容を書き込む命令です。  
`a0` registerは関数の第一引数が格納されるregisterです。  
`zero`は常に0として扱われる特別なregisterです。  
なので、`sw zero, 0(a0)`は第一引数のaddressに0を書き込むと解釈できます。  
`ret`は疑似命令でassembly上では登場するが実際には違う機械語に変換されます。  
`ret`の場合は`jalr zero, 0(ra)`になります。`jalr`はjump and link register命令で、raのaddressにjump(pcを書き換える)します。現在のpc + 4のaddressをregisterに書き込みますが、関数から戻る場合は不要なのでzeroに書き込んでいます。raには関数呼び出し時に戻り先のaddressが格納されています。

続いて、atomic変数にRelaxedで書き込む関数を見てみます。

```rust
pub fn a(x: &AtomicI32) {
    x.store(0,Relaxed);
}
```

```
example::a:
        sw      zero, 0(a0)
        ret
```

atomicでない`&mut`と同じ命令となりました。  
`&mut`と`&AtomicI32`ではcompilerによる扱いは変わる場合があるそうですが、関数単位では同じ機械語となりました。

読み込み(load)処理も同様でした。

```rust
pub fn a(x: &i32) -> i32 {
    *x
}

pub fn b(x: &AtomicI32) -> i32 {
    x.load(Relaxed)
}
```

```
example::a:
        lw      a0, 0(a0)
        ret

example::b:
        lw      a0, 0(a0)
        ret
```

`lw`はload word命令で、a0から第一引数のaddressを取得して、その値をa0に書き込んでいます。a0は戻り値を返すためのregisterです。

### Read modify write

次はatomicでないread-modify-write処理です。

```rust
pub fn a(x: &mut i32) {
    *x += 10;
}
```

こちらはread,modify,writeと3つの命令になりました。

```
example::a:
        lw      a1, 0(a0)
        addiw   a1, a1, 10
        sw      a1, 0(a0)
        ret  
```

`addiw`はadd word immediate命令で、a1に10を足してa1に書き込みます。  
Atomic版をみてみると

```rust
pub fn a(x: &AtomicI32) {
    x.fetch_add(10, Relaxed);
}
```

```
example::a:
        li      a1, 10
        amoadd.w        a0, a1, (a0)
        ret
```

`li`はload immediateという疑似命令で、10をa1に書き込みます。  
`amoadd.w`はatomic memory operation add word命令で、a0のaddressの値とa1を加算して結果をa0とa0のaddressに書き込みます。  
ということで、riscvだとfetch_addは1命令になることがわかりました。

### compare and exchange

compare_exchangeが成功するまでloopする処理をみてみます。

```rust
pub fn a(x: &AtomicI32) -> i32 {
    let mut current = x.load(Relaxed);
    loop {
        let new = current + 10;
        match x.compare_exchange(current,new,Relaxed,Relaxed) {
            Ok(v) => return v,
            Err(v) => current = v,
        }
    }
}
```

```
example::a:
        lw      a1, 0(a0)
.LBB0_1:
        addiw   a2, a1, 10
        sext.w  a3, a1
.LBB0_3:
        lr.w    a1, (a0)
        bne     a1, a3, .LBB0_1
        sc.w    a4, a2, (a0)
        bnez    a4, .LBB0_3
        mv      a0, a1
        ret  
```

`sext.w`は`addiw a3, a1, 0`の疑似命令です。  
`lr.w`はload reserved命令で、a0からa1に読み込んだ際に当該addressに印をつけ、他のthreadが同一addressにアクセスしたかどうかを記録します。  
`sc.w`はstore conditional命令で、a0 addressにa2を値を書き込み、lr.w以降他のthreadからアクセスされていなければ、a4に0を書き込みます。  
`bne`はbranch if not equal命令で、a1とa3が異なる場合、labelにjumpします。`bnez`は`bne a4 zero`の疑似命令です。

ということで、compare exchangeのloopはload reservedとstore conditionalを用いたloopに対応することがわかりました。  
また、`x.compare_exchange()`を`x.compare_exchange_weak()`に変えても命令は変化しませんでした。

### Ordering

まず、store,load,read-modify-writeに`SeqCst`を指定した場合について。

```rust
pub fn a(x: &AtomicI32) {
    x.store(0, SeqCst);
}

pub fn b(x: &AtomicI32) -> i32 {
    x.load(SeqCst)
}

pub fn c(x: &AtomicI32) {
    x.fetch_add(10, SeqCst);
}
```

```
example::a:
        fence   rw, w
        sw      zero, 0(a0)
        ret

example::b:
        fence   rw, rw
        lw      a0, 0(a0)
        fence   r, rw
        ret  

example::c:
        li      a1, 10
        amoadd.w.aqrl   a0, a1, (a0)
        ret
```

上記のように`fence`命令が使用された。  
RISC-V Spec 2.7 Memory Ordering Instructionsではfence命令について
  
> Informally, no other RISC-V hart or external device can observe any operation in the
successor set following a FENCE before any operation in the predecessor set preceding the FENCE.

と説明されていた。`fence pred succ`なので自分の理解では`fence rw, w`は  
このfence命令より以前のメモリのread/write命令はfence命令よりあとのメモリwrite命令より先に他のthreadに観測されなければならないとなる。

まとめると、`SeqCst` orderingを利用するとその前後で他のthreadに対してこれまでの操作が後続する操作よりも前に観測されることとなるようだった。  

また`amoadd.w.aqrl`は、`amoadd`命令のacとrl bitをそれぞれ1にしていることがわかる。

続いて、Release/Acquire orderingについて。

```rust
pub fn a(x: &AtomicI32) {
    x.store(0, Release);
}

pub fn b(x: &AtomicI32) -> i32 {
    x.load(Acquire)
}

pub fn c(x: &AtomicI32) {
    x.fetch_add(10, AcqRel);
}
```

```
example::a:
        fence   rw, w
        sw      zero, 0(a0)
        ret

example::b:
        lw      a0, 0(a0)
        fence   r, rw
        ret

example::c:
        li      a1, 10
        amoadd.w.aqrl   a0, a1, (a0)
        ret
```

これは3章のfench命令の説明の通り、release storeはfence + store、acquire loadはload + fenceに対応する命令が生成されることがわかった。  
またriscvにおいては`SeqCst`と`AcqRel` orderingで同じ`amoadd.w.aqrl`命令が生成されることが確かめられた。

### fence

最後にfence命令について。

```rust
pub fn a() {
    fence(Acquire);
}

pub fn b() {
    fence(Release);
}

pub fn c() {
    fence(AcqRel);
}

pub fn d() {
    fence(SeqCst);
}
```

```
example::a:
        fence   r, rw
        ret

example::b:
        fence   rw, w
        ret

example::c:
        fence.tso
        ret

example::d:
        fence   rw, rw
        ret
```

という結果になりました。  
`fence.tso`はさきほどの仕様 2.7で

> The optional FENCE.TSO instruction is encoded as a FENCE instruction with fm=1000, predeces-
sor=RW, and successor=RW. FENCE.TSO orders all load operations in its predecessor set before
all memory operations in its successor set, and all store operations in its predecessor set before all
store operations in its successor set. This leaves non-AMO store operations in the FENCE.TSO’s
predecessor set unordered with non-AMO loads in its successor set.  

と説明されていました。fence命令のfmがどういったものが理解できておらずいまいちよくわかっていません。  
fence命令がriscvにおけるatomic理解の鍵となりそうなので、今後調べていきたいです。

また本章ではcacheの一貫性(coherence)やcache line、x86-64とARM64のorderingの違い等が説明されます。

## 8章 OSプリミティブ

4章のスピンロックを利用すれば、kernelの機能を利用せずにロックを実装することができる。しかしスケジューリングを通じてthreadを動かしたり止めたりするのはkernelなので、kernelにthreadが何かをまっていることを伝えたほうがリソースを有効活用できる。  

本章では各Platform(Linux,macOS,Windows,...)でRustがどのようにロック関連のsystem callを行うかの概要が説明される。  
特にLinuxのsystem callの1つである、futex(fast user-space mutex)が解説されます。  
Futexでは、atomic変数を起点にして、waitやwakeを実装することができます。  

```rust
use std::{
    sync::atomic::{AtomicU32, Ordering::*},
    thread,
    time::Duration,
};

#[cfg(not(target_os = "linux"))]
compile_error!("Linux only.");

fn wait(a: &AtomicU32, expected: u32) {
    unsafe {
        libc::syscall(
            libc::SYS_futex,
            a as *const AtomicU32,
            libc::FUTEX_WAIT,
            expected,
            std::ptr::null::<libc::timespec>(),
        );
    }
}

fn wake_one(a: &AtomicU32) {
    unsafe {
        libc::syscall(libc::SYS_futex, a as *const AtomicU32, libc::FUTEX_WAKE, 1);
    }
}
fn main() {
    let a = AtomicU32::new(0);

    thread::scope(|s| {
        s.spawn(|| {
            thread::sleep(Duration::from_secs(3));
            a.store(1, Relaxed);
            wake_one(&a);
        });

        println!("Waiting...");
        while a.load(Relaxed) == 0 {
            wait(&a, 0);
        }
        println!("Done!");
    });
}

// Waiting...
// Done!
```

## 9章ロックの実装

`wait()`,`wake_one()`,`wake_all()`の機能を提供する[`atomic-wait`](https://crates.io/crates/atomic-wait)を利用して、`Mutex`, `Condvar`, `RwLock`を実装します。(Mara先生のcrateです)  
`atomic-wait`の内部で、Linuxでは`SYS_futex`, FreeBSDでは`_umtx_op`, Windowsでは`Wait{On,By}Address`, macOSでは`libc++`を利用して、futex類似のapiを抽象化してくれているそうです。  

`wait()`はsystem callを伴うので、それを呼ぶ前に一定回数spin lockを試みる等の最適化も紹介されます。  
さらに、spin lockでのloopの中で、compare_exchange等の比較交換操作を読んでしまうと、cache coherenceのprotocol上排他アクセスを要してしまうので、loadで読むようにするといった点も解説されます。  

futex likeなapiとatomic変数だけで、read lockとwrite lockを提供する`RwLock`を作れるのは驚きです。

## 10章 アイディアとインスピレーション  

平行性に関する様々なデータ構造やアルゴリズムが紹介されます。  
自分は[`parking_lot`](https://crates.io/crates/parking_lot)について知りたいと思っていたので挙げられている[参考文献](https://webkit.org/blog/6161/locking-in-webkit/)を読んでみよと思いました。

## 最後に

ということで、Rust Atomics and Locksの翻訳を読んでみました。  日本語翻訳もとても読みやすく、読んでいてとても楽しい本でした。  
来年は本書でもでてきた、`NonNull`,`UnsafeCell`,`ManuallyDrop`,`MaybUninit`等のunsafeなコードも読んでいければなどと思っています。  

~~著者のMara Bos先生をマラと読んでいましたが、マーラみたいでした。~~
