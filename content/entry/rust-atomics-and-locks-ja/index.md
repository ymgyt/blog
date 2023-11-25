+++
title = "📕 詳解 Rustアトミック操作とロックを読んだ感想"
slug = "rust-atomics-and-locks-ja"
description = "std::sync::atomic::{Ordering,fence}がわかる本"
date = "2023-11-25"
draft = true
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
こちらについては去年、[読んだ感想](https://blog.ymgyt.io/entry/rust_atomics_and_locks/)を書きました。  

あらためて日本語訳を読んだ感想を書きます。  

## Rust Atomics and Locksを読んでから

Rust Atomics and Locksを読む前は、CPUはメモリから命令をfetchした後、実行して結果をregisterないしメモリに書きもどすというのが自分のメンタルモデルでした。  
CPUとメモリの間にはcacheがあるものの、performanceを考慮しなければプログラマーには透過的で意識しなくてよいものと思っていました。  
しかし、このメンタルモデルは誤っていることがわかりました。  実際にはCPUコアごとに独立したcacheが存在している。CPUコアごとのcacheの整合性(cache coherence)を保つためにCPUコアはなんらかのprotocolでcacheの問い合わせや無効を行っている。cacheの更新自体もqueueでうけられて非同期。したがって、CPUコアAによる変数A,Bへの書き込みがなされても、CPUコアBには変数Bの変更しか観測されないという場合がありえる。   
と考えるようになりました。ので、atomicについて知るにはもうすこしCPUのことがわかりたいと思うようになり、以下の本を読みました。  

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

```rust
pub fn a(x: &mut i32) {
    *x += 10;
}
```

```
example::a:
        lw      a1, 0(a0)
        addiw   a1, a1, 10
        sw      a1, 0(a0)
        ret  
```

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


```rust
pub fn a(x: &AtomicI32) -> i32 {
    x.fetch_or(10, Relaxed)
}
```

```
example::a:
        li      a1, 10
        amoor.w a0, a1, (a0)
        ret  
```

```rust
pub fn a(x: &AtomicI32) -> i32 {
    let mut current = x.load(Relaxed);
    loop {
        let new = current | 10;
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
        ori     a2, a1, 10
        sext.w  a3, a1
.LBB0_3:
        lr.w    a1, (a0)
        bne     a1, a3, .LBB0_1
        sc.w    a4, a2, (a0)
        bnez    a4, .LBB0_3
        mv      a0, a1
        ret
  
```


### instructions and registers

* zero
* a0

* sw
* lw
* ori
* sext.w
* addiw
* amoadd.w
* amoor.w
* ret
