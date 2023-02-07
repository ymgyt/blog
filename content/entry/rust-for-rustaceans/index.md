+++
title = "📙 RUST FOR RUSTACEANSを読んだ感想"
slug = "rust-for-rustacieans"
date = "2021-12-31"
draft = false
[taxonomies]
tags = ["rust", "book"]
+++


## 読んだ本

{{ figure(caption="RUST FOR RUSTACEANS", images=["images/rust_for_rustaceans.png"], href="https://nostarch.com/rust-rustaceans") }}

著者: [Jon Gjengset](https://twitter.com/jonhoo)

本書を読んだ感想を書いていきます。
この記事で触れていることは本の内容の一部です。  
序文で[dtolnay先生](https://github.com/dtolnay)のメッセージが読めます。



## きっかけ

もともとJon GjengsetさんのRust動画を[youtube](https://www.youtube.com/c/jongjengset)でみていたので、本もおもしろいにちがいないと思い買いました。


## まとめ

非常におもしろかったです!
StackとHeapについてから、型やAPI Design、Test,Macro,Async,Pin,Unsafe,Concurrency,FFIと多様なトピックがあり、Rustの開発者の方がどういう風に考えているか垣間見え勉強になりました。
[The Book](https://doc.rust-lang.org/book/)に書いてあることは前提になっていると思います。
普段の職場ではRustを書いている人がいないので、同僚の方々から口頭で教わるような話が書いてある本は非常に貴重でした。

## FOUNDATIONS


Valueとvariableの違いや、variableについて考えるときのメンタルモデルとして、High-LevelとLow-Levelに分けてみることができる。High-Levelの方はborrow checkerやvariable間の関係に焦点をあて、Low-Level的な見方はvariableはmemory locationに名前をつけたと考えると自分なりには理解しました。

Codeを書くうえで、memoryのどの部分を利用するかは重要で、Rustに際してはstack, heap, static memoryの区別が特に重要。  
Stackの考え方は[rui ueyama先生のcompiler book 関数とローカル変数](https://www.sigbus.info/compilerbook#%E9%96%A2%E6%95%B0%E3%81%A8%E3%83%AD%E3%83%BC%E3%82%AB%E3%83%AB%E5%A4%89%E6%95%B0)が非常にわかりやすいと思いました。  
Stack frameはいずれ消える(書き換えられる)ということがlifetimeとして表現されているのがRustの特徴のひとつだなと思いました。

Heapはcall stackとは独立したメモリ領域。Rustでheapとやり取りするprimary mechanismは`Box`。heapに確保した領域はいずれ開放(free)する必要があり、その責務を表現したのがownership。  
Read-onlyなconfigurationへのアクセスをプログラム全体に提供するために、意図的に`Box::leak`で、リーク(`'static`をえる)させることもあると書かれており、この方法は試してみたいです。

Static memoryはbinaryに埋め込まれた領域で、static memoryへの参照は`'static`になる。  
`'static` はtrait boundsとしても使われる。(`T: 'static`)  このとき、Tはownedか`&'static`の参照だけをもつことが要求される。よい例として、`std::thread::spawn`が挙げられている。

Drop orderがvariableの場合はreverse(最後に宣言されたものが最初)で、nested values(struct, tuple, array,..)はsource code順になる理由も説明されており、なるほどでした。

Ownership,{Shared,Mutable} References, Interior Mutabilityについても簡潔に説明されていました。  
> References are pointers that come with an additional contract for how they can be used

という説明があり、referenceってpointerって考えていいんだよねと思っていたので参考になりました。
Lifetimeとvarianceの説明もあり、このあたりの話は[以前ブログで書いた](https://blog.hatena.ne.jp/yamaguchi7073xtt/ymgyt.hatenablog.com/edit?entry=26006613706218795)ので、理解できました。(どうして、`&mut T`がTにたいしてinvariantなのか等)

## TYPES

### Types In Memory
Typeの最もfundamentalな役割の一つはmemoryのbitsをどう解釈するかを示すことという話。  
structのfieldやenumがmemoryにどう表現されるかを理解しておくことは、codeのcorrectnessとperformanceに影響するので重要であるようです。

#### Alignment

typeのメモリ表現が決まっても、そのbitsを任意のメモリに置けるわけではなく、hardware上の制約をうけます。  
例として、pointerはbitsでなく必ずbytesを指し示す必要があり、T型の値をメモリの4bit目におくことはできない。つまりどんな型であれ
byte 0かbyte 1(bit 8)におく必要があり、その意味で"byte-aligned"(multiple of 8bits)であると説明されています。


#### Layout

structをメモリ上にどう表現するか(宣言された順当)を決めるのがlayout。  
Rustのcompilerはこの点に関して、あまり保証を与えてくれず、制御したい場合は`repr(C)`を使うことができる。  
`repr(C)`はC/C++と同じlayoutになることを保証してくれるので、FFIをする際に便利。また、Cのlayoutは予測しやすく変更の対象でないので、raw pointerを扱うunsafeのcontextでも利用できる。

####  Dynamically Sized Types and Wide Pointers

trait objectやsliceのようにcompile時にメモリ上のサイズがわからない型をDynamically Sized Types(DST)という。 
型のサイズがわかっていることはtrait `Sized`で表現できる。  
struct fields, 関数の引数、戻り値、local変数、arrayのtype等あらゆるところで、Sizedが要求される。Sizedが要求されるところで、DSTを使うには、wide(fat) pointerを使う。wide pointerはSizedで通常のpointerの情報に加えてword-sizeのfieldをもつ。DSTの参照をとるとcompilerが自動的にwide pointerを生成してくれる。追加で保持する情報は型ごとに異なるが、sliceの場合は長さ、trait objectの場合はvtableへの参照。 

### Traits and Trait Bounds

#### Compilation and Dispatch

型Tに対してstructや関数を書くと、compilerが実際にTとして使われた型(`i32`, String,...)ごとにimpl blockをコピーしてくれる。このgeneric typeからnon-generic typesへの変換プロセスをmonomorphizationという。  また、compile時に生成されたコードのaddressが決まっていることから、static dispatchともいわれる。

static dispatchと対になるのがdynamic dispatch。これは引数に`&dyn Trait`に書くことで表現できる。この場合、vtableといわれるtraitのmethodの実装へのaddressを保持したchunk of memoryへのpointerを要求することになる。  
`&dyn`と書いたのは、trait objectがSizedでないので、pointer経由で扱う必要があるから。

staticとdynamicどちらのdispatchを使うべきかについては、明確な基準はないものの、libraryではstatic dispatchを利用しておくとuser側で選択できる余地を残すことができる。binaryなら必要に応じてdynamic dispatchを使うことでgeneric parameterを避けることができたりする。

#### Generic Traits

traitをgenericにする方法は２つあり、一つは`trait From<T>`のようにtype parameterを使う方法
、もう一つは`trait FromStr { type Err; }`のようにassociated typeを使う方法。  
最初は使い分けがわかっていませんでしたが、`From<T>`のようにある型に複数個実装を生やしたい場合はtype parameter, ある型に対して一つだけ実装を要求する場合はassociated typeと考えるようになりましたが、本でも同様のことが述べられていました。


#### Coherence and the Orphan Rule

traitの実装に関してはorphan ruleが適用される。orphan ruleとは、traitをある型に実装する際にそのtraitか型がcrateに含まれている必要があるというもの。ただし、orphan ruleの適用例外もありそれがfundamental types。  
fundamental typesは`#[fundamenta]` attributeが付与され、現在のところ`&`, `&mut`, `Box`の３つの型がfundamental型とされている。fundamental型に関しては`impl IntoIterator for &MyType` のような実装が許される。orphan ruleが適用されるとするとこれは外部のtraitを外部の型に実装していることになる。

また、`impl From<MyType> for Vec<i32>` のような実装を許すために、限定的な例外規定が設けられている説明があったが、理解できなかったので、いずれ理解したい。


#### Trait Bounds

trait boundは必ずしも、`T: Trait`のように書かなければいけないというわけではない。  
`where String: Clone`や、`where io::Error: From<MyError<T>>`のように書くこともできる。  
なので`T: Hash + Eq, S: BuilderHasher + Default`の代わりに`where HashMap<T, usize, S>: FromIterator`のような表現もできる。


#### Marker

`Send`のようなmarker traitに似たものとして、marker typesというパターンがある。  
具体的なsample codeは載っていなかったので、こういうものと想像。

```rust
use std::marker::PhantomData;

struct Unauthenticated;
struct Authenticated;

struct SshConnection<T = Unauthenticated> {
    phantom: PhantomData<T>,
}

impl SshConnection<Unauthenticated> {
    pub fn new() -> SshConnection<Unauthenticated> {
        SshConnection {
            phantom: PhantomData,
        }
    }
    pub fn authenticate(&self) -> SshConnection<Authenticated> {
        SshConnection {
            phantom: PhantomData,
        }
    }
}

impl SshConnection<Authenticated> {
    pub fn exec(&self, _command: impl Into<String>) {}
}

fn main() {
    let connection = SshConnection::new();
    let authenticated = connection.authenticate();

    authenticated.exec("command");
}
```

stateを型として表現して、stateごとにimplを定義することで、stateごとに呼び出せるmethodを制御する実装方法は非常に参考になり、使ってみたいと思った。


#### Existential Types

local variableについてはcompilerが推測してくれるので型を明示する必要は少ないが、関数の引数、戻り値、top levelの定義では型を明示することが要求される。ただし、`async`を使ったり、closureを返す場合等、型を明示することが用意でない場合があるので、こんなときに、戻り値の型を`-> impl Trait`で書くことができる。  
existential typesはzero-cost type eraseとしても機能する。iteratorのようにhelper型をinterfaceに含めなくてよくなり、後方互換性を保ちながら実装を変えやすくなる。  


## Designing Interfaces

どんなprojectでも大小関わらず、なにかしらのinterface(API)をもつが、Rustにおいては特にtype, trait, moduleがinterfaceとして機能する。そこで、Rustにおけるinterfaceを考える際に考慮する原則として以下の４つが提唱されている。

* unsurprising
* flexible
* obvious
* constrained

さらにAPI関連でおすすめのdocumentとして以下が挙げられている。

* [About - Rust API Guidelines](https://rust-lang.github.io/api-guidelines/about.html)
* [1105-api-evolution](https://rust-lang.github.io/rfcs/1105-api-evolution.html)
* [SemVer Compatibility](https://doc.rust-lang.org/cargo/reference/semver.html)


### Unsurprising

要はinterfaceをpredictableにするにはどうすればよいかという視点。

#### Naming Practices

慣習として確立している命名には従う。

*  `iter()` は` fn iter(&self) -> impl Iterator` (`&self`とって、Iteratorに実装を返す)
*  `into_inner()` は`self`とって、wrapされている型を返す
*  `SomethingError`は`std::error::Error`を実装している

#### Common Traits for Types

orphan ruleによりlibraryのuserはlibrary側の型にstdで定義されているtraitを実装できないので、一般的なtraitは可能であれば実装されていることを期待している。(自前の型でwrapすればできるが、それでもinternalにアクセスできないので実装が難しくなる)  

代表格が`Debug`。型名を出力するだけでもよいから、実装しておくのがおすすめされている。`Debug`の実装をfeatureに切り出しているcrateは何度か見たことがあった。  
僅差で2位が、`Send`,`Sync`(と`Unpin`)のauto-traits。もし型がこれらのtraitを実装しないならそれなりの理由があるべき。
次にnearly universalなtraitが`Clone`と`Default`。仮に実装できないなら、理由をドキュメントに書いておく。
期待されるtraitとしてちょっと優先度下がるが、可能なら`PartialEq`, `PartialOrd`, `Hash`, `Eq`, `Ord`もほしい。  
`PartialEq`は`assert_eq!`で使って後から付け足すことが多かったです。
最後に、`serde::{Serialize,Deserialize}`も実装しておくとよいが、`serde`へ依存したくない場合もあるので、多くのlibraryではfeatureで制御している。

以上が一般的に実装されているのが期待されているtraitでしたが、反対に`Copy`は実装されていないほうが期待されているtrait。copyしたければ、明示的にcloneを呼べば良いし、最初は`Copy`だったstructが`Copy`じゃなくなる(fieldにString追加等)ことは後方互換性を破壊する変更なので、`Copy`は通常はつけないほうがいい。


#### Ergonomic Trait Implementations

ある型Tにtraitを実装した場合でも、&Tにそのtraitは自動的に実装されない。
traitが`&self`しかとらない場合`&T`にそのtraitが実装されていることをユーザは期待する。

そこで可能なら以下のblanket implementationを提供しておくとよい
* `&T where T: Trait`
* `&mut T where T: Trait`
* `Box<T> where T: Trait`

iterateできる型であれば、`&MyType`と`&mut MyType`にそれぞれ
`IntoIterator`を実装してfor loopで自然に使えるようにしておく。

#### Wrapper Types

Rustは継承という概念をもっていないが、`Deref`を使って、同様の機能を実現している。  
`T: Deref<Target = U>`ならUに実装されているmethodを直接Tの値をreceiverとして呼ぶことができる。

`Arc`のような比較的透過的なwrapper型を提供しているなら、`Deref`を定義してinner typeの
へ`.`でアクセスできるようにしておくとよい。
inner typeへのアクセスが複雑であったり遅くなったりしない場合`AsRef`を実装しておくと
ユーザが容易に`&WrapperType`を`&InnerType`として扱えるようになる。
`From<InnerType>`と`Into<InnerType>`を実装しておくと、ユーザがwrapper型にくるんだり剥がしたりしやすくなる。

`Borrow`の場合は、`AsRef`よりユースケースが限定的で、追加の要求がある(`Hash`, `Eq`, `Ord`
に関して同じように振る舞う)

inner typeが事前にわからない場合、wrapperにmethodを定義すると、deref先のinner type
のmethodと衝突する可能性があるので、`Arc`のようにstatic methodベースにしておくとよかったりする

### Flexible

codeは暗黙的にせよ明示的にせよcontractを含む。
contractはrequirementsとpromisesからなる。
requirementsはそのcodeの使われ方に制約を課し、promisesはそのcodeがどう使えるかに
保証を与える。

できるだけ不必要なrequirementsをなくし、できるpromiseだけをするのがよい。
追加のrequirementsや、promisesを取りぞくことはbreaking changeとなる。  
逆に、requirementsを緩和したり、promisesを追加することは互換性をたもつ変更になる。

Rustではrequirementsはtrait boundや引数の型として表現され、promisesは関数の戻り値の型で表現される。

#### Object Safety

新しいtraitを定義した際に、そのtraitがobject-safeかどうかは書かれざるcontractになる。
object-safeである場合、ユーザは`dyn Trait`のようにtrait objectとしてそのtraitを扱うので

`where Self: Sized`と書くと、そのtraitはtrait objectからは呼ばれず、必ずconcrete typeに呼ばれることを強制できる。

trait objectについては実装したことがないので、いまいち実感がわかず。
このあたり苦労したことがあると書いてあることがわかるかもしれないと思いました。


#### Borrowed vs. Owned

なにかしらのtraitや型を定義する際に、Rustにおいてはownedかreferenceで保持するのかの選択を迫られる。  
まずその型の`self`をとるmethodを呼んでいたり、別のthreadにmoveしたりする必要がある場合はownedを選択することになる。  
ownedする必要がない場合はreferenceを使うことになるが、`i32`や`bool`等はmoveするのと、参照経由でcopyするコストは同程度なので例外になる。  
ただし、`[u8; 8192]`も`Copy`なので、`Copy`なら全部そうというわけでもない。  
`String::from_utf8`のようにruntimeでownedかreferenceかわかるような場合は`Cow`が便利。  


#### Fallible and Blocking Destructors

I/O関連のcleanup処理(flush write, close disk,terminate connection)は
一般的には`Drop`の実装の中でなされる。  
しかし、一度valueがdropしてしまうと、`Drop`の処理の中でおきたエラーを伝播させる
方法はpanicさせるくらいしかなくなってしまう。

ユーザに明示的にdestructor処理を公開する代替手段が考えられる。その場合ownershipをtakeする(`self`をとる)methodになるが
その場合`Drop`があるので、fieldをmoveさせることはできない。  
また、`Drop`自体は`&mut self`をとるので、`Drop`の中から`self`をとるdestructorをよぶことができない。  
もちろん回避策はあるが、いずれにもなにかしらの欠点がある。(trade-off)
１つ目はwrapper型を用意して、inner型をOptionにして、destructorの中で`Option::take`する。
２つ目は各fieldをOptionでwrapする方法。
３つ目は`ManuallyDrop`を使う方法。

### Obvious

通常、ユーザはmethod `baz`を呼んでも大丈夫なのは月の角度が47度で、過去18秒間に誰もくしゃみをしなかった場合だけというのを理解していない。  
何かおかしなことがおきたときだけ、ドキュメントを呼んだりsignatureを確認したりするもの。  
したがって、ユーザのインターフェイスへの理解を助け、間違って使用されないようにすることが重要で、そのための手段としてドキュメントと型システムがある。

#### Documentation

よいdocumentについてで本一冊かけるので、Rustに絞った話。  
unexpectedな挙動をする場合や、type signatureで表現されていないuserへの期待がある場合はdocumentに書かれているべき。  
panicはよい例。errorを返す場合はどんな場合かについて記述する。unsafe functionの場合は、callerが保証すべきことがらについて書く。  

end-to-endのexampleをmodule levelのdocumentに書いておくのがよい。全体像がつかめると個別の型やmethodの使い所もわかり、userのcodeへの組み込みの出発点になる。

semantically relatedなitemはmoduleを活用してグルーピングしておく。  
互換性等の理由でしかたなく公開している型には`#[doc(hidden)]`をつけておくとよい。  

外部のリソース(RFC, blog, white paper等)へのlinkを付与する。featureで制御している機能には`#[doc(cfg..)]をつけておくと親切。

#### Type System Guidance

type systemはinterfaceをobviousにし、misuse-resistantを高めるのに適している。

そのための手段として、semantic typingがある。classic exampleとして、boolを引数をとる関数に対して

```rust
pub enum Overwrite {
  Yes,
  No,
}

pub enum DryRun {
  Yes,
  No,
}

pub fn foo(overwrite: Overwrite, dry_run: DryRun) { todo!() }
```

のようにenumをきることで、userがoverwriteとdry runの指定を間違う可能性をへらすことができる。  
その他にもnewtype patternでnumeric typeをwrapして単位をもたせたり、別の関数からのみ取得できる型で、raw pointerをwrapしたり方法もある。

関連したテクニックとして、zero-sized typeを使って、特定の状態を表すことができる。  
特定の状態のときにだけ呼べるmethodを定義したい場合、例えば以下のように書ける

```rust
struct Grounded;
struct Launched;
// and so on
struct Rocket<Stage = Grounded> {
  stage: std::marker::PhantomData<Stage>,
}

impl Default for Rocket<Grounded> {} 

impl Rocket<Grounded> {
    pub fn launch(self) -> Rocket<Launched> { todo!() } 
}

impl Rocket<Launched> {
    pub fn accelerate(&mut self) { }
    pub fn decelerate(&mut self) { }
}

impl<Stage> Rocket<Stage> {
    pub fn color(&self) -> Color { }
    pub fn weight(&self) -> Kilograms { }
}
```

特定の場合にだけ、追加で引数が必要になる場合は、それぞれの状況をenumで表しておくのもよい。  
必要なら`#[must_use]`を付与して、`Result`同様に呼び出し側に戻り値のハンドリングを強制(警告)することもできる。

特定の場合にだけ、追加で引数が必要になる場合は、それぞれの状況をenumで表しておくのもよい。  
必要なら`#[must_use]`を付与して、`Result`同様に呼び出し側に戻り値のハンドリングを強制(警告)することもできる。

### Constrained

型のrenameやmethodの削除のような変更がbackward incompatible changeであることは明らかだが、Rust特有のものもある。

#### Type Modifications

public typeのremove/renameはuser codeを破壊するので、可能な限り`pub(crate)`,`pub(in path)`をつけるとよい。  
public typeが少なければ少ないほど、codeを破壊することなく変更できる自由をえられる。  

private fieldのstructへの追加でもuserのconstructor表現を破壊する可能性がある。  
`matches!`で使われていたりする場合も同様。  

こんなときは`#[non_exhaustive]`を付与しておくと、将来的なfieldの追加可能性を宣言できるので便利。

#### Trait Implementations

blanket implementationを追加することは一般的にbreaking change。  
外部のtraitを既存の型に実装することも、既存のtraitを外部の型に実装することも同様にbreaking change。  

traitへの変更でbreaking changeを避けるために`sealed trait`を使うことができる。  
`sealed trait`はimplすることができず、useのみできる。  
`sealed trait`を利用しておくと、安全にtraitにmethodを追加することができる。

```rust
pub trait CanUseCannotImplement: sealed::Sealed { .. } 
mod sealed {
    pub trait Sealed {}
    impl<T> Sealed for T where T: TraitBounds {}
}

impl<T> CanUseCannotImplement for T where T: TraitBounds {}
```

このようにしておくと、super traitがprivate module配下にあるため、`CanUseCannotImplement` traitの実装を制御できる。

#### Hidden Contracts

codeへの変更が他の部分のcontractに影響する場合がある。  
他のcrateのtypeをexportしていた場合、そのcrateのmajor versionの変更はbreaking changeになる可能性がある。  
newtype pattern等でwrapしておくとこの事態を回避できる。

publicなstruct Aの中にprivateな型Bをもっている場合で、Bが`Send`でなくなった場合、Aも`Send`でなくなり、breaking changeになる。  
この変更を検知するのは難しいので、以下のようなtestを書いておくとよい。  

```rust
fn is_normal<T: Sized + Send + Sync + Unpin>() {}
    #[test]
    fn normal_types() {
      is_normal::<MyType>();
}
```

## Error Handling

error handlingのbest practicesは議論されているトピックで、ecosystemがひとつに統一されているわけではないので  
underlying principles and techniquesについて。

### Representing Error

errorを返す関数を書く際に最初に問うべきは、そのerrorをユーザがどう扱うかについて。  
errorの種別を特定したいのか、loggingのみにとどまるのか。  

errorを表現する際に主にenumerationかerasureの２つの選択肢がある。

#### Enumeration

callerがerrorの種別を特定できるように`enum MyError`を定義する。  
ecosystemと協調できるようにこのenumに`std::error::Error`を実装する。
`Display`では簡潔に表現し、他のerror messageに組み込まれることを意識する。  
`Debug`ではできるだけ詳細な情報を含めるとよい(port number, request identifier, filepath, ...)
multithreadのcontextでも使えるように`Send`,`Sync`にしておくとよい。  
可能な限り`'static`にしておくとcallerがlifetime issueに直面せず扱いやすい。


#### Opaque Errors

enumを定義する代わりにlibraryで一つだけのerror型を定義する方法。  
`Box<dyn Error + Send + Sync + 'static>`としておくと最小限のことのみuserに保証できる。  

一般的なcommunity consensusは、errorは稀であるべきで、"happy path"にcostをついかするべきでない。そのため、errorはpointer type(`Box`,`Arc`)で表現され、`Result`のsizeを増加させにくいようにしている。

`'static` boundをerror trait objectに付与する利点として、ユーザがpropagateしやすい以外にdowncastingを可能にする点があげられる。errorのcontextにおけるdowncastingは`dyn Error`型から具体型への変換を意味する。 `Error::downcast_ref`は`dyn Error + 'static`にimplされているので`'static` boundを付与した場合のみ利用できる。  
downcastingされる具体型がAPIに含まれるかは議論の余地があるポイント。  

#### Special Error Cases

`std::thread::Result`は  
```rust
pub type Result<T> = Result<T, Box<dyn Any + Send + 'static>>;
```
と定義されており、`dyn Error`のかわりに`Any`が使われている。  
これは`Result::Err` variantは`panic!()`でのみ作られ、`panic`マクロの引数になるから。  
そのため、panicしたという事実以上のものは型では保証されていない。

## Project Structure

Cargo.tomlやconditional compilation関連について。  
使ったことのない機能やtoolも紹介されておりとても参考になった。
このあたりの話を知ってからlibraryを読みたかった。
そのほかMinimum Supported Rust Version(MSRV)やChangelogsについても。


## Testing

### Rust Testing Mechanisms

Rustがtestを実行する仕組みについて。  
test時にのみ利用できるcodeを用意することで、public APIのbehavior以外にinternal stateについてもtestできる。

```rust
struct MyStruct {
    state: usize,
}

impl MyStruct {
    #[cfg(test)]
    pub(crate) fn state(&self) -> &usize {
        &self.state
    }
}

#[test]
fn initial() {
    let s = MyStruct{state: 0};
    
    assert_eq!(s.state(), &0);
}
```
そのほか、test時にだけfieldを追加できたりもするが、fieldの追加なんかはやりすぎに注意だと思った。


### Additional Testing Tools

clippyにはcorrectnessに分類される、ほぼbugと思われるcodeを検出することもできるので、CI等で実行されるようにしておくべき。  

randomなinputを生成するfuzzingによるtest方法については知りませんでした。使い所があれば是非とりいれてみたいと思いました。最初に触るなら`cargo-fuzz`がオススメされています。

property-based testについても初耳でした。こちらについては`proptest`crateがオススメされています。

race condition等によりnondeterministicなerrorに対応するために、MiriやLoomが紹介されています。Loomはtokioのtest codeで使われていたような気がします。

また、codeの変更によりある処理が100倍遅くなる場合だけでなく、100倍速くなるのもbugかもしれないので(なにかが抜けてる)、CIにperformance計測を設定しておくことについて言及されています。

## Macros

Rustのmacroはfar from the Wild West of C macrosで、well-defined rulesに従い、fairly misuse-resistantと紹介されている。  

### Declarative Macros

`macro_rules!`で定義するやつ。  
どうしてあのmacroがdeclarativeと言われるかというと、inputがこういう場合はoutputがこうなると定義してある点を捉えているからしい。(複雑なやつは手続き的ではと思うがそれでも十分宣言的だと言われればそうかもと思ってしまう)

macroへのinputに関してはRustのvalidなcodeでなくてもよいが、compilerがparseできるものでなくてはならない。(`{`だけを渡す等)

Rustのmacroはhygienicと言われるが実のところそれがなにを意味するのかよくわかっていませんでした。(Cみたいに何でもできるわけではないらしい程度)
hygienicとは、(generally) 明示的に渡された変数以外には影響を与えられない。と説明されています。


### Procedural Macros

与えられたinput tokenに対してhow generateを定義するので、proceduralと言われる。  
function-like, attribute, deriveの3種類に分類でき、それぞれのユースケースの説明。
中心になるのは`TokenStream`型で、`TokenTree`をiterateできる。`syn`crateでparseすることで、RustのASTを得られる。  
`span`を利用するとmacroのエラーをわかりやすく表示できたり、declarative macroのhygieneを実現できたりするらしい。

## Asynchronous Programming

### What's the Deal with Asynchrony

asynchronousなprogramを説明するために、synchronousなprogramをthreadと関連して説明してくれている。  
asynchronous interfaceでは、処理が完了していないことを`Poll`で表現し、処理がどこまで完了したかの状態が保持されているので、処理が進行できる準備が整ってから再開できるように呼び出し側が制御できる。  
なので、loopで必要なtaskを実行し、`Poll::Pending`が返ってきたら別のtaskを実行することで、blockingせずに常に処理を継続することができる。  
ただし、loopするということは、OSがthreadをsleepしてくれなくなるので、自前でCPU使い切らないように制御する必要がでてくる。

asynchronousな世界では、blockしうる関数はそれぞれ`poll`を実装する必要があるが、そのsignatureがそれぞれ違っては困る。ので、`Future` traitで`poll`のsignatureが定められている。


### Ergonomic Futures

asyncと書くと生成されるcodeを手で書くとどうなるかの説明があります。  
async fnの中で`await`を使うたびに、そこから処理を再開できるようにenumでlocal変数に対応したstateをもつvariantが生成され、そのenumに`poll`が実装される感じでしょうか。

async/await実装のbaseになっているgeneratorについても触れられています。  
generatorにせよ、enumによるstateにせよ、内部的な状態をstructのfield的に保持します。そうするとそのstructがmoveしてmemory上の位置が変わった場合、structのfieldAを参照しているfieldBがあった場合、そのBの値(メモリの位置)が不正なものになってしまいます。これがself-referentialといわれ、この事態に対処するために`Pin`型と`Unpin` traitが用意されています。

pin/Unpinについては[RustのPinチョットワカル
](https://tech-blog.optim.co.jp/entry/2020/03/05/160000)が非常にわかりやすかったです。 
あとは[Amos先生のPin and suffering](https://fasterthanli.me/articles/pin-and-suffering)

### Going to Sleep

`Future::poll`が`Poll::Pending`を返したとき、もう一度futureをpollする必要がある。  
これを行うのがexecutorとよばれる。executorはloopですべてのfutureをpollし続け、すべてのfutureが`Poll::Ready`を返すまでまつことでも実装できるが、それだとCPU cycleを浪費してしまう。  
そこで、なんらかのfutureが状態をすすめられるまで、待機してからpollする仕組みが必要となる。

#### Waking Up

futureの状態が進められるかをチェックする条件は多岐に渡る(network packetがこのportにきたら、mouse cursorが動いたら、channelにsendされたら、一定時間過ぎたら、...)ので、Rustはexecutorにprogressが可能だと通知できる仕組み、`Waker`を用意している。  
`Waker`はexecutorが用意して、`Context`経由で、`poll`時にfutureに渡す。  
`Waker`の`wake`がよばれたときに何が起きるかはexecutorに委ねられており、手動でvtableを実装する形で実装されている。

#### Fulfilling the Poll Contract

`Future::poll`が`Poll::Pending`を返したら、次に状態を進められるようになったときに、`Waker`の`wake`を呼び出すのはfutureの責務となる。  
ほとんどのfutureは他のfutureが`Poll::Pending`を返したときに、`Poll::Pending`を返せば、他のfutureが責務に従っている限り自身の責務を果たせる。  
process外のリソース(TCP,disk,...)と直接やりとりするfuture(leaf future)がloopで待機することがないようにOSと協調できるようにする仕組みが必要となるが、それはexecutorに委ねられている。    
一般的なexecutorの概要についても説明されていますが、自分の理解力では及びませんでした。  
executorがsleepする前に、`epoll`等を使って外部リソースの変更を適切にleaf futureに伝播させるような感じなのでしょうか。

## Unsafe Code

`unsafe`が何であり、何でないかについて。`unsafe`とは、開発者がcompilerがチェックできないinvariantsを利用するためのmechanismということを伝えたい。  
ところで、invariantsとはなにかというと、programが正しく動くために真でなければいけないもののfancy way of sayingくらいの意味のようです。(`&`はdanglingしないとか、head pointerはつねにtail pointerより進んでいる等)  
`unsafe`に含まれるcodeが安全でないのではなく、特定のcontextでは安全な操作であるため実行することが許可されている。

### The unsafe Keyword

`unsafe`というkeywordには２つの役割がある。  
* 特定の関数を`unsafe`にする
* code blockでunsafe functionalityを使えるようにする

unsafe keywordを含んでいない関数でもunsafeを付与することができる。逆にunsafeを含んでいてもunsafeを関数に付与しなくてもよい。

昔はunsafe fnは暗黙的に関数bodyがすべてunsafe blockになっていたが、[RFC2585](https://github.com/rust-lang/rfcs/blob/master/text/2585-unsafe-block-in-unsafe-fn.md)で、明示的にunsafe blockを宣言するように修正された経緯がある。  


### Great Power

`unsafe {}`の中でできるようになることは(他にもあるが、メインは)
* raw pointerのdereference
* unsafe fnの呼び出し

#### Juggling Raw pointers

`*const T`と`*mut T`はraw pointerと呼ばれる。(rawがつくのは`&`をpointerと捉えている開発者が多いから)。  
参照(`&`)と違い、lifetimeを持たず、validity ruleが適用されない。  
raw pointerのほうが適用されるruleが緩いので、`unsafe {}`の外でも、参照からraw pointerへの変換は実行できる。

#### Calling Unsafe Functions

unsafeな関数を呼ぶ場面は大別すると3つになる
* FFI(interact with non-Rust interfaces)
* skip safety checks(sliceのlen確認せずにindex accessしたり)
* custom invariantsをもつ関数(例としてあげられている処理、他にももっとある)
  * `MaybeUninit::assume_init`
  * `ManuallyDrop::drop`


### Great Responsibility

`unsafe`でなんでもできるとすると、そもそも`unsafe`の中で守らなければいけないsafeとはなにかが問題になってくる。この点については、Unsafe Code Guidelines Working Groupが活動中で、明確な線引を策定中らしい。

unwindとdrop時のことまで考えると本当にunsafeなコードを書くのは難しそうだと思いました。  
特にgenericsが絡むと、一時的にunsafeを使って、不整合な状態する、`T::foo()`のようなtrait boundのコードを呼ぶ -> panicする -> unwindで、不整合な状態でdrop処理がはじまる。のようなケース。

Drop checkまわりの話はまったくわかっていないです、特にDrop checkを通すために、`PhantomData`でgenericsを消費させたりするところです。このあたりはnomiconに挑戦して理解したいです。

## Concurrency 

本章でconcurrencyとは、things running more or less at the same timeくらいの意味。  
tread safetyが型システムでチェックされるのがRustの特徴。  

### The Trouble with Concurrency

concurrent programのなにが難しいのか、しばしば意図どおりのperformanceが得られない理由がある。
下手をしたらsingle threadで処理したほうが速くなるケースもあり得る。

### Concurrency Models

#### Shared Memory

thread間でregions of memoryを共有するモデル。`Mutex`やconcurrent hash mapを利用してstateを共有する。  
状態の変更に際してthread間で協調する必要がある場合(state sのthread1の更新処理fとthread2の更新処理gにおいてf(g(s)) != g(f(s)))このモデルが適している。


#### Worker Pools

Worker Pool modelでは、共有job queueからidenticalなworker threadがjobを実行する。  
このmodelではwork stealingが鍵になる。

#### Actors

actor modelではjobの種別ごとにそれぞれjob queueをもつ。actorはそれぞれのstate(resource)へのexclusive accessをもつので、lockやsynchronization mechanismsが必要なくなる。

### Lower-Level Concurrency

Atomic(`std::sync::atomic::{AtomicUsize,AtomicBool,Ordering}`)は複数のthreadがアクセスした際の挙動を制御するsemanticsを定めている。  
programでvariableに対して値を読んだり書いたりする際、どのようなCPU instructionを生成するかcompilerは自由に制御できる。そこでは、statementsのreorderingや、冗長な処理の省略、memoryの代わりにregisterを使うといったことが含まれる。  
compilerやCPUはprogramの結果のsemanticsに影響を与えない範囲で、codeを変換できる。  
しかし、並列実行の文脈ではこの種の変換がapplication behaviorに影響を与えるので、なんらかの方法で制約を伝える必要がある。Rustにおいてはそれがatomic typesとそれに用意されたmethods。

#### Memory Ordering

multithreadの文脈では、あるメモリの値を決めるのに時間(wall-clock)を考慮しない。有効なのはprogrammerが課した制約だけ。なので、thread間では後から書いた値が先に反映されるということがありえる。
どうも自分は`Acquire/Release`がわかりませんでした。(`Release`でstoreして、`Acquire`でloadしておけば変な並び替えおきない程度の理解)このあたりの話題は並行プログラミング入門で再挑戦したいと思います。

#### Compare and Exchange

compare_exchangeの引数や使い方の説明が非常にわかりやすかった。  
compare_exchange_weakの説明もあり。


#### The Fetch methods

複数のthreadが同一のatomic typeの書き換えをcompare_and_swapで行うと、片方は成功し、他方はretryを繰り返すことになる。現在の値によらずに実現したいoperationだけをCPUに伝えるために、`fetch_add`等のmethodがある。

### Sane Concurrency

multithreadだと実行pathが膨大になり、各実行pathをtestするのが難しい。  
そんなときのために、loom crateがある。  
概要としては、closureの形でtest caseを記述するとloomがcross-thread interactionsをtrackして、すべてのinteractionのパターンを試してくれる。  
一体どうやったらこんなことが可能なのか完全に謎ですが、機会があれば使ってみようと思いました。  
他にもGoogleのThreadSanitizer(TSan)も紹介されていました。

## Foreign Function Interfaces

FFIはまったくわかっていないのですがこの章を読んで雰囲気がつかめました。
また、FFIは必ずしも違う言語間に限ったことでなく、Rustで書かれたlibとdynamic linkしていたらそれもFFIといえる。

### Crossing Boundaries with extern

FFIは究極的にはapplicationの外のbytesにアクセスすること。  
Rustはsymbolsとcalling conventionsという２つのbuilding blocksを提供してくれている。
dynamic linkとstatic linkの違いの説明がわかりやすかったです。
FFI boundaryを超えると型が消えるのでその型がどういうbyte列になるかを意識しておく必要がある。
そのために`std::os::raw`や`std::ffi`、`#[repr(C)]`が用意されている。

### Allocation

FFIのinterfaceとしては呼び出し側がallocateするか、API側がallocationとfree用のAPIを用意しておくかに大別される。

### Safety

thread safeではない外部の型をwrapする際に`PhantomData<*const ()>`型を利用しておくことで、呼び出し側にsingle threadでの扱いを強制させたりする等、FFIをRustの型でwrapして安全なAPIを提供する方法について。

## Rust Without The Standard Library

ここでいうsystem programmingはosに頼らず直接hardwareで起動するという意味。
 
std libは実際には`core`と`alloc`をre-exportしたものという話。
`#![no_std`とするとpreludeが書き換わる仕組みらしい。

### The Rust Runtime

Rustはruntimeをもっていないといわれるが、mainの前に走るコードと、panicをハンドリングする処理が備わっているという意味でruntimeをもつ。

普段panicしたときの挙動はリッチなruntimeだからできていたことなんだと知りました。Writing Os in Rustで出てきた`#[panic_handler]`や`#![no_main]`がどうして必要かがすこしわかりうれしかったです。

### Low Level Memory Access

memory mapped hardwareを扱うさいに特定のCPU命令がelideされたりreorderされたりしないように`std::ptr::{read,write}_volatile`が用意されている。

registerが特定の状態に遷移することを型で表現する例がわかりやすかったです。


## The Rust Ecosystem

`cargo-{deny,expand,hack,llvm-lines,..}`等知らないtoolがたくさん紹介されていました。CIに組み込んでみたいものも多く非常に参考になりました。
ついでに、`fd`と`ripgrep`も紹介されていました。

その他、著者オススメの日常的によく利用するcrateが紹介されています。  
知らないcrateも多くあり、是非調べてりようしてみたいです。(`flume`のmulti-producer multi-consumer channelとか)
個人的には`itertool`と`tower`を使いこなしたいです。

`rustup`,`cargo`,`rustc`の便利機能も知らないものばかりで参考になりました。       

```rust
struct EntityIdentifier<'a> {
    namespace: Cow<'a, str>,
    name: Cow<'a,str>,
}
```

entityの識別子を上のように宣言しておくことで、検索処理の結果の場合にはOwnedを利用して、取得時の引数としてはBorrowedを利用できるようCowを使うことで、呼び出し側にallocationを強制しない使い方が参考になりました。

neat methodsも紹介されています。  
`Clone::clone_from`は使えるところではつかってみたいです。  
`Vec::swap_remove`もorder変わること許容できるならつかっていきたいです。

### Patterns in the Wild

Rustでよく使われる実装patternが紹介されています。  
panic起きてもちゃんと動くようなcodeというところの問題意識が鍵な気がしました。

### Staying Up to Date

Rustの開発状況をおさえておくのにオススメの情報源が紹介されています。
自分は紹介されている[This Week in Rust](https://this-week-in-rust.org/)をみていました。

### What Next?

いろいろなRustの学び方が紹介されています。  
文法解説した本とlibraryとして公開されているコードの間を埋めるのがムズいです。。

いろいろなリソースが紹介されているので、必ず参考になるものがみつかるのではないでしょうか。自分は[Too Many Lists](https://rust-unofficial.github.io/too-many-lists/fourth-building.html)を読んでみようと思いました。

[Amos先生のブログ](https://fasterthanli.me/tags/rust)も紹介されておりうれしかったです。

dtolnay先生のquizは知りませんでした。
