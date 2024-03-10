+++
title = "📕 Asynchronous Programming in Rustを読んだ感想"
slug = "asynchronous-programming-in-rust"
description = "CF Samson先生のFuture解説がついに本になった"
date = "2024-03-09"
draft = true
[taxonomies]
tags = ["rust", "book"]
[extra]
image = "images/emoji/closed_book.png"
+++

## 読んだ本

{{ figure(images=["images/apir-book.jpg"], caption="Asynchronous Programming in Rust", href="https://www.packtpub.com/product/asynchronous-programming-in-rust/9781805128137") }}

著者: [Carl Fredrik Samson](https://github.com/PacktPublishing/Asynchronous-Programming-in-Rust/tree/main?tab=readme-ov-file#get-to-know-the-author)  
[Repository](https://github.com/PacktPublishing/Asynchronous-Programming-in-Rust/tree/main?tab=readme-ov-file#get-to-know-the-author)

今はもう読めなくなってしまった[Futures Explained in 200 Lines of Rust](http://web.archive.org/web/20230324130904/https://cfsamson.github.io/books-futures-explained/)や[Exploring Async Basics with Rust](http://web.archive.org/web/20220814154139/https://cfsamson.github.io/book-exploring-async-basics/introduction.html)を書かれたCF Samson先生Async解説本がついに出版されました。  

本記事では本書を読んだ感想について書きます。


## まとめ

TODO

## Part 1:Asynchronous Programming Fundamentals

### Chapter 1: Concurrency and Asynchronous Programming: a Detailed Overview

本書の前提となるMultitaskingの歴史や言葉の定義、OSとCPUの関係等が説明されます。  
Preemptiveの概念や本書におけるconcurrencyとparallelismの違いが取り上げられます。　　
Efficiency(無駄を避ける能力)という観点からみると、parallelism(並列)はefficiencyには一切寄与せず、concurrency(並行)こそが、それを高めるという説明がおもしろかったです。  
Concurrency,parallelism,resource,task,asynchronous programmingといったともすれば多義的で文脈依存な用語を本書の範囲で、きちんと定義してくれるところもよかったです。   
一方で、

> On the other hand, if you fancy heated internet debates, this is a good place to start. Just claim someone else’s definition of concurrent is 100 % wrong or that yours is 100 % correct, and off you go.  

(ネット上での議論が好きなら、誰かのconcurrentの定義はまったくの誤りで、正しくはこうと主張してみるといいだろう)

という冗談もあり、もろもろの定義はあくまで本書の理解を助けるためにしているというスタンスです。
(日本以外でも並列/並行警察っているんですね)

ReadのI/Oを行う場合に3つの選択肢があり、それぞれthreadをsuspendするかだったりの違いが図で解説されているところもわかりやすかったです。epollとかの話なのですが、epoll等については3章で詳しく説明してくれます。  

Rustの本なのにFutureの話がでてくるのが6章なのが素晴らしいです。また、firmwareにはmicrocontroller(samll CPU)が備わっており、concurrencyとは効率性を上げることなのだから、同じ仕事をプログラムにさせないという話はとても参考になりました。  
知っている人にとっては当たり前なのかもしれませんが、このあたりを説明してくれるのは珍しいと思いました。


### Chapter 2: How Programming Languages Model Asynchronous Program Flow


#### Memo

- threads, futures, fibers, goroutines, promises,がなにを抽象化しているかについて
- Definitions
  - Cooperative: 自主的にscheduler等にyield(制御を返す)tasks。Rustのasync/awaitとjsのpromises
  - Non-cooperative: schedulerがpre-emptyするtask(stop) OS threadやgoroutines(after Go 1.14)

  - Stafkful: call stackをもつ: executionを任意の地点でsuspendできる
  - stackless: separateなstackがなく、same call stackを共有する

- Threads
  - Threadの指すところについて。OS Threadsとuser-level threadの区別。OS threadでもOS間で代替一致するが、必ずしもすべてのOSで共通するわけではない。
  - threadの作成/廃棄には時間がかかる
  - 専用の固定長のstackがある
  - context switching

- ad of decoupling aynschronous ops from os threads
  - Rustではstd::threadがあるのにasync/awaitのような抽象化レイヤーを利用するとどういったメリットがあるのかについて
    - stack sizeやthread間でのcontext switch

- Fibers and green threads
 - いわゆるM:N threadingについて
 - stackful coroutinesとも
 - "green threads"という用語がM:N threadingの異なる実装に結びついている
 - goroutinesはstackfull coroutinesの実装の一例(ただし、coroutineは暗黙的にco-operativeを意味するが、goroutinesはpre-emptingなのでこれまでの分類からするとグレー)
 - green threadsはOS threadと似た性質がある
  - stackが最初の割当より多く必要になった場合に対処する必要がある
    - 特に別領域にstackを割当、旧stackを移動させる際に、stackに保持されているpointerを壊さないようする必要がある。
    - この点、garbase collectorがあるprogramの場合はどのみちpointerをgcのために管理している。
    - 実行期間の短い間だけ、多くstackを必要として、それ以外の間はあまりstackを利用しないタスクの場合、必要以上にstackを消費することをうけいれるか、stack sizeを小さくするようなことをする必要がある
