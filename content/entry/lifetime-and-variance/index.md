+++
title = "🦀 Rustのlifetimeとvariance"
slug = "lifetime-and-variance"
date = "2021-03-21"
draft = false
[taxonomies]
tags = ["rust"]
+++

[nomicon](nomicon) を読んでいて[Subtyping and Variance](https://doc.rust-lang.org/nomicon/subtyping.html) の話がでてきたときにどうして継承の概念がないRustにvarianceの話がでてくるのかなと思っていました。  
その後、Rustの動画をyoutubeに投稿されている[Jon Gjengsetさん](https://twitter.com/jonhoo) の[Crust of Rust: Subtyping and Variance](https://www.youtube.com/watch?v=iVYWDIW71jk&ab_channel=JonGjengset) を見て自分なりにすこし理解が進んだのでブログに書くことにしました。

具体的にはnomiconに記載されているvarianceのテーブルのうち以下の理解を試みます。


|              |  `'a`         | `T`           |  `U`      |
| ------------ | ------------- | ------------- | --------- |
| `&'a T`      | covariant     | covariant     |           |
| `&'a mut T`  | covariant     | invariant     |           |
| `fn(T) -> U` |               | contravariant | covariant |
| `Cell<T>`    |               | invariant     |           |

## CHANGELOG

* 2023-02-08 fix: update broken link to https://github.com/sunshowers-code/lifetime-variance

## Subtypeの意味

形式的には２つの型があるときにあるかないかの関係。  
メンタルモデルとしては、and moreとか、[少なくとも同程度には役立つ(at least as useful as)と説明](https://youtu.be/iVYWDIW71jk?t=1627) されています。  
Cat is an Animal and more みたいな。  

## Lifetimeとsubtype

[nomicon][nomicon] ではfairly arbitary constructと前置きをおきつつもlifetimeを型としてとらえることができると書かれています。  
どういうことかというと、lifetimeはコードの領域(regions of code)のことで、コードの領域は含んでるか含んでないかの関係を考えることができる。あるコード領域(`'big`)が別のコード領域(`'small`)を含んでいるとき  
`'big`は`'small`のsubtypeといえます。
subtypeの関係をand moreと考えると、`'big` is `'small` and moreといえるので筋がとおっていますね。

こんなイメージ。
```
{ 
  let x: 'big = ...
  {
    let y: 'small = ...
    // ...
  }
}
```

`'static`は他のlifetimeをoutlivesするので、全てのlifetimeのsubtypeと考えられます。

ただし、lifetimeそれ自体で単独の型になることはなく、かならず `&'a u32`や`iterMut<'a, u32>`のようにある型の一部として現れる。そこで、subtypeを組み合わせたときにどうなるのかの話になりvarianceがでてきます。


## Variance

varianceとはtype constructorがもつ性質。Rustでいうtype constructorとは型`T`をうけとって`Vec<T>`を返す`Vec`だったり、`&`や`&mut`のこと。以後は[nomicon][nomicon]の例にならって`F<T>`と書きます。  
型`Sub`が型`Super`のsubtypeとして、varianceはcovariant, contravariant, invariantの3種類に分類できます。  
以下それぞれについて見ていきます。

### covariant

`F<Sub>`が`F<Super>`のsubtypeならcovariant。  
`s: &'a str`型に`&'static str`を渡せるのは、`&`がcovariantだからといえます。  
(`'static` subtype `'a`) -> (`&'static str` subtype `&'a str`)  
引数の型のsubtypeの関係が戻り値の型の関係にそのまま反映されるので素直で直感的な関係だと思います。  

```rust
let s = String::new();
let x: &'static str = "hello world";
let mut y/* :&'y str */ = &*s;
let y = x;
```

### contravariant

`F<Super>`が`F<Sub>`のsubtypeならcontravariant。  
これだけみてもよくわからないので具体例をみていきます。

```rust
pub fn contravariant(f: fn(&'static str) -> ()) {
    f("hello")
}
```
この関数に`fn(&'a str) -> ()`な関数を渡せるということをいっています。
`'a`は`'static`のsuper typeなので`Fn(&'a str) -> ()`は`Fn(&'static str)`のsubtypeになります。  
意味としては上記の`contravariant`関数は渡された関数に`'static` lifetimeをもつ変数を渡してよびだしてくれると読めます。その関数に必ずしも永続する必要はなく渡した関数の実行中だけ有効な文字列で十分なclosureを渡せるという感じでしょうか。引数に対する制約を弱くした関数はつよい制約を要求する関数のsubtypeになると考えれば自然といえるのではないでしょうか。

### invariant

もう一度variance表をみてみるとinvariantは以下のように定義されています。

|              |  `'a`         | `T`           | 
| ------------ | ------------- | ------------- | 
| `&'a mut T`  | covariant     | invariant     | 

まず`T`についてinvariantからみていきます。`T`についてinvariantなおかげで以下のようなコードのcompileがとおらないようになってくれます。

```rust
pub fn invariant_1<'a>(s: &mut &'a str, x: &'a str) {
    *s = x;
}

fn invariant_1_no_compile() {
    let mut x: &'static str = "hello";
    let z = String::new();

    // signature:  &mut &'a      str, &'a str
    // providing:  &mut &'static str, &'a str

    invariant_1(&mut x, &*z);

    drop(z);
    println!("{}", x);
}
```
もしcompileが通ってしまうと、`'static`な参照のはずがdropされた領域を参照できてしまうことになってしまいます。  
compile errorになってくれる理由は、`&'a mut T`がTについてinvariantなおかげで  
`&'a mut &'static str`が`&'a mut &'a str`のsubtypeにならないからです。`&'static str`は`&`がcovariantなので`&'a str`のsubtypeですが、その関係は`& mut`で変換されると維持されません。

次に`'a`についてはcovariantについて。
```rust
fn test_mut_ref_covariant() {
    let mut y = true;
    let mut z /*&'y bool */ = &mut y;

    let x = Box::new(true);
    let x: &'static mut bool = Box::leak(x);

    z = x; // &'a mut bool <- &'static mut bool
}
```

`Box::leak()`でheapに確保した値の`&'static mut`参照を作れます。  
`&'a mut T`が`'a`についてはcovariantなおかげで、lifetimeがより長い場合には自然な代入が許可されますね。

## `Cell<T>`

Cellについては[lifetime-variance-example]に非常にわかりやすい例がのっています。
`Cell<T>`はTについてinvariantなので`Cell<&'static str>`は`Cell<&'a str>`のsubtypeになれません。なので以下の関数はcompileできません。

```rust
fn cell_shortener<'a, 'b>(s: &'a Cell<&'static str>) -> &'a Cell<&'b str> {
    s
}
```

なんとなくですが`Cell<&'a str>`型に`Cell<&'static str>`をassignできても問題ないように思えます。しかし以下の例からそれは認められないことがわかります。

```rust
fn cell_counterexample() {
    let foo: Cell<&'static str> = Cell::new("foo");
    let owned_string: String = "non_static".to_owned();
  
    // If we pretend that cell_shortener works
    let shorter_foo = cell_shortener(&foo);
  
    // then shorter_foo and foo would be aliases of each other, which would mean that you could use
    // shorter_foo to replace foo's Cell with a non-static string:
    shorter_foo.replace(&owned_string);
  
    // now foo, which is an alias of shorter_foo, has a non-static string in it! Whoops.
}
```
https://github.com/sunshowers/lifetime-variance-example/blob/ac8fc6cbee7bfd9b70a8c58973a891ed8a5482a7/src/lib.rs#L62

たしかに`Cell<T>`をcovariantにしてしまうと危険な操作が可能になってしまいます。  
結局はinterior mutabilityを提供している型は実質的には`&mut`と同じことができることの帰結といえるんでしょうか。



## 具体例

### `strtok`

ここでは[Crust of Rust: subtyping and Variance]でとりあげられていた例をみていきます。以下のような関数を考えます。

```rust
pub fn strtok<'a>(s: &'a mut &'a str, delimiter: char) -> &'a str {
    if let Some(i) = s.find(delimiter) {
        let prefix = &s[..i];
        let suffix = &s[(i + delimiter.len_utf8())..];
        *s = suffix;
        prefix
    } else {
        let prefix = *s;
        *s = "";
        prefix
    }
}
```
c++の[strtok](http://www.cplusplus.com/reference/cstring/strtok/) という関数らしいです。処理内容自体は重要ではないのですが、引数の文字列sをdelimiterでsplitして最初のelementを返し、sを次のelementの先頭にセットします。連続してよぶことで、RustでいうところのsplitしてIteratorを取得する感じの関数です。  

```rust
#[test]
fn test_strtok() {
    let mut x: &'static str = "hello world";

    strtok(&mut x, ' ');
}
```

`strtok`を上記のように呼び出すとcompile errorになります。

```
error[E0597]: `x` does not live long enough
   --> src/main.rs:115:16
    |
113 |         let mut x: &'static str = "hello world";
    |                    ------------ type annotation requires that `x` is borrowed for `'static`
114 |
115 |         strtok(&mut x, ' ');
    |                ^^^^^^ borrowed value does not live long enough
116 |     }
```

なにがおきているかというと  
```
// 'aはgenericで 'xは具体的なlifetimeと思ってください。

// signature: <'a> &'a mut  &'a      str
// providing:      &'x mut  &'static str
               
// signature:      &'static &'static str
// providing:      &'x mut  &'static str

// signature:      &'static &'static str
// providing:      &'static mut  &'static str
```

変数`x`の`'static` lifetiemと`strtok`のlifetimeの型からlifetime generic `'a`が`'static`と解釈され、最終的に  
`strtok(& /* 'static */ mut x)`になってしまうが、xはstack変数なのでstaticではなく "does not live long enough"になってしまう。(という理解です)

そこでどうすればよいかというと、問題は`strtok`のlifetime genericがひとつしかないために`&mut x`自体のlifetimeもひきづられて`'sattic`になってしまうことだったので以下のように修正します。

```rust
pub fn strtok_2<'a, 'b>(s: &'a mut &'b str, delimiter: char) -> &'b str {/* */}
```

こうするとこでcompileがとおるようになりはれてテストも書けるようになりました。

```
// signature: <'a, 'b> &'a mut &'b      str
// providing:          &'x mut &'static str

// signature:          &'x mut &'static str
// providing:          &'x mut &'static str
```

```rust
#[test]
fn test_strtok() {
    let mut x: &'static str = "hello world";

    let hello = strtok_2(&mut x, ' ');
    
    assert_eq!(hello, "hello");
    assert_eq!(x, "world");
}
```

ちなみにこうでもOK  
`pub fn strtok<'s>(s: &'_ mut &'s str, delimiter: char) -> &'s str {/* */}`

### `evil_feeder`

次にnomiconの例をみてみます。

```rust
fn evil_feeder<T>(input: &mut T, val: T) {
    *input = val;
}

fn main() {
    let mut mr_snuggles: &'static str = "meow! :3";  // mr. snuggles forever!!
    {
        let spike = String::from("bark! >:V");
        let spike_str: &str = &spike;                // Only lives for the block
        evil_feeder(&mut mr_snuggles, spike_str);    // EVIL!
    }
    println!("{}", mr_snuggles);                     // Use after free?
}
```
この例も以下のように解釈されてcompile errorになります。

```
// signature: &'a mut T           , T
// providing: &'a mut &'static str, &'spike str

// signature: &'a mut &'static str, &'static str
// providing: &'a mut &'static str, &'spike str
```

となって、`&'static str`に`&'spike str`は渡せなくなります。

### `MessageCollector`

最後に[lifetime-variance-example]にのっていた実際に遭遇しそうな`&mut`のvarianceが影響する例をとりあげます。リンク先のコードではより詳細にstep by stepの解説があります。

```rust
use std::collections::HashSet;
use std::fmt;

struct Message<'msg> {
    message: &'msg str,
}

struct MessageDisplayer<'a> {
    list: &'a Vec<Message<'a>>,
}

impl<'a> fmt::Display for MessageDisplayer<'a> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        for message in self.list {
            write!(f, "{}\n", message.message);
        }
        Ok(())
    }
}

struct MessageCollector<'a> {
    list: &'a mut Vec<Message<'a>>
}

impl<'a> MessageCollector<'a> {
    fn add_message(&mut self, message: Message<'a>) {
        self.list.push(message)
    }
}

fn collect_and_display<'msg>(message_pool: &'msg HashSet<String>) {
    let mut list = vec![];

    let mut collector = MessageCollector { list: &mut list };
    for message in message_pool {
        collector.add_message(Message { message });
    }

    let displayer = MessageDisplayer { list: &list };
    println!("{}", displayer);
}
```

```
error[E0502]: cannot borrow `list` as immutable because it is also borrowed as mutable
  --> src/main.rs:39:46
   |
34 |     let mut collector = MessageCollector { list: &mut list };
   |                                                  --------- mutable borrow occurs here
...
39 |     let displayer = MessageDisplayer { list: &list };
   |                                              ^^^^^
   |                                              |
   |                                              immutable borrow occurs here
   |                                              mutable borrow later used here
```

問題は`MessageCollector`の定義にあります。
```
struct MessageCollector<'a> {
    list: &'a mut Vec<Message<'a>>
}
```
` collector.add_message(Message { message });` ここのmessageのlifetimeが関数全体に及ぶのでひきづられて`MessageCollector`のlistに対する`&mut`参照も関数全体におよび、compilerが`&mut`のlifetimeを縮めることができなくなってしまい、immutable refがエラーになってしまいます。

`MessageCollector`の定義を以下のようにするとcompileがとおるようになります。

```rust
struct MessageCollector2<'a, 'msg> {
    list: &'a mut Vec<Message<'msg>>
}

impl<'a,'msg> MessageCollector2<'a,'msg> {
    fn add_message(&mut self, message: Message<'msg>) {
        self.list.push(message)
    }
}
```

## まとめ

* `&`,`&mut`はtype converterと考えるといろいろcompilerの挙動の説明がつく。
* `&mut`における危険な操作がinvariantとして禁止されていたりとlifetimeが型として表現されている。
* Drop checkの挙動を制御したりする関係で、`PhantomData`等で型のvarianceをコントロールするみたいなトピックについてはまだまだわかっていない。


[nomicon]: https://doc.rust-lang.org/nomicon/index.html
[Crust of Rust: Subtyping and Variance]: https://www.youtube.com/watch?v=iVYWDIW71jk&ab_channel=JonGjengset
[lifetime-variance-example]: https://github.com/sunshowers-code/lifetime-variance

