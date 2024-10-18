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
  * Platform engineering is the discipline(専門分野) of developing and operating platforms.
  * The goal of this discipline is to mange overall system complexity to delier leverage to the business
  * software-based abstrations that serve a broad base of application developers
  * curated product approach

Leverage
  * PEの価値のcoreになるコンセプト
  * 少数のPEの仕事で組織全体の仕事を減らす
    * application engineersをmore productiveにする
    * application teams全体でのduplicate workをeliminateする

Product
  * platformをproductとして捉えることが重要
    * customer-centri approchにつながる
  * 多様な要求に対して製品を意図的かつセンス良くキュレーションすること

#### The Oveneral Swamp

* infraやdev toolは、public cloudやossと密接に関連しており、時間の経過と共にsystemの所有コストを増加させる一因になっている。
  * この分野がPEの需要を生み出している
  * applicationの構築は容易になったが、maintenanceは難しくなった
  * systemが大きくなればなるほど速度が落ちていく点をとらえて、沼

* softwareの主要なcostはmaintenance
  * cloudとossはこの問題を拡大している(amplify) 
    * ever-growing layer of primitives(general purpose building block)を増やすから
      * 機能させるには"glue"(integration code config, managment tools)
      * 変更をhardにしている

* "glue"が広がるにつれ、over-general swampが形成される
  * application teamはprimitives中からそれぞれ必要な選択を行い、custom glueを作成する
  * glueが広がると、些細な変更でも組織全体として多大な時間を消費する

* この問題に対処する方法は、glueの量を制限すること。
  * PEは限定されたOSSやvendorの選択肢を組織のニーズにあわせて抽象化することでこれを実現する

* PEはabstractionとencapsulationの概念(concepts)を実装して、interfaceを作成することでuserをunderlying complexityから保護し、glueの量を制限する
  * これらのconceptはよく知られているにもかかわらず、なぜPEが必要とされているのか


#### How We Got Stuck in the Over-General Swamp

##### Change 1 Explosion of Choice 

* internetの登場, hardware大量購入、apiで制御できるcloudの隆盛

* Heroku等のPassSでは多様なapplicationをサポートできず、結果的にIaaSが選ばれた
* Kubernetesの隆盛は、PaaS, IaaSが共にenterpriseのニーズを満たせなかったことの現れといえる
  * applicationが"cloud native"であることを強制することで、IaaS ecosystemをsimplifyする試み
  * ただ以前として多くの詳細な設定が必要であり、典型的な"leaky" abstraction

* OSSの問題は選択肢の増加
  * application teamはマッチするOSSを見つけることができるが、他のチームに最適であるとは限らない
    * 初期リリースを迅速に行うために選んだ選択肢は最終的にburdenになる
      * 独立してメンテナンスコストを支払う必要があるから


##### Higher Operational Needs

* 誰が運用するか


#### How Platform Engineering Clears the Swamp

* platformを作るには大きな投資が必要
  * app teamのOSSやcloudの選択肢を限定するというcostもかかる
  * 組織の再構成、役割の変更
  * これらの投資を正当化できるか

* 選択肢が多いことは悪いことばかりでない 
  * より早く出荷できる
  * 使っていて楽しいsystemを選べることで自立性と所有感をもてる

* 一方で、組織が長期のcostを減らすことを考え始めると忘れ去られる
  * リーダーシップが権威を用いて標準を強制することがよくある
  * 権威によるstandardizationでは十分ではない
    * expertsはbusinessのneedを十分に理解できないから

* PEは開発チームが使っていて楽しいsystemを使うべきだと認識している
  * cost削減やサポートの負担軽減だけを目指さない
  * curatedなsmall set of primitivesを提供する
  * うまくいけば、権威に頼ることなく、OSSやCloudのprimitiveを減らせる


#### Reducing Per-Application Glue

* 利用されるprimitivesの数を減らすだけでなく、glueを減らすことを目指す
  * platform capabilitiesとして、primitivesを抽象化する

* 具体例としてterraformの場合
  * 各application teamにcloudをprovisioningする権限を付与する
    * ほとんどのエンジニアは頻繁に使わないタスクのために新しいツールセットを学びたくない
    * これらの作業は新しいメンバーか、DevOpsに興味をもつ稀なエンジニアが担当することになる
    * provisioningのexpertに成長したとしても、これらのエンジニアはapplication teamに長くとどまらない

  * terraformを書くチームを作る
    * feature shop mindestに囚われている
      * 作業依頼をうけてそれを処理する
    * strong developerが参加したがらない
      * 構造を変えて、よりよい抽象を提供したい人
    * 時間の経過と共に、codebaseはspaghettiになる    

  * 単に中央化されたterraform writingチーム以上のより一貫性のある手段がある
    * glue保守部隊からplatformを構築するengineering centerへ
    * 言われたものを作るだけでなく、提供するものに意見をもち、単なるprovisioningを超えたなにかを作る

  * 専門チームを集中させて効率化することが重要
    * 各チームがDevOpsやSREを雇うのではなく
    * 単発の変更をサポートするだけでなく、基盤の複雑さを抽象化するプラットフォームを作成する


