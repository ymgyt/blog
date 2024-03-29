+++
title = "📗 Learning OpenTelemetryを読んだ感想"
slug = "learning-opentelemetry"
description = "Observability is a commitment"
date = "2024-03-29"
draft = false
[taxonomies]
tags = ["book", "opentelemetry"]
[extra]
image = "images/emoji/green_book.png"
+++


## 読んだ本

{{ figure(images=["images/otelbook.jpeg"], caption="Learning OpenTelemetry", href="https://learning.oreilly.com/library/view/learning-opentelemetry/9781098147174/") }}

著者: Ted Young, Austin Parker

OpenTelemetryを導入しようとしていたところ、ちょうどオライリーから本が出たので読んでみました。  
本記事では本書を読んだ感想について書きます。

## まとめ

OpenTelemetryの全体像を掴むうえでとても参考になりました。  
最初にOpenTelemetryのdocを読んだときは、signalやapiとsdkの関係がわかりづらかったので、もっと早くこの本を読みたかったです。 


## Chapter 1 The State of Modern Observability

現在のobservabilityを取り巻く状況についてから始まります。  

現代のsoftwareではend user experienceが非常に重視されている(ECではloadに2secかかるとuserが離脱するらしい)。一方で開発者にはuptime requirementsも課されている。そのため、issueの素早い特定が必要で、それにはdata、しかもただのdataではなく整理され分析の用に供される状態になっているdataが必要。  
OpenTelemtryはこれらの問題をlogs,metrics,tracesをcoherentなunifed graph of informationにかえることで解決する。　　

用語の説明として

* telemetry: describes what your system is doing
* signalはparticular form of telemetry
  * signalはinstrumentationとtransmission systemの2つからなる
    * instrumentationはtelemetry dataをemitするcode
    * transmission systemはdataをnetwork越しにanalysis toolに送る
* このtelemetryをemitするsystemとanalyzeするsystemを分離することが重要
* telemetry + analysis = observability

の説明はわかりやすかったです。

Logs,Metrics,Tracesが3本柱と呼ばれるのは歴史的にその順番でsystemに追加されたからであって

> The three pillars are a great way to describe how we currently practice observability—but they’re actually a terrible way to design a telemetry system!

とはっきり、terrible wayとされていたのが意外でした。  
"three pillars"と呼ぶとなにかよいarchitectureに聞こえるので、"three browser tabs of observability"と呼ぶ話はおもしろいです。

大切なのはdata streamのcorrelationsを見つけることなので

> three pillars are acutually a bad design!

ということでOpenTelemetryが必要となります。  
また、この本はOpenTelemetryの公式documentに代わることは意図しておらずphilosophyとdesignの説明を意図しているとありました。

## Chapter 2 Why Use OpenTelemetry

Production debuggingの3つの課題からはじめてなぜOpenTelemetryを使うのかが説明されます。また、これらの課題はhigh-quality, standard-based, consistent telemetry dataの欠如から生じるとして、Hard and Soft Context, Telemetry Layering, Semantic Telemetryという考え方が紹介されます。

  
## Chapter 3 OpenTelemetry Overview

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

Kubernetesに関してはcollectorのreceiverで情報を取得しようとすると[k8sclusterreiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver),[k8seventreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8seventsreceiver), [k8sobjectreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sobjectsreceiver), [kubeletstatsreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/kubeletstatsreceiver)等があって、うまいこと使い分ける必要があります。  将来的には1つのreceiverに統合されることを期待するとあったので、そうなればいいなと思いました。  

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

## Chapter 9 Rolling Out Observability

> Telemetry is not observability

ということで最終章は、組織における実践についてです。  

> Observability is a commitment to building teams, organizations, and software systems in ways that allow you to interpret, analyze, and question their results so you can build better teams, organizations, and software systems.  

このobservabilityの定義が一番好きです。  
どうしても一人でできることではなく、組織的な関与が必要になるので、どうやってうまく進めるかについての説明があります。  
計装を最初に深くやるか、広く浅くはじめるかであったり、codeを変更するか、collector側でがんばるかであったり、中央の主導するチームを作ったり等の話がのっていました。  

Traceやmetricsをtestで活用しようという話も載っており、時々そういう記事もみかけるので注目していきたいです。  
最後にOpenTelemetry Rollout Checklistが載っており参考になります。  
Is management involved?のようなチェック項目があります。


## Appendix A The OpenTelemetry Project

SIGであったり、Specificationであったり、OpenTelemetryというprojectがどのように運営されているかの説明があります。


## Appendix B Further Resources

OpenTelemetry関連のWebsiteのリンクと関連書籍の紹介があります。



