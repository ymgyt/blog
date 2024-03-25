+++
title = "📗 Learning OpenTelemetryを読んだ感想"
slug = "learning-opentelemetry"
description = "OreillyのLearning OpenTelemetryを読んだ感想"
date = "2024-03-22"
draft = true
[taxonomies]
tags = ["book", "opentelemetry"]
[extra]
image = "images/emoji/green_book.png"
+++


## 読んだ本

## まとめ

## Chapter 1 The State of Modern Observability

* 現代のsoftwareではend user experienceが非常に重視されている
  * ECではloadに2secかかるとと離脱する
* uptime requirementsも課されている
  * issueの素早い特定が必要
    * そのためにはdataが必要
      * ただのdataではなく、整理され分析の用に供される状態になっているdata

* otelはこれらの問題をlog,met,traceをcoherent,unifed graph of informationにかえることでこれらの問題を解決する

* 2024年現在、observabilityの分野には30年ぶりの"津波"がきている
* なぜo11yへの新しいアプローチが重要であるかを知るには、これまでのo11yのarchitectureやlimitationsを知る必要がある

* 本書の対象はdistributed system
  * componentが異なるnetworkに配置され、messageをやり取りすることで協調するsystem

* telemetry: describes what your system is doing
  * signalはparticular form of telemetry
    * signalはinstrumentationとtransmission systemの2つからなる
      * instrumentationはtelemetry dataをemitするcode
      * transmission systemはdataをnetworkごしにanalysis toolに送る
    * このtelemetryをemitするsystemとanalyzeするsystemを分離することが重要
* telemetry + analysis = observability

* o11yはpractice
  * devops同様、organizational practice
    * observability soruceはwide and variedなので、組織全体の向上のために継続的に使われる必要がある(訳が変)

* telemetryの名前の由来
  * power plantsの監視で使われた

* 歴史
  * 最初はlog
    * full text-searchに特化したdatabaseに貯めて検索した
  * loggingは個別のeventがいつ起きたのかを教えてくれるが、時系列にそった変化を捉えるためにはよりdataが必要だった
    * storage spaceが足りずにfile書き込みが失敗したことはわかるが、storage capacityをtrackして、足りなくなる前に対応したいよね
  * metricsはcompact statistical representation of system state and resource utilization
  * trace
    * systemがより複雑になり、transactionsがより多くのoperationを多くのmachineで行うようになった
    * localizing the source of a problemはより重要になった
    * しかし、traceはsample(resource制約の観点から)されるので、その有用性はperformance analysisに限定されることになってしまう
  * これまでは、log,metrics,traceごとにinstrumentation, data format, data transmission, storage,analysisが独立していた(だから3本柱と呼ばれていた)
  * これは歴史的にその順番で追加されてきたからそうなっているだけ
    * だから3つのbrowser tabが必要になってしまう

* 解決への手掛かりは異なるdata streamのcorrelationsを見つけることから得られる
  * three pillars are acutually a bad design!

* 重要なのはtelemetryの統合
* この本は、otelのguideで、otelのdocのreplacementを意図していないphilosophyとdesignの説明する
    

## Chapter 2 Why Use OpenTelemetry

* production debuggingの3つの課題
  * the amount of data they need to parse
  * the quality of that data
  * how the data fits together

* k8sではcodeを実行する状況がすぐに変わる(nodeが廃棄されたり)
* 種々の問題はhigh-quality standards-based consistent telemetry dataの欠如から生まれている
* hard context(=metadata)を付与して、log,trace,metricsを関連づける
* monitoring is passive action, o11y active practice
  * passive dashboardやalert based telemetry dataに頼る以上のこと?

  
## Chapter 3

* Trace
* Metrics
* Logs
* Context
* Semantic conventions, Attributes, Resources
  * 自分たちの組織でもsemantic conventions作るの推奨らしい

## Chapter 4 The OpenTelemetry Architecture

> What OpenTelemetry does not include is almost as critical as what it does include. Long-term storage, analysis, GUIs, and other frontend components are not included and never will be.

o11y backendはscope外だし、今後も変わらない

## Chapter 5 Instrumenting Applications


## Chapter 6  Instrumenting Libraries


## Chapter 7 Observing Infrastructure


## Chapter 8 Designing Telemetry Pipelines

### Memo
まず、collectorの機能が必要ないなら、applicationから直接analysis toolにtelemetryを送るのはありと説明されていた。

* 次にcollectorをappと同一hostで動かす
  * environment resource(pod名とかどこで動いてるかの情報)
    * この仕事は、api callやsystem callを必要とするので、appからdelegateできると望ましい。
  * telemetry送信のbatchをまかせられるので、appは小さいchunkでmemoryから追い出せる

* pipelineが大きくなってくると、filteringやsamplingをしたくなる
  * 一般にcollectorはそれぞれの言語のSDKよりrobust and efficient
  * telemetryをどこに送るか、formatはどするか、必要なprocessはなにかはapplication個別ではなく、service全体で共通するので、appからdelegateする理由になる
  * collectorの設定とapplicationではlifecycleも違う
  * appの設定がsimpleになる(batch sizeとtimeoutくらい)で後はotlpでなげるだけになる

* local collectorはsufficient starting pointだけど次にcollectorのpoolがほしくなる
  * load balancerの背後に複数のcollectorを設置する構成
  * メリットはlocal collectorの送るtelemetryのdataが多くなった際にもLBによってcollectorのbufferが増えるので、telemetryがdropされないこと(これはotlpがstatelessだからできる)
  * この場合、local collectorの責務はappからtelemetryをもらうことと、hostmetricsを取得することになる。CPUとMemoryを使いすぎるとapplicationに影響するので、Pool側にまかせたい

* [Open Agent Management Protocol(OpAMP)](https://github.com/open-telemetry/opamp-spec/blob/main/specification.md)も紹介されていた。
  * collectorの設定管理をより用意にできるらしい
  * これはanalysis tool側からcollectorの設定を変更できることにつながる
    * なぜこれが重要かというと、samplingの設定はanalysis toolに依存するところが大きく、analysis toolにsamplingの設定を委ねる必要がある

* Gateway and specialized workload

## Chapter 9
## Appendix A
## Appendix B
