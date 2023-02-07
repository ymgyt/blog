+++
title = "⚙️ proconio::input!の仕組みを追ってみる"
slug = "proconio_input_macro"
date = "2021-06-27"
draft = false
[taxonomies]
tags = ["rust"]
+++

この記事ではRustの[proconio::input!](https://github.com/statiolake/proconio-rs/tree/master/proconio) macroについて書きます。  
[document](https://docs.rs/proconio/0.4.3/proconio/index.html)や[test case](https://github.com/statiolake/proconio-rs/blob/p-v0.4.3/proconio/src/lib.rs#L690)で想定されているユースケースをどうやって実現しているのかを追っていきます。
versionは記事を書いている時点で最新の`p-v0.4.3` を対象にしています。

## `proconio::input!` とは

`proconio` とは以下の[README](https://github.com/statiolake/proconio-rs/blob/p-v0.4.3/proconio/README.md) にあるように競技プログラミングで利用されることを意図したIO libraryです。 
> Easy IO library for competitive programming.  
> proconio provides an easy way to read values from stdin (or other source). The main is input! macro.

`input!` は出題としてstdinからあたえられる入力を読み取る処理を簡潔に記述できることを意図したmacroです。  
atcoderのRustの実行環境(judge環境?)に有志の方々が準備してくださっており、利用されている方もおられるのではないでしょうか。  
https://github.com/rust-lang-ja/atcoder-rust-resources/wiki/2020-Update

例えば、出題として、m * nの行列が以下の形式であたえられるときの処理はこう書けます。

こんなstdinが与えられるとして
```text
3
3
1 2 3
4 5 6
7 8 9
```

```rust
fn main() {
    input! {
        n: u8,
        m: u8,
        a: [[i32; m]; n],
    }

    println!("n: {}, m: {}, a: {:?}", n,m,a);
    // n: 3, m: 3, a: [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
}

```

`input!` に与えられるデータの型とbindしたい変数名を書いておくと、stdinからのread, 型変換までを実行してくれます。  
stdinからほしいデータ構造をどう読み取るかは、問題の回答とはまた別の話ともいえるので、この処理を簡潔に記述できる手段があるのはうれしいのではないでしょうか。  
ただし、macroなので人によっては抵抗(とかモヤモヤ)をもたれることもあるかもしれません。
ということでmacroの内容を理解して、気持ちよく使えるようになるのが目標です。

## `proconio::input!` の仕組み

できるだけ単純な処理から追っていきたいので、以下ではミニマムの`input!` macroを作っていきます。[source](https://github.com/ymgyt/proconio-handson)  
実際の処理は外部から利用しやすいように書かれていますが、今回は必要な型を1 file(module)に展開します。

まずは一番シンプルな以下の処理がどう実現されているのかを追っていきます。  

```rust
input!{
    n: u8,
}
```
といいたいところですが、毎回stdinから入力を渡して動作確認するのは面倒ですし、テストも書きづらいです。  
`input!`には入力を変数経由で渡せる方法も用意されているのでそちらを利用します。  
ということで最初に見ていくのはこちら

```rust
fn main() {
    let source = OnceSource::from("10\n");

    input! {
            from source,
            a: u8,
    }

    assert_eq!(a, 10);
}
```
最初の入力に `from <入力変数名>` とすることでこれを入力として扱ってくれます。 `OnceSource`については後述。  
さっそく`input!` macroを見ていきましょう。

```rust
macro_rules! input {
    // terminator
    (@from [$source:expr] @rest) => {};

    (@from [$source:expr] @rest $($rest:tt)*) => {
        input! {
            @from [$source]
            @mut []
            @rest $($rest)*
        }
    };

    (@from [$source:expr] @mut [$($mut:tt)?] @rest $var:tt: $($rest:tt)*) => {
        input! {
            @from [$source]
            @mut [$($mut)*]
            @var $var
            @kind []
            @rest $($rest)*
        }
    };
    
    (@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest) => {
        let $($mut)* $var = read_value!(@source [$source] @kind [$($kind)*]);
    };
    (@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest, $($rest:tt)*) => {
        input!(@from [$source] @mut [$($mut)*] @var $var @kind [$($kind)*] @rest);
        input!(@from [$source] @rest $($rest)*);
    };
    (@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest $tt:tt $($rest:tt)*) => {
        input!(@from [$source] @mut [$($mut)*] @var $var @kind [$($kind)* $tt] @rest $($rest)*);
    };
    
    (from $source:expr, $($rest:tt)*) => {
       let mut s = $source;
       input! {
           @from [&mut s]
           @rest $($rest)*
       }
    };
}
```
実際にはもう少しarmがあるのですが、今回のケースを扱うにはこれで十分です。  
macroについてこの記事で関連する範囲で簡単に補足します。

* `input!{ ... }` macroに渡した内容がtoken列として、渡される(正確にはtoken tree 列)
* 上から各armにマッチするかどうか判定されて、マッチしたらその内容が実行される。(ので、armの順番に意味がある)
* `$name:type` と書くと、typeに応じたtokenがマッチして、`=>` の内側でnameで参照できる
* `@from` の先頭の`@`は特別な記号ではなく、リテラルとしてマッチする。(これがあるとマッチする範囲を指定しやすいのかなと思っている)
* `$rest:tt` の`tt`はどのtokenにもマッチする
* `$(rest:tt)*` こう書くと、すべてのtoken列にマッチできるので、残り全部を後続の処理にそのまま渡せる(tail的な感じ)
* カッコ( `[]`, `()`)でくくられているとそれがひとつの`tt`としてマッチする。(`$v:tt` に `[i32; 3]` がマッチする)

ということで
```rust
input!{
    from source,
    a: u8,
}
```
がどう展開されていくか見ていきます。結論を先にいうと以下のように展開されます。(`cargo expand` しました)
```rust
let source = OnceSource::from("10\n");
let mut s = source;
let a = <u8 as Readable>::read(&mut s);
```
まず、`input!`の最初に`from source`を渡しているので` (from $source:expr, $($rest:tt)*)`にマッチします。そこで以下のように展開されます。
```rust
let mut s = source;
input! {
  @from [&mut s]
  @rest a : u8,
}
```
`@from`と`@rest`を付け加えてさらに`input!`を呼び出します。  
次に、`(@from [$source:expr] @rest $($rest:tt)*)`にマッチして以下のように展開されます。
```rust
input! {
    @from [&mut s]
    @mut []
    @rest a : u8,
}
```
`@mut`を付け加えて、`input!`を呼び出します。  
これが `(@from [$source:expr] @mut [$($mut:tt)?] @rest $var:tt: $($rest:tt)*)`にマッチします。  
`@mut []` のように`@mut`にはなにも渡していませんが、 `@mut [$($mut:tt)?]` とrepeatが`?`になっているのでマッチします。  
さらにこのarmには、`@rest $var:tt: $($rest:tt)*` と書かれていて、変数名として渡した`a` が`$var`にマッチしています。`$var:tt`ではなく`$var:tt:`であることに注意してください。(最後にコロンがある)。このコロンのリテラルによって、`$rest` には変数`a`の型が先頭にくるように調整されています。このarmではさらに以下の呼び出しに展開されます。
```rust
input! {
    @from [&mut s]
    @mut []
    @var a
    @kind []
    @rest u8,
}
```

`@kind`が付与された呼び出しはどのarmにマッチするでしょうか。`@kind`が書かれているarmは３つあります。
```rust
(@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest) => {}                     // (1)
(@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest, $($rest:tt)*) => {}       // (2)
(@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest $tt:tt $($rest:tt)*) => {} // (3)
```
上から(1),(2),(3)とします。今回は`@rest u8,`としてよびだしているので、`@rest`で終わっている(1)にはマッチしません。  
(2)は `@rest,` と先頭が`,`(カンマ)になっているのでマッチしません。ということで、(3)にマッチします。  
ということで、(3)は以下のように展開されます。
```rust
input ! (@ from [&mut s] @ mut [] @ var a @ kind [u8] @ rest,)
```
いよいよ変数`a`が`kind [u8]`でparseされそうですね。さらに`@ rest,`となっているので、今度はさきほどの(2)にマッチします。
(2)の中で以下のように展開され、(1)にマッチします。
```rust
input ! (@ from [&mut s] @ mut [] @ var a @ kind [u8] @ rest) ; 
```
あらためて(1)の定義はこうなっていて
```rust
(@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest) => {
    let $($mut)* $var = read_value!(@source [$source] @kind [$($kind)*]);
};
```
こんなふうに展開されます
```rust
(@ from [&mut s] @ mut [] @ var a @ kind [u8] @ rest ) => {
    let a = read_value ! (@ source [&mut s] @ kind [u8]) ;
}
```
まだ、`read_value!`についてはふれていませんが、このmacroに入力の`source`と型`u8`を渡した結果が変数`a`にbindされました。  
`read_value!`にはいる前に、(2)では`input!`を2回呼び出しています。
```rust
// (2)
(@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest, $($rest:tt)*) => {
    input!(@from [$source] @mut [$($mut)*] @var $var @kind [$($kind)*] @rest); // <- read_value!
    input!(@from [$source] @rest $($rest)*);
};
```
1回目の`input!`は`read_value!`に展開され、残った処理はあらためて、`@from [$source] @rest $($rest)*`の形で呼ばれます。  
ただし今回渡している、`a: u8,`はすでに処理されているので、 ` $($rest)*`は空に展開されます。それがarmの先頭に定義されている  
`(@from [$source:expr] @rest) => {};` にマッチされ、`input!`呼び出しの展開が終了します。  
ということで、`read_value ! (@ source [&mut s] @ kind [u8])`この処理が入力から`u8`型を呼んで返せば、`input!`が完了したことになります。

`read_value!`で`input!`呼び出し側から渡される任意の型の読み取り処理をおこないます。今回は `a: u8,`なのでそれを処理するためだけなら以下のarmのみで対応できます。
```rust
macro_rules! read_value {
    (@source [$source:expr] @kind [$kind:ty]) => {
        <$kind as Readable>::read($source)
    };
}
```
ということで、`$kind:ty`で渡される型が`Readable` traitを実装していることを前提にして、`Readable::read()`を呼び出しています。  `Readable`は以下のように定義されています。
```rust
pub trait Readable {
    type Output;

    fn read<R: std::io::BufRead, S: Source<R>>(source: &mut S) -> Self::Output;
}
```
`Source`から自身を生成できる型が`Readable`という感じでしょうか。ということで`Source`の定義ですが以下のようになっています。
```rust
pub trait Source<R: std::io::BufRead> {
    /// Gets a whitespace-splitted next token.
    fn next_token(&mut self) -> Option<&str>;

    /// Check if tokens are empty
    fn is_empty(&mut self) -> bool;

    /// Force gets a whitespace-splitted next token.
    fn next_token_unwrap(&mut self) -> &str {
        self.next_token().expect(concat!(
        "failed to get the next token; ",
        "maybe reader reached an end of input. ",
        "ensure that arguments for `input!` macro is correctly ",
        "specified to match the problem input."
        ))
    }
}
```
今回の例では、`source`として、`OnceSource`を渡していました。`OnceSource`は概ね、入力(stdinだったり、&'static str)をwrapして、データの区切り(atcoderではwhite spaceとnewline)を隠蔽する役割をもっています。

```rust
struct OnceSource<R: std::io::BufRead> {
    tokens: std::iter::Peekable<std::str::SplitWhitespace<'static>>,
    context: Box<str>,
    _read: std::marker::PhantomData<R>,
}

impl<R: std::io::BufRead> OnceSource<R> {
    fn new(mut source: R) -> OnceSource<R> {
        let mut context = String::new();
        source.read_to_string(&mut context)
            .unwrap();

        let context = context.into_boxed_str();

        let mut res = OnceSource {
            context,
            tokens: "".split_whitespace().peekable(),
            _read: PhantomData,
        };

        use std::mem;
        let context: &'static str = unsafe { mem::transmute(&*res.context) };
        res.tokens = context.split_whitespace().peekable();

        res
    }
}

impl<R: std::io::BufRead> Source<R> for OnceSource<R> {
    fn next_token(&mut self) -> Option<&str> {
        self.tokens.next()
    }

    fn is_empty(&mut self) -> bool {
        self.tokens.peek().is_none()
    }
}

impl<'a> From<&'a str> for OnceSource<std::io::BufReader<&'a [u8]>> {
    fn from(s: &'a str) -> OnceSource<std::io::BufReader<&'a [u8]>> {
        OnceSource::new(std::io::BufReader::new(s.as_bytes()))
    }
}
```
入力をheapに確保しつつ、`mem::transmute()`して、`'static`なlifetimeに変換してwhite spaceをdelimiterとしてiteratorを保持している感じでしょうか。  
Sourceがなんとなくわかったので、最後は`u8`の`Readable`実装です。要はstringから自身を生成できればよいので、`str::FromStr`と同じ状況といえます。なので以下のように、`str::FromStr`を実装している型は`Readable`になります。
```rust
impl<T: std::str::FromStr> Readable for T
    where
        T::Err: std::fmt::Debug,
{
    type Output = T;
    fn read<R: std::io::BufRead, S: Source<R>>(source: &mut S) -> T {
        let token = source.next_token_unwrap();
        match token.parse() {
            Ok(v) => v,
            Err(e) => panic!(
                concat!(
                "failed to parse the input `{input}` ",
                "to the value of type `{ty}`: {err:?}; ",
                "ensure that the input format is collectly specified ",
                "and that the input value must handle specified type.",
                ),
                input = token,
                ty = std::any::type_name::<T>(),
                err = e,
            ),
        }
    }
}
```
ここにきて、`input!`が`parse::<u8>().unwrap()` を代わりにに呼んでくれていることがわかりました。  
(余談ですが、`std::any::type_name()`はこういうところで使われるんですね)

ここまででようやく、`input!`の処理を通しで追うことができました。最終的にはこれが
```rust
fn main() {
    let source = OnceSource::from("10\n");
    input! {
            from source,
            a: u8,
    }
}
```
こうなりました。
```rust
fn main() {
    let source = OnceSource::from("10\n");
    let mut s = source;
    let a = <u8 as Readable>::read(&mut s);
}
```
今回は、`u8`でしたが、`str::FromStr`を実装している型は`Readable`なので、他の基本的な型も同じです。  
次は`[i32; 3]`のような配列/sliceをみていきたいのですが、まだ標準入力から読む処理をみていなかったので、その場合のarmを追加しましょう。

### stdinから読む場合

以下のarmを追加するだけです。
```rust
lazy_static::lazy_static! {
    static ref STDIN_SOURCE: std::sync::Mutex<OnceSource<std::io::BufReader<std::io::Stdin>>> =
        std::sync::Mutex::new(OnceSource::new(std::io::BufReader::new(std::io::stdin())));
}

macro_rules! {
    // ... 
    (from $source:expr, $($rest:tt)*) => {
       let mut s = $source;
       input! {
           @from [&mut s]
           @rest $($rest)*
       }
    };
    // このarmを追加
    ($($rest:tt)*) => {
        let mut locked_stdin = STDIN_SOURCE.lock().unwrap();
        input! {
            @from [&mut *locked_stdin]
            @rest $($rest)*
        }
        drop(locked_stdin); // release the lock
    };
}
```
`input!`からsourceをもらうかわりに、`std::io::Stdin`から`OnceSource`を生成して、後続の`input!`に渡しています。以降の処理は`from source`で渡したときと同様です。  
一番上のレイヤーで入力がどこからきたかを吸収していて、非常に参考になります。  
ちなみに実際の処理はもうひとひねりされおりまして、以下のようになっています。
```rust
lazy_static! {
    #[doc(hidden)]
    pub static ref STDIN_SOURCE: Mutex<AutoSource<BufReader<Stdin>>> =
        Mutex::new(AutoSource::new(BufReader::new(io::stdin())));
}
```
https://github.com/statiolake/proconio-rs/blob/a3b10f55c15177ec322ce686f0bd977011593366/proconio/src/lib.rs#L525-L529  
さきほどは、`OnceSource`だった箇所が`AutoSource`になっています。さらに`AutoSource`は以下のようになっています。
```rust
pub mod auto {
    //! Defines `AutoSource`.
    //!
    //! It is `LineSource` for debug build, `OnceSource` for release build.

    #[cfg(debug_assertions)]
    pub use super::line::LineSource as AutoSource;
    #[cfg(not(debug_assertions))]
    pub use super::once::OnceSource as AutoSource;
}
```
https://github.com/statiolake/proconio-rs/blob/a3b10f55c15177ec322ce686f0bd977011593366/proconio/src/source/mod.rs#L63-L72

atcoder上では提出したコードはrelease buildされるはずだったので、結果的に`OnceSource`が実行されることになります。  
さらに、`OnceSource`の生成処理は以下のようになっており、`lazy_static`で一度だけ走る初期化処理時に入力をすべてメモリに保持します。
```rust
impl<R: std::io::BufRead> OnceSource<R> {
    fn new(mut source: R) -> OnceSource<R> {
        let mut context = String::new();
        source.read_to_string(&mut context)
            .unwrap();
        // ...
    }
}
```
なので、`input!` を複数回呼び出しても、読み込み処理が複数回走るわけではなさそうです。

### macroのdebug

ここまでで、一番シンプルなケースで`input!`がどう機能するか見てきました。以降はこの`input!`を拡張しながら他のユースケースにも対応できるようにしていきます。  
ただその前に、macroの展開debugする方法について書いておきます。以降はこのdebugの出力をみながら進めていきます。
```rust
#![feature(trace_macros)]

// ...

fn main() {
    let source = OnceSource::from("10\n-20");
    trace_macros!(true);
    input! {
        from source,
        n: i8,
    }
    trace_macros!(false);

    println!("m: {}", n);
}
```
`#![feature(trace_macros)]`を有効化して、`input!`の前後に`trace_macros!`を追加します。  
`cargo +nightly run` のように`nightly`で実行すると、以下の出力を得ます。

```text
❯ cargo +nightly run
   Compiling proconio-handson v0.1.0 (/Users/ymgyt/rs/proconio-handson)
note: trace_macro
   --> src/main.rs:299:5
    |
299 | /     input! {
300 | |         from source,
301 | |         n: i8,
302 | |     }
    | |_____^
    |
    = note: expanding `input! { from source, n : i8, }`
    = note: to `let mut s = source ; input ! { @ from [& mut s] @ rest n : i8, }`
    = note: expanding `input! { @ from [& mut s] @ rest n : i8, }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ rest n : i8, }`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ rest n : i8, }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ var n @ kind [] @ rest i8, }`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var n @ kind [] @ rest i8, }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var n @ kind [i8] @ rest,) ;`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var n @ kind [i8] @ rest, }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var n @ kind [i8] @ rest) ; input !
            (@ from [&mut s] @ rest) ;`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var n @ kind [i8] @ rest }`
    = note: to `let n = read_value ! (@ source [&mut s] @ kind [i8]) ;`
    = note: expanding `read_value! { @ source [&mut s] @ kind [i8] }`
    = note: to `< i8 as Readable > :: read(&mut s)`
    = note: expanding `input! { @ from [&mut s] @ rest }`
    = note: to ``

    Finished dev [unoptimized + debuginfo] target(s) in 0.49s
     Running `target/debug/proconio-handson`
m: 10
```
`input!`から`input!`を呼び出しているので、慣れないと見づらいですが自分は以下のように読んでいます。  
`expanding` がmacro呼び出し時のtrace。`@`の位置を参考にどのarmにマッチするかはここで判断できる。  
`to` がマッチしたarmの展開内容、後続のmacro呼び出し時にどのように展開されたかがわかる。  
このtraceをおっていくとさきほどまでみてきた流れと同じだとわかります。  
最終的な展開結果がみたい場合は、`cargo expand`を利用しました。

### `mut`

入力をbindする変数を`mut`にしておくこともできます。今回もarmをひとつ追加するだけです。  
```rust
macro_rules! input {
    // terminator
    (@from [$source:expr] @rest) => {};
    // このarmを追加
    // parse mutability
    (@from [$source:expr] @rest mut $($rest:tt)*) => {
        input! {
            @from [$source]
            @mut [mut]
            @rest $($rest)*
        }
    };
    // ... 
}
```
`mut`をリテラルであてて、後続の処理に渡しています。
```rust
(@from [$source:expr] @mut [$($mut:tt)?] @var $var:tt @kind [$($kind:tt)*] @rest) => {
    let $($mut)* $var = read_value!(@source [$source] @kind [$($kind)*]);
};
```
最終的に、変数宣言時に`mut`が付与されます。

### `marker::{Bytes,Chars}`

これまでみてきたように、入力からの変換処理は、`input!`に指定した型の`Readable::read()`の実装次第です。(`str::FromStr`を実装していれば、`FromStr::from_str()`がよばれる)  
そのため、入力を`String`として受け取りたければ、`String`がそのまま利用できます。
```rust
input!{
  s: String,
}
```
これは、`String`が[`FromStr`を実装](https://doc.rust-lang.org/src/alloc/string.rs.html#2225-2231)しているためです。  
入力を`Vec<char>`や、`Vec<u8>`でうけとりたいときはどうすればよいでしょうか。型定義して、`Readable`を実装すればよいのですが、想定されるユースケースなので、`proconio`側が用意してくれています。それが、`marker::{Chars,Bytes}`です。
[https://github.com/statiolake/proconio-rs/blob/master/proconio/src/marker.rs]

```rust
enum Chars {}

impl Readable for Chars {
    type Output = Vec<char>;
    fn read<R: std::io::BufRead, S: Source<R>>(source: &mut S) -> Vec<char> {
        source.next_token_unwrap().chars().collect()
    }
}

enum Bytes {}

impl Readable for Bytes {
    type Output = Vec<u8>;
    fn read<R: std::io::BufRead, S: Source<R>>(source: &mut S) -> Vec<u8> {
        source.next_token_unwrap().bytes().collect()
    }
}
```
それぞれが`Readable`を定義しているので、以下のようにかけます。
debugを抜粋すると以下のようになっているのがわかります。
```
= note: to `< String as Readable > :: read(&mut s)`
= note: to `< Chars as Readable > :: read(&mut s)`
= note: to `< Bytes as Readable > :: read(&mut s)`
```

### `marker::{Usize1,Isize1}`
1オリジンの数を0オリジンに変換するutilityを提供してくれます。処理としては[read時に`checked_sub()`を実行してくれています](https://github.com/statiolake/proconio-rs/blob/a3b10f55c15177ec322ce686f0bd977011593366/proconio/src/marker.rs#L41)

### array

次に、arrayの読み込みについて見ていきます。最初にarrayの要素数、次に要素数に対応した各要素が渡される入力を想定しています。
```rust
# ![feature(trace_macros)]
// ...
fn main() {
    let source = OnceSource::from("3 1 2 3");

    trace_macros!(true);
    input! {
        from source,
        n: usize,
        a: [i32; n],
    }
    trace_macros!(false);

    assert_eq!(a, [1, 2, 3]);
    println!("{:?}", a);
}
```

実は`input!` macro自体はさきほどのmut対応で、完成し、以後は`read_value!`の拡張で対応できる型を増やしていきます。どういうことかというと、debugの抜粋ですが以下のような出力をえます。(`n: usize,`が処理されたあとを想定してください)
```
    = note: expanding `input! { @ from [&mut s] @ rest a : [i32 ; n], }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ rest a : [i32 ; n], }`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ rest a : [i32 ; n], }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ var a @ kind [] @ rest [i32 ; n], }`

    // ここがポイント
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var a @ kind [] @ rest [i32 ; n], }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var a @ kind [[i32 ; n]] @ rest,) ;`
     //                                                           ↑ `[i32 ; n] がttとして扱われている
     //
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var a @ kind [[i32 ; n]] @ rest, }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var a @ kind [[i32 ; n]] @ rest) ; input !
            (@ from [&mut s] @ rest) ;`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var a @ kind [[i32 ; n]] @ rest }`
    = note: to `let a = read_value ! (@ source [&mut s] @ kind [[i32 ; n]]) ;`
