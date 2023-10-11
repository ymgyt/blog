+++
title = "📗 もっとCPUの気持ちが知りたいですか？を読んだ感想"
slug = "cpu_no_kimochi"
date = "2022-11-27"
draft = false
description = "CPUの気持ち本を読んだ感想"
[taxonomies]
tags = ["book"]
+++

## 読んだ本

{{ figure(caption="出村 成和 著", images=["images/cpu_no_kimochi_book.png"] )}}

[もっとCPUの気持ちが知りたいですか？](https://peaks.cc/cpu_no_kimochi)  
タイトルに惹かれて読んでみたので感想を書きます。(電子書籍 初版) 
目次は[本書のWebページ](https://peaks.cc/cpu_no_kimochi)から見れます。  
以下のような方が対象読者として挙げられていました。

> ■ CPU の内部で行われていること（主にソフトウェア方面）を理解したい人

> ■ CPU の挙動を理解した上でコードを書きたい人


## まとめ

* CPUについて知りたいと思った際に最初に読む本としてオススメしたいです。自分は最初にこの本読んでおきたかったなと思いました。

## 第1章 CPUの気持ちを知るということ

CPUの気持ち(CPUの仕組みや行われている処理)を理解しているとどういったメリットがあるかについて。  

Flutterといったクロスプラットフォームなフレームワークを使っていても肌間でOSやプラットフォーム依存の実装が必要な箇所が1~2割くらいあるという話がのっていました。以前React Nativeを利用したプロジェクトの際にiOS詳しい方がそういった箇所を担当されており、そういうものなのだなと思いました。

ソフトウェアを  

```
アプリケーション  
ミドルウェア
ライブラリ
os (software)
-------------
cpu (hardware)
```

というスタックとして捉えるとCPUがsoftとhardの境界にあたるのでアプリケーションとcpuの知識からミドルウェアやosを学ぶアプローチが紹介されていました。  
自分は最近[Green Threads Explained in 200 Lines of Rust](https://cfsamson.gitbook.io/green-threads-explained-in-200-lines-of-rust/)という記事を読んでいたのですが、Green threads(Goのgoroutine等)を理解するためには結局CPUの内部構造わかっている必要があり、CPUへの理解は必須でどうにか理解を深めたいと思っていました。

また、CPUと関連の知識はプログラミング言語の挙動の理解にも有用であるとされており、例としてポインターが挙げられていました。  
自分がプログラミングでCPUの理解が足りていないと強く感じたのは、[atomicのordering関連](https://doc.rust-lang.org/nomicon/atomics.html)です。
[並行プログラミング入門](https://www.oreilly.co.jp/books/9784873119595/)で`atomic::Ordering::SeqCst`等がCPUのどういった命令に対応しているといった話がでてきて、CPUについてもっと知りたいなと思うようになりました。


## 第2章 CPUと友達になろう

実行ファイルの概要を、加算を行う処理をCで書いて、compileしたのちobjdumpでdisassembleしながら説明してくれます。

## 第3章 アセンブリ言語をなんとなく読む

`x = 2`のような変数への代入が

```
mov w9, #2
str w9, [sp, #24]
```

のような命令に変換される例を通してアセンブリの概要の説明があります。  
アセンブリってどうしても業務や日々の開発で使わないのでどうも身につかないです。Rustの実行ファイルを読めるようになるなら[大熱血！ アセンブラ入門](https://www.amazon.co.jp/dp/B07CMMVY5J)等をやってみようかななどと思っていたりします。

## 第4章 CPUをざっくり把握する

CPUを構成するコンポーネントが命令を実行する際にどういった役割を果たすかが説明されます。  
命令セットアーキテクチャーとマイクロアーキテクチャーの２つを理解しておくとよいとされています。自分も最初はx86とamd64って同じなのか違うものなのか混乱していたりしました。

## 第5章 値を扱う(レジスター)

レジスターについての説明。  
汎用レジスターといいつつ、汎用でなかったりする説明はもっと早く知りたかったです。  
暗黙的に変更されるステータスレジスターの説明が丁寧でわかりやすかったです。

## 第6章 CPUができることは多くない(命令)

命令を以下のように分類してそれぞれ説明してくれます。  

* ロード/ストア命令
* 算術演算
* 論理演算
* 比較命令
* 並列命令
* 分岐命令
* その他

比較命令(`cmp`)って減算を行ってステータスレジスターを更新する処理だったんですね。  
SIMD命令について具体例もあってわかりやすかったです。

## 第7章 道は分かれる(分岐命令)

10章のパイプラインに関わってくることから分岐命令について、丁寧に説明されます。直前の命令の実行結果がステータスレジスターに書き戻されて初めて次に実行する命令が決まるという点がパイプライン処理で問題になるという理解です。

## 第8章 シンプルなCPU、複雑なCPU(RISCとCISC)

RISC(Reduced Instruction Set Computer)とCISC(Complex Instruction Set Computer)について。  
ロード・ストア アーキテクチャーである点や命令が固定長であること等の観点からRISCとCISCを比較しながら説明してくれます。  
RISCのReducedは命令数ではなくメモリアクセスへの頻度を指しているというのは知りませんでした。

## 第9章 記憶の仕組み(メインメモリ)

CPUとメモリの関係について。  
バイトオーダーやアライメントについての説明があります。

## 第10章 処理を効率よく実行する仕組み(パイプライン)

命令の実行を複数の処理に分割して、同時に実行できる命令を増やすパイプラインについて。  
理想状態では、命令をもっとも効率的に実行し、1クロック1命令が実行できるが現実は次の命令を直ちに実行できない事情が存在する。  
代表例として、前回の結果に依存する場合と、条件分岐命令が挙げられる。
このような場合にもパイプラインの実行効率を落とさないための工夫があり、以下が解説されています。

* スーパースカラー
* アウトオブオーダー実行
* 分岐予測
* 投機的実行

最初にCPUの仕組みについて知りたいと思ったのはatomic関連の話で実際のプログラムはソースコードの通りに上から実行される訳ではないという話を知ったときでした。([さらにcompilerだけでなくhardware側でもreorderされたり](https://doc.rust-lang.org/nomicon/atomics.html#hardware-reordering))

自分は分岐予測や投機的実行がよくわかっておらずこのあたりの解説が読みたいと思っていました。条件分岐やパイプラインが丁寧に説明されているのでなぜ分岐予測や投機的実行が必要かがとてもわかりやすかったです。  
`if false { }`のように実行時にtrueでなくてもifのblockがCPUでは実行されているってすごいですよね。実行結果は捨てられるらしいのですが副作用ある処理だったらどうなるのかなという疑問が生じます。条件の結果がレジスターに書き戻されるまでの話だから投機的に実行されるのも数命令程度という話なのかもしれませんが。

分岐予測には、静的か動的かで分類できるそうです。  
静的分岐予測は、compilerが命令を並び替えたりする手法。具体的にどういった命令の並び替えが行われるかの具体例がなかったので気になりました。C++20では

```cpp
constexpr double pow(double x, long long n) noexcept {
    if (n > 0) [[likely]]
        return x * pow(x, n - 1);
    else [[unlikely]]
        return 1;
}
```

https://en.cppreference.com/w/cpp/language/attributes/likely

のようにifに`[[likely]]`と書いてソースコードで分岐に関する情報をcompilerに伝えられるようです。すごい。

## 第11章 手が届く範囲にモノがあると便利だよね(キャッシュメモリ)

CPUとcacheについて。  
cacheを意識するかしないかでどれくらい速度に差がでるか検証するCのコードが載っていたので、Rustで書いて試してみました。

`Cargo.toml`

```toml
[dev-dependencies]
criterion = "0.3.0"

[[bench]]
name = "cache"
harness = false
```

`benches/cache.rs`

```rust
use criterion::{criterion_group, criterion_main, Criterion, BatchSize};

type Data = Vec<Vec<i64>>;

const D: i64 = 100;

#[derive(Clone)]
struct Input {
    buff_size: usize,
    a: Data,
    b: Data,
    answer: Data,
}

fn init_input(buff_size: usize) -> Input {
    let answer = vec![vec![0_i64; buff_size]; buff_size];
    let mut a = vec![vec![0_i64; buff_size]; buff_size];
    let mut b = vec![vec![0_i64; buff_size]; buff_size];

    for i in 0..buff_size {
        for j in 0..buff_size {
            a[i][j] = j as i64;
            b[i][j] = j as i64;
        }
    }

    Input {
        buff_size,
        a,
        b,
        answer,
    }
}

fn access_in_order(Input { buff_size, a, b, answer }: &mut Input) {
    let buff_size = *buff_size;
    for i in 0..buff_size {
        for j in 0..buff_size {
            answer[i][j] = a[i][j] * b[i][j] + D;
        }
    }
}

fn access(Input { buff_size, a, b, answer }: &mut Input) {
    let buff_size = *buff_size;
    for i in 0..buff_size {
        for j in 0..buff_size {
            answer[j][i] = a[j][i] * b[j][i] + D;
        }
    }
}


fn benchmark(c: &mut Criterion) {
    let buff_size = 0x2000;
    let mut group = c.benchmark_group("cache");
    let input = init_input(buff_size);

    group.bench_function("access_in_order", |b| {
        b.iter_batched(|| input.clone(), |mut input| access_in_order(&mut input), BatchSize::SmallInput)
    });

    group.bench_function("access", |b| {
        b.iter_batched(|| input.clone(), |mut input| access(&mut input), BatchSize::SmallInput)
    });
}

criterion_group! {
    name = bench_main;
    config = Criterion::default();
    targets = benchmark
}

criterion_main!(bench_main);
```

結果

```
❯ cargo criterion -- --sample-size=10
    Finished bench [optimized] target(s) in 0.03s
Gnuplot not found, using plotters backend
cache/access_in_order   time:   [145.88 ms 148.53 ms 151.90 ms]                                
Benchmarking cache/access: Warming up for 3.0000 s
Warning: Unable to complete 10 samples in 5.0s. You may wish to increase target time to 47.4s.
cache/access            time:   [4.2983 s 4.5101 s 4.6564 s]                          
```


ということで、cacheを考慮した`access_in_order`のほうが速い結果が再現できました。  
`pref`コマンドの使い方も載っており、とても参考になりました。

{{ figure(caption="criterion出力結果", images=["images/cpu_no_kimochi_bench.png"]) }}

## 第12章 CPUと周辺機器との結びつき(I/O)

CPUが周辺機器とやりとりする際にメモリマップどI/Oという仕組みでメモリ経由でデータを読み書きしているという話。  
[基礎から学ぶ 組込みRust](https://www.c-r.com/book/detail/1403)をやった際に出てきた気がします。  

## 第13章 多くの仕事を差し込まれる立場です(割り込み)

割り込みについての説明。  
ベクターテーブルが割り込み次にどのように参照されるか等のっており、割り込みの説明としてとてもわかりやすかったです。  
[Writing an OS in RustのCPU Exceptions](https://os.phil-opp.com/cpu-exceptions/)を読んだ際にInterrupt Descriptor Tableがよくわからなかったので最初にこの説明読んでいたらと思いました。

## 付録A 次に読むべき本

次に読む本のオススメが挙げられています。 
パタヘネ本(コンピューターの構成と設計)も載っていました。(第5版とありますが、第6版でてます)  
パタヘネ本はオススメされて一度読んでみたのですが難しく理解できないところも多かったので理解を深めてから再挑戦したいです。  
そしてここでも挙がるCPUの造り方。2003年の本ですが今でもオススメに上がり続けるのすごいなと思っています。  
自分はプロセッサを支える技術を読んでみようと思いました。

