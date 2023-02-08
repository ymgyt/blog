+++
title = "🏗  proc-macro-workshop/builderをやってみる"
slug = "proc-macro-workshop-builder"
date = "2022-10-10"
draft = false
[taxonomies]
tags = ["rust"]
+++

本記事ではdtolnay先生の[proc-macro-workshop]のbuilderをやっていきます。  
workshopはprocedural macrosの学習を目的に作られており、workshop内の各projectをstep by stepで実装していくことで自然とprocedural macrosに慣れることができます。
本workshopの存在自体は知っていたのですが途中までしかできていない状態でした。  
そんな中で今働いている[fraim]という会社でRust勉強会が始まり、そこで週一回少しづつ進めていく機会を得ました。(副業の募集もあるので仕事でRustに触れたい方等おられましたら是非[募集](https://www.wantedly.com/companies/FRAIM/projects)を覗いてみてください)

## workshopの進め方

workshopの進め方について。  
まず、[proc-macro-workshop]をfork(optional), cloneしてきます。  
projectのrootに各workshopのprojectが用意されています。本記事ではbuilderをおこなっていきますので、builderにcdします。  
すると、`tests/progress.rs`というファイルが用意されており、このファイルを編集しながら実装を進めていきます。  

```rust
#[test]
fn tests() {
    let t = trybuild::TestCases::new();
    //t.pass("tests/01-parse.rs");
    //t.pass("tests/02-create-builder.rs");
    //t.pass("tests/03-call-setters.rs");
    //t.pass("tests/04-call-build.rs");
    //t.pass("tests/05-method-chaining.rs");
    //t.pass("tests/06-optional-field.rs");
    //t.pass("tests/07-repeated-field.rs");
    //t.compile_fail("tests/08-unrecognized-attribute.rs");
    //t.pass("tests/09-redefined-prelude-types.rs");
}
```

最初は`t.pass()`がコメントアウトされており、一つずつコメントアウトを外しながら進めていきます。

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    t.pass("tests/01-parse.rs");
    // ...
}
```

## `01-parse`

まずは`01-parse.rs`を有効にします。  
`01-parse.rs`は以下の内容になっています。(commentは割愛)

```rust
use derive_builder::Builder;

#[derive(Builder)]
pub struct Command {
    executable: String,
    args: Vec<String>,
    env: Vec<String>,
    current_dir: String,
}

fn main() {}
```

定義されている`Command`structに`derive(Builder)`が宣言されています。この様に任意のstructにderiveしてbuilderを生成するのが本projectの目標です。  
`01-parse.rs`ではbuilderの処理がよびだされていないのでとりあえずcompileを通せばよいだけです。 
肝心のbuilderの実装は`src/lib.rs`に書いていきます。  
`lib.rs`は初期状態では以下のようになっています。  

```rust
use proc_macro::TokenStream;

#[proc_macro_derive(Builder)]
pub fn derive(input: TokenStream) -> TokenStream {
    let _ = input;

    unimplemented!()
}
```

この状態で`cargo test --quiet`を実行するとnot implementedとなり失敗します。
```console
❯ cargo test --quiet
running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.12s


test tests/01-parse.rs ... error
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
error: proc-macro derive panicked
  --> tests/01-parse.rs:26:10
   |
26 | #[derive(Builder)]
   |          ^^^^^^^
   |
   = help: message: not implemented
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
```

今回はcompileさえ通せばよいので空の`TokenStream`を返してみます。
```rust
#[proc_macro_derive(Builder)]
pub fn derive(input: TokenStream) -> TokenStream {
    let _ = input;
    TokenStream::new()
}
```

```console
❯ cargo test --quiet
running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/builder)
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.28s


test tests/01-parse.rs ... ok
```

これで`01-parse.rs`をパスできました🎉  
基本的な流れは後は同じでtestを通しながらBuilderを作っていきます。

## `02-create-builder`

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    // ...
    t.pass("tests/02-create-builder.rs");
    // ...
}
```

`02-create-builder.rs`は以下のようになっています。

```rust
#[derive(Builder)]
pub struct Command {
    executable: String,
    args: Vec<String>,
    env: Vec<String>,
    current_dir: String,
}

fn main() {
    let builder = Command::builder();

    let _ = builder;
}
```

`Command`に`builder`methodを生成し、`CommandBuilder`型を返せばよさそうです。  
生成するコードのイメージとしては

```rust
struct CommandBuilder {
    // field definitions...
}

impl Command {
    fn builder(&self) -> CommandBuilder {
        CommandBuilder {
            // initial fields...
        }
    }
}
```
という感じになりそうです。具体的には

* `CommandBuilder`のstruct定義
* `Command`に`builder` methodをimpl
* `CommandBuilder`の初期化処理

を実装します。実装に着手する前に必要な依存を追加します。  
`cargo add syn quote proc-macro2`を実行します。

```toml
[dependencies]
proc-macro2 = "1.0.46"
quote = "1.0.21"
syn = { version = "1.0.102", features = ["full", "extra-traits", "parsing"] }
```

