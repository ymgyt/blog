+++
title = "🍪 Parser combinator nom 入門"
slug = "getting_started_with_nom"
date = "2021-05-01"
draft = false
[taxonomies]
tags = ["rust"]
+++

{{ figure(caption="nom nom nom", images=["images/getting_started_nom.png"]) }}

この記事ではparser combinator nom[^nom]について書きます。versionは `v6.1`を前提にしています。  
nomは小さいparserを組み合わせて、目的とするデータ構造を入力から読み取るためのpackageです。  
[nushell](https://github.com/nushell/nushell) のコードを読んでいてみかけたのが初めてでしたが他のpackageでも時々利用されているのをみるので、読めるようになるのが目標です。  

そもそもparser combinatorといわれてもピンときていなかったので、自分と同じ様な方は[Learning Parser Combinators With Rust](https://bodil.lol/parser-combinators/) がおすすめです。この記事を読んでparserを組み合わせるという意味がわかりました。

nomで組み合わせるparserは概ね以下のような関数signatureをしています。

```rust
fn parse_unicode<'a, E>(input: &'a str) -> IResult<&'a str, char, E>
where
  E: ParseError<&'a str> + FromExternalError<&'a str, std::num::ParseIntError>,
{
  let parse_hex = take_while_m_n(1, 6, |c: char| c.is_ascii_hexdigit());

  let parse_delimited_hex = preceded(
    char('u'),
    delimited(char('{'), parse_hex, char('}')),
  );

  let parse_u32 = map_res(parse_delimited_hex, move |hex| u32::from_str_radix(hex, 16));

  map_opt(parse_u32, |value| std::char::from_u32(value))(input)
}
```
[https://github.com/Geal/nom/blob/38bb94e7bc45c2b4ef0c473e0e5c03ab134cdff3/examples/string.rs#L36](https://github.com/Geal/nom/blob/38bb94e7bc45c2b4ef0c473e0e5c03ab134cdff3/examples/string.rs#L36)

この関数は、文字列中のunicodeのcodepoint表現(`\u{0041}`)をparseするための関数です。  
エラーがgenericになっていたり、`IResult`型なるものがでてきて初見ではよくわからないと思うのでこのあたりからみていきます。


## `nom::IResult<I,O,E>`

nom parserのparse結果を表す型`IResult`[^IResult]は以下のように定義されています。  
`type IResult<I, O, E = Error<I>> = Result<(I, O), Err<E>>;`  
`I`はInput, `O`はparserの成功時のparse結果の型を表しています。  
parserはparseに成功すると自身がparseで消費したinputを取り除き、残りの`I`(input)とparse結果のタプルを返します。
`E`はさらに`Err<E>`とwrapされているので`Err`[^Err] をみてみると以下のように定義されています。  

```rust
pub enum Err<E> {
    Incomplete(Needed),
    Error(E),
    Failure(E),
}

pub enum Needed {
    Unknown,
    Size(NonZeroUsize),
}
```

このように`E`(parse error)をwrapすることで、parseの失敗が３つのカテゴリに分類されるようにしています。  
`Incomplte`は`streaming` moduleのparserが返すエラーで、inputが十分でないことを表すためにあります。  
network(tcp)ごしに送られてきたデータをparseしている場合、connectionをreadした段階でprotocol的に十分なデータがメモリにのっているかはわからないのでそんなときに返すのだと思います。  
以前、KeyValueStoreのtcp serverを書いたときに、[似たようなエラーを定義](https://github.com/ymgyt/kvsd/blob/897f60de4de5763a26d43c9c4a60756604dbfcd3/src/protocol/connection/mod.rs#L120)したことがありました。  
`complete` moduleのparserはこのエラーを返さないので`streaming`を利用していなければ気にしなくて良さそうです。

`Error(E)`はparserごとのparse失敗を表すエラー。(数値を期待したのにアルファベットがあったとか)  
`Failure`はunrecoverableなエラーを表します。ただここでいうunrecoverableはrustがpanicしたとかではなくあくまでparseのコンテキストでのunrecoverableなので他の選択肢を試す必要がないくらいの意味です。

`E`を指定していない場合は、`Error<I>`[^Error]が`Err`にwrapされて使われます。  
`Error`は

```rust
pub struct Error<I> {
    pub input: I,
    pub code: ErrorKind,
}
```

と定義されており、parse失敗時のinputとエラーの識別子`ErrorKind`[^ErrorKind]を保持します。  
`ErrorKind`はnomが提供しているparser関数を識別するためのenumです。  
```rust
pub enum ErrorKind {
    Tag,
    MapRes,
    MapOpt,
    Alt,
    IsNot,
    // ...
}
```
そのため、とくに自前でエラーを定義しなくても以下のようなテストが書けます。  
```rust
#[test]
fn test() {
    assert_eq!(
        nom::character::complete::alpha1("1"),
        Err(nom::Err::Error(nom::error::Error::new("1", nom::error::ErrorKind::Alpha))),
    );
}

```

また、`IResult`は`Finish::finish()`を実装しており、通常の`Result`型にも変換できます。(ただし、`Err::Incomplete`の場合panicするので注意)

## `nom::error`

### `Error<I>`

```rust
pub struct Error<I> {
    pub input: I,
    pub code: ErrorKind,
}
```

ユーザがとくにエラー型を指定しない場合に利用される型です。  
エラー発生時のinputとparser関数の識別子だけを保持しています。  
ただし、nomのparserは`Error`に直接依存はしておらず、`ParseError`等のtraitを実装すれば他のエラーも使えます。

### `ParseError<I>`

```rust
pub trait ParseError<I>: Sized {
    fn from_error_kind(input: I, kind: ErrorKind) -> Self;
    fn append(input: I, kind: ErrorKind, other: Self) -> Self;
    // ...
}
```

nomのparserで戻り値のエラーのtrait boundとして利用されます。  
`Error`, `VerboseError`には実装されているので、nomが提供するエラー型を利用する場合は特に意識する必要はないですが  
nomのparserをwrapしつつも、エラーをgenericにしておきたい場合はtrait boundにでてきます。

```rust
use nom::error::ParseError;
use nom::IResult;

fn alpha<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    nom::character::complete::alpha1(i)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_alpha() {
        use nom::error::{Error, ErrorKind, VerboseError, VerboseErrorKind};
        assert_eq!(
            alpha::<()>("123"),
            Err(nom::Err::Error(())),
        );
        assert_eq!(
            alpha::<Error<&'_ str>>("123"),
            Err(nom::Err::Error(Error::new("123", ErrorKind::Alpha))),
        );
        assert_eq!(
            alpha::<VerboseError<&'_ str>>("123"),
            Err(nom::Err::Error(VerboseError {
                errors: vec![(
                    "123", VerboseErrorKind::Nom(ErrorKind::Alpha),
                )]
            }))
        )
    }
}
```

このように呼び出し側でエラー型を渡すことで、エラーの詳細度を制御できます。

## nomのmodule

nomが提供している機能は役割ごとにsub moduleに分割されています。概ね各moduleは以下のような役割があります。

* `nom::branch` 複数のparserの分岐を扱う。 `nom::branch::alt`はどれかひとつでも成功したら成功。

* `nom::{character,bytes}::{streaming,complete}`: `alpha1`, `space0`, `digit1`等の基本となるデータ構造用のparser。

* `nom::combinator` `map`,`map_res`, `opt`, `verify`といった、parser + Closureでparserを作るための処理。

* `nom::multi` parserを複数回適用する。loopの抽象化。

* `nom::number::complete` 数値用

* `nom::sequence` finite sequences of inputをparseする。tupleはparserのtupleをうけとって、outputのtupleを返す。

* `many{0,1,_m_n}`があって、それぞれ、0回を許容, 1回以上、m回以上n回以下でmatchする。


## `sequence`

parserを順番に適用していくパターンを表現するための機能を提供するモジュール。

### `preceded`, `terminated`, `delimited`

parseしたいデータ構造の前後に特定の記号があるパターンをサポートするための機能が用意されています。  
先頭だけにmatchさせる場合は、`preceded`, 末尾にmatchさせる場合は`delimited`, 前後にmatchさせる場合は`delimited`を利用します。  
いずれも、matchした場合はparse結果からは捨てられて値が返ってきます。

```rust
preceded(tag("@"), parse_str);
terminated(parse_str, tag(";"));
delimited(tag("{"), parse_key_values, tag("}"))
```

## `branch`

### `alt`

複数のparserを第1引数から順番に適用して、最初にmatchした結果を返すparserを生成します。  
次のparserをtryするかは、parserが`nom::Err::Error(_)`を返した場合なので、後続のparserを呼び出したくない場合は、`combinator::cut()`でwrapする。

```rust
pub trait Alt<I, O, E> {
  /// Tests each parser in the tuple and returns the result of the first one that succeeds
  fn choice(&mut self, input: I) -> IResult<I, O, E>;
}

pub fn alt<I: Clone, O, E: ParseError<I>, List: Alt<I, O, E>>(
  mut l: List,
) -> impl FnMut(I) -> IResult<I, O, E> {
  move |i: I| l.choice(i)
}
```
のように定義されており、各tupleに`Alt::choice()`を実装することで実現されている。  
現在の実装では21個のparserを指定できるようになっている。それ以降はaltをnestさせる。  
`(A,B)`, `(A,B,C)`, `(A,B,C,D)`, `(A,B,C,..., U)`へのimplはmacroでなされており、概要としては以下のにようになっていた。

```rust
mod alt_handson {
    use nom::IResult;
    use nom::error::{ParseError, Error, ErrorKind};
    use nom::Parser;

    pub trait MyAlt<I, O, E> {
        /// Tests each parser in the tuple and returns the result of the first one that succeeds
        fn choice(&mut self, input: I) -> IResult<I, O, E>;
    }

    macro_rules! alt_trait(
        ($first:ident $second:ident $($id: ident)+) => (
            alt_trait!(__impl $first $second; $($id)+);
        );
        (__impl $($current:ident)*; $head:ident $($id: ident)+) => (
            alt_trait_impl!($($current)*);

            alt_trait!(__impl $($current)* $head; $($id)+);
        );
        (__impl $($current:ident)*; $head:ident) => (
            alt_trait_impl!($($current)*);
            alt_trait_impl!($($current)* $head);
        );
    );

    macro_rules! alt_trait_impl(
        ($($id:ident)+) => (
            impl<
                Input: Clone, Output, Error: ParseError<Input>,
                $($id: Parser<Input, Output, Error>),+
            > MyAlt<Input, Output, Error> for ( $($id),+ ) {

                fn choice(&mut self, input: Input) -> IResult<Input, Output, Error> {
                    match self.0.parse(input.clone()) {
                        Err(nom::Err::Error(e)) => alt_trait_inner!(1, self, input, e, $($id)+),
                        res => res,
                    }
                }
            }
        );
    );

    macro_rules! alt_trait_inner(
        ($it:tt, $self:expr, $input:expr, $err:expr, $head:ident $($id:ident)+) => (
            match $self.$it.parse($input.clone()) {
                Err(nom::Err::Error(e)) => {
                    let err = $err.or(e);
                    succ!($it, alt_trait_inner!($self,$input, err, $($id)+))
                }
                res => res,
            }
        );
        ($it:tt, $self:expr, $input:expr, $err:expr, $head:ident) => (
            Err(nom::Err::Error(Error::append($input, ErrorKind::Alt, $err)))
        );
    );

    macro_rules! succ (
  (0, $submac:ident ! ($($rest:tt)*)) => ($submac!(1, $($rest)*));
  (1, $submac:ident ! ($($rest:tt)*)) => ($submac!(2, $($rest)*));
  (2, $submac:ident ! ($($rest:tt)*)) => ($submac!(3, $($rest)*));
);

alt_trait!(A B C);
```

これを`cargo expand`してみると以下のようなコードが生成されていることがわかる。

```rust
mod alt_handson {
    use nom::IResult;
    use nom::error::{ParseError, Error, ErrorKind};
    use nom::Parser;
    pub trait MyAlt<I, O, E> {
        /// Tests each parser in the tuple and returns the result of the first one that succeeds
        fn choice(&mut self, input: I) -> IResult<I, O, E>;
    }
    impl<
            Input: Clone,
            Output,
            Error: ParseError<Input>,
            A: Parser<Input, Output, Error>,
            B: Parser<Input, Output, Error>,
        > MyAlt<Input, Output, Error> for (A, B)
    {
        fn choice(&mut self, input: Input) -> IResult<Input, Output, Error> {
            match self.0.parse(input.clone()) {
                Err(nom::Err::Error(e)) => match self.1.parse(input.clone()) {
                    Err(nom::Err::Error(e)) => {
                        let err = e.or(e);
                        Err(nom::Err::Error(Error::append(input, ErrorKind::Alt, err)))
                    }
                    res => res,
                },
                res => res,
            }
        }
    }
    impl<
            Input: Clone,
            Output,
            Error: ParseError<Input>,
            A: Parser<Input, Output, Error>,
            B: Parser<Input, Output, Error>,
            C: Parser<Input, Output, Error>,
        > MyAlt<Input, Output, Error> for (A, B, C)
    {
        fn choice(&mut self, input: Input) -> IResult<Input, Output, Error> {
            match self.0.parse(input.clone()) {
                Err(nom::Err::Error(e)) => match self.1.parse(input.clone()) {
                    Err(nom::Err::Error(e)) => {
                        let err = e.or(e);
                        match self.2.parse(input.clone()) {
                            Err(nom::Err::Error(e)) => {
                                let err = err.or(e);
                                Err(nom::Err::Error(Error::append(input, ErrorKind::Alt, err)))
                            }
                            res => res,
                        }
                    }
                    res => res,
                },
                res => res,
            }
        }
    }
}
```

徹底してruntimeのコストを避けるような工夫がされていると思いました。

### `combinator`

#### `map_opt`

parse結果を`Option`を返す関数に渡して新しいparserを作れます。(`map_opt::<>`の型は普通は推測される)

```rust
    fn test_map_opt() {
        assert_eq!(
            nom::combinator::map_opt::<_, _,_,nom::error::Error<&str>,_, _>(
                nom::character::complete::digit1,
                |s: &str| s.parse::<u8>().ok(),
            )("123u"),
            Ok(("u", 123)),
        )
    }
```

#### `verify`

```rust
pub fn verify<I: Clone, O1, O2, E: ParseError<I>, F, G>(
    first: F, 
    second: G
) -> impl FnMut(I) -> IResult<I, O1, E> 
where
    F: Parser<I, O1, E>,
    G: Fn(&O2) -> bool,
    O1: Borrow<O2>,
    O2: ?Sized, 
```

`verify`[^verify]はmatchしたparserのoutputをverify用の関数にかませて,trueが返ったらmatchするparserを作ります。
既存のparserに独自の制約をいれたいときに便利そうです。  
verify用の関数の引数が`O1: AsRef<O1>`ではなく`O1: Borrow<O2>`と`Borrow`で表現されているのは、verify関数の結果は`String`と`&str`で整合性あることを期待していることを表しているんでしょうか。

```rust
let not_quote_slash = is_not("\"\\");
verify(not_quote_slash, |s: &str| !s.is_empty())(input)
```

### `multi`

#### `fold_many`

`Iterator::fold`の機能を提供してくれます。parserのoutputでデータを更新したいときに利用できます。  
[公式のexample](https://github.com/Geal/nom/blob/38bb94e7bc45c2b4ef0c473e0e5c03ab134cdff3/examples/string.rs#L141) がわかりやすかったです。

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum StringFragment<'a> {
  Literal(&'a str),
  EscapedChar(char),
  EscapedWS,
}

fn parse_fragment<'a, E>(input: &'a str) -> IResult<&'a str, StringFragment<'a>, E>
    where
        E: ParseError<&'a str> + FromExternalError<&'a str, std::num::ParseIntError>,
{
    alt((
        map(parse_literal, StringFragment::Literal),
        map(parse_escaped_char, StringFragment::EscapedChar),
        value(StringFragment::EscapedWS, parse_escaped_whitespace),
    ))(input)
}

fn parse_string<'a, E>(input: &'a str) -> IResult<&'a str, String, E>
    where
        E: ParseError<&'a str> + FromExternalError<&'a str, std::num::ParseIntError>,
{
    let build_string = fold_many0(
        parse_fragment,
        String::new(),
        |mut string, fragment| {
            match fragment {
                StringFragment::Literal(s) => string.push_str(s),
                StringFragment::EscapedChar(c) => string.push(c),
                StringFragment::EscapedWS => {}
            }
            string
        },
    );

    delimited(char('"'), build_string, char('"'))(input)
}

```

## example

ここからはいくつか具体例をみていきます。

### `cargo install --list`のparse

`cargo install --list`を実行するとえられる出力をparseしてみます。  
[https://github.com/ymgyt/localenv/blob/74847c0789dd91d86798b7ba5b16192bceb55ac8/src/operation/installer/cargo.rs#L66](https://github.com/ymgyt/localenv/blob/74847c0789dd91d86798b7ba5b16192bceb55ac8/src/operation/installer/cargo.rs#L66)
実行すると以下のような出力をえました。

```
alacritty v0.7.2 (/Users/ymgyt/rs/alacritty/alacritty):
    alacritty
bat v0.17.1:
    bat
cargo-add v0.2.0:
    cargo-add
cargo-expand v1.0.6:
    cargo-expand
cargo-generate v0.6.1:
    cargo-generate
cargo-hf2 v0.3.1:
    cargo-hf2
cargo-make v0.32.12:
    cargo-make
    makers
// ... 
```

package名、version, optionalなlocalのpath, binaryといった情報があるようです。

```rust
use nom::bytes::complete;
use nom::character;
use nom::combinator;
use nom::multi;
use nom::sequence;
use nom::IResult;
use std::path::PathBuf;

#[derive(Debug, PartialEq, Clone)]
pub struct Package {
    name: String,
    bin: String,
    version: semver::Version,
    local_path: Option<PathBuf>,
}
```

`cargo install --list`の出力から`Vec<Package>`をparseすることをを目指します。  
まずは、`alacritty v0.7.2 (/Users/ymgyt/rs/alacritty/alacritty)`をparseしてみます。

```rust
/// consume separator spaces.
fn space(i: &str) -> IResult<&str, ()> {
    complete::take_while(|c: char| c.is_whitespace())(i).map(|(remain, _)| (remain, ()))
}

/// parse cargo package name.
fn package_name(i: &str) -> IResult<&str, &str> {
    complete::take_while(|c: char| c.is_alphanumeric() || c == '-' || c == '_')(i)
}

/// parse cargo package semantic version.
fn version(i: &str) -> IResult<&str, semver::Version> {
    combinator::map_res(
        sequence::preceded(
            complete::tag("v"),
            complete::take_while(|c| ('0'..='9').contains(&c) || c == '.'),
        ),
        semver::Version::parse,
    )(i)
}

/// parse local path enclosed in parentheses.
fn local_path(i: &str) -> IResult<&str, PathBuf> {
    combinator::map(
        sequence::delimited(
            character::complete::char('('),
            complete::take_until(")"),
            character::complete::char(')'),
        ),
        |path| PathBuf::from(path),
    )(i)
}

```

```rust
#[test]
fn test_package_name() {
    assert_eq!(package_name("alacritty"), Ok(("", "alacritty")));
}
#[test]
fn test_version() {
    assert_eq!(version("v0.1.2"), Ok(("", semver::Version::new(0, 1, 2))));
    assert_eq!(
        version("xxx"),
        Err(NomErr::Error(nom::error::Error::new(
            "xxx",
            nom::error::ErrorKind::Tag
        )))
    );
}
#[test]
fn test_local_path() {
    assert_eq!(
        local_path("(/Users/ymgyt/hello/rust)"),
        Ok(("", PathBuf::from("/Users/ymgyt/hello/rust")))
    );
    assert_eq!(
        local_path("(/Users/ymgyt/hello/rust"),
        Err(NomErr::Error(nom::error::Error::new(
            "/Users/ymgyt/hello/rust",
            nom::error::ErrorKind::TakeUntil
        )))
    );
}
```
package名、version, local path用のparserを定義したのでこれを組み合わせます。

```rust
/// parse first line in packages list entry.
fn package_line(i: &str) -> IResult<&str, Package> {
    combinator::map(
        sequence::terminated(
            sequence::tuple((
                package_name,
                space,
                version,
                combinator::opt(sequence::preceded(space, local_path)),
            )),
            complete::tag(":"),
        ),
        |(name, _, v, local_path)| Package {
            name: name.to_owned(),
            version: v,
            local_path,
            bin: "".to_owned(),
        },
    )(i)
}

#[test]
fn test_package_line() {
    assert_eq!(package_line("bat v0.17.1:"), Ok(("", pkg_bat())));
    assert_eq!(
        package_line("bat v0.17.1 (/Users/ymgyt/hello/rust):"),
        Ok(("", pkg_bat().with_local_path("/Users/ymgyt/hello/rust"))),
    );
}

fn pkg_bat() -> Package {
    Package {
        name: "bat".to_owned(),
        version: semver::Version::new(0, 17, 1),
        local_path: None,
        bin: "".to_owned(),
    }
}
```

次にinstallされているbinaryが1以上続くのでparseできるようにします。

```rust
/// parse package binary line.
fn bin_line(i: &str) -> IResult<&str, String> {
    combinator::map(
        sequence::tuple((
            complete::take_while1(|c: char| c.is_whitespace()),
            package_name, // define bin_name if needed.
        )),
        |(_, bin)| String::from(bin),
    )(i)
}

/// parse package binary lines.
fn bin_lines(i: &str) -> IResult<&str, Vec<String>> {
    multi::separated_list1(character::complete::line_ending, bin_line)(i)
}

#[test]
fn test_bin_line() {
    assert_eq!(bin_line("    nu"), Ok(("", "nu".to_owned())));
    assert_eq!(
        bin_line("nu"),
        Err(NomErr::Error(nom::error::Error::new(
            "nu",
            nom::error::ErrorKind::TakeWhile1
        )))
    );
}
#[test]
fn test_bin_lines() {
    assert_eq!(
        bin_lines("    nu_1\n    nu_2\nripgrep"),
        Ok(("\nripgrep", vec!["nu_1".into(), "nu_2".into()]))
    );
}
```

先頭にspaceがない場合は次のpackageの開始なので、`bin_line`では`take_while1`を利用して必ずwhitespaceがあることを要求しています。  
改行コードはnomに定義されている`character::complete::line_endoing`を利用すると`\n`と`\r\n`に両対応できます。  
1packageをparseできるようになったのでこれを組み合わせて最終的なparserにします。

```rust
impl Package {
    fn with_bin<T: Into<String>>(mut self, bin: T) -> Self {
        self.bin = bin.into();
        self
    }
}

/// parse package entry.
fn package_entry(i: &str) -> IResult<&str, Package> {
    combinator::map(sequence::tuple((package_line, bin_lines)), |(pkg, bins)| {
        pkg.with_bin(bins.first().expect("at least one binary"))
    })(i)
}

/// parse cargo install --list output.
pub(super) fn package_list(i: &str) -> IResult<&str, Vec<Package>> {
    multi::many1(sequence::preceded(
        combinator::opt(character::complete::newline),
        package_entry,
    ))(i)
}

#[test]
fn parse_install_list() {
    let s = r"alacritty v0.7.2 (/Users/ymgyt/rs/alacritty/alacritty):
    alacritty
bat v0.17.1:
    bat
cargo-make v0.32.12:
    cargo-make
    makers
nu v0.29.1 (/Users/ymgyt/rs/nushell):
    nu
    nu_plugin_core_fetch
    nu_plugin_core_inc
    nu_plugin_core_match
    nu_plugin_core_post
    nu_plugin_core_ps
    nu_plugin_core_sys
    nu_plugin_core_textview
    nu_plugin_extra_binaryview
    nu_plugin_extra_chart_bar
    nu_plugin_extra_chart_line
    nu_plugin_extra_from_bson
    nu_plugin_extra_from_sqlite
    nu_plugin_extra_s3
    nu_plugin_extra_selector
    nu_plugin_extra_start
    nu_plugin_extra_to_bson
    nu_plugin_extra_to_sqlite
    nu_plugin_extra_tree
    nu_plugin_extra_xpath
ripgrep v12.1.1:
    rg
";
    let want = vec![
        Package {
            name: "alacritty".to_owned(),
            bin: "alacritty".to_owned(),
            version: semver::Version::new(0, 7, 2),
            local_path: Some(PathBuf::from("/Users/ymgyt/rs/alacritty/alacritty")),
        },
        Package {
            name: "bat".to_owned(),
            bin: "bat".to_owned(),
            version: semver::Version::new(0, 17, 1),
            local_path: None,
        },
        Package {
            name: "cargo-make".to_owned(),
            bin: "cargo-make".to_owned(),
            version: semver::Version::new(0, 32, 12),
            local_path: None,
        },
        Package {
            name: "nu".to_owned(),
            bin: "nu".to_owned(),
            version: semver::Version::new(0, 29, 1),
            local_path: Some(PathBuf::from("/Users/ymgyt/rs/nushell")),
        },
        Package {
            name: "ripgrep".to_owned(),
            bin: "rg".to_owned(),
            version: semver::Version::new(12, 1, 1),
            local_path: None,
        },
    ];

    assert_eq!(package_list(s), Ok(("\n", want)));
}
```

無事parseできました。小さいparserから作っていきそれをだんだんと組み合わせていくことで最終的なparserをつくれることがわかりました。  各処理が関数に切り出されているのでtestを書きやすいのもうれしいですね。


### json

jsonのparse処理を見ていきます。[公式のexample](https://github.com/Geal/nom/blob/master/examples/json.rs) を参考にしております。

```rust
use nom::{
    branch::alt,
    bytes::complete::{escaped, tag, take_while},
    character::complete::{alphanumeric1, char, one_of},
    combinator::{cut, map, opt, value},
    error::ParseError,
    multi::separated_list0,
    number::complete::double,
    sequence::{delimited, preceded, separated_pair, terminated},
    IResult,
};
use std::{array::IntoIter, collections::HashMap, iter::FromIterator};

#[derive(Debug, PartialEq)]
pub enum JsonValue {
    Str(String),
    Boolean(bool),
    Num(f64),
    Array(Vec<JsonValue>),
    Object(HashMap<String, JsonValue>),
}

fn sp<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    let chars = " \t\r\n";
    take_while(move |c: char| chars.contains(c))(i)
}

fn parse_str<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    escaped(alphanumeric1, '\\', one_of("\"n\\"))(i)
}

fn boolean<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, bool, E> {
    let parse_true = value(true, tag("true"));
    let parse_false = value(false, tag("false"));

    alt((parse_true, parse_false))(i)
}

fn string<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    preceded(char('\"'), cut(terminated(parse_str, char('\"'))))(i)
}