```
ここがポイントなのですが、`a: [i32; n]` という入力がmacroにはtoken treesとして渡されます。擬似的にひとつのtoken treeを`{}` でくくるとすると以下のようになります。  
`{a} {:} {[i32 ; n]} {,}`   
その結果、`[i32 ; n]`がひとつの型情報として扱わ、`read_value ! (@ source [&mut s] @ kind [[i32 ; n]]) ;` として、`read_value!`にarrayとして渡されます。(nはparse済)  
したがって、`read_value!`でarrayを渡されても値をかえせるようにすればよいことになります。  
arrayに対応するarmを追加したあとの`read_value!`は以下のようになります。
```rust
macro_rules! read_value {
    // array
    (@source [$source:expr] @kind [[$($kind:tt)*]]) => {
        read_value!(@array @source [$source] @kind [] @rest $($kind)*)
    };
    (@array @source [$source:expr] @kind [$($kind:tt)*] @rest) => {{
        let len = <usize as Readable>::read($source);
        read_value!(@source [$source] @kind [[$($kind)*; len]])
    }};
    (@array @source [$source:expr] @kind [$($kind:tt)*] @rest ; $($rest:tt)*) => {
        read_value!(@array @source [$source] @kind [$($kind)*] @len [$($rest)*])
    };
    (@array @source [$source:expr] @kind [$($kind:tt)*] @rest $tt:tt $($rest:tt)*) => {
        read_value!(@array @source [$source] @kind [$($kind)* $tt] @rest $($rest)*)
    };
    (@array @source [$source:expr] @kind [$($kind:tt)*] @len [$($len:tt)*]) => {{
        let len = $($len)*;
        (0..len)
            .map(|_| read_value!(@source [$source] @kind [$($kind)*]))
            .collect::<Vec<_>>()
    }};


    (@source [$source:expr] @kind [$kind:ty]) => {
        <$kind as Readable>::read($source)
    };
}
```
ポイントは`(@source [$source:expr] @kind [[$($kind:tt)*]])` armで、`[[ ... ]]`でうけることで、`[i32 ; n ]`を再び、`{i32}, {;}, {n}`のようにtoken tree列にしているところです。  
こうすることで、最終的に`i32`を`n`回readするloopが生成されています。
```
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var a @ kind [[i32 ; n]] @ rest }`
    = note: to `let a = read_value ! (@ source [&mut s] @ kind [[i32 ; n]]) ;`
    = note: expanding `read_value! { @ source [&mut s] @ kind [[i32 ; n]] }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [] @ rest i32 ; n)`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [] @ rest i32 ; n }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [i32] @ rest ; n)`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [i32] @ rest ; n }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [i32] @ len [n])`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [i32] @ len [n] }`
    = note: to `{
                let len = n ; (0 .. len) .
                map(| _ | read_value ! (@ source [&mut s] @ kind [i32])) . collect :: <
                Vec < _ >> ()
            }`
    = note: expanding `read_value! { @ source [&mut s] @ kind [i32] }`
    = note: to `< i32 as Readable > :: read(&mut s)`