testではbuilderに特に処理が必要ないので空のbuilderを生成するコードを目指します。  
最初は以下のようになりました。

```rust
use proc_macro::TokenStream;
use quote::{format_ident, quote};
use syn::{Data, DataStruct, DeriveInput, Fields, FieldsNamed, Result, parse_macro_input, Error};
use syn::spanned::Spanned;
use proc_macro2::TokenStream as TokenStream2;

#[proc_macro_derive(Builder)]
pub fn derive(input: TokenStream) -> TokenStream {
    let input: DeriveInput = parse_macro_input!(input as DeriveInput);

    match derive_builder(input) {
        Ok(token_stream) => TokenStream::from(token_stream),
        Err(err) => TokenStream::from(err.to_compile_error())
    }
}

fn derive_builder(input: DeriveInput) -> Result<TokenStream2> {
    if let Data::Struct(DataStruct {
                            fields: Fields::Named(FieldsNamed { named, .. }), ..
                        }) = input.data {
        let _ = named;
        let ident = input.ident;
        let builder = format_ident!("{}Builder",ident);

        Ok(quote! {
           struct #builder {}

           impl #ident {
                fn builder() -> #builder {
                    #builder {}
                }
            }
        })
    } else {
        Err(Error::new(input.span(), "Only struct supported"))
    }
}
```
procedural macroの最初の課題はsyn(とquote)のapiに慣れることにあると思います。  
基本的に`TokenStream`を直接扱うことはせず、synでRustの型情報を表す型にparseします。今回は`derive`に書かれる前提なので`DeriveInput`型にparseします。  
そこから必要な情報を抽出して、`quote!`でTokenStreamを組み立てます。


```console
❯ cargo test --quiet

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/builder)
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.34s


test tests/02-create-builder.rs ... ok
```

無事testをパスしました。
生成されたコードを確かめる方法ですが、test caseのコードをproject直下のmain.rsに貼り付けて`cargo expand`を実行することで確かめられます。試しに実行してみると以下のようになりました。

```rust
#![feature(prelude_import)]
#[prelude_import]
use std::prelude::rust_2021::*;
#[macro_use]
extern crate std;
use derive_builder::Builder;
pub struct Command {
    executable: String,
    args: Vec<String>,
    env: Vec<String>,
    current_dir: String,
}
struct CommandBuilder {}
impl Command {
    fn builder() -> CommandBuilder {
        CommandBuilder {}
    }
}
fn main() {
    let builder = Command::builder();
    let _ = builder;
}
```

## `03-call-setters`

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    // ...
    t.pass("tests/03-call-setters.rs");
    // ...
}
```

`03-call-setters.rs`では

```rust
use derive_builder::Builder;

#[derive(Builder)]
pub struct Command {
    executable: String,
    args: Vec<String>,
    env: Vec<String>,
    current_dir: String,
}

fn main() {
    let mut builder = Command::builder();
    builder.executable("cargo".to_owned());
    builder.args(vec!["build".to_owned(), "--release".to_owned()]);
    builder.env(vec![]);
    builder.current_dir("..".to_owned());
}
```

builderに定義元のstructのfield名のmethodが定義されています。型は定義元のCommandのfieldと同じようです。これに対応するには以下の変更が必要そうです。

* builderのfieldを`Option<T>`とする
* builderにderive元のfield名に対応したmethodを定義

追加した実装が以下です。

```rust
fn derive_builder(input: DeriveInput) -> Result<TokenStream2> {
    if let Data::Struct(DataStruct {
                            fields: Fields::Named(FieldsNamed { named, .. }), ..
                        }) = input.data {
        let ident = input.ident;
        let builder = format_ident!("{}Builder",ident);
        // 👇
        let fields = named.iter().map(|f| (f.ident.as_ref().expect("field have ident"),&f.ty));
        let builder_fields = fields.clone().map(|(ident, ty)| quote! {#ident: ::core::option::Option<#ty>});
        let builder_init_fields = fields.clone().map(|(ident,_)| quote!{ #ident: ::core::option::Option::None});
        let builder_methods = fields.clone().map(|(ident, ty)| impl_builder_method(ident, ty));

        Ok(quote! {
           struct #builder {
                #(#builder_fields),*
            }

            impl #builder {
                #(#builder_methods)*
            }

           impl #ident {
                fn builder() -> #builder {
                    #builder {
                        #(#builder_init_fields),*
                    }
                }
            }
        })
    } else {
        Err(Error::new(input.span(), "Only struct supported"))
    }
}

fn impl_builder_method(
    ident: &Ident,
    ty: &Type,
) -> TokenStream2 {
    quote! {
        fn #ident (&mut self, #ident: #ty) -> &mut Self {
            self.#ident = ::core::option::Option::Some(#ident);
            self
        }
    }
}
```

fieldの情報(識別子と型)をiterateしてそれぞれOptionでwrapしたり同名のmethodを生成させています。

```rust
struct #builder {
    #(#builder_fields),*
}
```
declarative macroと同様に`#(...)*`で繰り返しが表現できるので、iteratorを参照するとそれが展開されるイメージです。

