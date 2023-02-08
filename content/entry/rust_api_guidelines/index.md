+++
title = "🦀 RustのAPI Guidelinesを読んでみる"
slug = "rust_api_guidelines"
date = "2022-07-25"
draft = false
[taxonomies]
tags = ["rust"]
+++

Rustのブログ記事でよく言及されることが多いので、[API Guidelines](https://rust-lang.github.io/api-guidelines/)を読んでみました。  
本GuidelinesはRustのlibrary teamによってメンテされているみたいです。

## Guidelinesの位置付け

本Guidelinesの位置付けは[About](https://rust-lang.github.io/api-guidelines/about.html)で述べられています。  

> These guidelines should not in any way be considered a mandate that crate authors must follow, though they may find that crates that conform well to these guidelines integrate better with the existing crate ecosystem than those that do not.

強制ではないが、Guidelinesに沿っておくことで既存のecosystemとよく馴染むというくらいのニュアンスでしょうか。

## [Naming](https://rust-lang.github.io/api-guidelines/naming.html#naming)

命名規則について。雰囲気で決めていましたがこうやって言語化してくれているのは非常に助かります。  
とくに複数人開発で、命名がぶれてきたときに好みではなくこのあたりを参照して議論してみると良いのではないでしょうか。

### [Casing conforms to RFC 430 (C-CASE)](https://rust-lang.github.io/api-guidelines/naming.html#casing-conforms-to-rfc-430-c-case)

moduleは`snake_case`で型は`UpperCamelCase`のような命名規則について述べられています。  
一般的には型の文脈では`UpperCamelCase`、値の文脈では`snake_case`と説明されておりなるほどと思いました。  

UUIDやHTMLといったacronymsは`Uuid`,`Html`のように書くように言われています。  
Goでは、`HTML`のように大文字なので最初は違和感あったのですが、今ではUpperCamelCaseのほうが自然に感じるようになりました。実用的な意味でも、コード生成の文脈では`UpperCamelCase`のほうがよいと考えています。特に多言語やprotobuf,sql等からの変換では、`html_parser`を`HTMLParser`のようにする必要があり、なんらかの方法で`HTML`や`UUID`を特別扱いする仕組みが必要になり、gormなんかは自前で辞書をメンテしていたりしていました。

意外なのが、専らlibraryを書く人向けのGuidelinesでlibraryのtop levelであるcratesについては[unclear](https://github.com/rust-lang/api-guidelines/issues/29)になっていた点でした。(ただし参照されている[RFC 430](https://github.com/rust-lang/rfcs/blob/master/text/0430-finalizing-naming-conventions.md)では, `snake_case` (but prefer single word)とされています)  
個人的には、packageは"-"、crateは"_"を使うのがいいかなと思っております。

### [Ad-hoc conversions follow `at_`,`to_` conventions (C-CONV)](https://rust-lang.github.io/api-guidelines/naming.html#ad-hoc-conversions-follow-as_-to_-into_-conventions-c-conv)

`as_`,`to_`,`into_`の使い分けに関するguide。ownershipと実行コストの観点から使い分けられております。例えば、`Path`から`str`はborrowed -> borrowedなのですが、OSのpath名はutf8である保証がないので、`str`変換時に確認処理がはいるので、この変換は[`Path::to_str`](https://doc.rust-lang.org/std/path/struct.Path.html#method.to_str)になります。  
この点を嫌ってか、UTF-8の`Path`型を提供する[`camino`]があります。  
[`camino`]では、`Path::to_str() -> Option<&str>`が、[`Utf8Path::as_str() -> &str`](https://docs.rs/camino/1.0.9/camino/struct.Utf8Path.html#method.as_str)になっています。

`into_`についてはcostは高い場合と低い場合両方あり得ます。  
例えば、[`String::into_bytes()`](https://doc.rust-lang.org/std/string/struct.String.html#method.into_bytes)は内部的に保持している`Vec<u8>`を返すだけなので低いのですが、[`BufWriter::into_inner()`](https://doc.rust-lang.org/std/io/struct.BufWriter.html#method.into_inner)はbufferされているdataを書き込む処理が走るので重たい処理になる可能性があります。  

また、`as_`と`into_`は内部的に保持しているデータに変換するので抽象度を下げる働きがある一方で、`to_`はその限りでないという説明がおもしろかったです。

### [Getter names follow Rust convention (C_GETTER)](https://rust-lang.github.io/api-guidelines/naming.html#getter-names-follow-rust-convention-c-getter)

structのfieldの取得は、`get_field`ではなく、`field`とそのまま使おうということ。  
ただし、[`Cell::get`](https://doc.rust-lang.org/std/cell/struct.Cell.html#method.get)のように`get`の対象が明確なときは、`get`を使います。  
また、getterの中でなんらかのvalidationをしている際は、`unsafe fn get_unchecked(&self)`のvariantsを追加することも提案されています。

### [Methods on collections that produce iterators follow `iter`,`iter_mut`,`into_iter` (C-ITER)](https://rust-lang.github.io/api-guidelines/naming.html#methods-on-collections-that-produce-iterators-follow-iter-iter_mut-into_iter-c-iter)

collectionのelementの型が`T`だったとしたときに、`Iterator`を返すmethodのsignatureは以下のようにしようということ。

```rust
fn iter(&self) -> impl Iterator<Item = &T> {}
fn iter_mut(&mut self) -> impl Iterator<Item = &mut T> {}
fn into_iter(self) -> impl Iterator<Item = T> {}
```

ただし、このguideは概念的に同種(conceptually homogeneous)なcollectionにあてはまるとされ、`str`はその限りでないので、`iter_`ではなく、[`str::bytes`](https://doc.rust-lang.org/std/primitive.str.html#method.bytes)や[`str::chars`](https://doc.rust-lang.org/std/primitive.str.html#method.chars)が提供されている例が紹介されています。

また、適用範囲はmethodなので、iteratorを返すfunctionには当てはまらないとも書かれています。
加えて、iteratorの型はそれを返すmethodに合致したものにすることも[Iterator type names match the methods that produce them (C-ITER_TY)](https://rust-lang.github.io/api-guidelines/naming.html#iterator-type-names-match-the-methods-that-produce-them-c-iter-ty)で書かれています。(`into_iter()`は`IntoIter`型を返す)  
この点については、existential typeで, `impl Iterator<Item=T>`のようにして具体型を隠蔽する方法もあると思うのですが、どちらがよいのかなと思いました。

### [Feature names are free of placeholder words (C_FEATURE)](https://rust-lang.github.io/api-guidelines/naming.html#feature-names-are-free-of-placeholder-words-c-feature)

feature `abc`を`use-abc`や`with-abc`のようにしないこと。  
また、featureはadditiveなので、`no-abc`といった機能を利用しない形でのfeatureにしないこと。

### [Names use a consistent word order (C-WORD_ORDER)](https://rust-lang.github.io/api-guidelines/naming.html#names-use-a-consistent-word-order-c-word-order)

`JoinPathsError`, `ParseIntError`のようなエラー型を定義していたなら、addressのparseに失敗した場合のエラーは`ParseAddrError`にする。(`AddrParseError`ではない)  
verb-object-errorという順番にするというguideではなく、crate内で一貫性をもたせようということ。


## [Interoperability](https://rust-lang.github.io/api-guidelines/interoperability.html)

直訳すると相互運用性らしいのですが、いまいちピンとこず。ecosystemとの親和性みたいなニュアンスなのでしょうか。

### [Types eagerly implement common traits (C-COMMON_TRAITS)](https://rust-lang.github.io/api-guidelines/interoperability.html#types-eagerly-implement-common-traits-c-common-traits)

Rustのorphan ruleによって、基本的には`impl`はその型を定義しているcrateか実装しようとしているtrait側になければいけない。  
したがって、ユーザが定義した型についてstdで定義されているtraitは当該crateでしか定義できない。  
例えば、`url::Url`が`std::fmt::Display`を`impl`する必要があり、application側で`Url`に`Display`を定義することはできない。

この点については[RUST FOR RUSTACEANS](https://blog.ymgyt.io/entry/books/rust_for_rustaceans#Ergonomic-Trait-Implementations)でも述べられていました。  
featureでserdeのSerialize等を追加できるようにしてあるcrateなんかもあるなーと思っていたら(C-SERDE)で述べられていました。

### [Conversions use the standard traits `From`, `AsRef`, `AsMut` (C-CONV-TRAITS)](https://rust-lang.github.io/api-guidelines/interoperability.html#conversions-use-the-standard-traits-from-asref-asmut-c-conv-traits)

`From`,`TryFrom`,`AsRef`,`AsMut`は可能なら実装してあるとよい。`Into`と`TryInto`は`From`側にblanket implがあるので実装しないこと。  
`u32`と`u16`のように安全に変換できる場合とエラーになる変換がある場合は、それぞれ`From`と`TryFrom`で表現できる。

### [Collections implement `FromIterator` and `Extend` (C-COLLECT)](https://rust-lang.github.io/api-guidelines/interoperability.html#collections-implement-fromiterator-and-extend-c-collect)

collectionを定義したら、`FromIterator`と`Extend`を定義しておく。

### [Data structures implement Serde's `Serialize`, `Deserialize` (C-SERDE)](https://rust-lang.github.io/api-guidelines/interoperability.html#data-structures-implement-serdes-serialize-deserialize-c-serde)

data structureの役割を担う型は`Serialize`と`Deserialize`を実装する。  
ある型がdata structureかどうかは必ずしも明確でない場合があるが、`LinkedHashMap`や`IpAddr`をJsonから読んだり、プロセス間通信で利用できるようにしておくのは理にかなっている。  
実装をfeatureにしておくことで、downstream側で必要なときにコストを払うことができるに実装することもできる。

```toml
dependencies]
serde = { version = "1.0", optional = true }
```

```rust
pub struct T { /* ... */ }

#[cfg(feature = "serde")]
impl Serialize for T { /* ... */ }

#[cfg(feature = "serde")]
impl<'de> Deserialize<'de> for T { /* ... */ }
```
のようにしたり、deriveを利用する場合は以下のようにできる。

```toml
[dependencies]
serde = { version = "1.0", optional = true, features = ["derive"] }
```

```rust
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct T { /* ... */ }
```

### [Types are `Send` and `Sync` where possible (C-SEND_SYNC)](https://rust-lang.github.io/api-guidelines/interoperability.html#types-are-send-and-sync-where-possible-c-send-sync)

`Send`と`Sync`はcompilerが自動で実装するので、必要なら以下のテストを書いておく。

```rust
#[test]
fn test_send() {
    fn assert_send<T: Send>() {}
    assert_send::<MyStrangeType>();
}

#[test]
fn test_sync() {
    fn assert_sync<T: Sync>() {}
    assert_sync::<MyStrangeType>();
}
```

時々こういうtestを見かけていたのですが、guidelineにあったんですね。

### [Error types are meaningful and well-behaved (C-GOOD-ERR)](https://rust-lang.github.io/api-guidelines/interoperability.html#error-types-are-meaningful-and-well-behaved-c-good-err)

`Result<T,E>`に利用する`E`には、`std::error::Error`、`Send`,`Sync`を実装しておくとエラー関連のecosystemで使いやすい。  
エラー型として、`()`は使わない。必要なら[`ParseBoolError`](https://doc.rust-lang.org/std/str/struct.ParseBoolError.html)のように型を定義する。

### [Binary number types provide Hex, Octal, Binary formatting (C-NUM_FMT)](https://rust-lang.github.io/api-guidelines/interoperability.html#binary-number-types-provide-hex-octal-binary-formatting-c-num-fmt)

`|`や`&`といったbit演算が定義されるようなnumber typeには、`std::fmt::{UpperHex, LowerHex,Octal,Binary}`を定義しておく。

### [Generic reader/writer functions take `R: Read` and `W: Write` by value (C-RW-VALUE)](https://rust-lang.github.io/api-guidelines/interoperability.html#generic-readerwriter-functions-take-r-read-and-w-write-by-value-c-rw-value)

read/write処理を行う関数は以下のように定義する。

```rust
use std::io::Read;

fn do_read<R: Read>(_r: R) {}

fn main() {
    let mut stdin = std::io::stdin();
    do_read(&mut stdin);
}
```
これがcompileできるのは、stdで

```rust

impl<'a, R: Read + ?Sized> Read for &'a mut R { /* ... */ }

impl<'a, W: Write + ?Sized> Write for &'a mut W { /* ... */ }
```
が定義されているので、`&mut stdin`も`Read`になるから。関数側が`r: &R`のように参照で定義されていないので、`do_read(stdin)`のようにmoveさせてしまい、loopで使えなくなるのがNew Rust usersによくあるらしい。  
逆に関数側が、`fn do_read_ref<'a, R: Read + ?Sized>(_r: &'a mut R)`のように宣言されている例もみたりするのですが、このguideに従うかぎは不要ということなのでしょうか。  
例えば、[`prettytable-rs::Table::print`](http://phsym.github.io/prettytable-rs/master/prettytable/struct.Table.html#method.print)


## [Macros](https://rust-lang.github.io/api-guidelines/macros.html)

専ら、declarative macroについて述べられています。

### [Input syntax is evocative of the output (C-EVOCATIVE)](https://rust-lang.github.io/api-guidelines/macros.html)

入力のsyntaxが出力を想起させるという意味でしょうか。  
macroを使えば実質的にどんなsyntaxを使うこともできるが、できるだけ既存のsyntaxによせようというもの。  
例えば、macroの中でstructを宣言するなら、keywordにstructを使う等。

### [Item macros compose well with attributes (C-MACRO-ATTR)](https://rust-lang.github.io/api-guidelines/macros.html)

macroの中にattributeを書けるようにしておこう。

```rust
bitflags! {
    #[derive(Default, Serialize)]
    struct Flags: u8 {
        const ControlCenter = 0b001;
        const Terminal = 0b010;
    }
}
```

### [Item macros work anywhere that items are allowed (C-ANYWHERE)](https://rust-lang.github.io/api-guidelines/macros.html)

以下のようにmacroがmodule levelでも関数の中でも機能するようにする。

```rust
mod tests {
    test_your_macro_in_a!(module);

    #[test]
    fn anywhere() {
        test_your_macro_in_a!(function);
    }
}
```

### [Item macros support visibility specifiers (C-MACRO-VIS)](https://rust-lang.github.io/api-guidelines/macros.html)

macroでvisibilityも指定できるようにする。

```rust
bitflags! {
    pub struct PublicFlags: u8 {
        const C = 0b0100;
        const D = 0b1000;
    }
}
```

### [Type fragments are flexible (C-MACRO-TY)](https://rust-lang.github.io/api-guidelines/macros.html)

macroで`$t:ty`のようなtype fragmentを利用する場合は以下の入力それぞれに対応できるようにする。

* Primitives: `u8`, `&str`
* Relative paths: `m::Data`
* Absolute paths: `::base::Data`
* Upward relative paths: `super::Data`
* Generics: `Vec<String>`

boilerplate用のhelper macroと違って外部に公開するmacroは考えること多そうで難易度高そうです。


## [Documentation](https://rust-lang.github.io/api-guidelines/documentation.html)

codeのコメント(rustdoc)について。

### [Crate level docs are thorough and include examples (C-CRATE-DOC)](https://rust-lang.github.io/api-guidelines/documentation.html)

See [RFC 1687](https://github.com/rust-lang/rfcs/pull/1687)と書かれ、PRへリンクされています。  
[リンクでなく内容を書くべきというissue](https://github.com/rust-lang/api-guidelines/issues/188)もたっているようでした。  
PR作られていたのがnushell作られている[JTさん](https://github.com/jntrnr)でした。  
内容としては[こちら](https://github.com/jntrnr/rfcs/blob/front_page_styleguide/text/0000-api-doc-frontpage-styleguide.md)になるのでしょうか。本家にはまだmergeされていないようでした。

### [All items have a rustdoc example (C-EXAMPLE)](https://rust-lang.github.io/api-guidelines/documentation.html#all-items-have-a-rustdoc-example-c-example)

publicなmodule, trait struct enum, function, method, macro, type definitionは合理的な範囲でexampleを持つべき。  
合理的というのは、他へのlinkで足りるならそうしてもよいという意味。  
また、exampleを示す理由は、使い方を示すというより、なぜこの処理を使うかを示すかにあるとのことです。

### [Examples use `?`, not `try!`, not `unwrap` (C-QUESTION-MARK)](https://rust-lang.github.io/api-guidelines/documentation.html#examples-use--not-try-not-unwrap-c-question-mark)

documentのexampleであっても、`unwrap`しないでerrorをdelegateしようということ。

```rust
/// ```rust
/// # use std::error::Error;
/// #
/// # fn main() -> Result<(), Box<dyn Error>> {
/// your;
/// example?;
/// code;
/// #
/// #     Ok(())
/// # }
/// ```
```

上記のように、`#`を書くと`cargo test`でcompileされるが、user-visibleな箇所には現れないのでこの機能を利用する。


### [Function docs include error, panic, and safety considerations (C-FAILURE)](https://rust-lang.github.io/api-guidelines/documentation.html#function-docs-include-error-panic-and-safety-considerations-c-failure)

Errorを返すなら、`# Errors` sectionで説明を加える。panicするなら、`# Panics`で。unsafeの場合は、`# Safety`でinvariantsについて説明する。

### [Prose contains hyperlinks to relevant things (C-LINK)](https://rust-lang.github.io/api-guidelines/documentation.html#prose-contains-hyperlinks-to-relevant-things-c-link)

[Link all the things](https://github.com/rust-lang/rfcs/blob/master/text/1574-more-api-documentation-conventions.md#link-all-the-things)ということで、他の型へのlinkがかける。  
linkにはいくつか書き方があり、[RFC1946](https://rust-lang.github.io/rfcs/1946-intra-rustdoc-links.html)に詳しくのっていた。

### [Cargo.toml includes all common metadata (C-METADATA)](https://rust-lang.github.io/api-guidelines/documentation.html#cargotoml-includes-all-common-metadata-c-metadata)

`Cargo.toml`の`[package]`に記載すべきfieldについて。licenseは書いておかないと`cargo publish`できなかった気がします。

### [Release notes document all significant changes (C-RELNOTES)](https://rust-lang.github.io/api-guidelines/documentation.html#release-notes-document-all-significant-changes-c-relnotes)

Release notes = CHANGELOGという理解でよいのでしょうか。  
CHANGELOGについては、[keep a changelog](https://keepachangelog.com/en/1.0.0/)のformatに従っていました。  
`Unreleased` sectionに変更点をためて行って、releaseのたびにそれをrelease versionに変える方式がやりやすかったです。  
Breaking changeも記載されるとおもうのですが、なにが破壊的変更かが[きちんと定義](https://github.com/rust-lang/rfcs/blob/master/text/1105-api-evolution.md)されているのはRustらしいと思いました。  
また、crates.ioへのpublishされたsourceにはgitのtagを付与することも書かれていました。

[f:id:yamaguchi7073xtt:20220725180221p:plain]
Rustのブログ記事でよく言及されることが多いので、[API Guidelines](https://rust-lang.github.io/api-guidelines/)を読んでみました。  
本GuidelinesはRustのlibrary teamによってメンテされているみたいです。

## Guidelinesの位置付け

本Guidelinesの位置付けは[About](https://rust-lang.github.io/api-guidelines/about.html)で述べられています。  

> These guidelines should not in any way be considered a mandate that crate authors must follow, though they may find that crates that conform well to these guidelines integrate better with the existing crate ecosystem than those that do not.

強制ではないが、Guidelinesに沿っておくことで既存のecosystemとよく馴染むというくらいのニュアンスでしょうか。

## [Naming](https://rust-lang.github.io/api-guidelines/naming.html#naming)

命名規則について。雰囲気で決めていましたがこうやって言語化してくれているのは非常に助かります。  
とくに複数人開発で、命名がぶれてきたときに好みではなくこのあたりを参照して議論してみると良いのではないでしょうか。

### [Casing conforms to RFC 430 (C-CASE)](https://rust-lang.github.io/api-guidelines/naming.html#casing-conforms-to-rfc-430-c-case)

moduleは`snake_case`で型は`UpperCamelCase`のような命名規則について述べられています。  
一般的には型の文脈では`UpperCamelCase`、値の文脈では`snake_case`と説明されておりなるほどと思いました。  

UUIDやHTMLといったacronymsは`Uuid`,`Html`のように書くように言われています。  
Goでは、`HTML`のように大文字なので最初は違和感あったのですが、今ではUpperCamelCaseのほうが自然に感じるようになりました。実用的な意味でも、コード生成の文脈では`UpperCamelCase`のほうがよいと考えています。特に多言語やprotobuf,sql等からの変換では、`html_parser`を`HTMLParser`のようにする必要があり、なんらかの方法で`HTML`や`UUID`を特別扱いする仕組みが必要になり、gormなんかは自前で辞書をメンテしていたりしていました。

意外なのが、専らlibraryを書く人向けのGuidelinesでlibraryのtop levelであるcratesについては[unclear](https://github.com/rust-lang/api-guidelines/issues/29)になっていた点でした。(ただし参照されている[RFC 430](https://github.com/rust-lang/rfcs/blob/master/text/0430-finalizing-naming-conventions.md)では, `snake_case` (but prefer single word)とされています)  
個人的には、packageは"-"、crateは"_"を使うのがいいかなと思っております。

### [Ad-hoc conversions follow `at_`,`to_` conventions (C-CONV)](https://rust-lang.github.io/api-guidelines/naming.html#ad-hoc-conversions-follow-as_-to_-into_-conventions-c-conv)

`as_`,`to_`,`into_`の使い分けに関するguide。ownershipと実行コストの観点から使い分けられております。例えば、`Path`から`str`はborrowed -> borrowedなのですが、OSのpath名はutf8である保証がないので、`str`変換時に確認処理がはいるので、この変換は[`Path::to_str`](https://doc.rust-lang.org/std/path/struct.Path.html#method.to_str)になります。  
この点を嫌ってか、UTF-8の`Path`型を提供する[`camino`]があります。  
[`camino`]では、`Path::to_str() -> Option<&str>`が、[`Utf8Path::as_str() -> &str`](https://docs.rs/camino/1.0.9/camino/struct.Utf8Path.html#method.as_str)になっています。

`into_`についてはcostは高い場合と低い場合両方あり得ます。  
例えば、[`String::into_bytes()`](https://doc.rust-lang.org/std/string/struct.String.html#method.into_bytes)は内部的に保持している`Vec<u8>`を返すだけなので低いのですが、[`BufWriter::into_inner()`](https://doc.rust-lang.org/std/io/struct.BufWriter.html#method.into_inner)はbufferされているdataを書き込む処理が走るので重たい処理になる可能性があります。  

また、`as_`と`into_`は内部的に保持しているデータに変換するので抽象度を下げる働きがある一方で、`to_`はその限りでないという説明がおもしろかったです。

### [Getter names follow Rust convention (C_GETTER)](https://rust-lang.github.io/api-guidelines/naming.html#getter-names-follow-rust-convention-c-getter)

structのfieldの取得は、`get_field`ではなく、`field`とそのまま使おうということ。  
ただし、[`Cell::get`](https://doc.rust-lang.org/std/cell/struct.Cell.html#method.get)のように`get`の対象が明確なときは、`get`を使います。  
また、getterの中でなんらかのvalidationをしている際は、`unsafe fn get_unchecked(&self)`のvariantsを追加することも提案されています。

### [Methods on collections that produce iterators follow `iter`,`iter_mut`,`into_iter` (C-ITER)](https://rust-lang.github.io/api-guidelines/naming.html#methods-on-collections-that-produce-iterators-follow-iter-iter_mut-into_iter-c-iter)

collectionのelementの型が`T`だったとしたときに、`Iterator`を返すmethodのsignatureは以下のようにしようということ。

```rust
fn iter(&self) -> impl Iterator<Item = &T> {}
fn iter_mut(&mut self) -> impl Iterator<Item = &mut T> {}
fn into_iter(self) -> impl Iterator<Item = T> {}
```

ただし、このguideは概念的に同種(conceptually homogeneous)なcollectionにあてはまるとされ、`str`はその限りでないので、`iter_`ではなく、[`str::bytes`](https://doc.rust-lang.org/std/primitive.str.html#method.bytes)や[`str::chars`](https://doc.rust-lang.org/std/primitive.str.html#method.chars)が提供されている例が紹介されています。

また、適用範囲はmethodなので、iteratorを返すfunctionには当てはまらないとも書かれています。
加えて、iteratorの型はそれを返すmethodに合致したものにすることも[Iterator type names match the methods that produce them (C-ITER_TY)](https://rust-lang.github.io/api-guidelines/naming.html#iterator-type-names-match-the-methods-that-produce-them-c-iter-ty)で書かれています。(`into_iter()`は`IntoIter`型を返す)  
この点については、existential typeで, `impl Iterator<Item=T>`のようにして具体型を隠蔽する方法もあると思うのですが、どちらがよいのかなと思いました。

### [Feature names are free of placeholder words (C_FEATURE)](https://rust-lang.github.io/api-guidelines/naming.html#feature-names-are-free-of-placeholder-words-c-feature)

feature `abc`を`use-abc`や`with-abc`のようにしないこと。  
また、featureはadditiveなので、`no-abc`といった機能を利用しない形でのfeatureにしないこと。

### [Names use a consistent word order (C-WORD_ORDER)](https://rust-lang.github.io/api-guidelines/naming.html#names-use-a-consistent-word-order-c-word-order)

`JoinPathsError`, `ParseIntError`のようなエラー型を定義していたなら、addressのparseに失敗した場合のエラーは`ParseAddrError`にする。(`AddrParseError`ではない)  
verb-object-errorという順番にするというguideではなく、crate内で一貫性をもたせようということ。


## [Interoperability](https://rust-lang.github.io/api-guidelines/interoperability.html)

直訳すると相互運用性らしいのですが、いまいちピンとこず。ecosystemとの親和性みたいなニュアンスなのでしょうか。

### [Types eagerly implement common traits (C-COMMON_TRAITS)](https://rust-lang.github.io/api-guidelines/interoperability.html#types-eagerly-implement-common-traits-c-common-traits)

Rustのorphan ruleによって、基本的には`impl`はその型を定義しているcrateか実装しようとしているtrait側になければいけない。  
したがって、ユーザが定義した型についてstdで定義されているtraitは当該crateでしか定義できない。  
例えば、`url::Url`が`std::fmt::Display`を`impl`する必要があり、application側で`Url`に`Display`を定義することはできない。

この点については[RUST FOR RUSTACEANS](https://blog.ymgyt.io/entry/books/rust_for_rustaceans#Ergonomic-Trait-Implementations)でも述べられていました。  
featureでserdeのSerialize等を追加できるようにしてあるcrateなんかもあるなーと思っていたら(C-SERDE)で述べられていました。

### [Conversions use the standard traits `From`, `AsRef`, `AsMut` (C-CONV-TRAITS)](https://rust-lang.github.io/api-guidelines/interoperability.html#conversions-use-the-standard-traits-from-asref-asmut-c-conv-traits)

`From`,`TryFrom`,`AsRef`,`AsMut`は可能なら実装してあるとよい。`Into`と`TryInto`は`From`側にblanket implがあるので実装しないこと。  
`u32`と`u16`のように安全に変換できる場合とエラーになる変換がある場合は、それぞれ`From`と`TryFrom`で表現できる。

### [Collections implement `FromIterator` and `Extend` (C-COLLECT)](https://rust-lang.github.io/api-guidelines/interoperability.html#collections-implement-fromiterator-and-extend-c-collect)

collectionを定義したら、`FromIterator`と`Extend`を定義しておく。

### [Data structures implement Serde's `Serialize`, `Deserialize` (C-SERDE)](https://rust-lang.github.io/api-guidelines/interoperability.html#data-structures-implement-serdes-serialize-deserialize-c-serde)

data structureの役割を担う型は`Serialize`と`Deserialize`を実装する。  
ある型がdata structureかどうかは必ずしも明確でない場合があるが、`LinkedHashMap`や`IpAddr`をJsonから読んだり、プロセス間通信で利用できるようにしておくのは理にかなっている。  
実装をfeatureにしておくことで、downstream側で必要なときにコストを払うことができるに実装することもできる。

```toml
dependencies]
serde = { version = "1.0", optional = true }
```

```rust
pub struct T { /* ... */ }

#[cfg(feature = "serde")]
impl Serialize for T { /* ... */ }

#[cfg(feature = "serde")]
impl<'de> Deserialize<'de> for T { /* ... */ }
```
のようにしたり、deriveを利用する場合は以下のようにできる。

```toml
[dependencies]
serde = { version = "1.0", optional = true, features = ["derive"] }
```

```rust
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct T { /* ... */ }
```

### [Types are `Send` and `Sync` where possible (C-SEND_SYNC)](https://rust-lang.github.io/api-guidelines/interoperability.html#types-are-send-and-sync-where-possible-c-send-sync)

`Send`と`Sync`はcompilerが自動で実装するので、必要なら以下のテストを書いておく。

```rust
#[test]
fn test_send() {
    fn assert_send<T: Send>() {}
    assert_send::<MyStrangeType>();
}

#[test]
fn test_sync() {
    fn assert_sync<T: Sync>() {}
    assert_sync::<MyStrangeType>();
}
```

時々こういうtestを見かけていたのですが、guidelineにあったんですね。

### [Error types are meaningful and well-behaved (C-GOOD-ERR)](https://rust-lang.github.io/api-guidelines/interoperability.html#error-types-are-meaningful-and-well-behaved-c-good-err)

`Result<T,E>`に利用する`E`には、`std::error::Error`、`Send`,`Sync`を実装しておくとエラー関連のecosystemで使いやすい。  
エラー型として、`()`は使わない。必要なら[`ParseBoolError`](https://doc.rust-lang.org/std/str/struct.ParseBoolError.html)のように型を定義する。

### [Binary number types provide Hex, Octal, Binary formatting (C-NUM_FMT)](https://rust-lang.github.io/api-guidelines/interoperability.html#binary-number-types-provide-hex-octal-binary-formatting-c-num-fmt)

`|`や`&`といったbit演算が定義されるようなnumber typeには、`std::fmt::{UpperHex, LowerHex,Octal,Binary}`を定義しておく。

### [Generic reader/writer functions take `R: Read` and `W: Write` by value (C-RW-VALUE)](https://rust-lang.github.io/api-guidelines/interoperability.html#generic-readerwriter-functions-take-r-read-and-w-write-by-value-c-rw-value)

read/write処理を行う関数は以下のように定義する。

```rust
use std::io::Read;

fn do_read<R: Read>(_r: R) {}

fn main() {
    let mut stdin = std::io::stdin();
    do_read(&mut stdin);
}
```
これがcompileできるのは、stdで

```rust

impl<'a, R: Read + ?Sized> Read for &'a mut R { /* ... */ }

impl<'a, W: Write + ?Sized> Write for &'a mut W { /* ... */ }
```
が定義されているので、`&mut stdin`も`Read`になるから。関数側が`r: &R`のように参照で定義されていないので、`do_read(stdin)`のようにmoveさせてしまい、loopで使えなくなるのがNew Rust usersによくあるらしい。  
逆に関数側が、`fn do_read_ref<'a, R: Read + ?Sized>(_r: &'a mut R)`のように宣言されている例もみたりするのですが、このguideに従うかぎは不要ということなのでしょうか。  
例えば、[`prettytable-rs::Table::print`](http://phsym.github.io/prettytable-rs/master/prettytable/struct.Table.html#method.print)


## [Macros](https://rust-lang.github.io/api-guidelines/macros.html)

専ら、declarative macroについて述べられています。

### [Input syntax is evocative of the output (C-EVOCATIVE)](https://rust-lang.github.io/api-guidelines/macros.html)

入力のsyntaxが出力を想起させるという意味でしょうか。  
macroを使えば実質的にどんなsyntaxを使うこともできるが、できるだけ既存のsyntaxによせようというもの。  
例えば、macroの中でstructを宣言するなら、keywordにstructを使う等。

### [Item macros compose well with attributes (C-MACRO-ATTR)](https://rust-lang.github.io/api-guidelines/macros.html)

macroの中にattributeを書けるようにしておこう。

```rust
bitflags! {
    #[derive(Default, Serialize)]
    struct Flags: u8 {
        const ControlCenter = 0b001;
        const Terminal = 0b010;
    }
}
```

### [Item macros work anywhere that items are allowed (C-ANYWHERE)](https://rust-lang.github.io/api-guidelines/macros.html)

以下のようにmacroがmodule levelでも関数の中でも機能するようにする。

```rust
mod tests {
    test_your_macro_in_a!(module);

    #[test]
    fn anywhere() {
        test_your_macro_in_a!(function);
    }
}
```

### [Item macros support visibility specifiers (C-MACRO-VIS)](https://rust-lang.github.io/api-guidelines/macros.html)

macroでvisibilityも指定できるようにする。

```rust
bitflags! {
    pub struct PublicFlags: u8 {
        const C = 0b0100;
        const D = 0b1000;
    }
}
```

### [Type fragments are flexible (C-MACRO-TY)](https://rust-lang.github.io/api-guidelines/macros.html)

macroで`$t:ty`のようなtype fragmentを利用する場合は以下の入力それぞれに対応できるようにする。

* Primitives: `u8`, `&str`
* Relative paths: `m::Data`
* Absolute paths: `::base::Data`
* Upward relative paths: `super::Data`
* Generics: `Vec<String>`

boilerplate用のhelper macroと違って外部に公開するmacroは考えること多そうで難易度高そうです。


## [Documentation](https://rust-lang.github.io/api-guidelines/documentation.html)

codeのコメント(rustdoc)について。

### [Crate level docs are thorough and include examples (C-CRATE-DOC)](https://rust-lang.github.io/api-guidelines/documentation.html)

See [RFC 1687](https://github.com/rust-lang/rfcs/pull/1687)と書かれ、PRへリンクされています。  
[リンクでなく内容を書くべきというissue](https://github.com/rust-lang/api-guidelines/issues/188)もたっているようでした。  
PR作られていたのがnushell作られている[JTさん](https://github.com/jntrnr)でした。  
内容としては[こちら](https://github.com/jntrnr/rfcs/blob/front_page_styleguide/text/0000-api-doc-frontpage-styleguide.md)になるのでしょうか。本家にはまだmergeされていないようでした。

### [All items have a rustdoc example (C-EXAMPLE)](https://rust-lang.github.io/api-guidelines/documentation.html#all-items-have-a-rustdoc-example-c-example)

publicなmodule, trait struct enum, function, method, macro, type definitionは合理的な範囲でexampleを持つべき。  
合理的というのは、他へのlinkで足りるならそうしてもよいという意味。  
また、exampleを示す理由は、使い方を示すというより、なぜこの処理を使うかを示すかにあるとのことです。

### [Examples use `?`, not `try!`, not `unwrap` (C-QUESTION-MARK)](https://rust-lang.github.io/api-guidelines/documentation.html#examples-use--not-try-not-unwrap-c-question-mark)

documentのexampleであっても、`unwrap`しないでerrorをdelegateしようということ。

```rust
/// ```rust
/// # use std::error::Error;
/// #
/// # fn main() -> Result<(), Box<dyn Error>> {
/// your;
/// example?;
/// code;
/// #
/// #     Ok(())
/// # }
/// ```
```

上記のように、`#`を書くと`cargo test`でcompileされるが、user-visibleな箇所には現れないのでこの機能を利用する。


### [Function docs include error, panic, and safety considerations (C-FAILURE)](https://rust-lang.github.io/api-guidelines/documentation.html#function-docs-include-error-panic-and-safety-considerations-c-failure)

Errorを返すなら、`# Errors` sectionで説明を加える。panicするなら、`# Panics`で。unsafeの場合は、`# Safety`でinvariantsについて説明する。

### [Prose contains hyperlinks to relevant things (C-LINK)](https://rust-lang.github.io/api-guidelines/documentation.html#prose-contains-hyperlinks-to-relevant-things-c-link)

[Link all the things](https://github.com/rust-lang/rfcs/blob/master/text/1574-more-api-documentation-conventions.md#link-all-the-things)ということで、他の型へのlinkがかける。  
linkにはいくつか書き方があり、[RFC1946](https://rust-lang.github.io/rfcs/1946-intra-rustdoc-links.html)に詳しくのっていた。

### [Cargo.toml includes all common metadata (C-METADATA)](https://rust-lang.github.io/api-guidelines/documentation.html#cargotoml-includes-all-common-metadata-c-metadata)

`Cargo.toml`の`[package]`に記載すべきfieldについて。licenseは書いておかないと`cargo publish`できなかった気がします。

### [Release notes document all significant changes (C-RELNOTES)](https://rust-lang.github.io/api-guidelines/documentation.html#release-notes-document-all-significant-changes-c-relnotes)

Release notes = CHANGELOGという理解でよいのでしょうか。  
CHANGELOGについては、[keep a changelog](https://keepachangelog.com/en/1.0.0/)のformatに従っていました。  
`Unreleased` sectionに変更点をためて行って、releaseのたびにそれをrelease versionに変える方式がやりやすかったです。  
Breaking changeも記載されるとおもうのですが、なにが破壊的変更かが[きちんと定義](https://github.com/rust-lang/rfcs/blob/master/text/1105-api-evolution.md)されているのはRustらしいと思いました。  
また、crates.ioへのpublishされたsourceにはgitのtagを付与することも書かれていました。

### [Rustdoc does not show unhelpful implementation details (C-HIDDEN)](https://rust-lang.github.io/api-guidelines/documentation.html#rustdoc-does-not-show-unhelpful-implementation-details-c-hidden)

rustdocはユーザがcrateを利用するためにあるので、実装の詳細についての言及は選択的に行う。  
例えば、`PublicError`の`From<PrivateError>`処理はユーザには見えないので、`#[doc(hidden)]`を付与したりすることができる。

```rust
// This error type is returned to users.
pub struct PublicError { /* ... */ }

// This error type is returned by some private helper functions.
struct PrivateError { /* ... */ }

// Enable use of `?` operator.
#[doc(hidden)]
impl From<PrivateError> for PublicError {
    fn from(err: PrivateError) -> PublicError {
        /* ... */
    }
}
```

## [Predictability](https://rust-lang.github.io/api-guidelines/predictability.html)

予測可能性について。

### [Smart pointers do not add inherent methods (C-SMART-PTR)](https://rust-lang.github.io/api-guidelines/predictability.html#smart-pointers-do-not-add-inherent-methods-c-smart-ptr)

`Box`のようなsmart pointerの役割を果たす型に`fn method(&self)`のようなinherent methodsを定義しないようにする。  
理由としては、`Box<T>`の値がある場合に`boxed_x.method()`という呼び出しが`Deref`で`T`のmethodなのか`Box`側なのか紛らわしいから。

### [Conversions live on the most specific type involved (C-CONV-SPECIFIC)](https://rust-lang.github.io/api-guidelines/predictability.html#conversions-live-on-the-most-specific-type-involved-c-conv-specific)

型の間で変換を行う際、ある型のほうがより具体的(provide additional invariant)な場合がある。  
例えば、`str`は`&[u8]`に対してUTF-8として有効なbyte列であることを保証する。  
このような場合、型変換処理は具体型、この例では`str`側に定義する。このほうが直感的であることに加えて、`&[u8]`の型変換処理methodが増え続けていくことを防止できる。

### [Functions with a clear receiver are methods (C-METHOD)](https://rust-lang.github.io/api-guidelines/predictability.html#functions-with-a-clear-receiver-are-methods-c-method)

特定の型に関連したoperationはmethodにする。

```rust
// Prefer
impl Foo {
    pub fn frob(&self, w: widget) { /* ... */ }
}

// Over
pub fn frob(foo: &Foo, w: widget) { /* ... */ }
```

Methodはfunctionに比べて以下のメリットがある。

* importする必要がなく、値だけで利用できる。
* 呼び出し時にautoborrowingしてくれる。
* 型`T`でなにができるかがわかりやすい
* `self`であることでownershipの区別がよりわかりやすくなる
  * ここの理由はいまいちわかりませんでした。

個人的にmethodにするか、関数にするか結構悩みます。  
具体的にはmethodの中で、structのfieldの一部しか利用しない場合、利用するfieldだけを引数にとる関数を定義したくなったりします。(structを分割することが示唆しているのかもしれませんが)

### [Functions do not take out-parameters (C-NO-OUT)](https://rust-lang.github.io/api-guidelines/predictability.html#functions-do-not-take-out-parameters-c-no-out)

いまいちよく理解できなかったのですが、戻り値を入力として受け取って加工して返すみたいなfunctionは避けようということでしょうか。例にあげられているコードがいまいち何を伝えたいかわからずでした。  
Preferの`foo`はどうして,`Bar`二つ返してるんでしょうか。

```rust
// Prefer
fn foo() -> (Bar, Bar)

// Over
fn foo(output: &mut Bar) -> Bar
```

例外としては、buffer等のcallerがあらかじめ確保しているdata構造に対する処理として、read系の例があげられていました。

```rust
fn read(&mut self, buf: &mut [u8]) -> io::Result<usize>
```

### [Operator overloads are unsurprising (C-OVERLOAD)](https://rust-lang.github.io/api-guidelines/predictability.html#operator-overloads-are-unsurprising-c-overload)

`std::ops`を実装すると、`*`や`|`が使えるようになるが、この実装は`Mul`として機能するようにする。

### [Only smart pointers implement `Deref` and `DerefMut` (C-DEREF)](https://rust-lang.github.io/api-guidelines/predictability.html#only-smart-pointers-implement-deref-and-derefmut-c-deref)

`Deref`で委譲をやるようにしたことあったのですがアンチパターンということでやめました。  
[Stack overflow](https://stackoverflow.com/questions/45086595/is-it-considered-a-bad-practice-to-implement-deref-for-newtypes)でも、[delegate](https://crates.io/crates/delegate)や[ambassador](https://crates.io/crates/ambassador)の利用を推奨している回答がありました。

### [Constructors are static, inherent methods (C-CTOR)](https://rust-lang.github.io/api-guidelines/predictability.html#constructors-are-static-inherent-methods-c-ctor)

型のconstructorについて。  
基本は、`T::new`を実装する。可能なら`Default`も。  
domainによっては、`new`以外も可能。例えば、`File::open`や`TcpStream::connect`。  
constructorが複数ある場合には、`_with_foo`のようにする。  
複雑ならbuilder patternを検討する。  
ある既存の型の値からconstructする場合は、`from_`を検討する。`from_`と`From<T>`の違いは、unsafeにできたり、追加の引数を定義できたりするところにある。

## [Flexibility](https://rust-lang.github.io/api-guidelines/flexibility.html)

### [Functions expose intermediate results to avoid duplicate work (C-INTERMEDIATE)](https://rust-lang.github.io/api-guidelines/flexibility.html#functions-expose-intermediate-results-to-avoid-duplicate-work-c-intermediate)

処理の過程で生成された中間データが呼び出し側にとって有用になりうる場合があるならそれを返すようなAPIにする。  
これだけだといまいちわかりませんが、具体例として

* `Vec::binary_search`
  * 見つからなかった時はinsertに適したindexを返してくれる
* `String::from_utf8`
  * 有効なUTF-8でなかった場合、そのoffsetとinputのownershipを戻してくれる
* `HashMap::insert`
  * keyに対して既存の値があれば戻してくれる。recoverしようとした際にtableのlookupを予め行う必要がない。

ownershipとるような関数の場合、エラー時に値を返すようなAPIは参考になるなと思いました。

### [Caller decides where to copy and place data (C-CALLER_CONTROL)](https://rust-lang.github.io/api-guidelines/flexibility.html#caller-decides-where-to-copy-and-place-data-c-caller-control)

```rust
fn foo(b: &Bar) {
   let b = b.clone(); 
}
```

のようにするなら最初から`foo(b: Bar)`でownershipをとるようにする。こうすれば呼び出し側でcloneするかmoveするかを選択できるようになる。

### [Functions minimize assumptions about parameters by using generics (C-GENERIC)](https://rust-lang.github.io/api-guidelines/flexibility.html#functions-minimize-assumptions-about-parameters-by-using-generics-c-generic)

引数に対する前提(assumption)が少ないほど、関数の再利用性があがる。  
ので、`fn foo(&[i64])`のようにうけないで  
```rust
fn foo<I: IntoIterator<Item= i64>>(iter: I)
```

のようにうけて、値のiterateにのみ依存していることを表現する。  ただし、genericsにもdisadvantageがあるのでそれは考慮する。(code size等)

### [Traits are object-safe if they may be useful as a trait object (C-OBJECT)](https://rust-lang.github.io/api-guidelines/flexibility.html#traits-are-object-safe-if-they-may-be-useful-as-a-trait-object-c-object)

traitを設計する際は、genericsのboundとしてかtrait objectとして利用するのかを決めておく。  
object safeなtraitにobject safeでないmethodを追加して、object safeを満たさなくならないように注意する必要があるということでしょうか。  
trait safeでないmethodを追加する際は、`where`に`Self: Sized`を付与してtrait objectからはよべなくする選択肢もあるそうで、`Iterator`ではそうしているという例ものっていました。  
`Send`や`Sync`と同様にtest caseでobject safeのassertも書いておいた方がよさそうだなと思いました。


## [Type safety](https://rust-lang.github.io/api-guidelines/type-safety.html)

### [Newtypes provide static distinctions (C-NEWTYPE)](https://rust-lang.github.io/api-guidelines/type-safety.html#newtypes-provide-static-distinctions-c-newtype)

単位やId(UserId,ItemId,...)等を`i64`や`String`ではなく専用の型をきって静的に区別する。 

```rust
struct Miles(pub f64);
struct Kilometers(pub f64);

impl Miles {
    fn to_kilometers(self) -> Kilometers { /* ... */ }
}
impl Kilometers {
    fn to_miles(self) -> Miles { /* ... */ }
}
```

### [Arguments convery meaning through types, not `bool` or `Option` (C-CUSTOM-TYPE)](https://rust-lang.github.io/api-guidelines/type-safety.html#arguments-convey-meaning-through-types-not-bool-or-option-c-custom-type)

boolじゃなくて専用の型をきろう。boolに対してenumにするのがわかりやすいのは理解できるのですが、Optionも使わない方がよいものなのかなと思いました。  
Optionはecosystemと親和性あるから変にwrapすると使いづらくなるのでは。

```rust
// Prefer
let w = Widget::new(Small, Round)

// Over
let w = Widget::new(true, false)
```

### [Types for a set of flags are `bitflags`, not enums (C-BITFLAG)](https://rust-lang.github.io/api-guidelines/type-safety.html#types-for-a-set-of-flags-are-bitflags-not-enums-c-bitflag)

他言語やシステムとの互換性の観点や整数値でフラグのsetを管理したい場合は`bitflags`を使おう。

```rust
use bitflags::bitflags;

bitflags! {
    struct Flags: u32 {
        const FLAG_A = 0b00000001;
        const FLAG_B = 0b00000010;
        const FLAG_C = 0b00000100;
    }
}

fn f(settings: Flags) {
    if settings.contains(Flags::FLAG_A) {
        println!("doing thing A");
    }
    if settings.contains(Flags::FLAG_B) {
        println!("doing thing B");
    }
    if settings.contains(Flags::FLAG_C) {
        println!("doing thing C");
    }
}

fn main() {
    f(Flags::FLAG_A | Flags::FLAG_C);
}
```

### [Builders enable construction of complex values (C-BUILDER)](https://rust-lang.github.io/api-guidelines/type-safety.html#builders-enable-construction-of-complex-values-c-builder)

型`T`のconstructが複雑になってきたときには、`TBuilder`を作ることを検討する。必ずしもBuilderとする必要はなく、stdのchild processに対する`Command`や`Url`の`ParseOptions`のようにdomainに適した名前があるならそれを利用する。  
`Builder`のmethodのreceiverに`&mut self`をとるか、`self`をとるかでそれぞれトレードオフがある。  
どちらを採用してもone lineは問題なくかけるが、ifを書こうとすると`self`をとるアプローチは再代入させる形にする必要がある。

```self
// Complex configuration
let mut task = TaskBuilder::new();
task = task.named("my_task_2"); // must re-assign to retain ownership
if reroute {
    task = task.stdout(mywriter);
}
```

## [Dependability](https://rust-lang.github.io/api-guidelines/dependability.html)

### [Functions validate their arguments (C-VALIDATE)](https://rust-lang.github.io/api-guidelines/dependability.html#functions-validate-their-arguments-c-validate)

RustのApiは一般的には[robustness principle](http://en.wikipedia.org/wiki/Robustness_principle)に従っていない。  
つまり、インプットに対してliberalな態度を取らない。代わりにRustでは実用的な範囲でインプットをvalidateする。  
validationは以下の方法でなされる。(優先度の高い順)

#### Static enforcement

```rust
// Prefer
fn foo(a: Ascii) { }

// Over
fn foo(a: u8) { }
```

ここでは`Ascii`は`u8`のwrapperでasciiとして有効なbyteであることを保証している。  
こうしたstatic enforcementはcostをboundaries(`u8`が最初に`Ascii`に変換される時)によせ、runtime時のcostを抑えてくれる。

#### Dynamic enforcement

実行時のvalidationの欠点としては

* Runtime overhead
* bugの発見が送れること
* `Result/Option`が導入されること(clientがハンドリングする必要がある)

また、production buildでのruntime costをさける手段として`debug_assert!`がある。  
さらに、`_unchecked`版の処理を提供し、runtime costをopt outする選択肢を提供している場合もある。

### [Destructors never fail (C-DTOR-FAIL)](https://rust-lang.github.io/api-guidelines/dependability.html#destructors-never-fail-c-dtor-fail)

Destructorはpanic時も実行される。panic時のdestructorの失敗はprogramのabortにつながる。  
destructorを失敗させるのではなく、clean teardownをcheckできる別のmethodを提供する。(`close`など)  
もし、こうした`close`が呼ばれなかった場合は、`Drop`の実装はエラーを無視するかloggingする。

### [Destructors that may block have alternatives (C-DTOR-BLOCK)](https://rust-lang.github.io/api-guidelines/dependability.html#destructors-that-may-block-have-alternatives-c-dtor-block)

同様にdestructorはblockingする処理も実行してはならない。  
ここでも、infallibleでnonblockingできるように別のmethodを提供する。

## [Debuggability](https://rust-lang.github.io/api-guidelines/debuggability.html)

### [All public types implement `Debug` (C-DEBUG)](https://rust-lang.github.io/api-guidelines/debuggability.html#all-public-types-implement-debug-c-debug)

publicな型には`Debug`を実装する。例外は稀。

### [`Debug` representation is never empty (C-DEBUG-NONEMPTY)](https://rust-lang.github.io/api-guidelines/debuggability.html#debug-representation-is-never-empty-c-debug-nonempty)

空の値を表現していても、`[]`なり`""`のなんらかの表示をおこなうべきで、空の出力をするべきでない。

## [Future proofing](https://rust-lang.github.io/api-guidelines/future-proofing.html)

### [Sealed traits protect against downstream implementations (C-SEALED)](https://rust-lang.github.io/api-guidelines/future-proofing.html#sealed-traits-protect-against-downstream-implementations-c-sealed)

crate内でのみ実装を提供したいtraitについては、ユーザ側で`impl`できないようにしておくことで、破壊的変更を避けつつtraitを変更できるように保てる。

```rust

/// This trait is sealed and cannot be implemented for types outside this crate.
pub trait TheTrait: private::Sealed {
    // Zero or more methods that the user is allowed to call.
    fn ...();

    // Zero or more private methods, not allowed for user to call.
    #[doc(hidden)]
    fn ...();
}

// Implement for some types.
impl TheTrait for usize {
    /* ... */
}

mod private {
    pub trait Sealed {}

    // Implement for those same types, but no others.
    impl Sealed for usize {}
}
```

ユーザは`private::Sealed`を実装できないので、結果的に`TheTrait`を実装できずboundariesのみで利用できる。  
libで時々みかけて、最初は意図がわかっていなかったのですが、ユーザにtraitを実装されると、traitのsignatureの変更が破壊的変更になることをきらってのことだとわかりました。もっとはやくガイドラインを読んでおけばよかったです。

### [Structs have private fields (C-STRUCT-PRIVATE)](https://rust-lang.github.io/api-guidelines/future-proofing.html#structs-have-private-fields-c-struct-private)

publicなfieldをもつことは強いcommitmentになる。ユーザは自由にそのfieldを操作できるのでvalidationやinvariantを維持することができなくなる。  
publicなfieldはcompoundでpassiveなデータ構造に適している。(C spirit)

### [Newtypes encapsulate implementation details (C-NEWTYPE-HIDE)](https://rust-lang.github.io/api-guidelines/future-proofing.html#newtypes-encapsulate-implementation-details-c-newtype-hide)

以下のようなiterationに関するロジックを提供する`my_transform`を考える

```rust
use std::iter::{Enumerate, Skip};

pub fn my_transform<I: Iterator>(input: I) -> Enumerate<Skip<I>> {
    input.skip(3).enumerate()
}
```

`Enumerate<Skip<I>>`をユーザにみせたくないので、Newtypeでwrapすると

```rust
use std::iter::{Enumerate, Skip};

pub struct MyTransformResult<I>(Enumerate<Skip<I>>);

impl<I: Iterator> Iterator for MyTransformResult<I> {
    type Item = (usize, I::Item);

    fn next(&mut self) -> Option<Self::Item> {
        self.0.next()
    }
}

pub fn my_transform<I: Iterator>(input: I) -> MyTransformResult<I> {
    MyTransformResult(input.skip(3).enumerate())
}
```

こうすることで、ユーザ側のcodeを壊すことなく実装を変更できるようになる。  
`my_transform<I: Iterator>(input: I) -> impl Iterator<Item =(usize, I::Item)>`のようなsignatureも可能だが、`impl Trait`にはトレードオフがある。  
例えば、`Debug`や`Clone`を書けなかったりする。

### [Data structures do not duplicate derived trait bound (C-STRUCT-BOUNDS)](https://rust-lang.github.io/api-guidelines/future-proofing.html#data-structures-do-not-duplicate-derived-trait-bounds-c-struct-bounds)

ちょっと理解があやしいですが、trait boundの設けたstruct定義に`derive`を書かないということでしょうか。  
trait boundを書かなくても`derive`はgenericsがtraitを実装しているかで制御されるし、deriveを追加する際にtrait boundを追加するとそれはbreaking changeになるからという理解です。

```rust
// Prefer this:
#[derive(Clone, Debug, PartialEq)]
struct Good<T> { /* ... */ }

// Over this:
#[derive(Clone, Debug, PartialEq)]
struct Bad<T: Clone + Debug + PartialEq> { /* ... */ }
```

## [Necessities](https://rust-lang.github.io/api-guidelines/necessities.html#necessities)

### [Public dependencies of a stable crate are stable (C-STABLE)](https://rust-lang.github.io/api-guidelines/necessities.html#public-dependencies-of-a-stable-crate-are-stable-c-stable)

public dependenciesのcrateがstable(`>=1.0.0`)でなければそのcrateはstableにできない。  
`From`の実装等、public dependenciesは以外なところに現れる。

### [Crate and its dependencies have a permissive licence (C-PERMISSIVE)](https://rust-lang.github.io/api-guidelines/necessities.html#crate-and-its-dependencies-have-a-permissive-license-c-permissive)

Rust projectで作られているsoftwareは[MIT](https://github.com/rust-lang/rust/blob/master/LICENSE-MIT)か[Apache 2.0](https://github.com/rust-lang/rust/blob/master/LICENSE-APACHE)のdual licenseになっている。  
Rustのecosystemとの親和性を重視するなら同じようにしておく。  
crateのdependenciesのlicenseはcrate自身に影響するので、permissively-licensed crateは一般的にpermissively-licensed crateのみを利用する。


## まとめ

Rustのapi guidelineをざっと眺めてみました。  
いろいろなcrateで共通していることが書かれていた印象です。  
自分で書いたりコードレビューしたりする際に参照していきたいです。


[`camino`]: https://github.com/camino-rs/camino
