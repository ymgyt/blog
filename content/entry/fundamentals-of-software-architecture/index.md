+++
title = "📗 ソフトウェアアーキテクチャの基礎を読んだ感想"
slug = "fundamentals-of-software-architecture"
date = "2022-06-18"
draft = false
aliases = ["/entry/2022/06/18/230408"]
[taxonomies]
tags = ["book"]
+++

## 読んだ本

{{ figure(caption="Mark Richards, Neal Ford 著, 島田 浩二 訳", images=["images/fundamentals_of_software_architecture_book.jpeg"] )}}

[ソフトウェアアーキテクチャの基礎](https://www.oreilly.co.jp/books/9784873119823/)  
[Fundamentals of Software Architecture](https://www.amazon.co.jp/dp/B0849MPK73/)

日本語版は紙、英語版はKindleで読みました。Kindle版は図がカラーで見れます。  
本書を読んだ感想を書いていきます。


## Chapter 1. Introduction

### Software Architectureとは

Software Architectureの定義が業界でよく定まっているわけではないところから話が始まります。
その理由として、Microserviceような新しいArchitectの台頭によってsoftware architectの役割が拡大していることが挙げられています。 また、本書はsoftware architectを一度作ればその後は変更の対象にならない静的なものではなく常に漸進的に変化していく動的なものと位置付けています。

本書ではsoftware architectureとは以下の四つからなるものと定義します。

* structure of the system
* architecture characteristics("-ilities")
* architecture decisions
* design principles

structure of the systemとは実装されているarchitecture styleの種類を指します。microserviceだったりlayered architecture。system architectureについて説明する際にmicroserviceですというだけでは不十分で、system architectureはより広範な概念。自分はarchitectureとは要するにAWS(Cloud)構成図 +CI/CD + Applicationのmodule構成くらいの理解でしたのでこの後に続くarchitecture characteristics, architecture decisions, design principlesについては非常にわくわくしました。

まずarchitecture characteristicsについてですが具体的にはsystemが備えなければならない以下の特性からなります。

* Availability(可用性)
* Reliability(信頼性)
* Testability(テスト容易性)
* Scalability
* Security
* Agility
* Fault Tolerance(耐障害性)
* Elasticity(弾力性)
* Recoverability(回復性)
* Performance
* Deployability(デプロイ容易性)
* Learnability(学習容易性)

`-ility`で終わることが多いので単にilityとも呼ぶそうです(どうにかしてPerformancityとかを作りたいですね)。 Architecture characteristicについてはchapter 4,5,6,7で説明されます。

次にarchitecture decisionsですが

> Architecture decisions define the rules for how a system should be constructed

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

とされており、具体的にはlayered architectureの場合にDB層にアクセスできるのはこの層といったルールが挙げられています。開発チームに対するなんらかの指針を提供するものという理解しました。

最後のdesign principlesは、ガイドラインのこと。強制力の点でarchitect decisionsよりより緩やかで、prefer xxxくらいの意味でしょうか。具体例としてはmicroservices間では非同期通信をservice間の基本通信方式として採用する例が挙げられております(RESTやgRPCを禁止するわけではない)。

ここまで自分なりにまとめると
Software architecture = structure of system + ilities + rule and guideline of implementation
という理解に至りました。

### Software Architectに期待されること

Software architectには以下の8つが期待されるので、理解し実践することがarchitectとしての役割を果たす第一歩になる。

* Make architecture decisions(アーキテクチャ決定を下す)
* Continually analyze the architecture(アーキテクチャを継続的に分析する)
* Keep current with latest trends(最新のトレンドを把握し続ける)
* Ensure compliance with decisions(決定の順守を徹底する)
* Diverse exposure and experience(多様なものに触れ、経験している)
* Have business domain knowledge(事業ドメインの知識を持っている)
* Possess interpersonal skills(対人スキルを持っている)
* Understand and navigate politics(政治を理解し、かじ取りする)

これらの期待に答え続けている人がいたら会社は離さないだろうなと思います。

#### Make Architecture Decisions(アーキテクチャ決定を下す)

Software architectureの構成要素であるarchitecture decisionsとdesign principlesを定義することが期待される。これはsoftware architectureの定義から当然期待されることに思えます。  
"guide"であることが重要らしく、具体例としてReact.jsまで特定するのではなく、AngularやVue.jsといった選択肢を残すようにreactive-bases frameworkの使用という粒度で指示することがあげられていました。  
ただこの線引きはility(scalability,performance,...)の観点から特定の技術を指定せざるを得ない場面もあり難しいとされています。  
個人的にはReactかVueの選択は採用やその後のメンテナンス性につながる大きい話だと思いましたが、あくまで開発チームに裁量を残すことが大事なのかもしれません。
Architecture decisionsについては19章で詳しくふれられています。

#### Continually Analyze the Architecture(アーキテクチャを継続的に分析する)

architectにはarchitectとcurrent technology environmentを継続的に分析して改善案を提案することが期待される。
大胆に訳すと、今のarchitectがどれだけイケてるかについて継続的に評価することが期待されている。  
コードや設計が変化していく中でリリースまでのアジリティが落ちないようにする。
この意識の必要性は求人票に掲載されることはないという表現がおもしろかったです。

#### Keep Current with Latest Trends(最新のトレンドを把握し続ける)

どの職業でも多かれ少なかれ必要なことだと思いますがarchitectが下す判断は変更が難しく影響が長期的になりがちなので特に重要でになってくる。
できる方々は自然とされていると思われますが本書はこの点の重要性をきちんと明言し、24章でさまざまな方法を紹介してくれております。

#### Ensure Compliance with Decisions

これはarchitecture decisions,design principlesとして決まった実装の制約と方針が実際の開発で守られているかを確認することを意味します。  
一度決めて、ドキュメントに書いたから終わりでなく実際に決定がどの程度有効になっているかまで継続的に確認するプロセスは重要だと思うので決まったことが守られているかを判断する方法まで決めることは自分も取り入れていきたいです。

#### Diverse Exposure and Experience

Architectは、様々なframework,platform,environmentに触れていることが期待される。  
Expertであることまでは要求されませんが、少なくとも様々な技術に慣れ親しんでいるという期待です。自分のcomport zone意外の技術に触れていくことを推奨しています。  
これは急にできるようになるものでもないので日々意識的に取り組んでいきたいです。

#### Have Business Domain Knowledge

事業ドメインも理解できているという期待。
この点はDDDの文脈でも強調されているのでわりと皆さんの総意なのではと思います。事業ドメインを理解できていないとステークホルダー達とうまく連携できず信頼をえられない。
結局はいいarchitectはビジネス要件を効果的に満たすもの。

#### Possess Interpersonal Skills

困難な期待であることは認めつつも、architectには卓越したリーダーシップと対人スキルが期待される。経験則的に技術的な問題に見えても実は人の問題であることが多く、またarchitectにはarchitectureの実装を通じて開発チームをリードすることが期待されているからだとします。  
当たり前かもしれませんがarchitectに期待されることはどれもすぐに身につけられるようなものでないなと思います。

#### Understand and Navigate Politics

Architectには企業の政治的風土(political climate of the enterprise)を理解し、政治をnavigateすることが求められる。
開発者が下すcodeの構造に関する決定と違ってarchitectが下す決定はコストや作業量の増加といった面から反発をよぶ(be challenged)。なのでarchitectはproduct owners, project managers, business stakeholders, developersを説得する必要がある。

> However, an architect, now able to finally be able to make broad and important decisions, must justify and fight for almost every one of those decisions.

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

自分がarchitectureを決めたら今度は交渉して実現しきるまでが必要なので"fight"する覚悟までもつ必要がある。

### Architectとの関連領域

開発と運用が一体化していく流れによってarchitectの関連領域が拡大していっている。


#### Engineering Practices

Microservicesは自動テスト、デプロイを前提にしているのでこれをテストがない状態であったり手動で行えば成功しない。問題領域に適したarchitectがあるようにarchitectに適したengineering practiceがある。なのでtech leadでもあることが多いarchitectはengineering practiceについても慎重に検討する必要がある。  

このほか著者がソフトウェア開発が他の工学分野ほどに成熟していないという問題意識がおもしろかったです。

#### Operations/DevOps

DevOpsの登場によりコスト削減のために外部に委託されがちだった運用形態が見直され、microservicesにみられるようなarchitectと運用がチームを組む体制が生まれてきた。

#### Process

ソフトウェア開発プロセスはarchitectと直接関係がないとする考えもあるが、開発プロセスはarchitectに多くの影響を与える。

#### Data

Codeとdataは共生関係(symbiotic relationship)にあるので外部ストレージへの依存を無視することはできない。

### Laws of Software Architecture

> Everything in software architecture is a trade-off. 

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

設計を変更したり作成したりする際にまず思い出せるようになりたいと思います。


### Self-Assessment Questions

What are the four dimensions that define software architecture?(ソフトウェアアーキテクチャを定義する4つの側面とは何か)

* structure of the system
* architecture characteristics("-ilities")
* architecture decisions
* design principles

###### What is the difference between an architecture decision and a design principle?(アーキテクチャ決定と設計指針の違いを説明せよ)

開発チームに対する強制力。architecture decisionはルール(強制)でdesign principleはガイドライン(適切な理由があれば従わなくて良い)。

###### List the eight core expectations of a software architect.(ソフトウェアアーキテクトへの8つの期待を挙げよ)

* Make architecture decisions(アーキテクチャ決定を下す)
* Continually analyze the architecture(アーキテクチャを継続的に分析する)
* Keep current with latest trends(最新のトレンドを把握し続ける)
* Ensure compliance with decisions(決定の順守を徹底する)
* Diverse exposure and experience(多様なものに触れ、経験している)
* Have business domain knowledge(事業ドメインの知識を持っている)
* Possess interpersonal skills(対人スキルを持っている)
* Understand and navigate politics(政治を理解し、かじ取りする)

###### What is the First Law of Software Architecture?(ソフトウェアアーキテクチャの第一法則とは何か)

Everything is a trade-off.

# Part Ⅰ. Foundations

Architectureにおけるトレードオフを理解するために、component, modularity, coupling, connascenceといった概念を理解する必要がある。

## Chapter 2. Architectural Thinking

Architectらしく考えるためには4つの視点がある。

1. Architectと設計の違いを理解し、開発チームとの協働の仕方を知ること
2. 技術的な深さを維持しながらも解決策をみいだせるような技術的な幅をもつこと
3. ソリューションや技術のトレードオフを理解し、分析し、調停(reconciling)できること
4. Business driver(ビジネスを伸ばすための要素)をarchitecture concernsに反映すること

### Architecture Versus Design

Architectがarchitecture characteristic,component構造を決めて、開発者がclass,UI設計、codeを担当する。というような境界は存在しないという主張です。結局はどちらもsoftware projectを構成するもので常に同期されている必要がある。

### Technical Breadth

まず技術的な知識を以下の3つに分類します。

* わかっていること
* わかっていないとわかっていること
* わかっていないとわかっていないこと

わかっていること=専門性であり常に変化していくので時間を投資して維持する必要があります。またわかっていることは技術的な深さになります。開発者に求められるものです。
一方でわかっていること+わかっていないとわかっていることは技術的な幅となります。Architectにはこの幅が求められる。Architectに求められる技術的な知識の質の違いを理解することにつまづくことで、専門性を維持しようとする幅を広げすぎて疲弊したり、専門性を陳腐化させてしまったりしてしまうことがある。
Architectへと役割を移そうとする開発者は知識の獲得方法を変える必要があると提言されています。

### Analyzing Trade-Offs

トレードオフを知ることの具体例として、オークションシステムを一つのtopicを用いるPub/Sub形式か、Consumerごとにqueueを用意する方式どちらで実装するかを検討します。  
挙げられているプラス/マイナス面とても参考になりました。ただ、topic方式では誰でもデータにアクセスできてしまうとしてセキュリティ面のマイナス面が指摘されておりましたが、ここはちょっと納得できませんでした(queueがconsumerを指定できるならtopicもできると仮定しないとフェアではないように思いました)。

### Understanding Business Drivers

Business driversを理解して、それらをarchitecture characteristicsに落とし込む。
このためには、ビジネスドメインの知識をもちステークホルダー達と健全で協力的な関係を保つ必要がある。 
開発チームのリーダがマネジメントの方々から信頼をきちんと得ていることが重要というのは本当に大切だと思います。

### Balancing Architecture and Hands-On Coding

> We firmly believe that every architect should code and be able to maintain a certain level of technical depth

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

とあるように、architectであってもcodeは書くべきで、問題はバランスをどうとっていくかだとしております。
その方法の一つとして、クリティカルパス(フレームワークの基礎になるコード)のコードは開発メンバーに委ね、1~3回のイテレーションで実現できそうな機能開発に集中する方法が提案されています。
この方法のメリットとして以下の点が挙げられています。

* Architectがチームのボトルネックとならずにproduction codeを書くhands-on experience(実地経験)が積める
* 開発チームのownership向上
* Architectが開発チームのpainや開発環境をよりよく理解できる

Architectが開発チームと一緒にcodeを書けない場合に技術的な深みを維持する方法として以下の様々な方法が提案されています。

* Proof-of-concept work. 
* Technical debt stories or architecture storiesに取り組む
* Bug fixes
* Leveraging automation by creating simple command-line tool
* Frequent code review

Proof-of-conceptでcodeを書く際はできるだけproduction-quality codeを書くことがアドバイスされています。それが自身の練習にもなるし、しばしばPoCのcodeがそのまま実装されたりするからです。
Architectのように意思決定する立場になられた方がどの程度codeを書く時間に当てるかはどの組織でも試行錯誤されている印象を受けます。


### Self-Assessment Questions

###### Describe the traditional approach of architecture versus development and explain why that approach no longer works.(アーキテクチャと開発の従来型のアプローチを説明し、そのアプローチがもはや機能しない理由を説明せよ)

Architectがビジネス要件を分析して作成した成果物(architecture, component)を開発チームが引き継ぎcodeを書くという役割分担を一方向で行うこと。
このアプローチには双方向性が欠如しているので機能しない。双方向性はarchitectがもつiterativeな性質から必要とされる。なぜiterativeな性質をもつかというとシステムには知らないことを知らない分野がどうしても存在するから。

###### List the three levels of knowledge in the knowledge triangle and provide an example of each.(知識の三角形における知識の3つのレベルを列挙し、それぞれの例を挙げよ)

* Stuff you know
  * 自分が書ける言語や慣れているフレームワーク(の一部)。
* Stuff you know you don't know
  * モナド。
* Stuff you don't know you don't know
  * (具体的に書くと矛盾する!)

###### Why is it more important for an architect to focus on technical breadth rather than technical depth?(アーキテクトにとって技術的な深さよりも技術的な幅に焦点を当てることが重要なのはなぜか)

> As an architect, breadth is more important than depth. Because architects must make decisions that match capabilities to technical constraints, a broad understanding of a wide variety of solutions is valuable.

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

日本語版では

> アーキテクトは、技術的な制約に能力を適合させる決定を行わなければならない。

の箇所が技術的な幅が深さよりarchitectには求められる理由ですがいまいちうまく理解できませんでした。ここでいうcapabilities(能力)は何を指しているのでしょうか。

###### What are some of the ways of maintaining your technical depth and remaining hands-on as an architect?(アーキテクトとして技術的な深さを維持し、現場感を持ち続けるための工夫にはどのようなものがあるか)

* ボトネネックにならない範囲での開発チームへの参画
* コードを書く機会を逃さないこと(Poc, buf fix, 負債解消, cli tool, review)

## Chapter 3. Modularity

### Definition

ModuleをA logical grouping of related code(関連するコードを論理的にグループ化すること)と定義します。

### Measuring Modularity(モジュール性の計測)

以下の3つのメトリクスからモジュール性を把握する。

* Cohesion(凝集度)
* Coupling(結合度)
* Connascence(コナーセンス)

#### Cohesion(凝集度)

モジュール内の要素間の関連度(how related)の指標。全ての関連する要素が一箇所にまとまっている状態が理想。
細かくしすぎてしまうと今度は有益な結果を得るためにモジュール同士の結合度が高まってしまい、結果的に可読性が下がってしまう。
凝集度の様々な尺度(Functional Cohesion, Sequential Cohesion,...)や機械的に計測するメトリクス(LCOM)が紹介されています。

#### Coupling(結合度)

メソッドの呼び出しからグラフを作りコードベースの結合度を分析する手法が紹介されています。
参考文献の「ソフトウェアの構造化設計法」は絶版らしく図書館等でないと読めなそうでした。


#### Connascence(コナーセンス)

Connascenceは以下のように定義されています。

> Two components are connascent if a change in one would require the other to be modified in order to maintain the overall correctness of the system.

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

つまり、コンポーネントの関係についてconnascentか否かを考えるものと理解できます。
connascentを動的(実行時)と静的(compile時)に分類し、さらにいろいろな種類のconnascenceが紹介されています。  
結合を分類して、結合している/していないではなく強弱(グラデーション)としてとらえるという風には考えたことがなかったのでコードを書くうえで意識していきたいです。

### Self-Assessment Questions

###### What is meant by the term connascence?(コナーセンスという用語を説明せよ)

コンポーネント間の関係であり、あるコンポーネントの変更が他方のコンポーネントの変更を必要とする場合にあると判断されるもの。

###### What is the difference between static and dynamic connascence?(静的なコナーセンスと動的なコナーセンスの違いは何か)

compile時に検出できるかruntime時に検出されるか。

###### What does connascence of type mean? Is it static or dynamic connascence?(型のコナーセンスは何を意味するか。それは静的なコナーセンスと動的なコナーセンスのどちらかに含まれるか)

プログラミング言語の型に関するconnascence. compile時に検出できるのでstatic。

###### What is the strongest form of connascence?(コナーセンスの最も強い形は何か)

Connascence of Identity。なぜこれがもっとも強いものとされるかはわかっておらず。

###### What is the weakest form of connascence?(コナーセンスの最も弱い形は何か)

Connascence of Name。もっとも弱い理由はrenameだけで動作をまったく変えずに変更できるからだろうか(変なことしていなければ)。

###### Which is preferred within a code base - static of dynamic connascence?(コードベースの中で好ましいのは、静的なコナーセンスと動的なコナーセンスのどちらか)

Static connascence. 静的な方が分析しやすいから。

## Chapter 4. Architecture Characteristics Defined

問題をソフトウェアで解決しようとする時、まずシステムの要件を定めることから始める。
しかし、architectにはシステム要件の他にも考慮しなくてはならない要素が存在する。
具体的には、以下の要素。

* Auditability(監査容易性)
* Performance
* Security
* Data
* Legality(合法性)
* Scalability

これらの特性をarchitectural characteristicsと呼ぶ。domainの機能には直接関係しないが、ソフトウェアが満たさなければいけない全てのことを意味する。
しばしば、nonfunctional requirements(非機能要件)やquality attributes(品質特性)とよばれたりもするが、前者は否定証言で、後者は設計よりも事後に行う品質評価の印象が強いため本書では用いない。

Architecture characteristicは以下の三つの基準を満たすものを指す。

* Specifies a nondomain design consideration
* Influences some structural aspect of the design
* Is critical of important to application success

#### Specifies a nondomain design consideration

アプリケーションがすべきことを明らかにするのが要件。
Architecture characteristicsはその要件をどうように実装するか、なぜある決定がなされたかに関心をもち、運用と設計の基準を明らかにする。
パフォーマンスや技術的負債を防ぐこと等は要件とは明記されないがarchitectや開発者にとっては一般的な考慮事項。

#### Influences some structural aspect of the design

しばしばarchitecture characteristicを満たすために特別な構造上の配慮が必要になる。
例えばシステムの決済に関して単にサードパーティモジュールによる決済か、アプリケーション内で決済を行うかどうかでSecurityがarchitecture characteristicに引き上げられるかどうか変わってくる。

#### Critical or important to application success

Architecture characteristicを備えることは設計の複雑性とトレードオフなので、architectの仕事はサポートするべきcharacteristicsを見極めるところにある。

### Architectural Characteristics (Partially) Listed

Architecture characteristicsはモジュール性といったcodeレベルの話からscalabilityといった運用面に関する領域に及ぶ。
以下ではarchitecture characteristicsの大まかな分類を試みる。

#### Operational Architecture Characteristics

* Availability(可用性)
  * How long the system will need to be available(システムがどれくらいの期間利用できるか)
* Continuity(継続性)
  * 障害復旧能力
* Performance
  * stress testing, peak analysis, capacity required, response timesなどの分析が含まれる
* Recoverability(回復性)
  * Business continuity requirements. 災害発生時にどれだけ早くオンラインに戻す必要があるか
* Reliability/safety(信頼性/安全性)
  * システムがフェイルセーフである必要があるか、人命に影響するか、障害が会社の多額の費用負担につながるか
* Robustness(堅牢性)
  * Ability to handle error and boundary conditions
* Scalability
  * ユーザやリクエスト数が増えてもシステムが動作する能力

Operational architecture characteristicsは運用やDevOpsの関心事と重なる面が大きい。

#### Structural Architecture Characteristics

Architectは単独または共同でコード品質に責任を負う。

* Configurability(構成用意性)
  * Softwareの設定をend userが簡単に変更できる
* Extensibility(拡張容易性)
  * 新機能をプラグインで追加できること
* Installability(インストール容易性)
  * インストールの容易さ
* Leverageability/Reuse(活用性/再利用性)
  * 共通コンポーネントを複数プロダクトで再利用できること
* Localization
  * 多言語対応
* Maintainability(メンテナンス容易性)
  * システムの変更や拡張を簡単に行えるか
* Portability(可搬性)
  * 一つ以上のプラットフォームで動作するか
* Upgradeability(アップグレード容易性)
  * 新versionへの移行を簡単に行えるか

#### Cross-Cutting Architectural Characteristics

上記に分類されない特性。

* Accessibility
  * 色覚障害や難聴等のユーザを含めたすべてのユーザの使いやすさ
* Archivability(長期保存性)
  * データの保持/削除要件。
* Authentication(認証)
  * ユーザがユーザが主張する者であることに自信をもつこと
* Authorization(認可)
  * ユーザが許可されたリソースにだけアクセスできること
* Legal(合法性)
  * 法的制約(データ保護、GDPR等)
* Privacy
  * 従業員からも情報を秘匿できているか
* Security
  * 暗号化、社内システムの認証等
* Supportability(サポート容易性)
  * エラー対応時に必要になる情報をロギングできているか
* Usability/archievability(ユーザビリティ/達成容易性)
  * ユーザが目標を達成するのにどれだけのトレーニングが必要か。
  * 他のarchitecture上の課題と同様に真剣に扱われる必要がある

これらのリストは完全になることはない。また、前述の各architecture characteristicsにおいても不明確で曖昧であることは否めない。また組織ごとに独自の特性を作り出すことを否定するものでもない。

自分は可用性と信頼性の違いがいつもピントきておりませんでした(ある出力が信頼できなければそれは可用しているといえないので、両者を分ける実益がないのでは)。本書ではTCP/IPを例にIPは可用性は高いが信頼性は高くないという例を紹介しております。この例から考えるに、可用性における可用とは後続の処理でカバー可能な程度に機能を実現しているといえるでしょうか。
また、architectに関する用語にもDDDのユビキタス言語の整備を適用することがアドバイスされています。

### Trade-Offs and Least Worst Architecture

Architecture characteristicsのサポートはtrade offの関係にある。

> Never shoot for the best architecture, but rather the least worst architecture.

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

として、最初から最善を狙わずに最悪を避けることがアドバイスされています。
また、architectを変更しやすいように保てればiterativeなアプローチが可能になり、Agile software developmentの重要な教えの一つであるイテレーションの価値はarchitectureにもあてはまるとされています。

### Self-Assessment Questions

###### What three criteria must an attribute meet to be considered an architecture characteristic?(アーキテクチャ特性とみなされる基準を3つ挙げよ)

* Specifies a nondomain design consideration
* Influences some structural aspect of the design
* Is critical of important to application success

###### What is the difference between an implicit characteristic and an explicit one? Provide an example of each.(明示的な特性と暗黙的な特性との違いは何か。それぞれの例を挙げよ)

要件に記載されているか否か。
implicit: Reliability, Security
explicit: 明示されたScalability.

###### Provide an example of an operational characteristic.(運用特性の例を挙げよ)

RobustnessやScalability

###### Provide an example of a structural characteristic.(構造特性の例を挙げよ)

MaintainabilityやLocalization

###### Provide an example of a cross-cutting characteristic.(横断的特性の例を挙げよ)

AccessibilityやArchivability

###### Which architecture characteristic is more important to strive for - availability or performance?(可用性とパフォーマンス、どちらのアーキテクチャ特性を目指すことがより重要か)

It depends!

## Chapter 5. Identifying Architectural Characteristics

与えられた問題のarchitecture characteristicsを明らかにすることはarchitecture作成における最初のステップ。
このステップには少なくても、domain concerns, requirements, implicit domain knowledgeという三つの視点がある。

### Extracting Architecture Characteristics from Domain Concerns

ドメインの関心事を適切なarchitecture characteristicsに変換する必要がある。ドメインのゴールや状況を理解しておくことは適切な決定の基礎になる。
すべてのarchitecture characteristicsを最初からサポートしようとするのはアンチパターン。なぜならドメインの問題に取り組む前にシステムが複雑になりすぎてしまうから。

また、サポートするべきarchitecture characteristicsの優先リストを作る試みも失敗に終わることがおおいとされています。関係者全員が優先順に同意することは滅多にないからです。そこで、順位をつけずに優先するトップ3を決めてもらう程度の粒度のほうがうまくいくとされています。

ドメインの関心事からarchitecture characteristicsを抽出することは簡単に思えるかもしれませんが、architectとステークホルダーが異なる言語を話すために話が噛み合わなくなることがあります。
具体例として、市場までの投入時間が、agility, testability, deployabilityに対応するといった対応表が紹介されています。 
ここで重要なのは、市場までの投入時間とagilityが1:1で対応するわけでなく、さらにtestability, deployabilityまで必要ということです。

### Extracting Architecture Characteristics from Requirements

ユーザ数やスケールの期待は要件に明示されることもある。またドメイン知識に由来することもある。
具体例として、大学の履修登録システムにおいては締切直前にリクエストが集中する等。

また、Architectural Katasというサイトが紹介されています。(本ではhttpですがhttps)
https://nealford.com/katas/

### Case Study: Silicon Sandwiches

あるサンドイッチ店でのオンライン注文を例に実際にarchitecture characteristicsを判断していきます。
本書は具体例を要所で乗せてくれているので非常に参考になります。

There are no wrong answers in architecture, only expensive ones.

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

これはいわゆる札束で解決というのもこういうことなのかもと思いました。

### Self-Assessment Questions

###### Give a reason why it is a good practice to limit the number of characteristics("-ilities") an architecture should support.(アーキテクチャがサポートすべき特性(イリティ)の数を制限することが良い習慣である理由を述べよ)

ドメインの問題に取り組む際にシステムが複雑になり過ぎてしまうから。

###### True of false: most architecture characteristics come from business requirements and user stories.(ほとんどのアーキテクチャ特性がビジネス要件とユーザーストーリーに由来するというのは正しいか)

false. ドメインの関心事や暗黙的な特性からも導かれる。

###### If a business stakeholder states that time to-makret(i.e, getting new features and bug fixes pushed out to users as fast as possible) is the most important business concern, which architecture characteristics would the architecture need to support?(ビジネスのステークホルダーが、市場投入までの時間(すなわち、新機能やバグ修正をできるだけ早くユーザーに提供すること)が最も重要なビジネス上の関心事だと述べた場合、アーキテクチャはどのアーキテクチャ特性をサポートする必要があるか)

Agility, testability, deployability.

###### What is the difference between scalability and elasticity?(スケーラビリティと弾力性の違いを述べよ)

どちらもユーザやリクエスト数の上昇に対してシステムの処理能力を維持できるかに関する特性だが、elasticity(弾力性)はバーストに耐えられるかという観点で評価される。

###### You find out that your company is about to undergo several major acquisitions to significantly increase its customer base. Which architectural characteristics should you be worried about?(顧客基盤を大幅に増やすために、あなたの会社がいくつかの大規模な買収を行おうとしていることがわかったとする。どのようなアーキテクチャ特性を心配する必要があるか)

相互運用性、スケーラビリティ。

## Chapter 6. Measuring and Governing Architecture Characteristics

### Measuring Architecture Characteristics

組織内で共通のArchitecture characteristicsの定義をもつにあたり以下が問題になる。

* 意味が曖昧なまま用いられている。(例 agility, deployability)
* 定義が様々。(例 performance)
* 複合的。(例 agilityはmodularity, deployability, testabilityに分解できる)

計測可能な特性を見つけるためにチームは客観的な定義を定めて合意する必要がある。

パフォーマンスの計測にしても、平均から統計モデルを用いたリアルタイム監視まで様々なレベルがある。  
またFirst Contentful Paint(コンテンツが描画されユーザにページが読み込み中であると示されるまでの時間)やFirst CPU Idle(メインスレッドが停止し、入力を受け付けるまでの時間)といった様々なメトリクスがある。

コードに関する計測としては循環的複雑度(Cyclomatic Complexity)が紹介されています。
閾値として設定する値を定めるにあたって、機能が複雑なのは問題領域のせいなのか、コードの質のせいなのかを見極める必要があります。

開発プロセスに関する指標としては、テストのカバレッジ率やデプロイに関する指標(成功率、時間)が紹介されています。

### Governance and Fitness Functions

Architectが優先すべきarchitecture characteristicsを見極めたとして、それを開発者にrespectしてもらうためにはどうすればよいか。モジュール性のように重要だが速度のために犠牲にされがちなものを守っていくための統制の仕組みが必要になってくる。
ここではfitness functions(適応度関数)という考え方を応用したarchitecture fitness functionが紹介されています。
これはarchitectureに対するobjective integrity assessment(客観的な整合性評価)を提供するなんらかの仕組みと定義されています。
具体的には、モジュールの循環依存や3章で紹介された主系列からの距離、レイヤードにおける制約違反を検出するツールをCIで適用します。
自分の現在の関心はRustにあるのですが、具体例として挙げられているJavaのエコシステムは本当に成熟しているなと思わされます。

```
layeredArchitecture()
        .layer("Domain")
        .layer("Persistence")
        .whereLayer("Persistence").mayOnlyBeAccessedByLayers("Domain")
```

のようなAPIでtestが書けるのはすごいと思います。

### Self-Assessment Questions

###### Why is cyclomatic complexity such an important metric to analyze for architecture?(循環的複雑度がアーキテクチャを分析する上で重要な指標なのはなぜか)

複雑すぎるコードはモジュール性、テスト容易性等の事実上すべてのコード特性に悪影響を与えるから。

###### What is an architecture fitness function? How can they be used to analyze an architecture?(アーキテクチャ適応度関数とは何か。アーキテクチャを分析するためにどのように使用できるか)

Architectureを評価するための客観的指標を提供してくれるもの。CI等で適用を自動化して統制を仕組みにして統制を実現する。

###### Provide an example of an architecture fitness function to measure the scalability of an architecture.(アーキテクチャのスケーラビリティを計測するためのアーキテクチャ適応度関数の例を示せ)

単位時間あたりのリクエスト数とデプロイ単位の比率が一定の範囲内に収まっているかのメトリクスとその監視ルール。

###### What is the most important criteria for an architecture characteristic to allow architects and developers to create fitness functions?(アーキテクトや開発者が適応度関数を作成できるようにするためにの、アーキテクチャ特性の最も重要な基準は何か)

計測可能な程度に具体的であること。

## Chapter 7. Scope of Architecture Characteristics

現代においては、architecture characteristicsはシステム全体ではなく分割された単位(スコープ)ごとに適用される。
この単位をArchitecture quantum(アーキテクチャ量子)として定義する。

個人的にはarchitecture quantumを定義してそこから演繹的にシステムを分割していくというより、architecture characteristicsの適用範囲という観点からarchitecture quantumをとらえていくのがよいと思った。
Architecture quantumの定義は

> An independently deployable artifact with high functional cohesion and synchronous connascence

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

とされており、independently deployableは依存するデータベースも量子の一部であることにつながる。
また、high functional cohesionは機能的凝集を意味し、DDDの境界づけられたコンテキストに対応する。
そして、synchronous connascenceはあるアプリケーションが同期呼び出ししているアプリケーションも量子の一部になることを意味する。なぜ同期呼び出しが量子の範囲を広げる方向に働くかというと呼び出しもとと呼び出し先にはおなじ運用特性(architecture characteristics)が求められることになるから。

まとめると、architectural characteristicsはある範囲の機能を実現するための同期呼び出ししているアプリケーション群 + 依存データストアに対して定義される。
ので、DDDの文脈では境界づけられたコンテキストごとにarchitecture characteristicsを定義するということになりとても自然な主張に思えました。

### Self-Assessment Questions

###### What is an architectural quantum, and why is it important to architecture?(アーキテクチャ量子とは何か)

An independently deployable artifact with high functional cohesion and synchronous connascence.
境界づけられたコンテキスト内のマイクロサービス群 + 依存データストアという理解。1マイクロサービスより広い。
これがarchitectureにとって重要なのはarchitectural quantumごとにarchitectural characteristicsが定義されるから。

###### Assume a system consisting of a single user interface with four independently deployed services, each containing its own separate database. Would this system have a single quantum or four quanta? Why?(1つのユーザーインターフェイスと4つの独立してデプロイされたサービスがあり、各サービスが独立したデータベースを持つシステムがあるとする。このシステムのアーキテクチャ量子は1つだろうか、それとも4つだろうか。理由も答えよ)

Service間に同期的呼び出しがないと仮定すると、4 quanta. architectural quantumをarchitecture characteristicsのscopeの観点から評価すると、各serviceごとにもとめられる特性はことなる可能性があるから。例えばService1にはPerformanceやScalabilityが重視される一方で、Service2ではそれらの優先度よりSecurityがより重視されるといった状況が考えられるから。 

###### Assume a system with an administration portion managing static reference data(such as the product catalog, and warehouse information) and a customer facing portion managing the placement of orders. How many quanta should this system be and why? If you envision multiple quanta, could the admin quantum and customer-facing quantum share a database? If so, in which quantum would the database need to reside?(静的な参照データ(製品カタログや倉庫情報)を管理する管理部門と、発注を管理する顧客対応部門をもつシステムがあるとする。このシステムのアーキテクチャ量子はいくつにすべきだろうか。また、その理由は何か。複数の量子を想定している場合、管理用の量子と顧客対応の量子はデータベースを共有できるか。その場合、データベースはどの量子に置く必要があるか)

場合による(与えられた情報だけだと判断できない)。
仮に量子を1にする場合はDBを共有することも可能。量子を2とする場合はDBは共有できない。なぜなら共有するとDBのスキーマ変更時に同時にデプロイが必要になる場合があり独立したデプロイ可能性を侵害するから。

## Chapter 8. Component-Based Thinking

コンポーネントは

> the physical manifestation of a module.

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

と定義されています。moduleが物理的にパッケージ化されたもので、具体例としてはrubyのgem。
Rustではモジュールはモジュール(`std::io`)、パッケージはパッケージ(`tokio`)と1:1対応していると考えて良いでしょうか。
(packageは最大で1つのlib crateと複数のbin crateからなるので、依存性の文脈ではpackage = crateと考えてよいという理解です)

ただ、用語を定義しながら話を進めてきた本書では珍しく8章のコンポーネントは多義的です。このあとにコンポーネントの分類の話が続くのですが、コンポーネントにはアプリケーションと同じアドレス空間で実行されるライブラリから、マイクロサービスのデプロイ単位、レイヤードアーキテクチャにおける1レイヤ等さまざまな種類があるとしています。

コンポーネントの粒度を決めていくアプローチとしてレイヤードアーキテクチャのような技術による分割とドメインによる分割の説明があります。各アーキテクチャの詳細は2部で解説されます。
大切なのは採用したアーキテクチャスタイルに関わらず適切なコンポーネントの粒度を見つけるのはイテレーティブなアプローチがもっとも効果的と理解しました。
自分の今のスタンスとしては、あまり用語の定義から演繹的に考えずに、各モジュール/コンポーネントの責務がチームで合意されていて、testabilityが保たれている(テストが書きやすい)状態になっていればいいのかなと考えております。

Entity Trap(DBのテーブルとドメインのエンティティが1:1)についても言及されています。
Entity Trapのなにがよくないかというと、ソースコードのパッケージ化や全体的な構造化という点で、開発チームに何のガイダンスも与えないと説明されており、これは本当にその通りだと思います。(なにも抽象化してないが詰め替えだけは必要な処理はつらい。最低でもなんらかの機械的な変換機能が欲しい)

### Self-Assessment Questions

###### We define the term component as a building block of an application - something the application does. A component usually consist of a group of classes or source files. How are components typically manifested within an application or service?(本書では、コンポーネントを、アプリケーションの構成要素、つまりアプリケーションが行うことを定義している。コンポーネントは通常、クラスやソースファイルのグループで構成される。アプリケーションやサービスの中で、コンポーネントは通常どのように表現されるか)

質問のsomething the application does(アプリケーションが行うこと)の箇所の意味が理解できませんでした。
マイクロサービスの文脈では、独立してデプロイ可能なサービスを指すこともあるし、アプリケーションにおいてはレイヤードの1レイヤーをさすこともある。
用語をできるだけ定義しながら話を進めてきた本書にしては珍しく、コンポーネントは多義的だなと思いました。

###### What is the difference between technical partitioning and domain partitioning? provide an example of each.(技術による分割とドメインによる分割の違いは何か。それぞれの例を示せ)

技術による分割は、プログラミング言語のライブラリ依存性による分割。結果的にリクエスト、レスポンスを制御する層やデータの永続層といった分割がなされる。
ドメインによる分割は業務フローを中心にした分割。

###### What is the advantage of domain partitioning?(ドメインによる分割の利点は何か)

自分が特にメリットだと思う点は、コードがビジネス機能により近い形でモデル化されること、メッセージフローが問題領域と一致していることだと思います。

###### Under what circumstances would technical partitioning be a better choice over domain partitioning?(ドメインによる分割よりも技術による分割が適切な選択なのは、どのような状況のときか)

ドメインが複雑でなかったり、ドメインの分析が不十分な状態でアプリケーションを書き始めなければいけない場合。


###### What is the entity trap? Why is it not a good approach for component identification?(エンティティの罠とは何か。エンティティの罠がコンポーネントを判別する際によくないのはなぜか)

DBのテーブル構成をそのまま、ドメインのエンティティと1:1に対応させてしまうこと。
こうしたエンティティはモジュールやコンポーネントを作り上げていくプロセスに対してガイダンスとならないから。
(これは実体験として納得できます)

###### When might you choose the workflow approach over the Actor/Actions approach when identifying core components?(コアコンポーネントを判別する際に、アクター/アクションアプローチよりもワークフローアプローチを選択するのはどのような場合か)

DDDを利用せず、かつアクターが明確でない場合。

# Part II. Architecture Styles

Architecture styleは、フロントエンドやバックエンドのソースコードがどのように編成されているか、そしてそのソースコードがどのようにデータストアと相互作用するかについての包括的な構造と定義されています。
これはarchitecture styleの中で特定の解決策を形作る低レベルの設計構造であるarchitecture patternと異なるものとしています。
これだけ聞いてもまだarchitecture styleについてはよくわからないので9章の基礎を読んでいきます。

## Chapter 9. Foundations

Part IIでarchitecture styleとarchitecture patternの違いは時に混乱を招くとされていたので両者は違うものと考えたのですが、ここではarchitecture styleはarchitecture patternと呼ばれることもあると説明されていています。
今のところ両者は違うものとして考えた方が良いのか判断がついていません。
ので、architecture patternはいったん気にせず、architecture styleについてみていきます。
まず定義ですが、様々なarchitecture characteristicsをカバーするコンポーネント同士の名付けられた関係を説明するものとされています。
また、後の記述で、architecture stylesはmonolithicとdistributedの二つに分類できるされています。

* Monolithic
  * Layered architecture
  * Pipeline architecture
  * Microkernel architecture
* Distributed
  * Service-based architecture
  * Event-driven architecture
  * Space-based architecture
  * Service-oriented architecture
  * Microservices architecture

上記のように各分類はさらに分類できます。なので結局はlayeredだったりmicroservicesだったりについての話なので、architecture styleとpatternの定義についてはこだわらなくてよいのかもしれません。

### Big Ball of Mud(巨大な泥団子)

認識できるarchitecture structureが不在の状態をBig Ball of Mud(巨大な泥団子)と呼ぶ。
現代的には、内部構造を持たずにevent handlersが直接databaseを操作するようなapplicationのこと。
みんな避けたいとわかっているが、多くのプロジェクトで統制不足により誕生してしまう。

### The Fallacies Of Distributed Computing(分散コンピューティングの誤信)

Distributed architecture stylesはperformance, scalability, availabilityの点でmonolithic architectureよりもはるかに強力とされているが、そこにもトレードオフがある。
以下では[the fallacies of distributed computing](https://en.wikipedia.org/wiki/Fallacies_of_distributed_computing)で述べられている8つの過信についてみていきます。

#### Fallacy 1: The Network is Reliable(ネットワークは信頼できる)

networkは信頼できない。なのでservice間の通信はすべて失敗する可能性がある。
たしかRelease It!で述べられていたかと思うのですがnetwork越しの通信にはすべてtimeoutを設定せよという教えがあったかと思います。同一service内であれば、シンプルなメソッド呼び出しになるところが、serviceを跨ぐとtimeoutの設定とretry policy(exponential/jitter, retryableか否かの判定ロジック)が絡んできてひとつ複雑度がますと考えてます。

#### Fallacy 2: Latency Is Zero(レイテンシーがゼロ)

Component間のlocal method callに比べてservice間の通信は常に遅くなる。したがって、latency averageと95~99 percentile latencyを把握しておかなければならない。

#### Fallacy 3: Bandwidth Is Infinite(帯域幅は無限)

帯域幅はmonolithic architectureでは通常問題にならないが、分散システムではそうとは限らない。
latencyとの問題にもなってきますが、自分もloopの中で実はnetwork callが行われていたみたいなことを経験したことがあります。

#### Fallacy 4: The Network Is Secure(ネットワークは安全)

The network is not secure.
Distributed systemになることで、the surface area for threats and attacksは増加してしまう。
service間通信であってもendpointを保護する必要があることもdistributed systemでperformanceが低下しがちな要因になっている。

#### Fallacy 5: The Topology Never Changes(トポロジーは決して変化しない)

network topology(routers, hubs, switches, firewalls, networks)は変化する。
従って、architectsは運用担当者やネットワーク管理者と常にコミュニケーションをとる必要がある。

#### Fallacy 6: There Is Only One Administrator(管理者は一人だけ)

distributed architectureは複雑なので維持するためには管理者が複数人必要になり、それにともなって調整コストも増える。

#### Fallacy 7: Transport Cost Is Zero(転送コストはゼロ)

fallacy 2のlatencyとは違い、REST呼び出し自体タダではなくコストがかかる。

#### Fallacy 8: The Network Is Homogeneous(ネットワークは均一)

networkが単一vendorのhardwareから形成されるとは限らない。


#### Other Distributed Considerations(その他の考慮事項)

* Distributed logging(分散ロギング)
  * 特定のワークフローにおけるログが複数箇所にあらわれるので調査が難しくなる
* Distributed transactions(分散トランザクション)
  * datastoreが提供してくれるACIDに頼れないので、eventual consistency(結果整合性)をうけいれる必要がある
  * [transactional sagas](https://microservices.io/patterns/data/saga.html)のような分散トランザクションを管理する手法が必要になる
* Contract maintenance and versioning
  * endpointのAPIの変更コストがあがる。特に後方互換性をもたない破壊的変更の場合。

### Self-Assessment Questions

###### List the eight fallacies of distributed computing(分散コンピューティングの誤信を8つ挙げよ)

* The Network is Reliable(ネットワークは信頼できる)
* Latency Is Zero(レイテンシーがゼロ)
* Bandwidth Is Infinite(帯域幅は無限)
* The Network Is Secure(ネットワークは安全)
* The Topology Never Changes(トポロジーは決して変化しない)
* There Is Only One Administrator(管理者は一人だけ)
* Transport Cost Is Zero(転送コストはゼロ)
* The Network Is Homogeneous(ネットワークは均一)

###### Name three challenges that distributed architectures have that monolithic architectures don't(モノリシックアーキテクチャにはない、分散アーキテクチャの課題を3つ挙げよ)

* Distributed logging(分散ロギング)
* Distributed transactions(分散トランザクション)
* Contract maintenance and versioning(API管理)

###### What is stamp coupling?(スタンプ結合とはなにか)

処理に必要のないデータにまで依存してしまうこと。引数の構造体の一部のfieldしか必要ない場合等。

###### What are some ways of addressing stamp coupling?(スタンプ結合に対処する方法にはどのようなものがあるか)

GraphQLを利用してclient側で必要な情報のみ取得するようにする。


## Chapter 10. Layered Architecture Style

組織のチーム構成(UI,backend, DBA)とlayeredの各層が一致することにより、もっとも一般的なarchitectureの一つとなっているlayered architectureについて。

### Topology

Layered architectureはapplicationのcomponentをlayerに分けます。
各layerはapplication内で特定の役割と責務を持ちます。
layer数と分け方については特に制限はありませんが、通信ロジックを担うpresentation layer, ビジネルルールを担うbusiness layer, 永続化/DB処理を担うpersistence layerのような分割が一般的です。
Layered architectureは技術による関心の分離をおこなっているといえます。
そのため、あるドメインの変更が各レイヤーの変更につながりやすいです。

### Layers of Isolation(層の分離)

各layerはclosedかopenに分類される。リクエストの処理において、そのlayerをスキップしてその下のlayerを呼び出せるかいなかを意味する。closedはスキップできず、openはスキップできる。
具体的にはリクエストを処理するlayerからpersistence layerに直接アクセスしてよいかのように問題になる。
このアクセスを許すとpersistence layerの変更が2層に影響するようになるので、component間の依存性が強くなることになる。

### Adding Layers(層の追加)

あるlayerをopenにするのが理にかなっている場合もある。
例えば、presentation layerにbusiness layerのあるcomponentにアクセスしてほしくない場合、新たにbusiness layerの下にservice layerを追加してそのcomponentを移動させる。このservice layerはopenにしてbusiness layerからは必要に応じてアクセスするといった場合。

### Architecture sinkhole anti-pattern

Architecture sinkhole anti-patternはリクエストが各layerで単にpass throughされる場合に起きる。
(本書ではwith no business logic performedとされているがbusiness logicはbusiness layerでは?と思ったりしました。)
Layered architectureではこのようなリクエストパスがあること自体は避けられない。
このアンチパターンに陥っているかの判断基準として、sinkholeになっているリクエストの比率を明らかにし、それが8割を超えていたらlayered architectureが適していないことの顕であると判断できる。
対策としてはlayerをopenにすることが考えられるがこれは当然トレードオフになる。

あるコードベースで、layer間の詰め替え処理だけあって、各layerの抽象化があまりメリットをもたらさないなと思うこともあったのでこの状態にsinkholeという名前がついているのは知りませんでした。
Layered architectureについて完結に説明してくれているので、チームで馴染みのないメンバーに最初に読んでもらうのによい章だと思いました。

### Self-Assessment Questions

###### What is the difference between an open layer and a closed layer?(開放レイヤーと閉鎖レイヤーの違いは何か)

上位層がその層の下の層に直接アクセスできるか否か。

###### Describe the layers of isolation concept and what the benefits are of this concept.(分離レイヤーの概念を説明し、その利点を説明せよ)

layerのcontract(api)がかわらない限りにおいて、あるlayerの変更は当該layerに閉じていて他のlayerに影響しない。
利点は変更の影響範囲を制御できること。

###### What is the architecture sinkhole anti-pattern?(アーキテクチャシンクホールアンチパターンとは何か)

各layerがなにもせず下のlayerにリクエストを渡すだけになっている状態。特に処理の大部分がこの状態になっている場合を指す。

###### What are some of the main architecture characteristics that would drive you to use a layered architecture?(レイヤードアーキテクチャを使用することを促進する主なアーキテクチャ特性は何か)

コストとシンプル性。

###### Why isn't testability well supported in the layered architecture style?(レイヤードアーキテクチャのスタイルでテスト容易性が十分にサポートされないのはなぜか)

数行の変更であっても実行に時間のかかるテストスイートを走らせる必要があるからという記述があるが、あまり説得的でないように思いました。

###### Why isn't agility well supported in the layered architecture style?(レイヤードアーキテクチャでアジリティが十分にサポートされていないのはなぜか)

deployabilityが低いからとされているから。これも実装次第ではと思いました。


## Chapter 11. Pipeline Architecture Style

### Self-Assessment Questions

###### Can pipes be bidirectional in a pipeline architecture?(パイプラインアーキテクチャでパイプを双方向にすることは可能か)

できない。

###### Name the four types of filters and their purpose.(フィルターの種類を目的と共に4つ挙げよ)

* Producer
  * dataの出力、処理の起点。
* Transformer
  * 入力dataを変換して出力する。`map()`的な機能。
* Tester
  * 入力を検査し、変換を加えて出力する。`reduce()`的な機能。
* Consumer
  * pipelineの最終処理。結果を永続化したり表示したりする。

###### Can a filter send data out through multiple pipes?(フィルターは複数のパイプを経由してデータを送り出せるか)

できる。

###### Is the pipeline architecture style technically partitioned or domain partitioned?(パイプラインアーキテクチャは技術によって分割されているか、それともドメインによって分割されているか)

技術によって分割されている。

###### In what way does the pipeline architecture support modularity?(パイプラインアーキテクチャはどのような方法でモジュール性をサポートしているか)

処理をfilterに分割し、かつstatelessに保つことでモジュール性を向上させている。

###### Provide two examples of the pipeline architecture style.

* [nushell](https://github.com/nushell/nushell)
* [AWS Glue](https://docs.aws.amazon.com/glue/index.html)


## Chapter 12. Microkernel Architecture Style

plug-in architectureとも。ユーザの環境にインストールされて使われるproduct-based applicationに適しているarchitecture。editorは大体このarchitectureな気がします。

### Topology

core systemとplug-in componentsの二つからなる。

### Core System

systemを実行するのに必要最低限の機能。
ほとんどなにも処理を行わないapplicationのhappy pathともいえる。
cyclomatic complexityをplug-inに切り出すことによって、testabilityを高めている。
UIをcore systemと一部とするかも、core systemをlayeredにするかも特に制限はない。

### Plug-In Components

特殊な処理や追加機能を含む独立したコンポーネント。plug-in間で依存性がないのが理想。
compile basedかruntime basedに分類できる。
core systemとREST等で通信することもありえる。core systemとは別にplug-in用のデータベースを用意することもある。

### Registry

core systemがplugin-inの情報を知るための仕組み。
単純なmap構造のデータから[HashiCorpのConsul](https://www.consul.io/)のような複雑なものまである。

### Self-Assessment Questions

###### What is another name for the microkernel architecture style?(マイクロカーネルアーキテクチャの別称は)

Plug-in architecture。

###### Under what situations is it OK for plug-in components to be dependent on other plug-in components?(プラグインコンポーネントが他のプラグインコンポーネントに依存していても問題ないのはどのような状況か)

わかりませんでした。

###### What are some of the tools and frameworks that can be used to manage plug-ins?(プラグインを管理するためのツールやフレームワークにはどのようなものがあるか)

自身で情報を保持するか、なんらかのservice discoveryを利用する。consul(使ったことがない)

###### What would you do if you had a third-party plug-in that didn't conform to the standard plug-in contract in the core system?(コアシステムの標準プラグインコンストラクトに準拠していないサードパーティ製プラグインがあった場合どうするか)

Adaptorを利用する。(よくわかっていないです)

###### Provide two examples of the microkernel architecture style.(マイクロカーネルアーキテクチャの例を2つ挙げよ)

Web browserやIDE。

###### Is the microkernel architecture style technically partitioned or domain partitioned?(マイクロカーネルアーキテクチャは技術によって分割されているか、それともドメインによって分割されているか)

技術によって分割されつつも、ドメインの要素と強く対応づけることで、ドメインによる分割も可能。

###### Why is the microkernel architecture always a single architecture quantum?(マイクロカーネルアーキテクチャはなぜ常に単一のアーキテクチャ量子なのか)

結局はcore systemに依存するから。

###### What is domain/architecture isomorphism?(ドメイン/アーキテクチャの同型性とは何か)

分割の粒度をドメインに対応させられること。

## Chapter 13. Service-Based Architecture Style

### Topology

UI, 個別にdeployされる粒度の荒いservice, 共通のdatabaseからなるのが基本。
各serviceでdatabaseを共有しているのが特徴。UIと対応するserviceの粒度には幅がある。
databaseをservice間で完全に分離できるなら複数ある場合もある。

### Service Design and Granularity(サービスの設計と粒度)

要は、ACID transactionで要件を実装できる構成という理解。

### Database Partitioning(データベース分割)

DBを共有しているトレードオフとして、スキーマ変更時に労力と調整を要する。基本的に前サービスに変更が影響する。
もちろんスキーマをserviceごとに論理的に分割して変更の影響を制御することはできる。
この構成の開発を経験したことがあるのですが、DBのスキーマ管理のやり方次第で開発体験が大きくかわるなと思います。
(そのときはこの構成に名前がついているのを知りませんでした)

### Self-Assessment Questions

###### How many services are there in a typical service-based architecture?(典型的なサービスベースアーキテクチャは、何個くらいのサービスから構成されるか)

7個。

###### Do you have to break apart a database in service-based architecture?(サービスベースアーキテクチャではデータベースを分解しなければならないか)

必要がなければ分割する必要はない。

###### Under what circumstances might you want to break apart a database?(データベースを分解したくなるのはどのような状況か)

DBをドメインで分割したい場合。

###### What technique can you use to manage database changes within a service-based architecture?(サービスベースアーキテクチャの中でデータベースの変更を管理するのに使えるテクニックにどのようなものがあるか)

DBを論理的に分割して、ライブラリでラップする。

###### Do domain service require a container(such as Docker) to run?(ドメインサービスの実行にはコンテナが必要か)

当然コンテナ化する必要がある。

###### Which architecture characteristics are well supported by the service-based architecture style?(サービスベースアーキテクチャはどのようなアーキテクチャ特性を十分にサポートするか)

* deployability
* modularity
* testability

###### Why isn't elasticity well supported in a service-based architecture?(サービスベースアーキテクチャではなぜ弾力性が十分にサポートされてないのか)

サービスの粒度が粗いかため。

###### How can you increase the number of architecture quanta in a service-based architecture?(サービスベースアーキテクチャでアーキテクチャ量子の数を増やすにはどうすれば良いか)

UIとDBもServiceに統合させる。

## Chapter 14. Event-Driven Architecture Style

highly scalableでhigh-performanceなdistributed asynchronous architecture。
request-based modelではなく、event-based modelに基づく。これは特定の状況に反応して、そのeventに基づいたactionを実施するモデル。

### Topology

mediator topologyとbroker topologyという二つに大別される。
broker topologyはevent処理に際して動的な制御が必要になる場合に、mediator topologyはevent処理のworkflow制御が必要な場合にそれぞれ利用される。これらのtopologyではarchitecture characteristicsとimplementation strategiesが異なるので、適切なtopologyを選択することが重要。

#### Broker Topology

中央のevent mediatorが存在しない点がmediator topologyと異なる。
message flowはmessage broker(RabbitMQ等)を介して、chain-like broadcasting fashionでevent processorに分散される。
event processing flowがsimpleでcentral event orchestrationを必要としない場合に便利なtopology。

broker topologyに以下の4つの主要なarchitecture componentがある。

* initiating event(開始イベント)
  * event flowを開始する最初のevent
  * オンラインオークションでの入札、医療給付システムにおける転職等
* event broker
* event processor
  * event brokerからeventを受け取り、処理を行い、processing eventを作成する
* processing event(処理イベント)
  * 必要に応じてevent brokerに送られる

Broker topologyでは、他のevent processorを気にすることなく、event processorが何をしたかをsystemの残りの部分に伝えることが良いpracticeとされている。
Broker topologyは高いperformanceやscalabilityをもつが、以下のようなマイナス面もある。

* workflow全体を制御できない。
* Error Handling
  * 障害が発生してもsystem内のどの要素もそれを認識できない。なんらかの自動または手動の介入が必要になる。
* Recoverability
  * 開始eventを再送信できないので、失敗したところから再開するのが難しい。

Broker topologyは各componentが疎結になっていて、非常に素晴らしいarchitectureだと思うのですがエラー処理を考えると運用がとても大変そうに思えます。
自分は通知やBatch処理を非同期処理としてQueueに逃すようなシステムしか経験したことがないので、broker topologyは是非一度は体験してみたいarchitectureです。

#### Mediator Topology

broker topologyのいくつかの欠点を解消する(addresses some of the shortcomings)のがmediator topology。
mediatorはworkflowを制御する。
このtopologyではinitiating eventはevnet queueに送られ、mediatorによって受け取られる。
mediatorのみがeventの処理方法を知っており、対応するprocessing eventを生成して、専用のevent queueにeventを送信する。専用のevent queueではprocessorがlistenしており、通常は作業の完了をmediatorに通知する。
broker topologyと異なり、event processorは自身が行ったことをsystemにadvertiseしない。

Mediator topologyのほとんどの実装では、複数のmediatorがdomain,event groupごとに存在する。
また、mediatorに前段にmediatorを置くような構成もある。

Mediator topologyはworkflowに関する知識と制御をもつ。そうすることによって、event stateを管理しerror handling, を可能にする。
例えば、event処理が途中のstepで失敗した場合、その状態を永続化し、次のevent処理時に失敗したところから処理を再開するといったことが可能になる。

broker topologyとmediator topologyではprocessing eventについての解釈が異なる。
broker topologyではprocessing eventはsystemで発生したevent(things that have already happened)として公開された。また、eventは無視されることもある。
一方、mediator topologyにおけるprocessing eventはcommand(things that need to happen)を意味する。
mediator topologyのtrade-offとしては、workflowの動的な処理を宣言的に記述するのが難しい。またevent processorはbroker topologyに比べてmediatorに対して結合度が上がる。

本質的には、workflow control and error handling capability とhigh performance and scalabilityのtrade-offで、brokerかmediator topologyかが決まる。

### Asynchronous Capabilities

Event-driven architectureは非同期通信のみに依存しているという特徴をもつ。
この非同期通信はさらに以下の方式に分類できる。

* fire-and-forget processing(no response required)
* request/reply processing(response required from the event consumer)

非同期通信は、eventを発行した時点で処理にたいしてresponseを返せるので、responsiveness(応答性)が高い。
主な問題点(main issue)はerror handling。これがevent-driven systemを複雑にする。

### Error Handling

workflow event pattern of reactive architectureが非同期処理でのerror handlingに対処する方法の一つ。
このpatternでは、workflow delegateを利用する。
具体的には、event consumerの処理中にerrorが発生したら、そのerrorをworkflow processorのqueueに投げる。
workflow processorはerrorをうけとると、修正が可能なら修正して元のqueueに再びenqueueする。
修正できない場合は、さらに別のqueueに送る。このqueueはdashboardと呼ばれるapplicationがlistenしており、運用担当者にエラーが表示される。

この説明を読んだ時に、自動でエラーを修正して再リトライなんてできるのかなと思いました。失敗の原因が外部サービスの一時的なダウン等で、単純なretryならできそうですが、本書には入力を修正と書いてありました。ユーザの助けなしに誤った入力を正しい入力に変換することなんてできるか疑問に思いました。ユーザの意に反した修正だと問題がさらにややこしくなりそうだなとも。

### Preventing Data Loss

非同期処理においては、data lossは常に最大の懸念事項(primary concern)になる。

* EventのEnqueueが失敗する
  * enqueueを同期通信にしてなんらかの永続化成功をもって、enqueue成功とする
* Queueからeventを受信後に、processorが落ちる
  * processorがevent完了をqueue側に知らせるようにする
  * AWS SQSはこれと思われる
* Event processorが永続化に失敗する
  * これは非同期通信でなくても起きることなのでは。

主に、enqueue,dequeueに関連してeventがlossしないことが必要。

### Broadcast Capabilities

broadcastはevent processor間の最上位の分離レベル(the highest level of decoupling between event processors)を実現する。

### Request-Reply

Event-driven architectureにおいて、同期通信はrequest-reply messaging(疑似的同期通信)によって実現される。
これはevent producerがreply queueをもち、eventをproduceしたあとにreply queueでblockすることで実現される。
request-reply messagingの主な実装には二つの種類がある。

#### Correlation ID(相関ID)

messageがもとのmessageのreplyであることを示すために、correlation id fieldをmessageに設けてreplyが紐づくrequestを特定できるようにするもの。

#### Temporary queue

特定のrequest専用のqueueが一時的に作成する。temporary queueの識別子をmessageにのせるので、consumerはその識別子でtemporary queueを特定して、replyを送る。
temporary queueはシンプルであるものの、状態を管理する必要があるので、performanceに影響を与える。
そのため、correlation idを利用する方式がおすすめ。

### Self-Assessment Questions

###### What are the primary differences between the broker and mediator topologies?(ブローカートポロジーとメディエータートポロジーの主な違いは何か)

workflowを制御するmeditorが存在するかどうか。
また、processing eventに対する解釈が違う。

###### For better workflow control, would you use the mediator or broker topology?(ワークフローをよりよく制御するには、メディエーターとブローカーのどちらのトポロジーを使用すべきか)

mediator。

###### Does the broker topology usually leverage a publish-and-subscribe model with topics or a point-to-point model with queues?(ブローカートポロジーは通常、トピックを使用したパブリッシュ/サブスクライブモデルとキューを使用したポイント二ポイントモデルのどちらを活用するか)

publish-and-subscribe model。


###### Name two primary advantage of asynchronous communications.(非同期通信の主な利点を2つ挙げよ)

応答性とモジュール性。

###### Give an example of a typical request within thr request-based model.(リクエストベースモデルにおける典型的なリクエスト例を挙げよ)

過去6か月間の注文履歴の取得。

###### Give an example of a typical request in an event-based model.(イベントベースモデルにおける典型的なリクエスト例を挙げよ)

オンラインオークションでの商品への入札。

###### What is the difference between an initiating event and a processing event in event-driven architecture?(イベント駆動アーキテクチャにおける開始イベントと処理イベントの違いは何か)

それがシステムの外部から来るか、システム内部で生成されるか。

###### What are some of the techniques for preventing data loss when sending and receiving messages from a queue?(キューからメッセージを送受信する際にデータロスを防ぐための技術にはどのようなものがあるか)

* Enqueue時にqueue側で永続化の成功までを同期通信で担保する
* Dequeue時にqueue側でmessageを削除せずに、consumerからの成功まで削除を遅らせる。

###### What are three main driving architecture characteristics for using event-driven architecture?(イベント駆動アーキテクチャを使う際に核となる3つの主要なアーキテクチャ特性は何か)

* Performance
* Scalability
* Durability

###### What are some of the architecture characteristics that are not well supported in event-driven architecture?(イベント駆動アーキテクチャでうまくサポートされないアーキテクチャ特性はどれか)

* Simplicity
* Testability


## Chapter 15. Space-Based Architecture Style

一般的なweb applicationでは負荷に対してスケールアウトしても、最終的にはDBがボトルネックになる。同時接続トランザクション数等。
同時接続ユーザ数が変動して予測できないようなアプリケーションにおいて、scalabilityをarchitecture的に解決することは、DBをスケールアウトさせたりcacheを後付けしたりするよりもよいアプローチであることが多い。

このarchitectureを初めて知りました。また、実装として紹介されている、[Apache Ignite](https://ignite.apache.org/)や[Hazelcast](https://hazelcast.com/)を利用した経験がないので、具体的なイメージがわきませんでした。
どうやらDBへの書き込みを非同期化して、各applicationのメモリに必要なデータがdbからなんらかの方法でreplicateされるというような仕組みらしいです。
通常のtransactional processingから中央のDBの関与を取り除くことで、near-infinite scalabilityを実現するそうです。一体どんなtrade-offがあるのか逆に怖くなります。

### Self-Assessment Questions

// TODO: space-based architectureの実装イメージがわかったら取り組む。

## Chapter 16. Orchestration-driven Service-Oriented Architecture Style

このarchitectureについても、enterprise service busやenterprise serviceが具体的になにを意味するのかいまいち実装のイメージがわかりませんでした。
各ドメインにCustomerが登場するので、全て切り出して単一のCustomerサービスに分離したところ、各Component間に膨大な量の結合が発生したという例だけは理解できました。
自分は逆のパターン、各ドメインでCustomerを定義するパターンを実装したことがあるのですが、これはこれでつらかったです。(データが自ドメイン+外部サービスに分散しているので、datastore側でsortかけられない等)

### Self-Assessment Questions

Skip。

## Chapter 17. Microservices Architecture

### History

ほとんどのarchitectureの流行りは、architect達が共通の意思決定を行ったことが事後的に認識され、命名されることによって作られる。一方で、microservices architectureは[Microservices](https://martinfowler.com/articles/microservices.html)というMartin FowlerとJames Levisによるブログエントリーをきっかけに普及した。
Microservicesはhigh decouplingを再利用性よりも優先し、bounded contextを物理的にモデル化したもの。

### Granularity(粒度)

Serviceをまたぐとtransaction管理が複雑になるので、serviceの粒度が問題になる。
transactionの範囲(=データの整合性が強く求められる範囲)は要件(ドメイン)で決まるので、この範囲をbounded contextとしてserviceの粒度の基準にしようとしているのがmicroserviceという理解です。
microと書いてあるからといって、必ずしもserviceの粒度を小さく保たなくてはならないわけではないと書いてあります。
適切なboundaryを見つけるためのガイドラインとして以下が挙げられています。

* Purpose
  * 各microserviceは高い機能的凝集を有しており、application全体におけるひとつの重要な振る舞いを提供するが理想。
* Transactions
  * bounded contextはbusiness workflows。distributed transactionを避けられればより望ましい。
* Choreography
  * 機能の実現で必要とするservice間の通信が多くなってしまう場合、serviceの粒度を大きくしたほうがよいかもしれない。

Microservicesではdatastoreも共有しないので、RDBに信頼できる唯一の値を保持するアプローチがとれない。
この問題に対して、ある事実にを管理するドメインを決めて、そのドメインから値を取得するか、replicationやcacheを利用して分散させるかして対応する。
自分は後者のreplicationを利用した方式を経験したことがないのでどうやって実装するのか興味があります。

### Operational Reuse

Microservices architectureがprefer duplication to coupling(結合よりも重複を好む)ではあるものの、これはmonitoring,logging, circuit breakersといったドメインに影響されない運用面での再利用性にまで及ぶか。
microservicesではどうやらこの二つは分けて考えるとあるので、ドメイン以外のapplication共通部分には分離性の要求は及ばないと考えてよさそう。
この問題へのアプローチとして、sidecar patternが提案されている。sidecar componentはPod内のcontainerを想定するとして、このsidecarに運用面の関心事を全て処理させる。

### Frontends

DDDに忠実に従うとUIもbounded contextによって分離されるが、monolithic frontendも登場している。
この辺りは、UIを分断してもUI側でなんらかの共通化は必ず必要になると思うので、組織ごとに自由に決めていいんじゃないかと思う。

### Communication

Microservicesにおける同期通信では、protocol-aware heterogeneous interoperabilityを利用する。
これは要はgRPCのことだと思う。
コラムで、開発チームが誤って違いのチームに結合点を作らないように、違いのチームで異なる技術スタック(Javaと.NET)を使うことを強制した例が登場した。
これはおもしろいけどやりすぎなんじゃないかとは思った。新しいチームできたらGoになるのだろうか。

### Transactions and Sagas

> The best advice for architects who want to do transactions across services is: don’t!

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

とあるように基本はtransaction boundariesとbounded contextを一致させてtransactionが閉じるようにする。
とはいうものの、architecture characteristicsがまったく異なるservice間にtransactionが必要になることもある。そんなときに登場するdistributed transactionのpatternとしてsagaがある。

sagaについては[マイクロサービスパターン](https://www.amazon.co.jp/dp/B086JJNDKS/)や[モノリスからマイクロサービスへ](https://www.oreilly.co.jp/books/9784873119311/)に説明があったのでそこから調べてみようと思いました。

### Self-Assessment Questions

###### Why is the bounded context concept so critical for microservices architecture?(境界づけられたコンテキストの概念はなぜマイクロサービスアーキテクチャにとって重要なのか)

microservicesの粒度はtransactionの範囲で決まり、transactionはデータの整合性を保ちたい範囲を意味し、データの整合性の要求はビジネス上のdomainやworkflowに由来するから。

###### What are three ways of determining if you have thr right level of granularity in a microservice?(マイクロサービスの粒度が適切なレベルにあるかどうかを判断する3つの方法とは)

* Purpose
* Transactions
* Choreography

###### What functionality might be contained within a sidecar?(サイドカーにはどんな機能があるか)

運用、技術的共通事項に関する機能。
authentication, logging, monitoring, tracing, retry, circuit breakers

###### What is the difference between orchestration and choreograph? Which does microservices support? Is one communication style easier in microservices?(オーケストレーションとコレオグラフィの違いはなにか。マイクロサービスはどちらをサポートしているか。マイクロサービスでは、どちらのコミュニケーションスタイルの方が容易か)

中央でworkflowを管理する存在がいるかどうか。microserviceはchoreographと親和性が高いが、局所的なmediatorをもつこともできる。

###### What is a saga in microservices?(マイクロサービスにおけるサーガとは)

複数datastoreにまたがるデータの更新を管理するための実装パターンの一つ。

###### Why are agility, testability, and deployability so well supported in microservices?(マイクロサービスでアジリティ、テスト容易性、デプロイ容易性がサポートされている理由は)

高度に分離された非常に小さなデプロイメントユニットで構成されているから。

###### What are two reasons performance is usually an issue in microservices?(一般にマイクロサービスでパフォーマンスが問題になる理由を2つ挙げよ)

service間の通信でnetwork呼び出しを多様し、その際にauthentication/authorizationのオーバーヘッドが発生するから。

###### Is microservices a domain-partitioned architecture or a technically partitioned one?(マイクロサービスはドメインによって分割されたアーキテクチャか、それとも技術によって分割されえたアーキテクチャか)

domain-partitioned architecture。

###### Describe a topology where a microservices ecosystem might be only a single quantum.(マイクロサービスのエコシステムが単一の量子しか持たない可能性のあるトポロジーを説明せよ)

全てのserviceが同期通信で連携しあっている場合等。

###### How was domain reuse addressed in microservices? How was operational reuse addressed?(マイクロサービスではドメインの再利用はどのように扱われるか)

分離性をより重視し、重複を許容する。


## Chapter 18. Choosing the Appropriate Architecture Style

このarchitectureを使おうとは単純に言い切れない。
それでも、適切なarchitectureの選択に際して考慮されるべき要素はある。

### Shifting "Fashion" in Architecture

Preferred architecture styleは様々な要因によって変化していく。
数年前までは誰もKubernetesを知らなかったし、Docker等のコンテナ技術の影響力は予想以上だった。
また、ビジネスドメインも変化するし、外部要因も影響する。
Architectは現在のtrendを把握して、それに従う場合と例外も設ける場合を賢明に判断しなければならない。

### Decision Criteria(判断基準)

Architectが考慮すべき要素。

* The domain
  * 特にoperational architecture characteristicsに影響を与える側面は理解していなくてはならない
* Architecture characteristics
* Data architecture
  * 本書ではあまり触れられていないがdata設計の理解は必要
* Organizational factors
  * 結局これの影響度が大きい一方で外に出しづらい話なので、いろいろな話が一般化できないのだと思う
* Knowledge of process, teams, and operational concerns
  * 運用や開発プロセスの影響も考慮にいれる。(QAチームとの関わり方とか組織ごとに全然違うなと思います)
  * agile文化が根付いていない組織でそれに依存したarchitecture styleを採用すると失敗する
* Domain/architecture isomorphism(同型性)
  * 問題領域とarchitectureの適しているilitiesが一致しているか

### Self-Assessment Questions

###### In what way does the data architecture(structure of the logical and physical data models) influence the choice of architecture style?(データアーキテクチャ(論理データモデルと物理データモデルの構造)は、どのような方法でアーキテクチャスタイルの選択に影響を与えるか)

整合性を保つ必要がある範囲(=transaction boundaries)に影響し、DBの粒度に影響を与える。

###### How does it influence your choice of architecture style to use?(上記は使用するアーキテクチャスタイルの選択にどのような影響をあたえるか)

Microservicesを選択していた場合、serviceの粒度。

###### Delineate the steps an architect uses to determine style of architecture, data partitioning, and communication styles.(アーキテクチャスタイル、データ分割、通信スタイルを決定する際にアーキテクトが用いる手順を説明せよ)

モノリスor分散 -> dataの持ち方 -> 通信方式(同期or非同期)

###### What factor leads an architect toward a distributed architecture?(アーキテクトを分散アーキテクチャに向かわせる要因は何か)

Scope of Architecture Characteristics(quantum)。

# Part Ⅲ. Techniques and Soft Skills

Software architectureの技術的側面の理解だけでなく、開発チームをガイドし、ステークホルダー達と協力していくにはテクニックとソフトスキルもまた必要になってくる。

## Chapter 19. Architecture Decisions

architectへのcore expectationsの一つにarchitecture decisionsがある。
architecture decisionsは、applicationやsystemの構造に関わる決定又はarchitecture characteristicsに関わる技術的な決定をさす。
architecture decisionsを下す際には、関連情報を集め、正当性を示し、ドキュメント化し、関係者に周知する必要がある。

またRelease It!におけるアーキテクチャ上重要な決定についての考え方も紹介されています。
Release It!では、structure, nonfunctional characteristics, dependencies, interfaces, construction techniquesに関わるものがそれであるとしています。

* Structure(構造)
  * architecture styleに影響を与えるもの
  * マイクロサービス間でデータを共有する等
* Nonfunctional characteristics(非機能特性)
  * "-ilities"のこと
  * Performance等
* Dependencies(依存性)
  * component/serviceのcoupling points(結合点)
  * scalability, modularity, testability等に影響する
* Interfaces
  * component/serviceがどうやってアクセスされるか
  * contractのversioningやdeprecation strategyも含まれる
* Construction techniques(構築手法)
  * platforms, frameworks, tools, processesに関わるものでarchitecture characteristicsに影響するもの

### Architecture Decision Anti-Patterns

Architecture decisionを下す際に起きがちな3つのアンチパターンがある。

* Covering Your Assets Anti-Pattern(資産防御アンチパターン)
* Groundhog Day Anti-Pattern
* Email-Driven Architecture Anti-Pattern

これらのアンチパターンは資産防御の克服がGroundhog Day,その克服がEmail-Drivenという関係にある。

#### Covering Your Assets Anti-Pattern

間違った選択を避けるためにarchitecture decisionsを下すことを避けたり、先延ばしにしたりする場合に発生するアンチパターン。
決定を保留できる期間は代替策がとれる間までの期間(last responsible moment)。
また、そもそも間違った決定をしまっても決定が変更できるような柔軟性を担保しておくために開発チームと密に連携しておくことも重要。

#### Groundhog Day Anti-Pattern

このアンチパターンは、architectが決定の根拠を示さないため、決定が下されたにもかかわらず何度も同じ議論が繰り返されてしまうアンチパターンのこと。
決定の根拠を示す際には、技術的な理由とビジネス上の理由の両方を示すことが重要。
ビジネス的な価値につながらないarchitecture decisionはおそらく良い決定ではない。
ビジネス的な価値は具体的には、コスト、市場投入までの時間、ユーザ満足度、strategic positioning(戦略的ポジショニング)等が一般的。

#### Email-Driven Architecture Anti-Pattern

メール駆動アンチパターンは、そもそもarchitect decisionがなされたことを忘れられたり、知らされていなかったりするためにその決定が実装されないというアンチパターン。
メールでは決定を伝えるツールとして不十分なところからきている。
決定を効果的に伝えるためルールとしては、第一にメールでは決定の性質と文脈のみに言及してWiki等の本文を記録しているシステムに誘導すること。
第二に、その決定に本当に関心がある人にだけ伝えること。

誰が関心があるかわからなかったりするので、開発者全員に周知したほうがよいと考えていたので、関心のある人にだけ伝えるというルールは以外でした。
(それ聞いてなかったです的な事態を避けたい)

個人的にはわざわざアンチパターンを持ち出さず、以下のポイントを守りましょうくらいの話でよいのではと思ったりしてます。

* 決定を先送りできる期間は代替案次第。
* 決定の際はビジネスと技術両方の根拠を明示する。
* ドキュメント化して関係者に周知する。

### Architecture Decision Records

Architecture Decision Records(ADR)というarchitecture decisionをドキュメント化する手法について。
ADRについては以前、同僚の方が実践されており自分でも真似しておりました。
厳密にやろうとするともっと細かく決まっているのかもしれませんが、要はADRとはarchitecture decisionをmarkdownで書く際のtemplateです。以下では各sectionについてみていきます。

#### Title

architecture decisionを要約した短い文。ADRを識別するために通常は連番もふるそうです。RFCみたいな感じでしょうか。
例. 42. use of Asynchronous Messaging Between Order and Payment Services.

#### Status

Proposed(提案済み), Accepted(承認済み),Superseded(破棄)のいずれかのstatusを記載します。
Proposedはなんらかの意思決定プロセスの途中、Acceptedは決定が承認され実装の準備ができていること、Supersededは決定が他のADRに取って代わられた状態を表します。
破棄済みのステータスを用意しておくことで、決定の歴史的経緯やなぜ変更されたのか、新しい決定はなんなのかを記録できるようになります。破棄された側は新しいADRの、破棄した側はされた側のADRをそれぞれstatusに記載します。
必要に応じて、Request for Comments(RFC)等のステータスを設ける例も紹介されています。

#### Context

決定時の状況や具体的な問題点を記載します。
これを言語化しておくのはとても大切だと思います。えてしてなんでこうなっているのだろうと思うようところは当時にはそれなりの理由があったりするもので、それを知っているかどうかで対応する人に影響があると思っております。
代替案の検討が長くなりそうなら、alternatives section作ってもよいとされています。

#### Decision

Architecture decisionの決定内容と理由を記載します。受動態や思うといった表現でなく、very affirmative, commanding(非常に肯定的かつ命令的)に記載するのがよいとされています。そのほうが意思決定として良い表現だからです。

#### Consequences(影響)

Architecture decisionの影響を良い点、悪い点含めて記載する。
またなされたトレードオフについてもここに記載しておくとよいとされています。

#### Compliance

本書で追加することが進められているセクション。
なされた決定が守られているかどうかをどうやって評価するかについて記載する。
手動でチェックするのか、CI等で自動化するのか等。

#### Notes(備考)

もうひとつ追加することを進めているセクションがnotes section。具体的には以下のようなmetadataを記載する。

* Original author(オリジナルの著者)
* Approval date(承認日)
* Approved by(承認者)
* Superseded date(置き換え日)
* Last modified date(最終更新日)
* Modified by(変更点)
* Last modification(最終更新内容)

ADRをgitで管理しているとある程度重複する内容も含まれるがあえて記載することがすすめられています。

#### Storing ADRs(ADRの保存)

大規模な組織の場合、gitで管理する際に以下の点に注意することが警告されています。

* ADRをみる必要がある人がgitにアクセスできるとは限らない
* Applicationのcontextを外れたADRを保管するのにgit repositoryは適していない

このあたりはドキュメント管理に利用しているsoftwareとの兼ね合いもあるので各組織で決めていくしかないのではと思っております。個人的にはgit管理したいです。(organizationにarchitecture_decisions repositoryを建てる)

### Self-Assessment Questions

###### What is the covering your assets anti-pattern?(資産防御アンチパターンとは)

間違った決定を下すことを恐れて、決定を先送りにした結果代替案がとれなくなること。

###### What are some techniques for avoiding the email-driven architecture anti-pattern?(メール駆動アーキテクチャパターンを回避するためのテクニックとは)

ADRを実践して、メールではADRへのリンクを記載する。

###### What are the five factors Michael Nygard defines for identifying something as architecturally significant?(何かをアーキテクチャ上重要なものと特定するためにMichael Nygardが定義した5つの要因はなにか)

* Structure(構造)
* Nonfunctional characteristics(非機能特性)
* Dependencies(依存性)
* Interfaces
* Construction techniques(構築手法)

###### What are the five basic sections of an architecture decision record?(アーキテクチャデシジョンレコードの基本的なセクションを5つ挙げよ)

* Title
* Status
* Context
* Decision
* Consequence

###### In which section of an ADR do you typically add the justification for an architecture decision?(アーキテクチャ決定の根拠を追加するのは、通常ADRのどのセクションか)

Decision.

###### Assuming you don't need a separate Alternatives section, in which section of an ADR would you list the alternatives to your proposed solution?(代替案セクションを独立化させる必要はないという想定の場合、提案されたソリューションの代替案を挙げるのはADRのどのセクションになるか)

Context.


###### What are three basic criteria in which you would mark the status of aan ADR as Proposed?(ADRのステータスを提案済みとする3つの基本的な基準は何か)

* コスト
* チーム間の影響
* セキュリティ

## Chapter 20. Analyzing Architecture Risk

全てのarchitectureにはなんらかのリスクがある。
なので、継続的にリスクを分析してリスクを軽減する措置をとる必要がある。

ドメインやサービスごとに、scalability, availability, performance, security, data integrity等のリスクを数値化して評価していく。リスクの数値化は可能性*影響度を用いる。
またこの評価を定期的におこない変化のトレンドを把握しておくなどが説明されています。

正直この表から意味のある活動につなげられるのか疑問に思ってしまいましたが、曖昧でとらえどころがない問題に対して可能なかぎり定量的に取りくもうとしたらこうならざるを得ないのかもしれません。

また、リスク評価を複数人で行うRisk Stormingについても具体的なやり方が解説されています。

### Self-Assessment Questions

###### What are the two dimensions of the risk assessment matrix?(リスクアセスメントマトリクスの2つの側面とは)

* the overall impact of the risk(リスクの全体的な影響)
* the likelihood of that risk occurring(リスク発生の可能性)

###### What are some ways to show direction of particular risk within a risk assessment? Can you think of other ways to indicate whether risk is getting better or worse?(リスクアセスメントの中で、特定のリスクの方向性を示す方法にはどのようなものがあるか)

リスクの改善を+, 悪化を-で表現する。また矢印と変化した値を記載する方法もある。
ただし、矢印の場合上向きが改善なのか悪化なのかについて判断がわかれている。


###### Why is it necessary for risk storming to be a collaborative exercise?(リスクストーミングが共同作業であることが必要なのはなぜか)

一人ではリスクを見落とす可能性があるし、システムの全ての部分について完全な知識をもつことはできないから。

###### Why is it necessary for the identification activity within risk storming to be an individual activity and not a collaborative one?(リスクストーミングでの識別活動が、共同活動ではなく、個人的な活動であることが必要なのはなぜか)

他の参加者の影響をうけないようにするため。

###### What would you do it three participants identified risk as high(6) for a particular area of the architecture, but another participant identified it as only medium(3)?(3人の参加者がアーキテクチャの特定の領域のリスクを高(6)と認識したが、別の参加者が中(3)と認識した場合どうするか)

各自の根拠を話し合い、共通の認識をもてるようにする。

###### What risk rating(1-9) would you assign to unproven or unknown technologies?(実証されていな技術や未知の技術はどのようなリスク評価(1-9)をするか)

高リスク(9)と評価する。


## Chapter 21. Diagramming and Presenting Architecture

Architectにとって、architectureの図解とプレゼンテーションは重要なソフトスキルであるとされています。
どちらにも共通するのが全体のtopologyを示したあとにcomponentの詳細の解説にうつるのがよいとしています。

### Diagramming(図解)

Architectureのtopologyは価値ある共通理解につながるのでdiagram skillは重要。

#### Tool

図解のためのtoolはいろいろあるので特定のtoolを薦めるようなことはない。
とはいいつつ、本書は[OmniGraffle](https://www.omnigroup.com/omnigraffle)で書かれているそうです。
Diagram toolは色々試していたので、omnigraffleを使ってみようと思います。

またtoolには少なくても以下の機能がほしいとしています。

* Layer
  * 描画アイテムを論理的にグルーピングする。
  * 必要に応じて詳細を隠せる
* Stencil/template
  * 描画アイテムのテンプレート。マイクロサービスには一貫した形を利用したり等。
* Magnets
  * 図形の間にひく線。自動で整列したり、接続の仕方を調整する。

UMLも言及されていますが、クラス図やシーケンス図以外はほとんどつかわれなくなってしまったとされています。
自分は最近はUMLに加えてmermaidを利用したりしています。(Githubでサポートされているのが便利)

### Presenting(プレゼンテーション)

PowerPointやKeynoteようなtoolを利用して、プレゼンを行うことも求められているソフトスキルの1つ。
プレゼンの特徴はドキュメントと違い、読み手が情報の展開速度を制御できないことにあるとしています。
ソフトウェアアーキテクチャの基礎という名前の本に、スライドの作り方のコツが載っているとは思いませんでした。

### Self-Assessment Questions

###### What is irrational artifact attachment, and why is it significant with respect to documenting and diagramming architecture?(不合理なアーティファクトへの執着とは何か、そしてなぜそれがアーキテクチャの文書化や図解で重要なのか)

時間をかけて作った図に過度に執着してしまうこと。
過度な執着はiteration(実験、修正、コラボレーション)を妨げ、真の姿の理解を遅らせるから。

###### What do the 4C's refer to in the C4 modeling technique?(C4モデリング技術における4つのCは何を指しているか)

Context, Container, Component, Class

###### When diagramming architecture, what do dotted lines between components mean?(アーキテクチャを図解するとき、コンポーネント間の点線は何を意味するか)

非同期通信。

###### What is the bullet-riddled corpse anti-pattern? How can you avoid this anti-pattern when creating presentations?(蜂の巣にされた死体アンチパターンとは何か。プレゼンテーションを作成する際に、このアンチパターンを回避するにはどうすればよいか)

スライドが文字だらけで、それが読み上げられるだけのプレゼン。
情報を段階的に追加していく。

###### What are the two primary information channels a presenter has when giving a presentation?(プレゼンをするときに発表者が持っている2つの主要な情報チャンネルは何か)

言語と視覚。

## Chapter 22. Making Teams Effective

Architectには開発チームの実装をガイドするという責務もある。
当たり前に思われるが、著者たちは開発チームを無視するarchitectを多くみてきた。

### Team Boundaries

Architectは開発チームの成否に大きな影響力をもつ。
Architectから取り残されているあるいは疎外されている(feel left out of the loop or estranged)と感じるチームはsystemの制約について正しい理解やガイダンスを得られない。
その結果、architectは正しく実装されない。
これは実感として本当にわかります。知識や情報もarchitectの人のほうが多いと思うのでいい関係を築くことは大切だと思います。

Architectの役割の一つに開発チームにarchitectを実装する際の制約を作り、伝えることがある。
制約がキツすぎると、開発チームの適切なtool, library, practiceへのアクセスを妨げ開発チームのフラストレーションの原因になってしまう。
結果的に、開発者はより幸せで健全な環境を求めてプロジェクトを離れてしまう。

制約がなさすぎても厳しすぎる場合と同じくらい悪い。開発チームが実質的にarchitectの責務を引き受けていることになるので、PoCや設計上の決定を行うことになり、生産性の低下や混乱、フラストレーションにつながる。
これはチームでみれば必ずしもそうとは限らない気もしました、逆に組織ごとの統制がとれない影響を気にしました。

### Architect Personalities

Team boundariesで述べられた制約の程度によるarchitectのパーソナリティ分類。

#### Control Freak

開発プロセスのあらゆる詳細な側面をコントロールしようとする。決定が細かすぎたり、低レベルだったりする。
Control freakはsteal the art of programming away from the developers(開発者からプログラミング技術を奪う)。
そして結果的にarchitectへの敬意の欠如を開発チームにもたらす。

プロジェクトの複雑さやチームのスキルレベルによってはarchitectがcontrol freakになる必要がある場合がある。
しかし、一般的には開発チームを混乱させ、適切なガイドを提供せず、チームを率いてarchitectureを実装することに関して効果を発揮しない(ineffective at leading the team through the implementation of the architecture)。

#### Armchair Architect

Armchair architectは長い間codingをしていないタイプのarchitectをいう。
こうしたarchitectは実装の詳細を考慮にいれない。開発チームから切り離されており、開発チームの近くにいないか、初期architecture diagramができると別のプロジェクトに移動してしまう。

開発者の仕事はcodeを書くことで、codeを書いているフリをするのは難しい。
一方でarchitectの仕事はなんだろうか。誰にもはっきりとはわからないので、architectのフリをするのはとても簡単。
armchair architectかどうかのindicatorは以下の3つ。

* Not fully understanding the business domain, business problem, or technology used
* Not enough hands-on experience developing software(ソフトウェアを実際に開発した経験が十分でない)
* Not considering the implications associated with the implementation of the architecture solution(アーキテクチャソリューションの実装に伴う影響を考慮していない)

意図してarmchair architectになったのではなく、技術やビジネスドメインに疎くなってしまい、たまたまそうなってしまうこともある。プロジェクトで使用されている技術に積極的に関わり、ビジネスドメインを理解することで、こうした罠を回避できる。

#### Effective Architect

Armchair architectでみたようにまったく管理しないのはアンチパターンなので、何にどの程度の制約を課すかが問題になる。
管理の度合いに影響を与える要素として以下が挙げられている。

* Team familiarity(チームの親しさ)
  * メンバーがどの程度お互いのことを知っているか。
  * すでにお互いのことを知っていれば自己組織化(self-organizing)しはじめるので、コントロールの必要性は低くなる
  * 新しいメンバーであれば、コラボレーションを促進し、内部の派閥を減らすためにコントロールが必要になる。
* Team size
  * チームの規模。12人以上は大きいチーム、4人以下は小さなチーム。
  * チームが大きければより多くのコントロールが必要になる。
  * チームが小さければコントロールの必要はなくなる。
* Overall experience(全体的な経験) 
  * シニアメンバーとジュニアメンバーの比率。チームの技術とドメインへの理解度。
  * ジュニアメンバーが多ければコントロールが必要になってくる。
  * シニアメンバーが多ければコントロールはあまり必要ない。
* Project complexity
  * 複雑なプロジェクトでは、より時間を割いて問題への支援が必要になる。
  * 比較的単純なプロジェクトではあまりコントロールを必要としない。
* Project duration(プロジェクトの期間)
  * プロジェクトの期間は、短期(2か月)か、長期(2年)か、平均的か(6か月)
  * 長期になればなるほどコントロールが必要。
  * 短期であれば切迫感が共有されているので、コントロールはあまり必要ない。

適切なチームのサイズを判断するにあたって、注意する点も述べられています。
大事なのは、architectは開発チームをガイドするだけでなく、チームが健康で幸せであり、共通のゴールを達成するために協力しあうことを確保することであるとされています。

### Checklist

CI/CD側で行えばいいのかなと思いました。よりフィードバック早くするためにはgit hook等。

### Governing the layered stack(技術スタックの統制)

プロジェクトに依存ライブラリを追加する際に、開発者が自由に決められるもの、architectが決めるものをどうやって分類するかについて。ここでは以下の基準が提案されている。

* Special purpose(特別な目的のもの)
  * 開発者がarchitectの承認なしに決められる。
  * 例 PDF rendering, bar code scanning
* General purpose(汎用的な目的のもの)
  * architectの承認が必要。
  * 言語のAPIのwrapper的なlibrary。
* Framework
  * architectが決定
  * applicationの構造に関わるようなライブラリ。

ライブラリのこの3分類はとてもいいなと思います。
ただ、別の箇所では、ReactかVueかをarchitectは指定しないほうがいいとありましたが、この基準によるとarchitectがReactをきめるのかなと思いました。

### Self-Assessment Questions

###### What are three types of architecture personalities? What type of boundary does each personality create?(アーキテクトのパーソナリティを3つ挙げよ。それぞれのパーソナリティはどのような境界を作るか)

* Control Freak architect
  * 強すぎる制約を作る。
* Armchair architect
  * 弱すぎる制約を作る。
* Effective architect
  * 効果的な制約を作る。

###### What are the five factors that go into determining the level of control you should exhibit on the team?(チーム内で発揮すべきコントロールのレベルを決定する5つの要因とは)

* Team familiarity(チームの親しさ)
* Team size
* Overall experience(全体的な経験)
* Project complexity
* Project duration(プロジェクトの期間)

###### What are three warning signs you can look at to determine if your team is getting too big?(チームが大きくなりすぎているかを判断するための3つの警告サインとは)

* Process loss
  * conflictが頻発。作業の並列性が作れていない。
* Pluralistic ignorance(多言的無知)
  * 心理的安全性の問題かも
* Diffusion of responsibility(責任の分散)
  * 困っている人が放置される


###### List three basic checklists that would be good for a development team(開発チームにとって良い基本的なチェックリストを3つ挙げよ)

* developer code completion checklist
* unit and functional testing checklist
* software release checklist

## Chapter 23. Negotiation and Leadership Skills

Chapter 1のarchitectに期待されることの最後にUnderstand and navigate politicsがある。
なぜ政治と交渉が必要になるのか。それは、architectが下すほぼ全ての決断はchallengeされるから。
まず、architectよりも知識があると考えている開発者にchallengeされる。他のarchitectからもされるし、stakeholdersからも費用が高すぎたり、時間がかかりすぎるといった理由で対立する。

可用性に関する具体例の話で、99.9%のダウンタイムはどれくらいかという話題がでてくるのですが、昔(2018)にGoでCLI作ったのを思い出しました。

```sh
go install github.com/ymgyt/sla99@latest

# GOにbinaryが$PATHにある前提
sla99
rate     hour      minute      second
99.00000 87.600000 5256.000000 315360.000000
99.90000 8.760000  525.600000  31536.000000
99.99000 0.876000  52.560000   3153.600000
99.99900 0.087600  5.256000    315.360000
99.99990 0.008760  0.525600    31.536000
99.99999 0.000876  0.052560    3.153600
```

議論の際に、当該論点だけでなくその後の関係においても、不健全で非協力的にならないためのアドバイスがのっており、実践的でした。議論になったら実証したり、正当な根拠を示すようにしようという言われれば当たり前だがなかなか難しいことだと思うので立場に関わらず意識していきたいです。開発者が決定に同意しない場合、開発者自身に解決策を見つけてもらうという考え方も好きです。

また、

> First, notice the use of the words “you must.” This type of commanding voice is not only demeaning, but is one of the worst ways to begin a negotiation or conversation.

Richards, Mark; Ford, Neal. Fundamentals of Software Architecture . O'Reilly Media. Kindle Edition.

まさかソフトウェアアーキテクチャの基礎という本に、話し方の注意までのっていると思いませんでした。
言い方は本当に大切だと思います。
肩書きではなくて、手本で人を動かす等、もしかしたらこの章が一番大事なことをいっているかもしれません。

### Self-Assessment Questions

###### Why is negotiation so important as an architect?(アーキテクトとして交渉が重要な理由は)

全ての決定に対して手強い人たちからchallengeされるから。

###### Name some negotiation techniques when a business stakeholder insists on five nines of availability, but only three nines are really needed.(ビジネスステークホルダーがファイルナインの可用性を主張しているが本当に必要なのはスリーナインだけの場合の交渉術をいくつか挙げよ)

* ファイブナインの具体的なダウンタイムを明示する。
* コストがかかりすぎることを主張する。
* ファイブナインの適用範囲を限定する。

###### What can you derive from a business stakeholder telling you "I needed it yesterday"?(ビジネスステークホルダーの"それは昨日必要だった"という発言から導き出せるのは何か)

市場投入までの時間を重視していること。

###### Why is it important to save a discussion about time and cost for last in negotiation?(時間やコストの議論を交渉の最後まで取っておくことが重要なのはなぜか)

もっと重要な正当性や合理性を議論したほうが結果的に物事が進むことが経験則的にわかっているから。

###### What is the divide-and-conquer rule? How can it be applied when negotiating architecture characteristics with a business stakeholder? Provide an example.(分割統治ルールとは何か。アーキテクチャ特性をビジネスステークホルダーと交渉する際に分割統治ルールはどう適用できるか、例を挙げて示せ)

問題をより小さい単位に分解して対処すること。business stakeholderが主張するarchitecture characteristicsの適用範囲を限定して議論を進める。

###### List the 4C's of architecture.(アーキテクチャの4つのCを挙げよ)

* Communication
* Conciseness
* Collaboration
* Clarity

###### Explain why it is important for an architect to be both pragmatic and visionary.(プラグマティックであることとビジョナリーであることがアーキテクトにとって重要である理由を説明せよ)

Architectとして敬意をえることができるから。


###### What are some techniques for managing and reducing the number of meetings you are invited to?(課せられたミーティング数を管理して、減らすためのテクニックとは何か)

Agendaを事前に確認して、自分がでなくてもよいものにはでない。

## Chapter 24. Developing a Career Path

学び続ける必要があることは、おおくの職種で共通していることだと思いますが、この職種の特殊性として知識の陳腐化が早い点があると思っています。(そのうちKubernetesを誰も使わなくなる日が来るのでしょうか)
そんな中で日々どうやって変化にキャッチアップしていくかについて述べられています。

technologyをtool, language&frameworks, techniques, platformに分類して、さらにそれらをhold, trial, adopt等に評価してどれくらいcommitするかを判断する手法はとても参考になりました。
本書を通して、architecture characteristicsであったり、risk categoryであったり、曖昧で多様なものをどうにか分類して体系化しようとする態度が自分にはとても欠けていると思わされます。

### Self-Assessment Questions

###### What is the 20-minute rule, and when is it best to apply it?(20分ルールとは何か。いつ適用するのがベストか)

学ぶ時間に一日に20分は費やすルール。一日の始まりに設けるとよい。

###### What are the four rings in the Thought-Works technology radar, and what do they mean? How can they be applied to your radar?(ThoughtWorksテクノロジーレーダーの4つのリングとは何か。また、それはどのようにあなたのレーダーに適用できるのか)

tool, language&frameworks, techniques, platformの分類とcommitの度合い。
自身の技術ポートフォリオに関して、commitする対象の判断に利用できる。

###### Describe the difference between depth and breadth of knowledge as it applies to software architects. Which should architects aspire to maximize?(ソフトウェアアーキテクトにとっての知識の深さと広さの違いを説明せよ。アーキテクトはどちらを重視すべきか)

深さは特定の技術的topicの原理や詳細、実装を理解していること。広さはこの技術的topicの数。
広さを重視すべし。

## 学んだこと

* Everything is a trade-off
* Architecture characteristicは計測可能な程度にまで具体的に定義すること。定義の合意の範囲は組織内でよい。
* Architecture characteristicsはシステム全体で一律でなく、適用スコープがある。スコープを定めるにあたってはDDDの境界づけられたコンテキストや、機能的凝集性+依存データストア+同期呼び出しが出発点になる。
* 適切なコンポーネントの粒度の発見はイテレーティブなアプローチによって見つけていく
* Transaction boundaries is one of the common indicators of service granularity.
* Architect関連の決定は根拠を明示して、ADRでドキュメント化
* Architecture全体のリスク評価をチームで行い、共通認識をもつ。対応の優先度を定量的に決める。