expandしてみると

```rust
struct CommandBuilder {
    executable: ::core::option::Option<String>,
    args: ::core::option::Option<Vec<String>>,
    env: ::core::option::Option<Vec<String>>,
    current_dir: ::core::option::Option<String>,
}
impl CommandBuilder {
    fn executable(&mut self, executable: String) -> &mut Self {
        self.executable = ::core::option::Option::Some(executable);
        self
    }
    fn args(&mut self, args: Vec<String>) -> &mut Self {
        self.args = ::core::option::Option::Some(args);
        self
    }
    fn env(&mut self, env: Vec<String>) -> &mut Self {
        self.env = ::core::option::Option::Some(env);
        self
    }
    fn current_dir(&mut self, current_dir: String) -> &mut Self {
        self.current_dir = ::core::option::Option::Some(current_dir);
        self
    }
}
impl Command {
    fn builder() -> CommandBuilder {
        CommandBuilder {
            executable: ::core::option::Option::None,
            args: ::core::option::Option::None,
            env: ::core::option::Option::None,
            current_dir: ::core::option::Option::None,
        }
    }
}
```
となり意図通りのコードが生成されています。

```console
❯ cargo test --quiet

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.13s


test tests/03-call-setters.rs ... ok
```

無事テストもパスしました。
[source code](https://github.com/ymgyt/proc-macro-workshop/tree/3d0f9b3ca5f38e0539cdf7499bde7087557b7044)

## `04-call-build`

`04-call-build`では実際にbuilderのbuild methodが呼ばれます。

```rust
fn main() {
    let mut builder = Command::builder();
    builder.executable("cargo".to_owned());
    builder.args(vec!["build".to_owned(), "--release".to_owned()]);
    builder.env(vec![]);
    builder.current_dir("..".to_owned());

    let command = builder.build().unwrap();
    assert_eq!(command.executable, "cargo");
}
```

これに対応するためにはbuilderにbuild methodを追加し、自身のfieldの値からderive元のCommandをconstructするような処理が必要です。これに対応したのが以下です。

```rust
fn derive_builder(input: DeriveInput) -> Result<TokenStream2> {
    if let Data::Struct(DataStruct {
        fields: Fields::Named(FieldsNamed { named, .. }),
        ..
    }) = input.data
    {
        let ident = input.ident;
        let builder = format_ident!("{}Builder", ident);
        let fields = named
            .iter()
            .map(|f| (f.ident.as_ref().expect("field have ident"), &f.ty));
        // 👇
        let idents = fields.clone().map(|(ident,_)| ident);
        let builder_fields = fields
            .clone()
            .map(|(ident, ty)| quote! {#ident: ::core::option::Option<#ty>});
        let builder_init_fields = fields
            .clone()
            .map(|(ident, _)| quote! { #ident: ::core::option::Option::None});
        let builder_methods = fields
            .clone()
            .map(|(ident, ty)| impl_builder_method(ident, ty));

        Ok(quote! {
           struct #builder {
                #(#builder_fields),*
            }

            impl #builder {
                #(#builder_methods)*

                // 👇
                fn build(&mut self) -> ::core::result::Result<
                    #ident,
                    ::std::boxed::Box<dyn ::std::error::Error>
                >
                {
                    Ok(#ident {
                        #(
                            #idents: self.#idents.take().ok_or_else(||
                               format!("{} is not provided", stringify!(#idents))
                            )?
                        ),*
                    })
                }
            }

           impl #ident {
                fn builder() -> #builder {
                    #builder {
                        #(#builder_init_fields),*
                    }
                }
            }
        })
    } else {
        Err(Error::new(input.span(), "Only struct supported"))
    }
}
```

filedの識別だけを保持するiteratorを用意しておき、`#idents: self.#idents.take()`のように使います。あくまでtokenなので、実際にはOptionでなくても(`syn::Ident`)`take`が呼べてしまうんですね。

```console
❯ cargo test
    Finished test [unoptimized + debuginfo] target(s) in 0.02s
     Running unittests src/lib.rs (/Users/ymgyt/rs/proc-macro-workshop-blog/target/debug/deps/derive_builder-5d658299e3122af7)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running tests/progress.rs (/Users/ymgyt/rs/proc-macro-workshop-blog/target/debug/deps/tests-0fe6acae350aa640)

running 1 test
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.13s


test tests/04-call-build.rs ... ok
```

テストもパスしました。


## `05-method-chaining`

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    // ...
    t.pass("tests/05-method-chaining.rs");
    // ...
}
```

builderのmethodをchainできるかのtestです。

```rust
fn main() {
    let command = Command::builder()
        .executable("cargo".to_owned())
        .args(vec!["build".to_owned(), "--release".to_owned()])
        .env(vec![])
        .current_dir("..".to_owned())
        .build()
        .unwrap();

    assert_eq!(command.executable, "cargo");
}
```

今回は新たに実装を変更しなくてもテストをパスできます。  
今回はbuilderのsignatureを`&mut self`としていますが、`self`としたい場面もあります。今回のケースでは初期値をすべてOption型としているので、takeで所有権を奪えるのですがそうでない場合には`&mut self`から値をmoveできずに不要なcloneが生じてしまう場合があります。  
このあたりのPro/Conについては[derive_builder](https://docs.rs/derive_builder/latest/derive_builder/#builder-patterns)に説明がありました。

```console
❯ cargo test
    Finished test [unoptimized + debuginfo] target(s) in 0.02s
     Running unittests src/lib.rs (/Users/ymgyt/rs/proc-macro-workshop-blog/target/debug/deps/derive_builder-5d658299e3122af7)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running tests/progress.rs (/Users/ymgyt/rs/proc-macro-workshop-blog/target/debug/deps/tests-0fe6acae350aa640)

