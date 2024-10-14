+++
title = "📗 Platform Engineeringを読んだ感想"
slug = "platform-engineering"
description = "TODO"
date = "2024-10-14"
draft = true
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/green_book.png"
+++

## 読んだ本

{{ figure(images=["images/book.jpg"], caption="Platform Engineering", href="https://www.oreilly.com/library/view/platform-engineering/9781098153632/")}}

著者: Camille Fournier, Ian Nowland

TODO

## Part 1. The What and Why of Platform Engineering

* PEのmotivationはなに?
* PEで解決できる問題はなに?
を説明する章

この本を書いた動機の説明

PEが生まれたのは、可用性やパフォーマンスを維持しながら、急速に変化する広大なecosystemを管理するという要求に対処するため

PEがすべての問題を解決するわけではないが、なぜPEが正しいアプローチなのか

Ch 2は成功するためのcore pillarsについて。  
PEは単に何人かの人をチームに配属して、権限をあたえるだけではない。
PEの基礎である、product, software, breadth, operationsを理解して行動する必要がある


### Chapter 1. Why Platform Engineering Is Becoming Essential

課題感
* ソフトウェア組織は過去25年間、複数のチームで共有されるコード、ツール、インフラをどう管理するかという問題に直面してきた。
  * central teamを作り担当させたがうまくいかず
    * つかいづらい、
    * 自分たちの優先事項を優先
    * system aren't stable enough

  * central teamを廃止し、それぞれのチームにcloudへのアクセス権とOSSの選択権を与える方法も試みられた
    * application teamは運用やmaintenance complexityに直面する
      * 結果的にscaleのメリットを享受するどころか、小規模チームでさえ、SREやDevOpsの専門家が必要になった
    * even with dedicated specialists, 複雑さを管理するコストはかかりつづけた

  * 中央チームを維持しつつも、他のエンジニアがが安心して使えるプラットフォームをを構築したチームもある。
    * クラウドやOSSの複雑さを管理し、ユーザに安定した環境を提供するエキスパート
    * application teamの声に耳を傾けてる

この章で扱うこと
  * Platformの意味
  * cloudとossの時代にあって、system complexityがどのように悪化しているのか(over-general swamp)
  * PEがこのcomplexityをどのように管理するのか


Platformの意味

[Evan Bottchersの定義](https://martinfowler.com/articles/talk-about-platforms.html)を用いる。  

> A platform is a foundation of self-service APIs, tools, services, knowledge, and support that are arranged as a compelling internal product. Autonomous application teams1 can make use of the platform to deliver product features at a higher pace, with reduced coordination.

逆にPlatformでないもの
  * Wiki
  * Cloud. 組み合わせてinternal platformにすることはできるが、cloudそれ自身では、提供するものが多すぎて、統一された(coherent) platformとはみなせない


Platform engineering
