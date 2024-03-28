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

OpenTelemetryで扱われる、Traces, Metrics, Logs, Context, Attributes/Resources, Semantic Conventions, OTLP, Telemetry Schemas等の概要が説明されます。

Semanti conventionsに関して、あるprometheusのmaintainerの方が

> these semantic conventions are the most valuable thing I’ve seen in a while.

と話されたエピソードが印象的でした。  
個人的にはprodとかstagingのkeyを`deployment.environment`としたり、userのidを`enduser.id`と決めたことはいろいろなtoolで利用できそうだなと思っています。

また、

> you can write a semantic conventions library yourself that includes attributes and values that are specific to your technology stack or services. 

として公式のconventions以外にもチームや組織でもconventionsを作っていくのはよい考えだなと思いました。(なんらかの方法で各プログラミング言語への生成の仕組みは必要そうですが)  

[OpenSLO](https://openslo.com/)や[OpenFeature](https://openfeature.dev/)への言及もありました。


## Chapter 4 The OpenTelemetry Architecture

OpenTelemetryの各種componentの概要の説明と実際のdemoの紹介があります。

> What OpenTelemetry does not include is almost as critical as what it does include. Long-term storage, analysis, GUIs, and other frontend components are not included and never will be.

(OpenTelemetryが扱わないものは扱っているものと同じくらい重要です。永続化ストレージ、分析用ダッシュボード等は含まれておらず、これからも含まれないでしょう)

という感じで、OpenTelemetryだけでは、実際の運用が完結しない点が強調されています。  
ここをvendorやOSSにまかせるというところがopentelemetry普及の鍵なのかなとか思っています。(vendorやossが協力してくれる(せざるを得ない))

最後に"The new model of observability tools"という将来像が載っているのですがそこにある、universal query apiがはやく実用化されてほしいと思っています。  
本書では紹介されていませんでしたが、[query language standardization](https://www.cncf.io/blog/2023/08/03/streamlining-observability-the-journey-towards-query-language-standardization/)が気になっています。

## Chapter 5 Instrumenting Applications

Applicationへの計装について。  
OpenTelemetryにおけるSDKとAPIの責務の違い等の説明があります。  
自動計装に対応している言語として、JavaやNode.js, pythonが挙げられていますが、GoがeBPFを利用して対応しているのがすごいです。Rustには現状、自動計装はなく、対応するにはGo同様、eBPFを使うものになるのでしょうか。  [issue](https://github.com/open-telemetry/opentelemetry-rust/issues/801)はあるのですが、あまり盛り上がっていないです。  

Traces,metrics,logsそれぞれのcomponent(providerやprocessor)の概要の説明もあります。  
自分は最初このあたりの説明をdocで読んでもピンとこなかったのですが、rustのsdkの実装をみてみると、仕様通りの型が実装されていて、具体的なイメージがわきました。一度componentの概要がわかると、別の言語でも基本的には同様の型がいるはずなので理解も進むと思います。(Metricsのexport頻度の設定はPeriodicMetricsReaderが設定する等)  
その他、設定に関するBest practicesも紹介されています。  
Service resourceとして、`service.name`,`service.namespace`,`service.version`を設定しておくことの重要性が強調されています。これらは基本的にapplicationのbuild時にわかると思うので、付与するのは特に問題ないのですが`service.instance.id`はruntime時にしかわからず、しかもapplication自身からだと(外部に問い合わせないと)わからないと思うのでcollector側で付与する必要があると思っています。  
Grafana cloudにexportした際は、`service.instance.id`がloki,prometheusの`instance` labelに対応する[仕様](https://grafana.com/docs/grafana-cloud/monitor-applications/application-observability/setup/resource-attributes/)だったりで、前提にされていることがあったので気をつけたいです。  

また、RUM(Real User Monitoring)については簡単にunder active developmentと紹介されています。  
ここが揃わないとanalysis tool以外のvendor agnosticが達成できないと思っているので期待したいです。


## Chapter 6  Instrumenting Libraries

Libraryへの計装について。  
Libraryが直接opentelemetryで計装されることの重要性が説かれます。hook等を用意して、opentelemetryをplugin的に差し込むのではどうしてダメかの説明がなるほどでした。  
OpenTelemetryがanalysis toolには踏み込まず、telemetryの生成と伝播までをスコープとしていることで、得られるvendor中立性のメリットはlibraryのmaintainerが自分から計装してくれることにあるのかなと考えています。  

> As a library maintainer, you have a relationship and a responsibility to your users.

ここを読んでいて、libraryのpublic apiが変わったら基本的にはsemverのmajor versionを上げる必要があると思いますが、libararyが生成するmetricsの名前や型(counterがhistrogram等)が変わった場合、どういう扱いになるのかなと思いました。(applicationのcompileは失敗しないですが、userのanalysys toolやalertは壊れると思うので)

また、applicationが依存しているlibrary A,Bがotel v1とv2で一緒に使えないということが起きないようにopentelemetryにv2は来ないという話も紹介されます。


## Chapter 7 Observing Infrastructure

Cloud provider(AWS,GCP, Azure,..)やplatform(kubernetes,FaaS,CI/CD service)でopentelemetryをどう活用していくかに関して述べられています。  
OpenTelemetry Collectorに関しては[builder](https://opentelemetry.io/docs/collector/custom-collector/)を使いましょうであったり、collector自信のmetricsを取得することがアドバイスされています。  

Kubernetesに関してはcollectorのreceiverで情報を取得しようとすると[k8sclusterreiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver),[k8seventreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8seventsreceiver), [k8sobjectreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sobjectsreceiver), [kubeletstatsreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/kubeletstatsreceiver)等があって、うまいこと使い分ける必要がある。  将来的には1つのreceiverに統合されることを期待するとあったので、そうなればいいなと思いました。  

Traceに[span links](https://opentelemetry.io/docs/concepts/signals/traces/#span-links)というfieldがありいまいち使い所がわかっていなかったのですが、queueを介した非同期処理での利用例が紹介されており参考になりました。


## Chapter 8 Designing Telemetry Pipelines

Telemetry pipeline、具体的にはopentelemetry collectorに関する話。  
collectorがない場合の構成から始まり、applicationと同一hostでcollectorを動かす場合, LoadBalander越しに複数のcollectorを用意する構成等の説明があります。  
Collectorの機能が不要なら必ずしも使う必要はないと前置きしつつも、filteringやsampling、hostやkubernetesの情報取得等、collectorを利用するメリットが説明されます。    
[Open Agent Management Protocol(OpAMP)](https://github.com/open-telemetry/opamp-spec/blob/main/specification.md)というprotocolも紹介されており、将来的にはcollectorの設定がより容易になるかもしれません。  
大規模になると、traceやmetricsごとに専用のcollector poolを分ける構成も紹介されていました。まだstableに達していないものの、OTLP以外にも[Otel Arrow](https://github.com/open-telemetry/otel-arrow)というprotocolがあるのは知りませんでした。

Collectorの構成に続き、filteringやsamplingの話もあります。  
私はsampling特に、head-basedとtail-basedをどうしようか迷っていたので、本章の説明は非常に参考になりました。  
意外だったのは

> We don’t suggest using head-based sampling in OpenTelemetry, since you could miss out on important traces. 

と思ったよりはっきり、head-based samplingを勧めないと書いてあったことです。また

> If sampling your logs sounds like a bad idea, why would you want to sample your traces?

(logをsamplingしないのに、どうしてtraceをsamplingしようとするのか)

これは確かにそのとおりかもと思わされました。  

その他、OTTLやConnector,backpressure, kubernetes operator等、collectorの各種機能が紹介されているので、本章を読んでおくとcollectorの全体感がつかめて良いと思いました。



## Chapter 9
## Appendix A
## Appendix B