running 1 test
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.13s


test tests/05-method-chaining.rs ... ok
```

## `06-optional-fields`

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    // ...
    t.pass("tests/06-optional-field.rs");
    // ...
}
```

```rust
#[derive(Builder)]
pub struct Command {
    executable: String,
    args: Vec<String>,
    env: Vec<String>,
    current_dir: Option<String>,
}

fn main() {
    let command = Command::builder()
        .executable("cargo".to_owned())
        .args(vec!["build".to_owned(), "--release".to_owned()])
        .env(vec![])
        .build()
        .unwrap();
    assert!(command.current_dir.is_none());

    let command = Command::builder()
        .executable("cargo".to_owned())
        .args(vec!["build".to_owned(), "--release".to_owned()])
        .env(vec![])
        .current_dir("..".to_owned())
        .build()
        .unwrap();
    assert!(command.current_dir.is_some());
}
```

derive元では`current_dir`がOptionになっています。それに対応してbuilderでもcurrent_dirの呼び出しがoptionalになっています。  
ようやくbuilderらしくなってきたのですが、このあたりからつらくなります。具体的には扱っている対象があくまでtoken列なので、型として情報がまだなく、今扱っているfiledの型がOptionなのかの判別やOption<T>からTを得る場合をがんばらないといけなくなります。

今回の変更点は以下です。

* Option<T>型のbuilderのfieldの初期値を`Some(None)`にする
* Option<T>型のbuilder methodがTをうけとるようにする

変更後のコードは以下になります。

```rust
fn derive_builder(input: DeriveInput) -> Result<TokenStream2> {
    if let Data::Struct(DataStruct {
        fields: Fields::Named(FieldsNamed { named, .. }),
        ..
    }) = input.data
    {
        let ident = input.ident;
        let builder = format_ident!("{}Builder", ident);
        let fields = named
            .iter()
            .map(|f| (f.ident.as_ref().expect("field have ident"), &f.ty));
        let idents = fields.clone().map(|(ident, _)| ident);
        let builder_fields = fields
            .clone()
            .map(|(ident, ty)| quote! {#ident: ::core::option::Option<#ty>});
        let builder_init_fields = fields.clone().map(builder_init_field);
        let builder_methods = fields
            .clone()
            .map(|(ident, ty)| impl_builder_method(ident, ty));

        Ok(quote! {
           struct #builder {
                #(#builder_fields),*
            }

            impl #builder {
                #(#builder_methods)*

                fn build(&mut self) -> ::core::result::Result<
                    #ident,
                    ::std::boxed::Box<dyn ::std::error::Error>
                >
                {
                    Ok(#ident {
                        #(
                            #idents: self.#idents.take().ok_or_else(||
                               format!("{} is not provided", stringify!(#idents))
                            )?
                        ),*
                    })
                }
            }

           impl #ident {
                fn builder() -> #builder {
                    #builder {
                        #(#builder_init_fields),*
                    }
                }
            }
        })
    } else {
        Err(Error::new(input.span(), "Only struct supported"))
    }
}

// 👇
fn impl_builder_method(ident: &Ident, ty: &Type) -> TokenStream2 {
    match field_type(ty) {
        FieldType::Option(inner_ty) => {
            quote! {
                fn #ident (&mut self, #ident: #inner_ty) -> &mut Self {
                    self.#ident = ::core::option::Option::Some(
                        ::core::option::Option::Some(#ident)
                    );
                    self
                }
            }
        }
        _ => {
            quote! {
                fn #ident (&mut self, #ident: #ty) -> &mut Self {
                    self.#ident = ::core::option::Option::Some(#ident);
                    self
                }
            }
        }
    }
}

// 👇
fn builder_init_field((ident, ty): (&Ident, &Type)) -> TokenStream2 {
    match field_type(ty) {
        FieldType::Option(_inner_ty) => {
            quote! { #ident: ::core::option::Option::Some(::core::option::Option::None)}
        }
        FieldType::Vec(_inner_ty) => {
            quote! { #ident: ::core::option::Option::Some(::std::vec::Vec::new())}
        }
        FieldType::Raw => {
            quote! { #ident: ::core::option::Option::None}
        }
    }
}

// 👇
fn field_type(ty: &Type) -> FieldType {
    use syn::{
        AngleBracketedGenericArguments, GenericArgument, Path, PathArguments, PathSegment, TypePath,
    };
    if let Type::Path(TypePath {
        qself: None,
        path: Path {
            leading_colon,
            segments,
        },
    }) = ty
    {
        if leading_colon.is_none() && segments.len() == 1 {
            if let Some(PathSegment {
                ident,
                arguments:
                    PathArguments::AngleBracketed(AngleBracketedGenericArguments { args, .. }),
            }) = segments.first()
            {
                if let (1, Some(GenericArgument::Type(t))) = (args.len(), args.first()) {
                    if ident == "Option" {
                        return FieldType::Option(t.clone());
                    } else if ident == "Vec" {
                        return FieldType::Vec(t.clone());
                    }
                }
            }
        }
    }
    FieldType::Raw
}

enum FieldType {
    Raw,
    Option(Type),
    Vec(Type),
}
```