```
expandしてみると以下のようなコードになっています。
```rust
fn main() {
    let source = OnceSource::from("3 1 2 3");
    let mut s = source;
    let n = <usize as Readable>::read(&mut s);
    let a = {
        let len = n;
        (0..len)
            .map(|_| <i32 as Readable>::read(&mut s))
            .collect::<Vec<_>>()
    };
    // ...
}
```
ここから、`input!`に`a: [i32 ; 3]` と渡してもarrayではなく`Vec<i32>`が生成されることもわかりますね。

### 2d array

arrayを読み込めるようになったので次に2d arrayを読み込めるようにします。なんとmacroは特に追加することなく既に対応できています。

```rust
# ![feature(trace_macros)]
// ...
fn main() {
    let source = OnceSource::from("1 2 3 4 5 6");

    trace_macros!(true);
    input! {
        from source,
        m: [[i32; 3]; 2],
    }
    trace_macros!(false);

    assert_eq!(m, vec![
        vec![1,2,3],
        vec![4,5,6],
    ]);
    println!("{:?}", m);
    // [[1, 2, 3], [4, 5, 6]]
}
```
今回はdebugをすべてのせます
```
❯ c +nightly run
note: trace_macro
   --> src/main.rs:272:5
    |
272 | /     input! {
273 | |         from source,
274 | |         m: [[i32; 3]; 2],
275 | |     }
    | |_____^
    |
    = note: expanding `input! { from source, m : [[i32 ; 3] ; 2], }`
    = note: to `let mut s = source ; input ! { @ from [& mut s] @ rest m : [[i32 ; 3] ; 2], }`
    = note: expanding `input! { @ from [& mut s] @ rest m : [[i32 ; 3] ; 2], }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ rest m : [[i32 ; 3] ; 2], }`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ rest m : [[i32 ; 3] ; 2], }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ var m @ kind [] @ rest [[i32 ; 3] ; 2], }`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var m @ kind [] @ rest [[i32 ; 3] ; 2], }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var m @ kind [[[i32 ; 3] ; 2]] @ rest,) ;`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var m @ kind [[[i32 ; 3] ; 2]] @ rest, }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var m @ kind [[[i32 ; 3] ; 2]] @ rest) ;
            input ! (@ from [&mut s] @ rest) ;`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var m @ kind [[[i32 ; 3] ; 2]] @ rest }`
    = note: to `let m = read_value ! (@ source [&mut s] @ kind [[[i32 ; 3] ; 2]]) ;`
    = note: expanding `read_value! { @ source [&mut s] @ kind [[[i32 ; 3] ; 2]] }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [] @ rest [i32 ; 3] ; 2)`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [] @ rest [i32 ; 3] ; 2 }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [[i32 ; 3]] @ rest ; 2)`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [[i32 ; 3]] @ rest ; 2 }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [[i32 ; 3]] @ len [2])`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [[i32 ; 3]] @ len [2] }`
    = note: to `{
                let len = 2 ; (0 .. len) .
                map(| _ | read_value ! (@ source [&mut s] @ kind [[i32 ; 3]])) . collect
                :: < Vec < _ >> ()
            }`
    = note: expanding `read_value! { @ source [&mut s] @ kind [[i32 ; 3]] }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [] @ rest i32 ; 3)`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [] @ rest i32 ; 3 }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [i32] @ rest ; 3)`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [i32] @ rest ; 3 }`
    = note: to `read_value ! (@ array @ source [&mut s] @ kind [i32] @ len [3])`
    = note: expanding `read_value! { @ array @ source [&mut s] @ kind [i32] @ len [3] }`
    = note: to `{
                let len = 3 ; (0 .. len) .
                map(| _ | read_value ! (@ source [&mut s] @ kind [i32])) . collect :: <
                Vec < _ >> ()
            }`
    = note: expanding `read_value! { @ source [&mut s] @ kind [i32] }`
    = note: to `< i32 as Readable > :: read(&mut s)`
    = note: expanding `input! { @ from [&mut s] @ rest }`
    = note: to ``

    Finished dev [unoptimized + debuginfo] target(s) in 0.00s
     Running `target/debug/proconio-handson`
[[1, 2, 3], [4, 5, 6]]
```

