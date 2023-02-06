+++
title = "🛩  RustConf 2019にいってきました"
slug = "rustconf-2019"
date = "2019-08-24"
draft = false
[taxonomies]
tags = ["rust", "event"]
+++

現地時間(PDT) 8/22 ~ 23、オレゴン州ポートランドで開催された[RustConf](https://rustconf.com/)に参加してきたので、その模様を書いていこうと思います。

## 参加のきっかけ

Rustに関わっておられる方々がにどんな人達なのか実際に見てみたいと思い、ちょうどRustConfの開催時期に夏季休暇と有給で1週間休みがとれそうだったので、思い切っていってみることにしました。
一人海外旅行もアメリカも初めてでした。


## 道のり

成田空港からポートランド国際空港(PDX)まで、デルタ航空の直通便が就航しており、片道10時間程度です。時差はJST - 16時間。
会場は[オレゴンコンベンションセンター](https://www.oregoncc.org/)で、空港から[MaxLightRail](https://trimet.org/max/)という電車で20分程度の距離でした。
入国審査で、目的は観光で滞在日数は4日と答えたところ、"Very Short" と言われました。


{{ figure(caption="portlandの場所", images=["/images/rustconf-2019/portland_1.jpeg"]) }}

{{ figure(caption="PDXとオレゴンコンベンションセンター入口", images=[
  "/images/rustconf-2019/pdx.jpeg", "/images/rustconf-2019/oregon_convention_center.jpeg",
], width="48%") }}


## 1日目

RustConfは２日に渡って開催され、1日目は、いくつかの[Training Course](https://rustconf.com/training/)が用意されています。
あらかじめ、参加したいcourseのticketを購入しておく必要があり、今回は[Async](https://rustconf.com/training/#async)のcourseを選択しました。(これ以外は全て売り切れていました。)


{{ figure(caption="Conferenceの様子", images=[
  "/images/rustconf-2019/rustconf_2019_day1_1.jpeg", 
  "/images/rustconf-2019/rustconf_2019_day1_2.jpeg",
  "/images/rustconf-2019/rustconf_2019_day1_3.jpeg",
], width="32%") }}

Async Courseの内容は、Futureの概要/Conceptの説明や、[`async-std`](https://github.com/async-rs/async-std)のhandsonで、[chat](https://github.com/async-rs/a-chat)を作ってみるものでした。ちょうど、前日に`async/await` syntaxがmergeされ、`rustc 1.39.0-nightly (e44fdf979 2019-08-21)` versionを利用しました。

{{ figure(caption="1.39からasync/awaitがstable!", images=[
  "/images/rustconf-2019/rustconf_2019_async_pr.jpeg",
]) }}

[`async-book`](https://book.async.rs/tutorial/index.html)にそって進めていったのですが、よくあるsample codeのuseが漏れていて、book通りに進めていくとcompileが通らないことがおきました。するとすかさず(おそらく)参加者の一人の方が[PR](https://github.com/async-rs/async-std/pull/98)を送り(それがmergeされ)、「画面をリロードしてくれ、もう直ってるから」といって、sample codeのcompileが通るようになる場面がありました。

Rustの非同期関連については、まったくわかっておらず、今回のcourseの参加をきっかけに

* [`async-book`](https://book.async.rs/tutorial/index.html)
* [`async-std-book`](https://book.async.rs/)
* [`tokio-doc`](https://tokio.rs/docs/overview/)

あたりから読んでみようと思っています。


{{ figure(caption="irlnaさんによるasyncの冊子(ちなみに、2日目のspeakerでもあられる", images=[
  "/images/rustconf-2019/rustconf_2019_paper_1.jpeg",
  "/images/rustconf-2019/rustconf_2019_paper_2.jpeg",
], width="48%") }}


## 2日目

2日目が本番といったところで、参加者の人数は1日目よりはるかに多かったです。

{{ figure(caption="会場ロビー", images=[
  "/images/rustconf-2019/rustconf_2019_day2_1.jpeg"
])}}


{{ figure(caption="開始前のkeynote会場(はじまると8,9割程度埋まっていました)", images=[
  "/images/rustconf-2019/rustconf_2019_day2_2.jpeg"
])}}

openingとclosingのkeynote以外は、２つの会場でSessionが行われ、各々好きなほうを聞きに行く形式でした。[schedule](https://rustconf.com/schedule/)

自分は以下のsessionに参加しました。sessionの内容はそのうちyoutubeにupされるかと思います。

* [CLASS FIXES; OR, YOU BECOME THE RUST COMPILER](https://rustconf.com/schedule/#class-fixes-or-you-become-the-rust-compiler)
* [Syscalls for Rustaceans](https://rustconf.com/schedule/#syscalls-for-rustaceans)
* [IS THIS MAGIC!? FERRIS EXPLORES RUSTC!](https://rustconf.com/schedule/#is-this-magic-ferris-explores-rustc)
* [MONOTRON - BUILDING A RETRO COMPUTER IN EMBEDDED RUST](https://rustconf.com/schedule/#monotron-building-a-retro-computer-in-embedded-rust)
* [From Electron, to WASM, to Rust (aaand back to Electron)](https://rustconf.com/schedule/#from-electron-to-wasm-to-rust-aaand-back-to-electron)
* [BRINGING RUST HOME TO MEET THE PARENTS](https://rustconf.com/schedule/#bringing-rust-home-to-meet-the-parents)
* [THE RUST 2018 MODULE SYSTEM](https://rustconf.com/schedule/#the-rust-2018-module-system)

特に印象的(理解できた)だったのは

* mongoDBのGUIである[compass](https://www.mongodb.com/products/compass)のschema parser部分をperformanceをだすためにjsからrust/wasmを利用する構成に書き換えた話

* Facebookで、Rustの導入に取り組まれているC歴30年の方が、Rustは今までで初めて、every roleでCを置き換えられる言語だ的なことをおっしゃっていたこと

{{ figure(caption="rustの求人", images=[
  "/images/rustconf-2019/rustconf_2019_rust_jobs.jpeg"
])}}

{{ figure(caption="AWSにもrustの募集がある", images=[
  "/images/rustconf-2019/rustconf_2019_aws_rust_job.jpeg"
])}}

{{ figure(caption="Sponsors", images=[
  "/images/rustconf-2019/rustconf_2019_sponsors.png",
])}}



## 感想

実際にOpenSourceなprojectの活動に参加してみて、あらためて、こういった活動にContributeできるようなエンジニアになりたいという思いを持ちました。
(あとは、英語の冗談で笑えるようになりたい)