まず型の判別とinner typeを取得するutil処理として、`field_type()`を定義します。  
このようにsynから型を判別してinner typeを取得する処理は結構大変です。この処理でも簡易的でもっと考慮しないといけなケースがあります。  
filedの型が`Option<T>`と判別できれば、初期値は`Some(None)`として、methodの引数では`T`をうけとれるようにできます。

これでテストをパスできました。

```console
❯ cargo test
    Finished test [unoptimized + debuginfo] target(s) in 0.02s
     Running unittests src/lib.rs (/Users/ymgyt/rs/proc-macro-workshop-blog/target/debug/deps/derive_builder-5d658299e3122af7)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running tests/progress.rs (/Users/ymgyt/rs/proc-macro-workshop-blog/target/debug/deps/tests-0fe6acae350aa640)

running 1 test
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.13s


test tests/06-optional-field.rs ... ok
```
[source code](https://github.com/ymgyt/proc-macro-workshop/tree/84105faa4bcafce3a6219b45c51ad99da501ddfe)

## `07-repeated-field`

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    // ...
    t.pass("tests/07-repeated-field.rs");
    // ...
}
```

`07-repeted-field`は以下のようになっています。

```rust
#[derive(Builder)]
pub struct Command {
    executable: String,
    #[builder(each = "arg")]
    args: Vec<String>,
    #[builder(each = "env")]
    env: Vec<String>,
    current_dir: Option<String>,
}

fn main() {
    let command = Command::builder()
        .executable("cargo".to_owned())
        .arg("build".to_owned())
        .arg("--release".to_owned())
        .build()
        .unwrap();

    assert_eq!(command.executable, "cargo");
    assert_eq!(command.args, vec!["build", "--release"]);
}
```

fieldに`builder(each = ...)`というannotationが追加されており、`Vec<T>`型のfieldに対して、eachで指定したmethodを複数回呼ぶことで内部的なvecにpushできるようなapiになっています。  
ここで注意していただきたいのが、`args`ではeachが`arg`になっているのに対して、`env`ではeachも`env`となっており、eachと元々のfield名が一致しています。

今回必要な変更点は

* `each`のannotationに対応したbuilder method

変更後のコードは以下のようになりました。

```rust
#[proc_macro_derive(Builder, attributes(builder))]
pub fn derive(input: TokenStream) -> TokenStream {
    let input: DeriveInput = parse_macro_input!(input as DeriveInput);
    // ...
}

fn derive_builder(input: DeriveInput) -> Result<TokenStream2> {
    if let Data::Struct(DataStruct {
        fields: Fields::Named(FieldsNamed { named, .. }),
        ..
    }) = input.data
    {
        let ident = input.ident;
        let builder = format_ident!("{}Builder", ident);
        let fields = named
            .iter()
            .map(|f| (f.ident.as_ref().expect("field have ident"), &f.ty));
        let idents = fields.clone().map(|(ident, _)| ident);
        let builder_fields = fields
            .clone()
            .map(|(ident, ty)| quote! {#ident: ::core::option::Option<#ty>});
        let builder_init_fields = fields.clone().map(builder_init_field);
        // 👇
        let each_attributes = named.iter().map(|f| match f.attrs.first() {
            Some(attr) => inspect_each(attr),
            None => Ok(None),
        }).collect::<Result<Vec<_>>>()?;
        let builder_methods = fields
            .clone()
            .zip(each_attributes)
            .map(|((ident, ty), maybe_each)| impl_builder_method(ident, ty, maybe_each));

        Ok(quote! {
           struct #builder {
                #(#builder_fields),*
            }

            impl #builder {
                #(#builder_methods)*

                fn build(&mut self) -> ::core::result::Result<
                    #ident,
                    ::std::boxed::Box<dyn ::std::error::Error>
                >
                {
                    Ok(#ident {
                        #(
                            #idents: self.#idents.take().ok_or_else(||
                               format!("{} is not provided", stringify!(#idents))
                            )?
                        ),*
                    })
                }
            }

           impl #ident {
                fn builder() -> #builder {
                    #builder {
                        #(#builder_init_fields),*
                    }
                }
            }
        })
    } else {
        Err(Error::new(input.span(), "Only struct supported"))
    }
}