さきほどarrayで述べたように、`[...]` はひとつのtoken treeとして扱われるので、`read_value!`へは、`@ kind [    [[i32 ; 3] ; 2]    ])` として、`[[i32; 3]; 2]`という2d arrayの型情報をたもったまま扱われます。 ここが2d arrayのポイントなのですが、`read_value!`は先頭のarmで`@kind [[$($kind:tt)*]]`のようにマッチさせているので、`@rest`として、`[i32 ; 3] ; 2`が残ります。arrayのところでは、`read_value!`は `i32 ; 3`のような入力をうまく扱えましたが、これは`型 ; len`という順番のtoken treeともいえます。`[i32 ; 3] ; 2`であっても、`[]`でグルーピングされひとつのtoken treeとして扱われるので、`[i32 ; 3](型) ; 2(len)`と同じ並びといえます。したがって、`i32`を3回readするコードが生成されたのと同じ理由で、`[i32 ; 3]`を2回readするコードが生成されます。
expandしてみると
```rust
let source = OnceSource::from("1 2 3 4 5 6");
input! {
    from source,
    m: [[i32; 3]; 2],
}
```
から
```rust
fn main() {
    let source = OnceSource::from("1 2 3 4 5 6");
    ();
    let mut s = source;
    let m = {
        let len = 2;
        (0..len)
            .map(|_| {
                let len = 3;
                (0..len)
                    .map(|_| <i32 as Readable>::read(&mut s))
                    .collect::<Vec<_>>()
            })
            .collect::<Vec<_>>()
    };
    // ...
}
```
というコードが生成されました。  
ということで、再帰的に処理されるので
```rust
input! {
    m: [[[i32; 2]; 2]; 3],
}
```
のように拡張できることもわかりました。