#### Centralizing the Cost of Migrations

* migrationはplatformの重要な価値のひとつ

* OSSのdiversityを減らす
  * 少ないほどmigrationの頻度は減る
* Encapsulating OSS and vendor systems with API
* Creaing observability of platform usage
  * metadataを制御できるメカニズムをもてるので、upgrade時に活用できる
* Giving ownership of OSS and cloud systems to teams with software developer
  * APIでwrapしているので、migrationをapplication teamに透過的に実施できる


#### Allowing Application Developers to Operate What They Develop

* ossとそのglueが引き起こすoperational problemsがapplication codeのそれを上回っている

* 基盤システムの運用上の複雑さをplatformの抽象化で隠蔽できれば、この複雑さはplatformチームが所有できます。


#### Empowering Teams to Focus on Building Platforms

* Platform adjacent approaches
  * Infrastructure
    * infraの抽象化にはあまり注力しない
    
  * DevTools
    * productionでのdeveloperのproductivityに対してlittle focus

  * DevOps
    * little focus on automation/toolsがhelp the widest possible audience

  * SRE
    * little focus on systemic issues other than reliability
    * delivering impact through organizational practives instead of developing better systems

* PEはこれらのgroupの人々と協同して、platformを構築する
  * infra: infra capabilitiesとdeveloper centered simplicityのbalance
  * devtool: development experience with production support experience
  * devops: optimal(最適) per-application glueからより一般的なsoftwareへ
  * sre: balancing reliability with other system attributes(feature agility, cost efficiency, security, performance)
    
* あえてshadow platformsを作らせるという判断もときには必要


## Chapter 2. The Pillars of Platform Engineering

PE practiceのfour pillars

* Product: Taking a curated product approach
* Development: Developing software-based abstractions
* Breadth: Serving a broad base of application developers
* Operations: Operating as foundations for the business


### Taking a Curated Product Approach

* product approach
  * technical mindset
  * focus customers need, experience using system
  * これがないと、実際のneedsに沿わないものを提供することにつながる
* curated approach
  * platformのscopeに対して意見をもって、キュレーションする
  * これがないとcoherent strategyなくcustomerに対応することになり、service centerに成り下がってしまう

* A successful curated product approachには２つのtypeがある  
  * Paved paths
    * 強制ではない

  * Railways


### Developing Software-Based Abstractions

* softwareを作っていないならば、PEをやっていない
  * 抽象化していないならば複雑製をuserに転嫁しているだけ


#### The Major Abstractions: Platform Service and It' APIs

* APIによる抽象化は必要だが、PostgreSQLのようなOSSを提供するplatformはSQLを完全に抽象化してAPI requestを要求するべきだろうか
  * 正しい抽象度を見極めるには、application engineerの目線に立つ必要がある
    * appの生産性があがったと確信できるまでは直接的なアクセスを許可したほうがよい


#### thick Clients

* OSSのClientをplatformのlibとして提供する方法もある。
  * observabilityやupgrade cycleをplatform teamで制御できなくなるが、trade-offを考慮して、検討の価値はある


#### OSS Customizations

* OSSをカスタマイズすることが求められる場合がある
  * カスタマイズの一環として、pluginやcontributionが必要になる場合もある
  * forkする場合もある
  * OSSのコードを修正する能力はPEの付加価値の一部


#### Integrating Metadata Registries

* PEの仕事として、OSやCloud primitivesの問題や変更にuserのかわりに対処することである
  * このためには、各primitivesに関するmetadataを管理しておく必要がある。これらのmetadataで以下の問に答える
    * Ownership
    * Access Control
    * Cost efficiency
    * Migrations

* systemとしては
  * tag management systems
  * api/schema registries
   i Internal developer portals

##### IS AN IDP A REQUIRED COMPONENT OF A PE

* An IDP is not a requirement for building a great platform
  * なくてもいいというスタンス。
  * 反対しているわけでもない


### Serving a Broad Base of Application Developers

* 単なる機能開発から、devloping capabilitiesの開発に移行する必要がある。これはsystemをcheaper, safer, easierにする。
  * Self-service interfaces
    * 新しいcustomerのonboardingのたびにmanual workや複数チーム間の調整が必要な場合、leverageを失う

  * User observability
    * user observabilityは重要
      * userが間違っているのか、platformが間違っているのか判断できるか

  * Guardrails
    * 単純なご設定が大きな影響を及ぼすことがある。userが全員、underlyingなsystemに通じているわけではない
    * expensive misconfigurationを防止する、protectionとしてのguardrailsが必要

  * Multitenancy
    * applicationごとに one systemではなく、同一のruntime componentで複数のapplicationをサポートする必要がある
      * multitenancyをはじめると難しい問題が生じるので、これもPEにsoftware engineerが必要な理由の一つ


### Operationg as Foundations