// ...

// 👇
fn inspect_each(attr: &syn::Attribute) -> Result<Option<Ident>> {
    use syn::{Lit, Meta, MetaList, MetaNameValue, NestedMeta};
    let meta = attr.parse_meta()?;
    match &meta {
        Meta::List(MetaList { path, nested, .. }) if path.is_ident("builder") => {
            if let Some(NestedMeta::Meta(Meta::NameValue(MetaNameValue { lit, path, .. }))) =
            nested.first()
            {
                match lit {
                    Lit::Str(s) if path.is_ident("each") => {
                        Ok(Some(format_ident!("{}", s.value())))
                    }
                    _ => Err(Error::new(
                        meta.span(),
                        "expected `builder(each = \"...\")`",
                    )),
                }
            } else {
                Err(Error::new(
                    meta.span(),
                    "expected `builder(each = \"...\")`",
                ))
            }
        }
        _ => Ok(None),
    }
}
```
`builder` attributeをうけとるために、top levelの関数のannotationを変更しています。  
具体的には、`#[proc_macro_derive(Builder, attributes(builder))]`のようにしてbuilder attributeを使うことを指示しています。  
attributeを値を抽出するhelperを定義。eachが指定されていたらbuilderのmethod生成時にVec型のsignatureを変更します。

無事テストをパスしました。

```console
❯ cargo test --quiet
running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/builder)
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.41s


test tests/07-repeated-field.rs ... ok
```

[source code](https://github.com/ymgyt/proc-macro-workshop/tree/9ab9a673c37c14c1b60177bad4e8c6175545a2b8)

## `08-unrecognized-attribute`

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    // ...
    t.compile_fail("tests/08-unrecognized-attribute.rs");
    // ...
}
```

`08-unrecognized-attribute`は意図しないattributeが渡された場合に適切なcompile errorを返せているかをチェックするテストです。具体的には以下のように`each`がtypoされています。

```rust
#[derive(Builder)]
pub struct Command {
    executable: String,
    //         👇
    #[builder(eac = "arg")]
    args: Vec<String>,
    env: Vec<String>,
    current_dir: Option<String>,
}
```

testを実行してみると以下のように意図したエラーメッセージとちょっとずれています。

```console
test tests/08-unrecognized-attribute.rs ... mismatch

EXPECTED:
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
error: expected `builder(each = "...")`
  --> tests/08-unrecognized-attribute.rs:22:7
   |
22 |     #[builder(eac = "arg")]
   |       ^^^^^^^^^^^^^^^^^^^^
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈

ACTUAL OUTPUT:
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
error: expected `builder(each = "...")`
  --> tests/08-unrecognized-attribute.rs:22:7
   |
22 |     #[builder(eac = "arg")]
   |       ^^^^^^^
┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
```

`^`を`builderから引数の終わりまでつけたいのですが、現状ではbuilderにしか付与されていません。これに対応するために以下のように変更します。

```rust
fn inspect_each(attr: &syn::Attribute) -> Result<Option<Ident>> {
    use syn::{Lit, Meta, MetaList, MetaNameValue, NestedMeta};
    let meta = attr.parse_meta()?;
    match &meta {
        Meta::List(MetaList { path, nested, .. }) if path.is_ident("builder") => {
            if let Some(NestedMeta::Meta(Meta::NameValue(MetaNameValue { lit, path, .. }))) =
            nested.first()
            {
                match lit {
                    Lit::Str(s) if path.is_ident("each") => {
                        Ok(Some(format_ident!("{}", s.value())))
                    }
                    _ => {
                        // 👇
                        Err(Error::new_spanned(
                            meta,
                            "expected `builder(each = \"...\")`",
                        ))
                    },
                }
            } else {
                // 👇
                Err(Error::new_spanned(
                    meta,
                    "expected `builder(each = \"...\")`",
                ))
            }
        }
        _ => Ok(None),
    }
}
```

具体的には、`syn::Error::new()`を`syn::Error::new_spanned()`に変更して、引数にspanではなく、直接`syn::Meta`を渡しました。

`syn::Error::new_spanned()`は以下のように定義されています。

```rust
/// Creates an error with the specified message spanning the given syntax
/// tree node.
///
/// Unlike the `Error::new` constructor, this constructor takes an argument
/// `tokens` which is a syntax tree node. This allows the resulting `Error`
/// to attempt to span all tokens inside of `tokens`. While you would
/// typically be able to use the `Spanned` trait with the above `Error::new`
/// constructor, implementation limitations today mean that
/// `Error::new_spanned` may provide a higher-quality error message on
/// stable Rust.
///
/// When in doubt it's recommended to stick to `Error::new` (or
/// `ParseStream::error`)!
#[cfg(feature = "printing")]
pub fn new_spanned<T: ToTokens, U: Display>(tokens: T, message: U) -> Self {
    let mut iter = tokens.into_token_stream().into_iter();
    let start = iter.next().map_or_else(Span::call_site, |t| t.span());
    let end = iter.last().map_or(start, |t| t.span());
    Error {
        messages: vec![ErrorMessage {
            start_span: ThreadBound::new(start),
            end_span: ThreadBound::new(end),
            message: message.to_string(),
        }],
    }
}
```

> Creates an error with the specified message spanning the given syntax
  tree node.

とあるので、syn側でいい感じにtoken treeからspanの開始と終了を組み立ててくれている様です。  
実装もstartとendを取得しているので、error messageを返す際はこのmethodを使っておけば直感的に問題のあるコードが指定されそうです。

無事テストも通りました。  
(stderrもテストできるtrybuildも便利で他にも使い道がありそうでもっと調べてみたくなります)

```console
❯  cargo test --quiet

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/builder)
    Checking derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.42s


