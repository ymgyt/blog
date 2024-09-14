+++
title = "📗 なぜ依存を注入するのか DIの原理・原則とパターンを読んだ感想"
slug = "dependency-injection"
description = "DIという観点からコードの設計を考える本"
date = "2024-09-14"
draft = false
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/green_book.png"
+++

## 読んだ本

{{ figure(images=["images/di-book.jpg"], caption="なぜ依存を注入するのか DIの原理・原則とパターン", href="https://book.mynavi.jp/ec/products/detail/id=143373") }}

著者: Steven van Deursen, Mark Seemann  
訳者: 須田智之

表紙には.NETやC#の文字はないのですが、前の版は"Dependency Injection in .NET"で.NETを前提した本のようでした。  
ただ、はじめにで

> 本書では、.NETとC#を用いて、依存注入に関する用語や指針を包括的に紹介し、描写しているのですが、本書の価値が.NETの外の世界にも届くことを望んでいます。

とありました。  
RustのDIでなにか活かせる教えを期待して、読んでみました。

## 第1部 依存注入 (Dependency Injection: DI) の役割

### 第1章 依存注入 (Dependency Injection: DI) の基本: 依存注入とは何なのか? なぜ使うのか? どのように使うのか?

まず、保守容易性(maintainability)を高めるという目的がある。  
そのために、疎結合(loose couplig)な設計が必要。  
依存注入は、疎結合なコードを実現するためのテクニックのひとつ。  

疎結合だとメンテナンスしやすくなるのは、責務が明確になり、単体テストが行いやすく、拡張容易性が向上するから。  

しかし、なんでも抽象化して注入すればよいわけではなく、依存には、安定依存(stable dependency)と揮発性依存(volatile dependency)がある。  

揮発性依存とは、外部のDBのように動かすには別の設定が必要になるものや、非決定的(ランダム、現在時刻)なものをいう。  

依存注入をするとうれしい点は、依存を利用する側から、依存の生成や制御の責務が取り除かれ、依存をwrapして、処理を追加するといったことが可能になるから。


### 第2章 密結合したコードで構築されたアプリケーション

本章では、UI、ドメイン、データアクセスの3層構造のアプリケーションが密結合すると実際にどんなコードになるのか、具体的に紹介されます。  

単一責任の原則(Single Responsibility Principal)の説明がでてきまして、いわく、クラスの変更理由は一つであるべき。しかし、変更の理由が一つかの判断は難しい。そこで観点として、凝集性(cohesion)に着目すると良い。凝集性とは、要素同士の機能的な関連度のこと。  
注意が必要なのは、単一責任の原則が妥当しない場合があり、その際に無理やり、本原則を適用してしまうと、不要な分割となり複雑さをあげてしまう結果になることがある。　　

ということで、大事なのはあくまで、保守しやすいかどうかであるとされていました。  
意外と単一責任の原則が妥当しない場合もあると明言しているのは珍しいと思いました。(ある原則が常にあてはまる例は稀なので、前提となっているだけかもしれませんが) 

私は、単一責任や一つの責務をもたせるという考え方には大賛成なのですが、この"一つ"は、解釈次第で揺れがちだなといつも思います。ので、最近はテストがしやすければOKとして、テストのしやすさ至上主義に傾いています。(複数の責務あれば自然とテストの準備やassertion書きづらくなりますし)


### 第3章 疎結合なコードへの変換

前章で扱ったアプリケーションを依存を注入する形で疎結にしていきます。  
依存をコンストラクタ経由で渡すと、以下のように依存の依存を作る様なコードになります。　　
```rust
FooHandler::new(
  BarService::new(
    BazRepository::new(
      HogeClient::new()
    )
  )
)
```

これは、依存の制御の負担を別の場所に押し付けているだけではという問に対して、その負担を別のとろこに移せるというのが、重要なのだと説明されていました。  
そして、依存の注入を上位に移していった結果、アプリケーションの最上位にある合成起点(Composition Root)で依存注入を行えるようになります。

依存注入を行うと、何がどれを呼び出しているかをすぐに把握できないという問題点があります。  
しかし、合成起点で依存注入を行うことで、凝集度の高い状態で、オブジェクトの依存関係を把握できるとされています。

