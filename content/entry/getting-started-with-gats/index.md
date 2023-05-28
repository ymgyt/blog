+++
title = "🦀 GATsに入門する"
slug = "getting-started-with-gats"
date = "2023-05-27"
draft = false
[taxonomies]
tags = ["rust"]
[extra]
image = "images/emoji/crab.png"
+++

 
RustのGeneric associated types(GATs)が[1.65.0](https://releases.rs/docs/1.65.0/)でstabilizeとなりました。  
ということで本記事では、GATsについての各種解説等を読みながら、GATsの理解を少しでも進めることを目指します。  
Rustのversionは`1.69.0`を利用しました。

## The push for GATs stabilization

まずは、2021年8月Rust blogの記事[The push for GATs stabilization](https://blog.rust-lang.org/2021/08/03/GATs-stabilization-push.html)から読んでいきます。  
そこでは、GATsの具体例として以下のcodeが挙げられています。

```rust
trait Foo {
    type Bar<'a>;
}
```

今までは、traitのassociated typeにはgenericsやlifetimeは書けなかったのですが、GATsによって書けるようになりました。  
以前、[Rustのlifetimeとvariance](https://blog.ymgyt.io/entry/lifetime-and-variance/)でも書いたのですが、`Vec<T>`が、`Vec<usize>`のように具体的な型を与えられてtypeになるように、`Bar<'a>`も具体的なlifetimeがあたえられてtypeになると理解しています。  
Associated typeのところにlifetimeが書けるとなにがうれしいかというと

```rust
impl<T> Foo for Vec<T> {
    type Bar<'a> = &'a T;
}
```

こんなcodeが書けるようになります。以前ですと、`&'a T;`の`'a`は実装するstructに定義されている必要がありました。  
ちなみに上記のcodeはcompileが通りません。

```
   |
82 |     type Bar<'a> = &'a T;
   |                    ^^^^^- help: consider adding a where clause: `where T: 'a`
   |                    |
   |                    ...so that the reference type `&'a T` does not outlive the data it points at
```

compile通すには結果的に以下のようになりました。  

```rust
trait Foo {
    type Bar<'a>
    where
        Self: 'a;
}

impl<T> Foo for Vec<T> {
    type Bar<'a> = &'a T
    where T: 'a;
}
```

`T`は実際には`&str`かもしれないので、`&str: 'a`の制約が必要といわれるのはなんとなくわかります。

次にもう少し具体的な利用例が紹介されます。  
ここではmut sliceのwindow(sub slice)を返すiteratorを実装したいというユースケースです。  
具体的には`[1,2,3,4,5]`があったときに`[1,2,3], [2,3,4], [3,4,5]`を返すようなiteratorです。 


```rust
struct WindowsMut<'t, T> {
    slice: &'t mut [T],
    start: usize,
    window_size: usize,
}
```

この`WindowsMut`に`Iterator`を実装しようとすると

```rust
impl<'t, T> Iterator for WindowsMut<'t, T> {
    type Item = &'t mut [T];

    fn next<'a>(&'a mut self) -> Option<Self::Item> {
        let retval = self.slice[self.start..].get_mut(..self.window_size)?;
        self.start += 1;
        Some(retval)
    }
}
```

```
error: lifetime may not live long enough
  --> src/lending.rs:21:9
   |
15 | impl<'t, T> Iterator for WindowsMut<'t, T> {
   |      -- lifetime `'t` defined here
...
18 |     fn next<'a>(&'a mut self) -> Option<Self::Item> {
   |             -- lifetime `'a` defined here
...
21 |         Some(retval)
   |         ^^^^^^^^^^^^ method was supposed to return data with lifetime `'t` but it is returning data with lifetime `'a`
   |
   = help: consider adding the following bound: `'a: 't`
```

`self.slice`の参照を返しているので、`'a: 't`の制約が必要となり、compile errorとなります。  

```rust
fn next<'a>(&'a mut self) -> Option<Self::Item>
where
    'a: 't,
{ /* ... */ }
```

のように`where 'a: 't'`をつけると今度は

```
error[E0195]: lifetime parameters or bounds on method `next` do not match the trait declaration
  --> src/lending.rs:18:12
   |
18 |     fn next<'a>(&'a mut self) -> Option<Self::Item>
   |            ^^^^ lifetimes do not match method in trait
```

`Iteraotr` traitにそんな制約はないのでこれもcompile errorとなってしまいます。


そこで、GATsを利用した、`LendingIterator`を定義します。

```rust
trait LendingIterator {
    type Item<'a>
    where
        Self: 'a;

    fn next<'a>(&'a mut self) -> Option<Self::Item<'a>>;
}
```

これは`self.next()`の戻り値を利用している間だけ有効な`Item`を返す`Iterator`と読めます。

```rust
impl<'t, T> LendingIterator for WindowsMut<'t, T> {
    type Item<'a>
    where
        Self: 'a,
    = &'a mut [T];

    fn next<'a>(&'a mut self) -> Option<Self::Item<'a>> {
        let retval = self.slice[self.start..].get_mut(..self.window_size)?;
        self.start += 1;
        Some(retval)
    }
}
```

実装は`Iterator`と同じですが、`Item`のlifetimeに呼び出し時のlifetimeを渡せています。

```rust
fn main() {
    let mut v = [1, 2, 3, 4, 5];

    let mut w = WindowsMut {
        slice: &mut v,
        start: 0,
        window_size: 3,
    };

    while let Some(window) = w.next() {
        println!("{window:?}");
    }
}

// => [1, 2, 3]
// => [2, 3, 4]
// => [3, 4, 5]
```

無事、windowを返すことができました。  
記事でも触れられていますが、`type Item<'a> where Self: 'a`がなぜ必要かというと  
`fn next<'static>(&'static mut self) -> Option<Self::Item<'static>>` のようなcodeを書けなくするためみたいです。  
この点は[issue](https://github.com/rust-lang/rust/issues/87479)になっており将来的には暗黙的に仮定されるかもしれません。

## Generic Associated Types Initiative

次は[Generic Associated Types Initiative](https://github.com/rust-lang/generic-associated-types-initiative)が提供してくれているbookをみていきます。 
GATsに関する過去あった議論も整理されており、RFCやissueのコメントは長く全部読むのは大変なので助かりました。  
例えば、GATsはRustの[複雑度を上げすぎてしまう懸念](https://rust-lang.github.io/generic-associated-types-initiative/mvp/concern-too-complex.html)の話は頷けるところ多かったです。   

### `Iterable` trait

次は`Iterable` traitを通してGATsの使い所をみていきます。  

まず以下のように今まで通り`Iterator`を実装してみます。

```rust
struct Iter<'c, T> {
    data: &'c [T],
}

impl<'c, T> Iterator for Iter<'c, T> {
    type Item = &'c T;

    fn next(&mut self) -> Option<Self::Item> {
        if let Some((head, remain)) = self.data.split_first() {
            self.data = remain;
            Some(head)
        } else {
            None
        }
    }
}
```

ここで次のように、ある処理の中で複数回iterateしたいので、iteratorを返せるcollectionを引数にした処理を書きたいとします。  

```rust
fn count_twice<I: Iterator>(collection: I) {
    let mut count = 0;
    for _ in collection {
        count += 1;
    }

    for elem in collection {
        process(elem, count)
    }
}

fn process<T>(_elem: T, _count: usize) {}
```

これは以下のように2回目のfor loopでmoveした値を利用しているのでcompileが通りません。

```
28  |     for elem in collection {
    |                 ^^^^^^^^^^ value used here after move
    |
```

ということで、`Iterator`を返せることを抽象化した`Iterable` traitを作ることにします。

```rust
trait Iterable {
    type Item;

    type Iter: Iterator<Item = Self::Item>;

    fn iter<'c>(&'c self) -> Self::Iter;
}
```

`Iter`が`Iterator`で`Item`を返します。[`IntoIterator`](https://doc.rust-lang.org/std/iter/trait.IntoIterator.html)の`&self`版といった感じです。  
`&[T]`は複数回`Iterator`を返せるので`Iterable`を実装したいところですが..

```rust
impl<T> Iterable for [T] {
    type Item = &'what T; // 👈

    type Iter = Iter<'what, T>; // 👈

    fn iter<'c>(&'c self) -> Self::Iter {
        //        ^^ このlifetimeを'whatで使いたい
        Iter { data: self }
    }
}
```

ここで`&'what` lifetimeをどこからもってくるかで問題が生じます。GATsがないと今までは、`impl<'a> Iterable for A<'a>`のようにimplにlifetime書く必要がありましたが、今回の`[T]`にはlifetimeがでてきません。  
というわけで、`Iterable` traitをGATsを使って書き直します。

```rust
trait Iterable {
    type Item<'collection>
    where
        Self: 'collection;

    type Iterator<'collection>: Iterator<Item = Self::Item<'collection>>
    where
        Self: 'collection;

    fn iter<'c>(&'c self) -> Self::Iterator<'c>;
}
```

`Item`と`Iter`にlifetimeを渡したいので、trait側で定義します。  
実装はtrait側のlifetimeを使うだけです。  

```rust
impl<T> Iterable for [T] {
    type Item<'c> = &'c T where T: 'c;

    type Iterator<'c> = Iter<'c,T> where T: 'c;

    fn iter<'c>(&'c self) -> Self::Iterator<'c> {
        Iter { data: self }
    }
}
```

`fn count_twice<I: Iterable + ?Sized>(collection: &I) { /* ... */}` Sized制約をopt outすると無事compileが通りました。

```rust
fn main() {
    let array = [1, 2, 3];
    count_twice(array.as_slice());
}
```

要はGATsによって、呼び出し側が使っている間だけ有効な`self`のdataの参照を返せるようになったと理解しています。

bookにはGATsを実際に利用している[crateのlist](https://rust-lang.github.io/generic-associated-types-initiative/design_patterns.html)も載っていたりしました。  
また、`Iterable`や`LendingIterator`以外にも、GATsのdesign patternとして、Many modeやgenerics scopesも取り上げられていました。  
Many modeについてはわからないことが多く、今後の課題です。


## まとめ

GATsの一利用例をみてきました。今後はlibrary等でも使われてくることが増えてくるのではと思っているのでうまい使い所を見つけていきたいです。  


## 参考

* [PR](https://github.com/rust-lang/rust/pull/96709/)
* [RFC PR](https://github.com/rust-lang/rfcs/pull/1598)
* [RFC](https://github.com/rust-lang/rfcs/blob/master/text/1598-generic_associated_types.md)
* [A shiny future with GATs](https://jackh726.github.io/rust/2022/05/04/a-shiny-future-with-gats.html)
* [Associated type constructors, part 1](http://smallcultfollowing.com/babysteps/blog/2016/11/02/associated-type-constructors-part-1-basic-concepts-and-introduction/)
* [Associated items rust nightly reference](https://doc.rust-lang.org/nightly/reference/items/associated-items.html)
* [GATsを必要としていたcrates](https://github.com/rust-lang/rust/pull/96709#issuecomment-1173170243)
* [Strong concerns about GAT stabilization](https://github.com/rust-lang/rust/pull/96709#issuecomment-1129311660)
* [Generic Associated Types initiative](https://rust-lang.github.io/generic-associated-types-initiative/index.html)