test tests/08-unrecognized-attribute.rs ... ok
```

[source code](https://github.com/ymgyt/proc-macro-workshop/tree/c73568a39a76914af9d76c82b63ee38aabf0f7e6)

## `09-redefined-prelude-type`

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    // ...
    t.pass("tests/09-redefined-prelude-types.rs");
    // ...
}
```

最後のケースはstdのよく使われる型にaliasが設定されていても機能するかのテストです。  
具体的には以下のように`Option`や`Result`のaliasが設定されています。  
procedural macroに限らずdeclarative macroでも共通しますが、ユーザのimport/aliasに影響されないように型を参照する際はすべてフルパスにしておく必要があります。

```rust
type Option = ();
type Some = ();
type None = ();
type Result = ();
type Box = ();

#[derive(Builder)]
pub struct Command {
    executable: String,
}

fn main() {}
```

元々、`::core::option::Option`のように型をフルパスで指定していたので特に変更せずにテストをパスできます。

```console
❯ cargo test --quiet

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.13s


test tests/09-redefined-prelude-types.rs ... ok
```

## まとめ

今まではtest caseを一つずつ有効にしていましたが通しで実行してみましょう。

```rust
fn tests() {
    let t = trybuild::TestCases::new();
    t.pass("tests/01-parse.rs");
    t.pass("tests/02-create-builder.rs");
    t.pass("tests/03-call-setters.rs");
    t.pass("tests/04-call-build.rs");
    t.pass("tests/05-method-chaining.rs");
    t.pass("tests/06-optional-field.rs");
    t.pass("tests/07-repeated-field.rs");
    t.compile_fail("tests/08-unrecognized-attribute.rs");
    t.pass("tests/09-redefined-prelude-types.rs");
}
```

```console
❯ cargo test --quiet

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s


running 1 test
   Compiling derive_builder-tests v0.0.0 (/Users/ymgyt/rs/proc-macro-workshop-blog/target/tests/derive_builder)
    Finished dev [unoptimized + debuginfo] target(s) in 0.14s


test tests/01-parse.rs [should pass] ... ok
test tests/02-create-builder.rs [should pass] ... ok
test tests/03-call-setters.rs [should pass] ... ok
test tests/04-call-build.rs [should pass] ... ok
test tests/05-method-chaining.rs [should pass] ... ok
test tests/06-optional-field.rs [should pass] ... ok
test tests/07-repeated-field.rs [should pass] ... ok
test tests/08-unrecognized-attribute.rs [should fail to compile] ... ok
test tests/09-redefined-prelude-types.rs [should pass] ... ok
```