### slice

documentではjagged arrayとして書かれているsliceの読み込みについて

> If the first input is the length of the array, you can omit the length. This is the only way to read jagged array (an array of arrays of which the member arrays can be of different sizes) at once. 

入力が`2 X Y`のように要素数 要素..要素の場合、`input!`にsliceを渡すことができます。

```rust
# ![feature(trace_macros)]
// ...
fn main() {
    let source = OnceSource::from("3  3 1 2 3  0  2 1 2");

    trace_macros!(true);
    input! {
        from source,
        n: usize,
        a: [[i32]; n],
    }
    trace_macros!(false);

    assert_eq!(a, vec![
        vec![1,2,3],
        vec![],
        vec![1,2],
    ]);
    println!("{:?}", a);
    // [[1, 2, 3], [], [1, 2]]
}
```

ここはポイントだけかいつまんで話すと`[i32]`が`read_value`に以下のように渡されます。
` = note: expanding read_value! { @ source [&mut s] @ kind [[i32]] }`  
そして、このarmにマッチします。
```rust
(@array @source [$source:expr] @kind [$($kind:tt)*] @rest) => {{
    let len = <usize as Readable>::read($source);
    read_value!(@source [$source] @kind [[$($kind)*; len]])
}};
```
このため、`read_value!`が要素数が渡されている前提で`len`を取得する処理が生成され、要素数分readするloopが生成されます。

