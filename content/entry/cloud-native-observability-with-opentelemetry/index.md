+++
title = "📗 Cloud-Native Observability with OpenTelemetryを読んだ感想"
slug = "cloud-native-observability-with-opentelemetry"
date = "2023-03-28"
draft = true
description = "Cloud-Native Observability with OpenTelemetryを読んだ感想を書いていきます"
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/green_book.png"
+++

## 読んだ本

Cloud-Native Observability with OpenTelemetry  

2022年4月に出版された本です。

## Chapter 1 The History and Concepts of Observability

Observabilityがより求められるようになった背景やコンセプトについて。  
人によってobservabilityの定義は異なりますが、本書では以下のように定義されています。  

> Observability is about empowering the people who build and operate distributed applications to understand their code's behavior while running in production.

Boten, Alex. Cloud-Native Observability with OpenTelemetry: Learn to gain visibility into systems by combining tracing, metrics, and logging with OpenTelemetry (p. 33). Packt Publishing. Kindle Edition. 

個人的には、observabilityを明確に定義して、xxは該当するけど、yyは違うみたいな議論は得るところ少ないので、開発者をempoweringするくらいの緩い括りでいいように思ってしまう。  

また、observabilityの概念が最近着目されているかというと、従来のops(traditional ops)では対応できない新たな課題に対応するためという背景があります。  
自分が理解した範囲では、具体的には以下のような流れです。  

1. Cloud Provider(Amazon,Google,Microsoft,...)が普及
1. メリットを享受するためにservice orientedなarchitecture(microservices)への移行が進む
1. 独立したserviceが増加する。具体的にはdev teamがlifecycle全般のownershipをもつ
1. 組織全体の構成を理解できる人が減り、問題調査の難易度が上がる
1. この状況の変化に対応するためにシステムを観察する方法も変わってきた

### Observabilityの歴史

現状のobservabilityをよりよく理解するためには、いくつかの手法がどのようにして生まれて変化してきたかをしることが重要。  
ということで、以下のconseptについての解説があります。  

* Centralized logging
* Metrics and dashboard
* Tracing and analysis

この中でとにかくいろいろなtoolがでてきます。このことが業界やopen source commnityの分断につながっていると指摘されます。  
これがOpenTelemetryにつながります。

### OpenTelemetryの歴史

OpenTelemetry自体は2019年に、OpenTracingとOpenCensusプロジェクトがmergeされる形で発表されました。  
ということで、まずはそれぞれのプロジェクトがどういった問題を解決しようとしていたかが説明されます。  
自分はOpenTelemetryしか知らなかったので、その中で登場する概念がもともとどういった背景で誕生したかが知れてよかったです。  

OpenTracingの説明を読んで思ったのがプログラミング言語に依らない統一的なAPIを定義して、applicationやlibraryから呼んでもらう試みって今までに見たことなかったということでした。 

OpenTracingとOpenCensusが人気を博するようになると、userとしてはどちらを利用すべきか判断するのが難しくなり、それがOpenTelemetryへの統合につながったそうです。  
具体的には、projectを跨いだcontext propagationができなかったり、OpenCensusを使っているが利用したlibraryがOpenTracingのみをサポートしていたりするケースがつらみだったようです。

{{ figure(images=[images/standards_2x.png], caption="https://xkcd.com/927/") }}



## Chapter 2
## Chapter 3
## Chapter 4
## Chapter 5
## Chapter 6
## Chapter 7
## Chapter 8
## Chapter 9
## Chapter 10
## Chapter 11
## Chapter 12




