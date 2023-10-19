+++
title = "🔭 OpenTelemetry Meetup 2023-10にいってきました"
slug = "opentelemetry-meetup-2023-10"
description = "OpenTelemetry Meetupにいってきたので感想を書きます"
date = "2023-10-19"
draft = false
[taxonomies]
tags = ["event", "opentelemetry"]
[extra]
image = "images/emoji/telescope.png"
+++

2023年10月19日に行なわれた[OpenTelemetry Meetup 2023-10](https://opentelemetry.connpass.com/event/296353/)にいってみました。  
楽しかったので感想を書きます。

なお、本eventは
* 会場/配信: [CARTA HOLDINGS社](https://cartaholdings.co.jp/en/)
* 飲み物: [Splunk社](https://www.splunk.com/)

の協賛で行なわれたそうです。ありがとうございます🙏

[会場の様子](https://twitter.com/ShuzoN__/status/1714945903575093307?s=20)

リアルのeventはとても久しぶりでconnpass上ですと前回参加したのは2019年の[Kubernetes Meetup Tokyo #23](https://blog.ymgyt.io/entry/kubernetes-meetup-tokyo-23/)でした。

## オープニング

[スライド](https://docs.google.com/presentation/d/1Qm8R5AA5Bvqj15Aq7qKTOX3zXWJxv_4ojMdExxAhSkA/edit?pli=1#slide=id.p)

本eventが開催されたのは"機運がたかまってきた"からということでした。  
自分がOpenTelemetryに興味をもったのは、[tokio-rs/tracing-opentelemetry crate](https://github.com/tokio-rs/tracing-opentelemetry)をみかけたのがきっかけでした。

{{ figure(images=["images/ss-question-1.png"], caption="あなたはOpenTelemetryを...")}}

最初にアイスブレイクでOpenTelemetryの使用に関する質問がありました。  
Eventに参加されるだけあって、利用されている方々が多かったです。  
~~自分は気が大きくなってopentelemetry-rustのgood first issueをやったし、コントリビューターでしょと回答してしまいました~~



## OpenTelemetryのここ4年弱の流れ

[スライド](https://speakerdeck.com/ymotongpoo/opentelemetry-in-last-4-plus-years)

スピーカー: 山口能迪さん（@ymotongpoo）

2022年に発表された[OpenTelemetryのこれまでとこれから](https://cloudnativedays.jp/o11y2022/talks/1347)
を今回のevent用に更新/まとめていただいた内容でした。  

自分がOpenTelemetryについて知ったのは2022年だったので、歴史的経緯の説明は非常にありがたいです。  
OTLPについても自分はprotobuf定義してあって、言語に依らずに
data構造定義されていて便利だなくらいにしか思っていなかったのですが、それができた問題意識等の説明がありました。  

2023年10月の各言語の実装状況では、Javaがtrace,metrics,logでstableとなっており、実装が先行しているそうです。  
C/C++も3 signalでstableとなっており、さすが強いと思いました。 Rustについてはopentelemetry-rustをみている限り、現在絶賛実装中という感じです。  

また、エコシステム(Splunk, Elastic, Honeycomb, Dynatrace, Sentry,...)でもOTLPのサポートが増えてきているそうです。  
うれしいですね。

これは完全に知らなかったのですが、[Profilingを標準化する試み](https://github.com/open-telemetry/oteps/pull/237)もあるそうです。  
OpenTelemetryでprofilingも扱うことができるようになるのは夢があると思いました。  
また、[Opentelemetry Enhancement Proposal(OTEP)](https://github.com/open-telemetry/oteps)というrepositoryを知れました。これからPRをwatchしていこうと思います。



## OTel導入事例1: ジョインしたチームのマイクロサービスたちを再計装した話

[スライド](https://speakerdeck.com/k6s4i53rx/getting-started-tracing-instrument-micro-service-with-opentelemetry)

スピーカー: 逆井（さかさい）啓佑さん

参画されたプロダクトにOpenTelemetryのtraceを計装された点についてのお話でした。  
再計装というのは一部、前任者の方が導入された点を引き継いだという文脈でした。

現状、自分はcontrib版のopentelemetry-collectorを利用しているのですが、productionでは必要なcomponentのみを備えたものをbuildするほうがよいというアドバイスがありました。  
実際に利用しそうなreceiverやprocessorのあたりがついてきたので、自前のcollector作成にも取り組んでみようと思いました。
Rustならこの点はfeatureで制御できそうで、rustでcollectorが実装される日を夢見ています。  

実際にチームに展開する際の取り組みやlocalの切り分け等、とても参考になるお話でした。  
また、Span Metrics Connectorは知らなかったので、調べてみたいと思いました。


## ヘンリーにおける可観測性獲得への取り組み

[スライド](https://speakerdeck.com/nabeo/henriniokeruke-guan-ce-xing-huo-de-henoqu-rizu-mi)

スピーカー: 株式会社ヘンリー Nabeoさん

複雑なdomainを背景にOpenTelemetryを導入する際の検討について共有いただいた話。  
こういう案試したけど、こうでしたという話はひたすら参考になるので非常にありがたいです。  
opentelemetry-collectorをsidecarとして利用する方法にもメリット/デメリットあるので、うまいことトレードオフするのが自分の課題だったので、とても参考になりました。  
現状はsidecarでcollectorを動かしていますが、リソースの有効利用の観点からdeploymentかdaemonsetもありかなと現状では考えています。  
ただ、daemonsetでcollector動かすと、特定のtelemetryのrewrite系の処理がメンテしづらくなりそうだなと懸念していたりします。


## Q&A

発表後にslidoでのQ&Aがありました。  
質問は30以上はあったかと思います。

slidoの質問のURLの取得方法がわからなかったので、自分がメモした範囲でSSを掲載します。

### Collectorのメリット

{{ figure(images=["images/ss-slido-1.png"]) }}

Collectorを導入するメリットはいろいろあると思います。  
識者の方々の回答としてはprocessorを利用できる点があげられていました。  
逆にいうとcollectorというcomponentを一つ増やす以上はcollectorの機能を使い倒さないと管理コストだけ増えることになるので、collectorの理解度をあげないとなと思いました。

### Observabilityの費用対効果

{{ figure(images=["images/ss-slido-2.png"]) }}

個人的にはやらないという選択肢はないと思っていたのですが、こういった問題意識は忘れずに、運用での問題調査や改善でopentelemetry導入して正解でしたね、にしないといけないと思っています。 
~~いうのは簡単だが、果たして~~ 

### Sidecar collectorのCPU

{{ figure(images=["images/ss-slido-3.png"]) }} 

Cloud Runは利用したことがないのですが、collectorへのリソース割当は自分も悩ましく思っています。  
これは実際に計測するしかないので、collectorを計測できるようにするのが次の課題だと思っています。

### 結局、トレースとログは何が違うのですか？

{{ figure(images=["images/ss-slido-4.png"]) }}

回答: "同じです"  
補足: samplingされていて、water fallになっていて、latencyに関する情報をもっているのがtrace。  
任意の情報をもっているのがlog。

なにごとも言い切れるのはすごいと思ってしまう。


### Realtime User Monitoringについて

{{ figure(images=["images/ss-slido-5.png"]) }}

実装が公開されているのでそれをまずは見てましょうということでした。  

Frontの話ですがここも追っていかなければ..

### コストの抑え方

{{ figure(images=["images/ss-slido-6.png"]) }}

Samplingの話でした。  
Traceの全件取得は実際問題現実的でないので、samplingは必須という認識でした。  
自分はhead samplingしてapplicationへのperformanceへの影響も抑えたいと考えていたのですが、errorの補足の観点からはtail samplingしたくなるので、ここも課題です。~~課題しかない~~
### Metricsのexamplarの使い方

{{ figure(images=["images/ss-slido-7.png"]) }}

これは自分が質問しました。  
答えとしては、metricsとtraceを紐付ける機能ということでした。  
例えばCPU使用率のmetricsが高くなった場合に相関するtraceを紐付けるといったことが可能となるようです。  
これができてはじめて、traceとmetricsを統一して扱うメリットが得られると思うので、調べて実装していきたいです。  
時間の関係で回答は得られませんでしたが、semantic conventionsにおけるschema_urlの利用例も気になるところでした。  


## まとめ

楽しかったので次回も参加してみたいです。  
Rustが一度も言及されなかったので、Rust + OpenTelemetryをがんばっていきたいと思いました。

## 参考

* [Tail Smapling Processorを使ってAPMの使用量を効率化しよう](https://ymotongpoo.hatenablog.com/entry/2022/12/02/145308)