### tuple

tupleの場合はどうでしょうか。シンプルな要素数2のタプルを読む処理でみていきます。

```rust
# ![feature(trace_macros)]
// ...
fn main() {
    let source = OnceSource::from("10 X");
    trace_macros!(true);
    input! {
        from source,
        t: (i8, String),
    }
    trace_macros!(false);

    assert_eq!(t, (10, String::from("X")));
    println!("t: {:?}", t);
    // t: (10, "X")
}
```

tupleもarray同様に、`()`でグルーピングされ、`read_value!`に渡されます。tupleのために追加するarmは以下です。
```rust
macro_rules! read_value {
    // ...
    // tuple
    (@source [$source:expr] @kind [($($kinds:tt)*)]) => {
        read_value!(@tuple @source [$source] @kinds [] @current [] @rest $($kinds)*)
    };
    (@tuple @source [$source:expr] @kinds [$([$($kind:tt)*])*] @current [] @rest) => {
        (
            $(read_value!(@source [$source] @kind [$($kind)*]),)*
        )
    };
    (@tuple @source [$source:expr] @kinds [$($kinds:tt)*] @current [$($curr:tt)*] @rest) => {
        read_value!(@tuple @source [$source] @kinds [$($kinds)* [$($curr)*]] @current [] @rest)
    };
    (@tuple @source [$source:expr] @kinds [$($kinds:tt)*] @current [$($curr:tt)*] @rest, $($rest:tt)*) => {
        read_value!(@tuple @source [$source] @kinds [$($kinds)* [$($curr)*]] @current [] @rest $($rest)*)
    };
    (@tuple @source [$source:expr] @kinds [$($kinds:tt)*] @current [$($curr:tt)*] @rest $tt:tt $($rest:tt)*) => {
        read_value!(@tuple @source [$source] @kinds [$($kinds)*] @current [$($curr)* $tt] @rest $($rest)*)
    };


    (@source [$source:expr] @kind [$kind:ty]) => {
        <$kind as Readable>::read($source)
    };
}
```
arrayでは、`@kind [[$($kind:tt)*]]`でマッチさせていたところが、`@kind [($($kinds:tt)*)]`になっています。arrayと違うのは、tupleの要素の型を順番に処理して最終的には以下のようなコードを生成しているところです。
```rust
let t = (
    <i8 as Readable>::read(&mut s),
    <String as Readable>::read(&mut s),
    );
```

