+++
title = "📗 Write Powerful Rust Macrosを読んだ感想"
slug = "write-powerful-rust-macros"
description = "一冊まるごとMacroについての本"
date = "2024-07-15"
draft = false
[taxonomies]
tags = ["rust","book"]
[extra]
image = "images/emoji/green_book.png"
+++

## 読んだ本

{{ figure(images=["images/macro-book.jpg"], caption="Write Powerful Rust Macros", href="https://www.manning.com/books/write-powerful-rust-macros") }}

著者: Sam Van Overmeire 

[Rustacean station](https://rustacean-station.org/episode/sam-van-overmeire/)というpodcastで紹介されていて、おもしろそうだったので読んでみました。


## 1 Going meta

hygieneやcompile時にチェックされる等、Rustのmacroの特徴について。  
Procedural macroはderive macro, attribute macro, function like macroに分類されます。これらにどういった違いがあるのか自分は曖昧に理解していたのですが、deriveはcodeの追加のみ、attributeとfunction likeはcodeの変更や削除までできるという違いがあることがわかりました。

## 2 Declarative macros

Declarative macroについての章です。  
Declarative macroの基本的な書き方から、hygieneまで解説があります。  
Usecaseとして、newtype pattern実装時のboilerplateの記述等が紹介されます。  
また、`trace_macros!`や`log_syntax!`によるdebug方法の解説もあります。  
`log_syntax!`は使ったことがなかったです。compile時にdebugできるので`cargo check`でmacroをdebugできます。  

その他、簡単なDSLや関数をcomposeする例が載っています。  
Real world usecaseとして`lazy_static!`の実装の解説もあります。

## 3 A "Hello, World" procedural macro

3章からはprocedural macroの話になります。  
まずderive macroの説明から始まります。
projectのsetupの仕方からmacroの処理の概要、`syn`や`quote`の基本的な使い方が解説されます。  
以下のような`#[derive(Hello)]`の実装を1行づつ説明してくれます。

```rust
use proc_macro::TokenStream;
use quote::quote;
use syn::DeriveInput;

#[proc_macro_derive(Hello)]
pub fn hello(item: TokenStream) -> TokenStream {
    let ast = match syn::parse::<DeriveInput>(item) {
        Ok(input) => input,
        Err(err) => return TokenStream::from(err.to_compile_error()),
    };
    let name = ast.ident;
    let add_hello_world = quote! {
        impl #name {
            fn hello_world(&self) {
                println!("Hello World")
            }
        }
    };
    add_hello_world.into()
}
```

```rust
use hello_world_macro::Hello;

#[derive(Hello)]
struct Example {}

fn main() {
    let e = Example {};
    e.hello_world(); // => Hello World
}
```

本書を試していて気づいたのですが、`cargo expand`はmain.rsだけでなく、moduleのpathも指定できて、`cargo expand path/to/module/hello`のように実行すると、`crate::path::to::module::hello`の内容が展開できました。  
 今まで、main.rs等にcopyしていたのですが、これからは気になったコードをすぐにexpandできそうです。


## 4 Making fields public with attribute macros

本章では、付与された型のfieldをpublicにする`#[public]` attribute macroを実装していきます。  

```rust
#[public]
struct Example {
    first: String,
    second: i64,
}
```

が以下のように変換されます。

```rust
struct Example {
    pub first: String,
    pub second: i64,
}
```

この処理を実装するには、structのfieldをparseする必要があります。  
この例を通じて、`quote::ToTokens`や`syn::parse::Parse`の仕組みを学べます。`proc_macro2::TokenStream`も登場します。  
fieldを加工できるようになるといよいよできることが広がってきておもしろくなってきます。  
また、read worldのusecaseとして、dtolnay先生の[no-panic](https://github.com/dtolnay/no-panic)も紹介されます。  
章末のexercisesまでやると、各種structとenumの対応まで実装できます。


## 5 Hiding information and creating mini-DLSs with function-like macros

5章は`foo!()`のようなfunction like macroについてです。  
function like macroはattribute macroのようにinputのTokenStreamを置き換えられます。  
attribute macroとの違いは、macroの入力として、rustのcodeに限らず任意の入力を渡せる点です。  
この特性から、`sqlx`や`yew`では、SQLやhtmlを入力にとれるmacroが提供されています。  
本章では、2章で実装した、compose macroのprodedural版を実装します。

```rust
use compose_macro::compose;

fn add_one(n: i32) -> i32 {
    n + 1
}

fn to_string(n: i32) -> String {
    n.to_string()
}

fn with_prefix(s: String) -> String {
    format!("prefix_{s}")
}

fn main() {
    let composed = compose!(add_one.to_string.with_prefix);

    println!("{}", composed(2)); // => "prefix_3"
}
```

## 6 Testing a builder macro

6章では、`#[derive(Builder)]` macroによるbuilder patternの実装を通して、macroのtestについて学びます。また、`proc-macro2`を利用して、procedural macroの実装を通常のlib crateに移譲する方法についても説明されます。  
他のprocedural macroについてのリソースについてdtolnay先生の[proc-macro-workshop](https://github.com/dtolnay/proc-macro-workshop)やjon gjengset先生の[Procedural Macros in Rust](https://www.youtube.com/watch?v=geovSK3wMB8) 動画が紹介されていました。


## 7 From panic to result: Error handling

本章では、以下のような`panic!()`する関数をResultを返す関数に変換する`#[panic_to_result]`を通して、関数の変換とエラーハンドリングについて学びます。

```rust
#[panic_to_result]
fn create_person(name: String, age: u32) -> Person {
    if age > 30 {
        panic!("I hope I die before I get old");
    }
    Person {
        name,
        age,
    }
}
```

```rust
fn create_person(name: String, age: u32) -> Result<Person,String> {
    if age > 30 {
        return Err("I hope I die before I get old".into());
    }
    Person {
        name,
        age,
    }
}
```

変換時のエラー、例えば`panic!()`にメッセージがない場合をユーザにわかりやすく伝える方法が解説されます。[proc-macro-error](https://docs.rs/proc-macro-error/latest/proc_macro_error/)は知らなかったので参考になりました。  

## 8 Builder with attributes

8章では、attributesを扱う方法について学びます。 
以前のBuilder macroでrenameを扱えるようにします。  

```rust
#[derive(Builder)]
struct Example {
    #[rename("bar")]
    foo: String,
}

fn main() {
    Example::builder().bar("bar".into()).build();
}
```

attributeにも、`#[rename(foo)]`であったり、`#[rename(key=value)]`と書き方が複数あり、それぞれsyn上での表現が異なります。  
また、今のBuilderの実装では、ユーザが適切にbuilderのmethodを呼び出しかどうかをruntime時にチェックしています。  
これをcompile時にチェックできるようにいわゆるtype state patternを実装します。
attribute macroの場合、他のattributeを保持するかどうかも判断する必要があり、`#[allow()]`等の他のattributeを保持するか否かを判定する必要があるのは知らなかったので参考になりました。


## 9 Writing an infrastructure DSL

9章では、function like macroでDSLを作っていきます。  
具体的には以下のようにAWSのresourceを宣言するterraformのようなInfrastructure as Code(IaC) macroを作ります。

```rust
iac! {
    bucket uniquename => lambda (
        name = "name", mem = 1024, time = 10
    )
}
```

この実装の中で、`syn::custom_keyword!`や`syn::parenthesized`の使い方も紹介されます。
From the real worldではdeclaratve macroとprocedural macroを組み合わせて使われている例が紹介されていました。  


## 10 Macros and the outside world

最後の10章はcompile時にyaml fileから`Config` structを生成する`config!`を実装します。  
本章ではproc macro crateのfeature制御やdocumentについての解説もあります。  
最後にまとめとして、`#[tokio::main]`のsrcの解説があります。  
また、本書で紹介しきれなかったsynの[`Fold` traitの解説記事](https://www.infoq.com/articles/rust-procedural-macros-replace-panic/)やproc macro実装時に利用できるcrateが紹介されています。

## まとめ

Procedural macroだけでほぼ1冊書かれており、実際にcodeを書きながら少しずつ改良していくのでとても楽しく読めました。  
章末のexerciseの答えもappendixに載っていてありがたいです。  
今までprocedural macroの実装を読んでいなかったのですが、これからは色々なlibの実装を読んでみようと思えるようになりました。