fn array<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, Vec<JsonValue>, E> {
    preceded(
        char('['),
        cut(terminated(
            separated_list0(preceded(sp, char(',')), json_value),
            preceded(sp, char(']')),
        )),
    )(i)
}

fn key_value<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, (&'a str, JsonValue), E> {
    separated_pair(
        preceded(sp, string),
        cut(preceded(sp, char(':'))),
        json_value,
    )(i)
}

fn hash<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, HashMap<String, JsonValue>, E> {
    preceded(
        char('{'),
        cut(terminated(
            map(
                separated_list0(preceded(sp, char(',')), key_value),
                |tuple_vec| {
                    tuple_vec
                        .into_iter()
                        .map(|(k, v)| (String::from(k), v))
                        .collect()
                },
            ),
            preceded(sp, char('}')),
        )),
    )(i)
}

fn json_value<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, JsonValue, E> {
    preceded(
        sp,
        alt((
            map(hash, JsonValue::Object),
            map(array, JsonValue::Array),
            map(string, |s| JsonValue::Str(String::from(s))),
            map(double, JsonValue::Num),
            map(boolean, JsonValue::Boolean),
        )),
    )(i)
}

fn root<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, JsonValue, E> {
    delimited(
        sp,
        alt((map(hash, JsonValue::Object), map(array, JsonValue::Array))),
        opt(sp),
    )(i)
}