無事全てケースをパスできました🎉  
[source code](https://github.com/ymgyt/proc-macro-workshop/tree/1dc0ce4f7b86b4f9e97e79efce454793aef2a98e)

最終的には以下のようになりました。

```rust
use proc_macro::TokenStream;
use proc_macro2::TokenStream as TokenStream2;
use quote::{format_ident, quote};
use syn::spanned::Spanned;
use syn::{
    parse_macro_input, Data, DataStruct, DeriveInput, Error, Fields, FieldsNamed, Ident, Result,
    Type,
};

#[proc_macro_derive(Builder, attributes(builder))]
pub fn derive(input: TokenStream) -> TokenStream {
    let input: DeriveInput = parse_macro_input!(input as DeriveInput);

    match derive_builder(input) {
        Ok(token_stream) => TokenStream::from(token_stream),
        Err(err) => TokenStream::from(err.to_compile_error()),
    }
}

fn derive_builder(input: DeriveInput) -> Result<TokenStream2> {
    if let Data::Struct(DataStruct {
        fields: Fields::Named(FieldsNamed { named, .. }),
        ..
    }) = input.data
    {
        let ident = input.ident;
        let builder = format_ident!("{}Builder", ident);
        let fields = named
            .iter()
            .map(|f| (f.ident.as_ref().expect("field have ident"), &f.ty));
        let idents = fields.clone().map(|(ident, _)| ident);
        let builder_fields = fields
            .clone()
            .map(|(ident, ty)| quote! {#ident: ::core::option::Option<#ty>});
        let builder_init_fields = fields.clone().map(builder_init_field);
        let each_attributes = named.iter().map(|f| match f.attrs.first() {
            Some(attr) => inspect_each(attr),
            None => Ok(None),
        }).collect::<Result<Vec<_>>>()?;
        let builder_methods = fields
            .clone()
            .zip(each_attributes)
            .map(|((ident, ty), maybe_each)| impl_builder_method(ident, ty, maybe_each));

        Ok(quote! {
           struct #builder {
                #(#builder_fields),*
            }

            impl #builder {
                #(#builder_methods)*

                fn build(&mut self) -> ::core::result::Result<
                    #ident,
                    ::std::boxed::Box<dyn ::std::error::Error>
                >
                {
                    Ok(#ident {
                        #(
                            #idents: self.#idents.take().ok_or_else(||
                               format!("{} is not provided", stringify!(#idents))
                            )?
                        ),*
                    })
                }
            }

           impl #ident {
                fn builder() -> #builder {
                    #builder {
                        #(#builder_init_fields),*
                    }
                }
            }
        })
    } else {
        Err(Error::new(input.span(), "Only struct supported"))
    }
}

fn impl_builder_method(ident: &Ident, ty: &Type, each: Option<Ident>) -> TokenStream2 {
    let has_each = each.is_some();
    match field_type(ty) {
        FieldType::Option(inner_ty) => {
            quote! {
                fn #ident (&mut self, #ident: #inner_ty) -> &mut Self {
                    self.#ident = ::core::option::Option::Some(
                        ::core::option::Option::Some(#ident)
                    );
                    self
                }
            }
        }
        FieldType::Vec(inner_ty) if has_each => {
            let each = each.unwrap();
           quote! {
               fn #each (&mut self, #each: #inner_ty) -> &mut Self {
                   self.#ident.as_mut().map(|v| v.push(#each));
                   self
               }
           }
        }
        _ => {
            quote! {
                fn #ident (&mut self, #ident: #ty) -> &mut Self {
                    self.#ident = ::core::option::Option::Some(#ident);
                    self
                }
            }
        }
    }
}

fn builder_init_field((ident, ty): (&Ident, &Type)) -> TokenStream2 {
    match field_type(ty) {
        FieldType::Option(_inner_ty) => {
            quote! { #ident: ::core::option::Option::Some(::core::option::Option::None)}
        }
        FieldType::Vec(_inner_ty) => {
            quote! { #ident: ::core::option::Option::Some(::std::vec::Vec::new())}
        }
        FieldType::Raw => {
            quote! { #ident: ::core::option::Option::None}
        }
    }
}

fn field_type(ty: &Type) -> FieldType {
    use syn::{
        AngleBracketedGenericArguments, GenericArgument, Path, PathArguments, PathSegment, TypePath,
    };
    if let Type::Path(TypePath {
        qself: None,
        path: Path {
            leading_colon,
            segments,
        },
    }) = ty
    {
        if leading_colon.is_none() && segments.len() == 1 {
            if let Some(PathSegment {
                ident,
                arguments:
                    PathArguments::AngleBracketed(AngleBracketedGenericArguments { args, .. }),
            }) = segments.first()
            {
                if let (1, Some(GenericArgument::Type(t))) = (args.len(), args.first()) {
                    if ident == "Option" {
                        return FieldType::Option(t.clone());
                    } else if ident == "Vec" {
                        return FieldType::Vec(t.clone());
                    }
                }
            }
        }
    }
    FieldType::Raw
}

enum FieldType {
    Raw,
    Option(Type),
    Vec(Type),
}

fn inspect_each(attr: &syn::Attribute) -> Result<Option<Ident>> {
    use syn::{Lit, Meta, MetaList, MetaNameValue, NestedMeta};
    let meta = attr.parse_meta()?;
    match &meta {
        Meta::List(MetaList { path, nested, .. }) if path.is_ident("builder") => {
            if let Some(NestedMeta::Meta(Meta::NameValue(MetaNameValue { lit, path, .. }))) =
            nested.first()
            {
                match lit {
                    Lit::Str(s) if path.is_ident("each") => {
                        Ok(Some(format_ident!("{}", s.value())))
                    }
                    _ => {
                        Err(Error::new_spanned(
                            meta,
                            "expected `builder(each = \"...\")`",
                        ))
                    },
                }
            } else {
                Err(Error::new_spanned(
                    meta,
                    "expected `builder(each = \"...\")`",
                ))
            }
        }
        _ => Ok(None),
    }
}
```

簡単にですがbuilder projectをやってみました。  
synのAPIを理解して、実装したい型を適切に分割して部分的に組み立てられることがわかりました。  
token streamのparseはすでに実装されているので、rustのiterator等を普段と同じ様に使えるので非常に表現力が高いと感じました。また、`quote!`してしまうとTokenStreamになって型としては情報を失うので、できるだけ途中結果を表現する型を用意して、最後にquoteするようにしないとどんどん読みにくくなるなと感じました。今回の短い例でも、builderの初期値はこうなってるから...と考えながらやったのでより複雑なユースケースに対応するにはfiled毎のparse結果を保持する型を定義してユニットテスト書きながら行いたいと思いました。



[proc-macro-workshop]: https://github.com/dtolnay/proc-macro-workshop
[fraim]: https://fraim.co.jp/

