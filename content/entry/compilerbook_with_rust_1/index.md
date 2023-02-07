+++
title = "📕 RustでRui Ueyama先生の低レイヤを知りたい人のためのCコンパイラ作成入門をやってみる1(環境構築から四則演算まで)"
slug = "compilerbook_with_rust_1"
date = "2020-01-02"
draft = false
[taxonomies]
tags = ["book", "rust"]
+++

compilerbookこと[低レイヤを知りたい人のためのCコンパイラ作成入門](https://www.sigbus.info/compilerbook)をRustでやっていきます。
本記事では、環境構築から四則演算のtestを通すところまでおこないます。compilerbookのステップ5: 四則演算のできる言語の作成までです。

## 概要
概要としては、計算の対象となる文字列(`2*(3+4)`)を引数にとるCLIをRustで作成し、アセンブリを出力します。そのアセンブリをcompilerbookが提供してくださっているdocker上のgccでcompileして機械語を生成する流れとなります。
生成されたプログラムは計算結果を終了ステータスとして返します。

```sh

# 入力からアセンブリを生成するCLI
cargo run -- '2*(3+4)'
    Finished dev [unoptimized + debuginfo] target(s) in 0.01s
     Running `target/debug/r9cc '2*(3+4)'`
.intel_syntax noprefix
.global main
main:
  push 2
  push 3
  push 4
  pop rdi
  pop rax
  add rax, rdi
  push rax
  pop rdi
  pop rax
  imul rax, rdi
  push rax
  pop rax
  ret

# docker上で利用するためにcross compile
cross build --target x86_64-unknown-linux-musl

# build済のdocker上でtestを実行
docker run -it -v $(pwd):/ws -w /ws compilerbook ./test.sh
```

compilerbookにそって、(文字列->Token列)、(Token列 -> AST)、(AST -> アセンブリ)の３つの変換処理を行います。
`main.rs`
```rust
use r9cc::{gen, parse, tokenize, Error};
use std::{env, io, process};

fn main() {
    let result = env::args()
        .skip(1)
        .next()
        .ok_or(Error::InputRequired)
        .and_then(|input| tokenize(&input))
        .and_then(|tokens| parse(tokens))
        .and_then(|ast| gen(&mut io::stdout(), &ast));

    if let Err(e) = result {
        match e {
            Error::Lexer(e) => {
                eprintln!("{}\n{}", env::args().skip(1).next().unwrap(), e);
            }
            _ => eprintln!("{}", e),
        }

        process::exit(1);
    }
}
```

## 環境構築

環境構築といっても、必要なツールが揃っている[Dockerfile](https://www.sigbus.info/compilerbook/Dockerfile)を準備していただいているので、Rust側だけです。
compilerbookでは`9cc`という名前で実装していくので、`r9cc`としました。[repositoryはこちらです](https://github.com/ymgyt/r9cc)

```sh
# clone
git clone https://github.com/ymgyt/r9cc

# 必要なツールをinstall
cargo install cargo-make
cargo install cross

# version
rustc -V
rustc 1.40.0 (73528e339 2019-12-16)

cross -V 
cross 0.1.16
cargo 1.40.0 (bc8e4c8be 2019-11-22)

# docker imageをbuild
cargo make image

# docker containerとinteractiveにやりとりしたい場合
# cargo make login

# r9ccをbuild
cargo make build

# testを実行
cargo make my_test
```




## tokenize

環境もととのったので、処理の流れをおっていきます。まずは、入力文字列をtokenのVecに変換するlex部分からです。
この部分は、[実践Rust入門](https://www.amazon.co.jp/dp/B07QVQ7RDG)の第9章パーサを作るを参考にさせていただきました。
https://github.com/ymgyt/r9cc/blob/7cad51b06d1ba4c1c73d5a01213128853bd115ff/src/lex/token.rs#L177

tokenは以下のように定義しました。
```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Loc(pub usize, pub usize);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Annot<T> {
    pub value: T,
    pub loc: Loc,
}

impl<T> Annot<T> {
    fn new(value: T, loc: Loc) -> Self {
        Self { value, loc }
    }
}

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum TokenKind {
    Number(u64), // [0-9][0-9]*
    Plus,        // '+'
    Minus,       // '-'
    Asterisk,    // '*'
    Slash,       // '/'
    LParen,      // '('
    RParen,      // ')'
    Eof,         // sentinel
}

impl TokenKind {
    pub(crate) fn is_number(&self) -> bool {
        match *self {
            TokenKind::Number(_) => true,
            _ => false,
        }
    }
}

pub type Token = Annot<TokenKind>;
```
tokenに位置に関する情報をもたせるために、`Annot`でwrapしています。これは実践Rust入門でおこなわれていた実装方法で、Genericsの使い方として非常に参考になりました。
`Loc`の情報はエラー時に以下のような表示をだすために利用します。
```sh
./target/debug/r9cc '1 + 2 - aaa'  
1 + 2 - aaa
        ^ invalid char 'a'
```

tokenの生成は`tokenize`関数で行います。
```rust
#[derive(Debug)]
struct Input<'a> {
    input: &'a [u8],
    pos: Cell<usize>,
}

impl<'a> Input<'a> {
    fn new(s: &'a str) -> Self {
        Self {
            input: s.as_bytes(),
            pos: Cell::new(0),
        }
    }
    fn consume_byte(&self, want: u8) -> Result<usize> {
        self.peek().and_then(|got: u8| {
            if got != want {
                let pos = self.pos();
                Err(Error::invalid_char(got as char, Loc(pos, pos + 1)))
            } else {
                Ok(self.pos_then_inc())
            }
        })
    }
    fn consume_numbers(&self) -> Result<(usize, u64)> {
        let start = self.pos();
        self.consume(|b| b"0123456789".contains(&b));
        let n = std::str::from_utf8(&self.input[start..self.pos()])
            .unwrap()
            .parse()
            .unwrap();
        Ok((start, n))
    }
    fn consume_spaces(&self) {
        self.consume(|b| b" \n\t".contains(&b))
    }
    fn consume(&self, mut f: impl FnMut(u8) -> bool) {
        while let Ok(b) = self.peek() {
            if f(b) {
                self.inc();
                continue;
            }
            break;
        }
    }
    fn peek(&self) -> Result<u8> {
        self.input
            .get(self.pos())
            .map(|&b| b)
            .ok_or_else(|| self.eof())
    }
    fn pos(&self) -> usize {
        self.pos.get()
    }
    fn inc(&self) {
        self.pos.set(self.pos() + 1);
    }
    fn pos_then_inc(&self) -> usize {
        let pos = self.pos();
        self.inc();
        pos
    }
    fn eof(&self) -> Error {
        let pos = self.pos();
        Error::eof(Loc(pos, pos))
    }
}

pub fn tokenize(input: &str) -> StdResult<Stream, crate::Error> {
    let mut tokens = Vec::new();
    let input = Input::new(input);

    macro_rules! push {
        ($lexer:expr) => {{
            let tk = $lexer?;
            tokens.push(tk);
        }};
    }
    loop {
        match input.peek() {
            Err(e) => match e.value {
                ErrorKind::Eof => {
                    tokens.push(Token::eof(Loc(input.pos(), input.pos())));
                    return Ok(tokens);
                }
                _ => return Err(e.into()),
            },
            Ok(b) => match b {
                b'0'..=b'9' => push!(lex_number(&input)),
                b'+' => push!(lex_plus(&input)),
                b'-' => push!(lex_minus(&input)),
                b'*' => push!(lex_asterisk(&input)),
                b'/' => push!(lex_slash(&input)),
                b'(' => push!(lex_lparen(&input)),
                b')' => push!(lex_rparen(&input)),
                _ if (b as char).is_ascii_whitespace() => input.consume_spaces(),
                _ => {
                    return Err(
                        Error::invalid_char(b as char, Loc(input.pos(), input.pos() + 1)).into(),
                    )
                }
            },
        }
    }
}

fn lex_number(input: &Input) -> Result<Token> {
    input
        .consume_numbers()
        .map(|(pos, n)| Token::number(n, Loc(pos, input.pos())))
}

fn lex_plus(input: &Input) -> Result<Token> {
    input
        .consume_byte(b'+')
        .map(|pos| Token::plus(Loc(pos, pos + 1)))
}

fn lex_minus(input: &Input) -> Result<Token> {
    input
        .consume_byte(b'-')
        .map(|pos| Token::minus(Loc(pos, pos + 1)))
}

fn lex_asterisk(input: &Input) -> Result<Token> {
    input
        .consume_byte(b'*')
        .map(|pos| Token::asterisk(Loc(pos, pos + 1)))
}

fn lex_slash(input: &Input) -> Result<Token> {
    input
        .consume_byte(b'/')
        .map(|pos| Token::slash(Loc(pos, pos + 1)))
}

fn lex_lparen(input: &Input) -> Result<Token> {
    input
        .consume_byte(b'(')
        .map(|pos| Token::lparen(Loc(pos, pos + 1)))
}

fn lex_rparen(input: &Input) -> Result<Token> {
    input
        .consume_byte(b')')
        .map(|pos| Token::rparen(Loc(pos, pos + 1)))
}
```

演算子ならそのままtokenに、空白は無視して、数字なら途切れるまで読んでから変換を試みます。
入力文字列と何byteまで読んだかを一緒に引き回したかったので`Input`型でwrapしています。入力文字列は`&str`で可変参照がとれないので、posを`Cell`でwrapしています。
(これがCellの正しい使い方なのかはあまり自信がないです。)


## ASTへの変換

続いて、token列をTree型のデータ構造に変換します。ASTを表すNodeは以下のように定義しました。

```rust
#[derive(Debug, PartialEq)]
pub enum Kind {
    Add,
    Sub,
    Mul,
    Div,
    Number(u64),
}

pub type Link = Option<Box<Node>>;

#[derive(Debug, PartialEq)]
pub struct Node {
    pub kind: Kind,
    pub lhs: Link,
    pub rhs: Link,
}

impl Node {
    pub fn new(kind: Kind, lhs: Link, rhs: Link) -> Node {
        Self { kind, lhs, rhs }
    }
    pub fn link(node: Node) -> Link {
        Some(Box::new(node))
    }
    pub fn number(n: u64) -> Node {
        Node::new(Kind::Number(n), None, None)
    }
}
```

Cのpointerは`Option<Box<T>>`で代用しました。(もっといい方法があるかもしれません。)
今回は利用しませんでしたが、Rustのpointerのひとつである`Rc`については@qnighyさんの[こちらの記事](https://qiita.com/qnighy/items/4bbbb20e71cf4ae527b9)が大変参考になりました。

四則演算をparseするための文法規則は以下のように定義されています。
```
expr    = mul ("+" mul | "-" mul)*
mul     = primary ("*" primary | "/" primary)*
primary = num | "(" expr ")"
```

この`expr`, `mul`, `primary`それぞれに対応する関数を定義します。

```rust
type Result<T> = StdResult<T, Error>;

pub fn parse(stream: Stream) -> StdResult<Node, crate::Error> {
    let mut tokens = stream.into_iter().peekable();
    expr(&mut tokens).map_err(|e| crate::Error::from(e))
}

fn expr<Tokens>(tokens: &mut Peekable<Tokens>) -> Result<Node>
where
    Tokens: Iterator<Item = Token>,
{
    let mut node = mul(tokens)?;
    loop {
        if consume(tokens, TokenKind::Plus)? {
            node = Node::new(Kind::Add, Node::link(node), Node::link(mul(tokens)?));
        } else if consume(tokens, TokenKind::Minus)? {
            node = Node::new(Kind::Sub, Node::link(node), Node::link(mul(tokens)?));
        } else {
            return Ok(node);
        }
    }
}

fn mul<Tokens>(tokens: &mut Peekable<Tokens>) -> Result<Node>
where
    Tokens: Iterator<Item = Token>,
{
    let mut node = primary(tokens)?;
    loop {
        if consume(tokens, TokenKind::Asterisk)? {
            node = Node::new(Kind::Mul, Node::link(node), Node::link(primary(tokens)?));
        } else if consume(tokens, TokenKind::Slash)? {
            node = Node::new(Kind::Div, Node::link(node), Node::link(primary(tokens)?));
        } else {
            return Ok(node);
        }
    }
}

fn primary<Tokens>(tokens: &mut Peekable<Tokens>) -> Result<Node>
where
    Tokens: Iterator<Item = Token>,
{
    let node = if consume(tokens, TokenKind::LParen)? {
        let node = expr(tokens)?;
        expect(tokens, TokenKind::RParen)?;
        node
    } else {
        Node::number(expect_number(tokens)?)
    };
    Ok(node)
}

fn consume<Tokens>(tokens: &mut Peekable<Tokens>, kind: TokenKind) -> Result<bool>
where
    Tokens: Iterator<Item = Token>,
{
    let peek = tokens.peek();
    if peek.is_none() {
        return Ok(false);
    }
    let peek = peek.unwrap();
    if peek.is_kind(kind) {
        tokens.next();
        Ok(true)
    } else {
        Ok(false)
    }
}

fn expect<Tokens>(tokens: &mut Peekable<Tokens>, kind: TokenKind) -> Result<()>
where
    Tokens: Iterator<Item = Token>,
{
    let peek = tokens.peek();
    if peek.is_none() {
        return Err(Error::Eof);
    }
    let peek = peek.unwrap();
    if peek.is_kind(kind) {
        tokens.next();
        Ok(())
    } else {
        Err(Error::UnexpectedToken(peek.clone()))
    }
}

fn expect_number<Tokens>(tokens: &mut Peekable<Tokens>) -> Result<u64>
where
    Tokens: Iterator<Item = Token>,
{
    let peek = tokens.peek();
    if peek.is_none() {
        return Err(Error::Eof);
    }
    let peek = peek.unwrap();
    match peek.value {
        TokenKind::Number(n) => {
            tokens.next();
            Ok(n)
        }
        _ => Err(Error::UnexpectedToken(peek.clone())),
    }
}
```

優先度の高い演算子ほど先に処理されて、木の深い位置におかれるようになっています。(文法規則をそのままコードにして動くのは感動します。)

## アセンブリの生成

ASTのparse処理によって、計算の優先度は木の深さで表現されているので、一番深いところから、演算子に対応する命令を実行して計算結果をスタックに保持するようなアセンブリを出力します。

```rust
pub fn gen<W: Write>(w: &mut W, node: &Node) -> Result<(), crate::Error> {
    pre_gen(w)
        .and_then(|_| main_gen(w, node))
        .and_then(|_| post_gen(w))
        .map_err(|e| crate::Error::from(e))
}

fn pre_gen<W: Write>(w: &mut W) -> io::Result<()> {
    write!(
        w,
        ".intel_syntax noprefix\n\
         .global main\n\
         main:\n",
    )
}

fn main_gen<W: Write>(w: &mut W, node: &Node) -> io::Result<()> {
    if let NodeKind::Number(n) = node.kind {
        write!(w, "  push {}\n", n)?;
        return Ok(());
    }

    main_gen(w, &node.lhs.as_ref().unwrap())?;
    main_gen(w, &node.rhs.as_ref().unwrap())?;

    write!(w, "  pop rdi\n")?;
    write!(w, "  pop rax\n")?;

    match node.kind {
        NodeKind::Add => write!(w, "  add rax, rdi\n")?,
        NodeKind::Sub => write!(w, "  sub rax, rdi\n")?,
        NodeKind::Mul => write!(w, "  imul rax, rdi\n")?,
        NodeKind::Div => {
            write!(w, "  cqo\n")?;
            write!(w, "  idiv rdi\n")?;
        }
        _ => unreachable!(),
    }

    write!(w, "  push rax\n")?;

    Ok(())
}

fn post_gen<W: Write>(w: &mut W) -> io::Result<()> {
    write!(w, "{}{}", "  pop rax\n", "  ret\n")
}
```

(divだけx86-64の仕様が特殊で追加の処理が必要らしいです)
数値ならstackにpushして、演算子ならpopを2回おこなってから計算して結果をstackに書き戻すシンプルな処理です。


## test

ここまでで、入力文字列からアセンブリを出力できるようになりました。
```sh
./target/debug/r9cc '6/2*(3+4)'   
.intel_syntax noprefix
.global main
main:
  push 6
  push 2
  pop rdi
  pop rax
  cqo
  idiv rdi
  push rax
  push 3
  push 4
  pop rdi
  pop rax
  add rax, rdi
  push rax
  pop rdi
  pop rax
  imul rax, rdi
  push rax
  pop rax
  ret
```

アセンブリから機械語への変換はdocker上でおこない、testを走らせます。
test用のscriptはcompilerbookのものを実行pathを修正して利用しました。
```bash
#!/bin/bash

CMD=./target/x86_64-unknown-linux-musl/debug/r9cc
TARGET=./target/tmp

mkdir -p "${TARGET}"

try() {
  expected="$1"
  input="$2"

  ${CMD} "$input" > "${TARGET}/tmp.s"
  gcc -o "${TARGET}/tmp" "${TARGET}/tmp.s"
  "${TARGET}/tmp"
  actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

try 0 0
try 100 100
try 2 '1+1'
try 21 '3*(9-2)'
try 14 '(3+3)+2*(5-1)'

echo OK
```
dockerのbase imageはubuntuなので、crossを利用してcross compileを実行してから、docker上で上記のtest.shを実行します。

```sh
[loc rs/r9cc] cargo make build 
[cargo-make] INFO - cargo make 0.25.0
[cargo-make] INFO - Project: r9cc
[cargo-make] INFO - Build File: Makefile.toml
[cargo-make] INFO - Task: build
[cargo-make] INFO - Profile: development
[cargo-make] INFO - Running Task: init
[cargo-make] INFO - Running Task: build
[cargo-make] INFO - Execute Command: "cross" "build" "--target" "x86_64-unknown-linux-musl"
   Compiling r9cc v0.1.0 (/project)
    Finished dev [unoptimized + debuginfo] target(s) in 11.71s
[cargo-make] INFO - Running Task: end
[cargo-make] INFO - Build Done in 13 seconds.
[loc rs/r9cc] cargo make my_test   
[cargo-make] INFO - cargo make 0.25.0
[cargo-make] INFO - Project: r9cc
[cargo-make] INFO - Build File: Makefile.toml
[cargo-make] INFO - Task: my_test
[cargo-make] INFO - Profile: development
[cargo-make] INFO - Running Task: init
[cargo-make] INFO - Running Task: my_test
0 => 0
100 => 100
1+1 => 2
3*(9-2) => 21
(3+3)+2*(5-1) => 14
OK
[cargo-make] INFO - Running Task: end
[cargo-make] INFO - Build Done in 2 seconds.
```

## まとめ

環境構築から四則演算までを行いました。次回はステップ6 単項プラスと単項マイナスからを予定しています。
このようなすばらしいドキュメントを無料で公開してくださっているRui Ueyama先生、ありがとうございます。(なんらかの形で販売されることがありましたら必ず購入します)


## 参考

- compilerbook 低レイヤを知りたい人のためのCコンパイラ作成入門
  - Rui Ueyama
  - https://www.sigbus.info/compilerbook
- 実践Rust入門
  - κeen , 河野 達也 , 小松 礼人
  - https://www.amazon.co.jp/dp/B07QVQ7RDG