#[cfg(test)]
#[macro_use]
mod tests {
    use super::*;

    // https://stackoverflow.com/questions/27582739/how-do-i-create-a-hashmap-literal
    macro_rules! hashmap {
        ($($k:expr => $v:expr),* $(,)?) => {
            std::iter::Iterator::collect(std::array::IntoIter::new([$(($k, $v),)*]))
        };
    }

    #[test]
    fn parse_json() {
        let data = vec![
            (
                r#"{"name": "ymgyt"}"#,
                "",
                JsonValue::Object(hashmap!(
                    String::from("name") => JsonValue::Str(String::from("ymgyt")),
                )),
            ),
            (
                r#" {  "name"   : "ymgyt"   }  "#,
                "",
                JsonValue::Object(hashmap!(
                    String::from("name") => JsonValue::Str(String::from("ymgyt")),
                )),
            ),
            (r#"{"package" : {"name": "nom", "features": ["alloc", "std"]}, "release": true, "version": 1.2 }"#,
             "",
             JsonValue::Object(hashmap!(
                    String::from("package") => JsonValue::Object(hashmap!(
                        String::from("name") => JsonValue::Str(String::from("nom")),
                        String::from("features") => JsonValue::Array(vec![JsonValue::Str(String::from("alloc")), JsonValue::Str(String::from("std"))]),
                    )),
                    String::from("release") => JsonValue::Boolean(true),
                    String::from("version") => JsonValue::Num(1.2),
                )),
            )
        ];

        for tc in data.into_iter() {
            assert_eq!(root::<()>(tc.0), Ok((tc.1, tc.2)), );
        }
    }
}
```

primitiveのparse処理から書いていって、key_value -> json objectとボトムアップで書かれていて非常に読みやすいと思いました。

```rust
alt((
    map(hash, JsonValue::Object),
    map(array, JsonValue::Array),
    map(string, |s| JsonValue::Str(String::from(s))),
    map(double, JsonValue::Num),
    map(boolean, JsonValue::Boolean),
)),
```
`alt`はbranchの各parserが同じ型を返すことを要求するので、`JsonValue`のenumを定義して、mapするやり方は非常に参考になります。


## 参考にさせていただいたドキュメント

* [nom tutorial](https://github.com/benkay86/nom-tutorial)  
  `mount`コマンドの出力をparseするnomのtutorial。
* [Parsing in Rust with nom](https://blog.logrocket.com/parsing-in-rust-with-nom/)  
  uriをparseする処理を実装しながらnomの解説をしてくれています。contextの使い方も参考になりました。
* [Learning Parser Combinators With Rust](https://bodil.lol/parser-combinators/)  
  こちらはnomについてではなくそもそもparser combinatorとはなにかについて解説してくれています。簡易的なxml parserを作ります。
* [公式](https://github.com/Geal/nom/tree/master/doc)  
  * [parser一覧](https://github.com/Geal/nom/blob/master/doc/choosing_a_combinator.md)  
    parser一覧がmoduleごとに整理されているのでほしいものがあるかを探すのに便利です。
  * [error management](https://github.com/Geal/nom/blob/master/doc/error_management.md)  
    nomのErrorについて。user定義型のErrorの使い方についても。
  * [recipe](https://github.com/Geal/nom/blob/master/doc/nom_recipes.md)
    nomのrecipe。docのexampleより複雑なので参考になりました。
  * [examples](https://github.com/Geal/nom/tree/master/examples)  
    json, S expression, escaped strings等のexampleがコメントつきでのっています。
* [Rust: nom によるパーサー実装](https://hazm.at/mox/lang/rust/nom/index.html)  
  `v5`についての解説。`v6`になって、言及されているエラーの報告手段が改善されたんだなと思いました。
  
## まとめ

* nomを利用するとボトムアップでparse処理がかける。
* parse時にどこまでエラーの詳細が欲しいかはgenericsでコントロールできる。
* allocationもfeatureで制御できるので、`no_std`環境でもつかえそう。
* `complete`と`streming`が用意されているので、networkからのデータのparseにも利用できる。

[^nom]: https://github.com/Geal/nom  
[^IResult]: https://docs.rs/nom/6.1.2/nom/type.IResult.html  
[^Err]: https://docs.rs/nom/6.1.2/nom/enum.Err.html  
[^Error]: https://docs.rs/nom/6.1.2/nom/error/struct.Error.html  
[^ErrorKind]: https://docs.rs/nom/6.1.2/nom/error/enum.ErrorKind.html  
[^verify]: https://docs.rs/nom/6.1.2/nom/combinator/fn.verify.html  