依存性逆転の原則(Dependency Inversion Principle)の説明もあるのですが
抽象はその抽象を使うモジュールによって所有されるべきで、抽象を利用するモジュールがその抽象をもっとも有効活用できる方法で定義できるようにしなければならないという説明がわかりやすかったです。  
DDDの文脈では、ドメインとインフラ層の層間の安定性の違いから、インターフェースをドメイン側に定義するとあったのですが、あまり納得できていなかったので、こちらの説明のほうが好みでした。


## 第2部 カタログ

### 第4章 依存注入のパターン

実際に依存を注入するそれぞれの設計パターンについて。

#### 合成基点 (Composition Root)

DIはアプリケーションのエントリーポイントに可能な限り近いところで行う。  
大切なのは、依存関係がどのように構築されるかについて、composition rootがそれを知る唯一の場になること。  
依存関係の解決を一箇所で行うと思うと、必然的にmainに近いところで依存の解決が行われるようになる。

依存の注入をエントリーポイントで行うと、エントリーポイントの依存が増えてしまうという懸念がある。  
しかし、それは推移的な依存(A -> B -> Cのとき、A -> Cの依存)を考慮していないからで、それを考慮にいれると、エントリーポイントで依存を解決したほうが、全体の依存の数を減らせる。

{{ figure(caption="推移的な依存を考慮した密結合の依存", images=[
  "images/dep_graph_1.svg", 
  "images/dep_graph_3.svg",
  "images/dep_graph_2.svg",
], width="32%") }}

推移的な依存も、依存の数として考えたことがなかったので、この考えは新しかった。


#### コンストラクタ経由での注入 (Constructor Injection)

依存をconstruct時に渡す方式。基本的にはこの方式が推奨で、construct時に依存を渡せないような場合にメソッド経由での注入を検討する。


#### メソッド経由での注入 (Method Injection)

Composition rootでは、依存を利用する側がまだ、存在していなかったり、リクエスト時の情報等を注入する際は、メソッド経由で依存を渡す。  
逆に言うと、construct時に渡せる依存はメソッド経由で渡さないようにしたほうがよい。


#### プロパティ経由での依存 (Property Injection)

依存をpropertyに設定することで注入する方式。

```rust
let mut foo = Foo::new();

foo.dependency = Dependency::new();

foo.do_something();
```

通常はデフォルトの依存を利用するが、利用側が特別なことをしたい場合は、依存を上書きできるようにしておきたいケースで用いられる。  
うまく利用すると、ライブラリのAPIをシンプルにできる。  
一方で、特定の依存がpropertyに注入されることを暗黙的に期待するようなコードだと、コードの嫌な臭い(code smell)につながるので注意が必要。


### 第5章 依存注入のアンチ・パターン

依存注入にまつわるアンチパターンについて。

#### コントロール・フリーク (Control Freak)

Composition root以外のところで、揮発性依存を生成して、保持すること。  

```rust
impl FooService {
  fn new() -> Self {
    let bar_repository = BarRepository::new();

    Self {
      bar_repository,
    }
  }
}
```

のように、DIで依存をもらわずに自身で生成してしまうこと。  
そもそも、これをやらないためにDIをがんばっている。


#### サービス・ロケータ (Service Locator)
  
`Locator.GetService<IProductService>()`のようにgenericな型parameterを渡すと、事前に登録された実装の型をうけとれるservice locatorによって依存を解決するパターン。  
必要な依存がconstructorで明示されないので、利用側はあらかじめ、service locatorを利用するクラスが必要とするserviceを登録しておかないといけない。  
変更によって新しいserviceの解決が必要になったとしても、それが型に明示されていないので、実行時にエラーになってしまう。


#### アンビエント・コンテキスト (Ambient Context)

合成基点の外で、揮発性依存へのグローバルなアクセスを提供すること。  
典型的には、現在時刻の取得や、ロギング。  
現在時刻の取得は、テストの観点から、DIしていたが、ロギング処理も、グローバルにloggerを取得するのはアンチパターンとされていた。  
ただ、loggerもDIするとなると、コンストラクターのいたるところで、loggerを要求する必要があり、過度な注入(constructor over-injection)と呼ばれるcode smellにつながってしまう。 
ではどうしたらよいかの話は10章で説明される。  

私は、loggingに関しては、`tracing`を利用しており、その中で、`tracing::info!("message")`にようにしてlogを出力していました。このマクロは内部的には、globalのthread localにアクセスしています。  
テストに関しては