debugしてみると以下の出力をえます
```
❯ c +nightly run
   Compiling proconio-handson v0.1.0 (/Users/ymgyt/rs/proconio-handson)
note: trace_macro
   --> src/main.rs:366:5
    |
366 | /     input! {
367 | |         from source,
368 | |         t: (i8, String),
369 | |     }
    | |_____^
    |
    = note: expanding `input! { from source, t : (i8, String), }`
    = note: to `let mut s = source ; input ! { @ from [& mut s] @ rest t : (i8, String), }`
    = note: expanding `input! { @ from [& mut s] @ rest t : (i8, String), }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ rest t : (i8, String), }`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ rest t : (i8, String), }`
    = note: to `input ! { @ from [&mut s] @ mut [] @ var t @ kind [] @ rest(i8, String), }`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var t @ kind [] @ rest(i8, String), }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var t @ kind [(i8, String)] @ rest,) ;`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var t @ kind [(i8, String)] @ rest, }`
    = note: to `input ! (@ from [&mut s] @ mut [] @ var t @ kind [(i8, String)] @ rest) ;
            input ! (@ from [&mut s] @ rest) ;`
    = note: expanding `input! { @ from [&mut s] @ mut [] @ var t @ kind [(i8, String)] @ rest }`
    = note: to `let t = read_value ! (@ source [&mut s] @ kind [(i8, String)]) ;`
    = note: expanding `read_value! { @ source [&mut s] @ kind [(i8, String)] }`
    = note: to `read_value !
            (@ tuple @ source [&mut s] @ kinds [] @ current [] @ rest i8, String)`
    = note: expanding `read_value! { @ tuple @ source [&mut s] @ kinds [] @ current [] @ rest i8, String }`
    = note: to `read_value !
            (@ tuple @ source [&mut s] @ kinds [] @ current [i8] @ rest, String)`
    = note: expanding `read_value! { @ tuple @ source [&mut s] @ kinds [] @ current [i8] @ rest, String }`
    = note: to `read_value !
            (@ tuple @ source [&mut s] @ kinds [[i8]] @ current [] @ rest String)`
    = note: expanding `read_value! { @ tuple @ source [&mut s] @ kinds [[i8]] @ current [] @ rest String }`
    = note: to `read_value !
            (@ tuple @ source [&mut s] @ kinds [[i8]] @ current [String] @ rest)`
    = note: expanding `read_value! { @ tuple @ source [&mut s] @ kinds [[i8]] @ current [String] @ rest }`
    = note: to `read_value !
            (@ tuple @ source [&mut s] @ kinds [[i8] [String]] @ current [] @ rest)`
    = note: expanding `read_value! { @ tuple @ source [&mut s] @ kinds [[i8] [String]] @ current [] @ rest }`
    = note: to `(read_value ! (@ source [&mut s] @ kind [i8]), read_value !
             (@ source [&mut s] @ kind [String]),)`
    = note: expanding `read_value! { @ source [&mut s] @ kind [i8] }`
    = note: to `< i8 as Readable > :: read(&mut s)`
    = note: expanding `read_value! { @ source [&mut s] @ kind [String] }`
    = note: to `< String as Readable > :: read(&mut s)`
    = note: expanding `input! { @ from [&mut s] @ rest }`
    = note: to ``

    Finished dev [unoptimized + debuginfo] target(s) in 0.37s
     Running `target/debug/proconio-handson`
