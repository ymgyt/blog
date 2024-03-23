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
    * 

## Chapter 2
## Chapter 3
## Chapter 4
## Chapter 5
## Chapter 6
## Chapter 7
## Chapter 8
## Chapter 9
## Appendix A
## Appendix B