```rust

dispatcher::with_default(&dispatcher, || {
  tracing::info!("message")
});

/* ... */
assert_eq!(log.message, "message");
```

のような特定の関数実行自に意図されたlogが出力されたかの[テスト](https://github.com/ymgyt/syndicationd/blob/c754affa70ca466e36be690ed0317a4e442091cc/crates/synd_o11y/src/tracing_subscriber/otel_log/mod.rs#L90)を書けているのでよしとしていました。  
また、この処理は、thread localの変数で行われるので、testの並行性でも問題ないと考えています。


#### 制約に縛られた生成 (Constrained Construction)

抽象の実装に際して、特定の実装に引きづられたシグネチャを利用してしまうこと。  
例えば、`IProduceRepository`のコンストラクタとして、`SqlProductRepository`に引きづられて、引数に文字列型のconnection stringを要求する型にしてしまう等。  
この例はさすがに使いづらいのでやらないと思うが、抽象の定義に際して、実装が漏れてしまうのはよくあると思う。  
自分が課題に思っているのは、`Repository`の抽象(trait)を定義するに際して、RDSのトランザクションと、NoSQL(DynamoDBや、MongoDB)の書き込み制約をどうやって反映するかだと思っている。トランザクションや書き込み制約を抽象に反映しないと、RDSの実装では、変更が後続のread処理からすぐ見えるが、Mongoの実装だとみえないというようなことが起きてしまったり。


### 第6章 コードの嫌な臭い (code smell)

#### コンストラクタ経由での過度な注入 (Constructor Over-Injection)

基本的にコンストラクタ経由での依存注入を用いるべきなので、素直にその通りにしたところ以下のようなコードになった。

```rust
impl<OrderRepository, MessageService, BillingSystem, LocationService, InventoryManagement>
    OrderService<
        OrderRepository,
        MessageService,
        BillingSystem,
        LocationService,
        InventoryManagement,
    >
{
    pub fn new(
        order_repository: OrderRepository,
        message_service: MessageService,
        billing_system: BillingSystem,
        location_service: LocationService,
        inventry_management: InventoryManagement,
    ) -> Self { /* ... */ }
}
```

このように依存が多い場合は、単一責任の原則に違反している兆候なので、注入する依存の数を減らしたい。  
そんなときにどういった方法があるかという解説がされています。  
注入したい依存の数が増えていってしまう点については課題に感じることが多かったので、本章で紹介されたアプローチを試してみようと思っています。


#### 抽象ファクトリ (abstract factory) の誤用

最初から素直に依存を注入すればよいだけではと思ってしまったので割愛。  
インターフェイス分離の原則の説明がわかりやすかったです。


#### 循環依存 (cyclic dependency)

新たに監査証跡(Audit Trail)を追加するために、`SqlUserRepository` クラスに`AuditTrailAppender`を注入したいが、循環依存に陥ってしまったケースを例に、解消のアプローチを解説してくれます。  
循環依存は、単一責任の原則違反の兆候であり、インターフェースを分離して、依存を解消する方法は非常に参考になりました。


## 第3部 純粋な依存注入 (Pure DI)

### 第7章 オブジェクト合成 (object composition)

Windows, .NET固有の話が多かったので割愛。


### 第8章 オブジェクトの生存期間 (lifetime)

注入される依存がスレッドセーフでない場合や、依存を利用するクラスより有効期間が短い場合等に関する注意事項。  
RustではSend, Syncやborrow checkerといった言語上の仕組みで、違反していたらコンパイルが通らないので、捕われた依存 (Captive Dependency)のようにわざわざ名前をつけて論じなくてもよい。  
依存の生成コストの観点から、生成処理を遅延させるために`Lazy<T>`を用いる場合についての説明もある。  
ただ、`Lazy`型を導入するそもそもの問題点を指摘しつつも、`Lazy<T>`の注入自体は間違っているわけではないと説明されており、要領をえなかった。

抽象を漏洩させないという観点から

```rust
use std::cell::LazyCell;

trait Foo {
    fn foo(&self);
}

impl Service {
    fn new<F: Foo>(foo: LazyCell<F>) -> Self { /* ...*/ }
}
```

のように引数の型に`LazyCell`を要求するのではなく

```rust
struct FooImpl {}

impl Foo for FooImpl {
    fn foo(&self) { /* ...*/ }
}

struct LazyFoo<Foo> {
    foo: LazyCell<Foo>,
}

impl<F: Foo> Foo for LazyFoo<F> {
    fn foo(&self) { /* ... */ }
}

impl Service {
    fn new<F: Foo>(foo: F) -> Self { /* ... */ }
}

fn main() {
    let lazy_foo = LazyFoo {
        foo: LazyCell::new(|| FooImpl {}),
    };
    let service = Service::new(lazy_foo);
}
```

のようにして、Lazyの利用は注入側で行い、利用する側に意識させない方法が紹介されていた。  
これは書いてしまいそうなコードだったので気をつけていきたい。



### 第9章 介入 (interception)

いわゆるDecoratorパターンについて。横断的関心事として、監査証跡(Audit Trail)やサーキットブレーカを例に実際に既存の処理にこれらを追加する例をみていく。  
私の意見としては、同一の抽象(interface)を維持して、処理をwrapしていくのは、エラーの存在を考慮すると、そんなに単純じゃないのかなと思う。  
例えば、repositoryの`UpdateUser`の呼び出しをwrapして、auditの記録をとる場合でも、auditの失敗というエラーが新しく発生するようになるのだから、呼び出し側のエラーハンドリングは影響を受けると思う。auditの記録が失敗した場合、hashicorpのvaultのように処理自体を失敗させるのか、処理自体は継続するのかによっても、エラーハンドリングの方針は変わると思うので、ここの例で紹介されているようにwrapして呼び出し側に意識させずに処理を追加できるのか疑問だった。  
処理をwrapしていくといえば、towerのServiceがあるが、そこでもエラーをどう表現するかで[議論](https://github.com/tower-rs/tower/issues/131)があった。  
エラーを`AuditError<RepositoryError>`のように具体型にせず、`Box<dyn Error>`にすれば、呼び出し側にAudit処理のwrapを意識させずに追加が可能だけど、今度はcompile時にAuditErrorがきちんとハンドリングされているかを確かめることができない。(`error.downcast_ref::<AuditError>()`する必要があるから)

とわいえ、一つの処理に横断的関心事を記述していくと処理がcomposeでなくなってしまうので、rustにあった形で、こういった処理を書けるようにしたい。  

### 第10章 設計だけで実現するアスペクト指向プログラミング (Aspect-Oriented Programming: AOP)

機能を追加していった結果、肥大化した`ProductService` interfaceをSOLID原則の観点から分析し、interfaceを分割していくリファクタを行います。  

```rust
trait ProductService {
    fn get_featured_products() -> impl Iterator<Item = DiscountedProduct>;
    fn delete_product(product_id: ProductId) -> DeletedProduct;
    fn get_product_by_id(product_id: ProductId) -> Product;
    fn insert_product(product: Product);
    fn update_product(product: Product);
    fn search_products(params: SearchParams) -> Paged<Product>;
    fn update_product_reviews(product_id: ProductId, reviews: Vec<ProductReview>);
    fn adjust_inventory(product_id: ProductId, decrease: bool, quantity: i64);
    fn update_has_tier_prices_property(product: Product);
    fn update_has_discounts_applied(product_id: ProductId, description: String);
}
```

また9章の介入で紹介されていた方法で、横断的関心事(Audit Trail)を実装しようとすると、wrap(decorate)する処理が重複してしまう問題にも対処します。  
実際に最終型はとても綺麗になっており、非常に参考になりました。  
SOLID原則(Single Responsibility, Open/Closed, Liskov Substitution, Interface Segragation)、それぞれの観点から違反している点が具体的に指摘されていてわかりやすかったです。



### 第11章 ツールを用いたアスペクト指向プログラミング

.NETのツールの使い方なので割愛

## 第4部 DI コンテナ

.NETを前提にしたDIコンテナと各種ライブラリの話なので割愛

## まとめ

簡単にですが、Rustを書くうえで取り入れられることはないかなという観点で読んでみました。  
基本的には.NETないしOOPを前提にしていますが、Rustにも通じる教えも多く、参考になりました。  

本書を読んだ上での現時点でのスタンスですが、とにかくテストを書きやすいコードを目指したいです。  
テストの書きやすさを考えていくと、自然と揮発性依存を注入したり、interfaceの粒度が小さくなったり、抽象がもれなくなると思っています。