t: (10, "X")
```
`@current` を経由して、一つづつtupleの型を処理して、すべて処理したら(`@current []`) tupleの生成表現に変換しています。
2d arrayと同様に、tupleもarrayの要素型にできます。

```rust
fn main() {
    let source = OnceSource::from("2 10 X 20 Y");
    trace_macros!(true);
    input! {
        from source,
        n: usize,
        ts: [(i8, String); n],
    }
    trace_macros!(false);

    assert_eq!(ts, vec![
        (10, String::from("X")),
        (20, String::from("Y")),
    ]);
    println!("ts: {:?}", ts);
    // ts: [(10, "X"), (20, "Y")]
}
```

### 複数回よびだし

`OnceSource`のところでみたように`input!`は最初の呼び出しで、入力をすべてメモリに読み込んで`lazy_static`経由でglobalに保持するので2回目以降の呼び出しでも前回呼び出しの状態から読み込むことができます。そのため、入力の構造にあわせて適宜loopの中でもよべるようになっています。

## まとめ

`proconio::input!` macroがどうやって入力を読み込む処理を実現しているのかをみてきました。  
`input!`と書いたときのモヤモヤがすこしでも軽減されればうれしいです。  
シンプルなarmを組み合わせて、任意な型の読み込み処理を行うコードが生成されており、とてもすごいと思いました。
今回は触れられませんでしたが、User定義型に自動で、`Readable`の実装を生成する`#[derive_readable]`についてもそのうち追ってみようと思っています。
こういった環境を整備してくださっている有志の皆様にはいつも大変感謝しております。
(`proconio`以外にもいろいろなコードがatcoder上で使えます )
[https://github.com/rust-lang-ja/atcoder-rust-resources/wiki/2020-Update:embed:cite]



## 参考ドキュメント

* [The Little Book of Rust Macros
](https://danielkeep.github.io/tlborm/book/index.html)



