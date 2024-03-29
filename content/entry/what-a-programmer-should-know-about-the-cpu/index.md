+++
title = "📕 プログラマーのためのCPU入門を読んだ感想"
slug = "what-a-programmer-should-know-about-the-cpu"
description = "プログラマーのためのCPU入門がとてもわかりやすかったです"
date = "2023-03-15"
draft = false
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/closed_book.png"
+++

## 読んだ本


{{ figure(images=["images/what-a-programmer-should-know-about-the-cpu-book.png"], href="https://www.lambdanote.com/products/cpu") }}

[プログラマーのためのCPU入門](https://www.lambdanote.com/products/cpu)  
著者: Takenobu Tani

会社で読まれた方がオススメされており、読んでみたので感想を書きます。  
出版社は[ラムダノート](https://www.lambdanote.com/)です。  


## まとめ

非常に良かったです。この本を出版してくれてありがとうございますという感謝の気持ちでいっぱいです。  
具体的には以下の点が良かったです。

* CPUの速度向上の為には命令流の密度を上げる必要がある -> そのための工夫 -> それにより発生する問題 -> 問題へのアプローチという章展開が非常にわかりやすかった
* 新しい概念(パイプライン、スーパースカラ、アウトオブオーダー, 分岐命令等)が登場する際に必ず図による説明がある
* 同じ概念がVendorや本(パタヘネ)では異なる用語で説明されている場合にその揺らぎを補足してくれる
* x86/Arm両対応のAssemblyによる検証コードがあり、実際に登場した機能を確かめられる 

プログラムはメモリから命令を取得して順番に実行していく、くらいのメンタルモデルだと解像度が一段上がると思いました。


## 第1章 CPUは如何にしてソフトウェアを高速に実行するのか

### CPUの性能とは

本書はCPUを性能の面から眺めるのですが、そもそも性能とはというところから始めてくれます。  

$$ CPU時間 = \frac{実行命令数}{プログラム} \times \frac{クロックサイクル数}{実行命令数} \times \frac{秒数}{クロックサイクル数} $$

そして、CPUの性能とは、上記で定めるCPU時間が短いほどよいとします。

$$ CPU時間 = \frac{秒数}{プログラム} $$

のようにせず、わざわざ3項にしているかというと、各項がそれぞれ、CPUの異なる側面を表すからです。  
具体的には、第1項がプログラムを構成する命令数、コンパイラ、命令セットアーキテクチャによって決まります。  
第2項はCPUの内部構造(microarchitecture)、第3項は半導体や回路実装技術がそれぞれ対応します。

### 命令流

プログラムをbuild/compileして機械語にしてCPUに渡しますが、CPUからこの機械語がどう見えているかというと、ある種の命令流として見えていると説明されます。  
そして本書ではこの命令流を早くするためにCPUが行っている工夫と、遅くなる要因という観点から章が構成されます。


## 第2章 命令の密度を上げるさまざまな工夫

CPUの命令流を速くするためにその密度に着目します。密度というのは、実行中のCPUのスナップショットを採ったときにどれくらいの命令が実行中かという概念と理解しています。  

まず逐次処理から始めます。  


{{ figure(images=["images/pipe_1.svg"], caption="逐次処理") }}

これはある命令の実行を完了してから次の命令の実行を開始する処理方法です。実行中のCPUのどの時点でも1つの命令しか実行していないので密度としては最も低い状態です。  
さらに、命令実行の各処理(ステージ)を考慮すると逐次処理は以下のように表すことができます。

{{ figure(images=["images/pipe_2.svg"], caption="ステージaware") }}

次にパイプライン化します。今までは前の命令の実行完了まで待ってから次の命令を実行していましたが、完了まで待つのではなく、ステージの完了まで待ってから次の命令を実行します。  
この結果、ある1時点をみるとステージ数の命令が実行中となります。  

{{ figure(images=["images/pipe_3.svg"], caption="パイプライン化") }}

なお、パイプライン化により、前の命令の実行の完了を待たずに次の命令を実行することになります。これは広い意味での「投機的な処理」を導入するものと説明されます。このことが次章以降のデータ依存関係や、分岐命令の話につながります。  

そして、このパイプラインを物理的に複数設けるアプローチがスーパースカラ化です。  

{{ figure(images=["images/pipe_4.svg"], caption="スーパースカラ化") }}

最後に、ステージ分割を更に推し進め(スーパーパイプライン化)し、スーパースカラの並列度を4に、ステージ分割数を12にすると現代の標準的なCPUと同程度の規模感になるそうです。  

{{ figure(images=["images/pipe_5.svg"], caption="4並列、12段ステージ") }}

最初の逐次処理と比較すると密度が向上していることがわかります。  
スーパースカラやパイプライン化は概念としては知っていましたが命令流の密度という観点から整理してくれている本章の説明はとてもわかりやすかったです。


## 第3章 データ依存関係

第2章で導入されたパイプライン化により命令流の密度を高めることができました。ただし、パイプライン化によって、先の命令の実行完了を待たずに次の命令の実行が開始されます。  
これによって命令間に依存関係がある場合に問題が生じます。具体的には  

```
add x1, x2, x3
sub x4, x5, x1
```

のように`add`命令で更新したregisterを後続の`sub`命令で利用する場合、`add`命令の完了によってx1 registerが更新されてからでないと`sub`命令が実行できません。  
この命令を待機している間はパイプラインのステージの一部が利用されていない状態となってしまい、命令流の密度が低下してしまいます。  
そこで、依存関係によって待機している命令を実行する代わりに別の命令を先に実行することで、ステージの空きを埋めるアウトオブオーダーという手法が導入されます。  
また、データの依存関係にもいろいろ種類があり、依存関係の種類によっては、registerのリネームで対応できるといった説明もあります。  

アウトオブオーダーの存在自体は、[Atomics and Locksを読んで](https://blog.ymgyt.io/entry/rust_atomics_and_locks/)知っていたのですがどういう理由でそれが実行されるかはわかっていなかったので本章の説明はとてもわかりやすかったです。  

### 命令レイテンシの計測実験

実際に各種命令(add,mul,load)のレイテンシを計測するassemblyのサンプルがあります。  

```sh
$ sudo perf stat -e"cycles,instructions" ./latency_add

loop-variable = 10000000

 Performance counter stats for './latency_add':

     1,001,224,176      cycles                                                      
     1,031,181,195      instructions              #    1.03  insn per cycle         

       0.213554069 seconds time elapsed

       0.213500000 seconds user
       0.000000000 seconds sys
```

となり、add命令については1cycleで実行していることが確かめられました。  
0.2秒程度で10億回の命令が実行されるのはすごいです。  
この他にも依存関係を変えるとどう変化するかの実験もあります。

検証環境は以下です。  

```
$ uname --kernel-name --kernel-release  --machine --processor --hardware-platform --operating-system
Linux 5.19.0-35-generic x86_64 x86_64 x86_64 GNU/Linux 
```


## 第4章 分岐命令

アウトオブオーダーをもってしてもカバーできない命令流の密度低下要因に分岐命令があります。  
というのも、ifのような命令は実行して条件成立を判断したのちに、pc registerを更新することで命令流を切り替えるので分岐命令の後の命令の実行が全て無駄になる可能性があります。  

そこで、これに対処するために分岐予測という仕組みがCPUに実装されます。  
分岐予測では、分岐命令が実行されるたびにその命令のアドレスと分岐先を専用の記憶領域(BTB)に保持しておき、命令をfetchする度にアドレスで検索して分岐命令かを判定します。さらに分岐命令の条件の成否の履歴を保持しておき、分岐予測に役立てるそうです。 ifを実行する度にCPUではこんなことが起きていると知り衝撃的でした。  
本章に限ったことではないですが、参考として米国特許までもが挙げられており筆者の知識の深さに驚かされます。

### 分岐予測ミスの計測実験

本章の実験では、分岐予測が50%ミスするプログラムと100%ヒットするプログラムでどの程度の差がでるかを検証します。  
以下が自分の手元の計測結果でした。


```sh
$ sudo perf stat -e "cycles,instructions,branches,branch-misses" ./branch_miss_many
loop-variable = 10000000

 Performance counter stats for './branch_miss_many':

       167,198,348      cycles                                                      
       155,965,644      instructions              #    0.93  insn per cycle         
        20,179,030      branches                                                    
         5,003,075      branch-misses             #   24.79% of all branches        

       0.039321696 seconds time elapsed

       0.039277000 seconds user
       0.000000000 seconds sys
```

2000万 branchesとありますが、この内半分はloopの判定なので実質的には1000万で、missが500万となっています。  
次が分岐予測がほとんどあたる場合です。

```sh
$ sudo perf stat -e "cycles,instructions,branches,branch-misses" ./branch_miss_few
loop-variable = 10000000

 Performance counter stats for './branch_miss_few':

        66,698,390      cycles                                                      
       150,937,374      instructions              #    2.26  insn per cycle         
        20,174,821      branches                                                    
             5,368      branch-misses             #    0.03% of all branches        

       0.017504270 seconds time elapsed

       0.017500000 seconds user
       0.000000000 seconds sys
```

着目すべきは、cycle数が40%程度減っていおり、実行速度も40%程度向上しました。  
このように分岐予測の影響が実際に確かめることができました。


## 第5章 キャッシュメモリ

CPUからメモリへのアクセスには10 ~ 100サイクル程度を要する。そしてアウトオブオーダー実行で埋められるサイクル数にも限界がある。そこで、CPU、メモリ間にキャッシュが導入されます。  
メモリへの書き込みはキャッシュになされるのでキャッシュとメモリ間の不整合が発生することとなるがこの問題は10章で扱います。  

キャッシュを導入したとしてもキャッシュミス自体は避けられず、その影響は大きい。  
そこでキャッシュミスが起きやすい場合を3つに類型化し、それぞれ対策していきます。  
まず初期参照ミスに対してはキャッシュラインで、容量性ミスに対しては階層化、競合性ミスにはセットアソシアティブ方式で対処します。  
キャッシュの話でキャッシュラインや階層化がよく説明されますが、それをキャッシュミスの類型と対応させる説明がわかりやすかったです。  
また、自分はフルアソシアティブ方式とセットアソシアティブ方式の違いやway数というものがよくわかっていなかったので本章説明は非常にありがたかったです。  
普段のアプリケーションでキャッシュラインを意識することはほとんどないのですが、ライブラリのコードを見ているとキャッシュラインを意識したコメントを時々見かけることもあります。現状ではstructを64byte以内にしておくとキャッシュに乗りやすいくらいの理解度です。

### キャッシュミスの測定

本章ではキャッシュミスがどのように影響するかを実験します。以下がキャッシュをミスさせるプログラム。  
アドレスの増分値として4096を利用しました。

```sh
$ sudo perf stat -e "cycles,instructions,L1-dcache-loads,L1-dcache-load-misses" ./cache_miss_many
loop-variable = 10000000

 Performance counter stats for './cache_miss_many':

        22,006,883      cycles                                                      
        91,018,467      instructions              #    4.14  insn per cycle         
        10,257,315      L1-dcache-loads                                             
         8,954,362      L1-dcache-load-misses     #   87.30% of all L1-dcache accesses

       0.008935091 seconds time elapsed

       0.008868000 seconds user
       0.000000000 seconds sys
```

次が、メモリアクセスがキャッシュラインにのるようなプログラムです。  


```sh
$ sudo perf stat -e "cycles,instructions,L1-dcache-loads,L1-dcache-load-misses" ./cache_miss_few
loop-variable = 10000000

 Performance counter stats for './cache_miss_few':

        21,923,146      cycles                                                      
        90,949,898      instructions              #    4.15  insn per cycle         
        10,239,289      L1-dcache-loads                                             
            12,032      L1-dcache-load-misses     #    0.12% of all L1-dcache accesses

       0.008941629 seconds time elapsed

       0.008911000 seconds user
       0.000000000 seconds sys
```

0.1%程度しかミスしていないようです。  
自分の環境では実行速度に差がでませんでした。


## 第6章 仮想記憶

Virtual addressとphysical addressの変換を行うレイヤーが仮想記憶。  仮想記憶を導入することで様々なメリットがある一方で、対応関係の情報自体(ページテーブル)はメモリ上にある。したがって、メモリにアクセスする際には対応関係の解決のためにメモリアクセスが必要になるので都合2回のアクセスが必要となってしまう。  
これではキャッシュが解決しようとした問題と同じことが起きてしまう。そこで、ページテーブルの一部をCPU上に保持すること(TLB)でアドレス解決時のメモリアクセスを抑えるようにする。  

自分はページテーブルとTLBの関係の理解が曖昧だったので、本章の説明もとてもありがたかったです。  
また、プロセスよりもスレッドの方が切り替えコストが低い理由としてTLBのキャッシュミスが影響しているのもなるほどでした。  
加えてページテーブルを大きくしたい動機がわかっていなかったので、TLBのキャッシュミスを下げられるという説明もとてもわかりやすかったです。  

CPUの命令流の密度を高めるための工夫を知ると、ページフォルト時にI/Oが発生したらもう今までの苦労が全部水の泡になるというのが腹落ちできたのもうれしいです。

### TLBミス計測実験

キャッシュライン同様に、TLBミスの影響を実験します。  以下はTLBがヒットするプログラムです。  

```sh
$ sudo perf stat -e "cycles,instructions,L1-dcache-loads,dTLB-loads,dTLB-load-misses" ./tlb_miss_few
loop-variable = 100000000

 Performance counter stats for './tlb_miss_few':

       243,254,513      cycles                                                      
       901,372,541      instructions              #    3.71  insn per cycle         
       100,349,655      L1-dcache-loads                                             
       100,349,655      dTLB-loads                                                  
               899      dTLB-load-misses          #    0.00% of all dTLB cache accesses

       0.054821090 seconds time elapsed

       0.054809000 seconds user
       0.000000000 seconds sys
```

次に、TLBをミスさせるプログラムです。変更点は、参照するメモリアドレスを一定範囲に抑えるコードをなくし、参照するページ数を増やしただけです。

```sh
$ sudo perf stat -e "cycles,instructions,L1-dcache-loads,dTLB-loads,dTLB-load-misses" ./tlb_miss_many
loop-variable = 100000000

 Performance counter stats for './tlb_miss_many':

     1,919,208,667      cycles                                                      
       913,274,488      instructions              #    0.48  insn per cycle         
       103,472,076      L1-dcache-loads                                             
       103,472,076      dTLB-loads                                                  
        97,106,889      dTLB-load-misses          #   93.85% of all dTLB cache accesses

       0.405079023 seconds time elapsed

       0.405029000 seconds user
       0.000000000 seconds sys
```

自分の環境では実行時間が7倍程度増加しました。  
TLBミスの影響が確認できました。

## 第7章 I/O

CPUの命令実行によりCPUから外部のデバイスにアクセスする仕組みについて。  
自分は、メモリマップドI/Oと専用のI/O命令によるアクセスの方式をごっちゃになって理解していたので、本章の整理は非常に助かりました。  
また、DMAコントローラとCPUの関係の説明もわかりやすかったです。

### I/O命令によるデバイスの値の読み出し

本章の実験では、real time clock(RTC)やPCI Expressの情報を読み出すプログラムを試します。  
残念ながら自分のPCではSegmentation faultとなってうまくいきませんでしたが、I/Oがin,out命令から実現されていることがわかります。


## 第8章 システムコール、例外、割り込み

分岐命令以外で、命令流の切り替えが起きるケースについて。  
exception, interrupt, trap, fault, system call,...等を命令流の特別な切り替えという観点から整理してくれています。  
本書はCPUに関連するトピックを命令流という観点から整理してくれておりますが、本章の整理は特にわかりやすいです。  
定義の仕方にもよりますが、システムコール、例外、割り込みについてメンタルモデルを確立したいと思う方に本章はとてもおすすめしたいです。  

またこれまでの章で、割り込みコントローラー, アドレス変換処理、キャッシュ、I/Oバス等にふれましたが、それら関連コンポーネントと各種事象がどう対応しているかの図が非常にわかりやすかったです。  
加えて、システムコール、例外、割り込み時の挙動の説明も具体的で、ベクターテーブルの説明もあります。  
システムコールは遅いと漠然と思っていたのですが、なぜ遅いかが、これまでのパイプラインやキャッシュの観点から理解できます。章立てが練られていると思わされます。

### システムコールと例外の実験

実際にシステムコールを実行してみます。  
システムコール自体は、仕様を把握できていれさえすれば、引数をregisterに設定したのち、専用の命令を実行するだけというのがわかります。

```
 /* write(2) system-call */
 mov     eax, 1                  /* system-call number: write() */
 mov     edi, 1                  /* fd: stdout */
 lea     rsi, [rip + msg]        /* buf: */
 mov     edx, 13                 /* count: */
 syscall
```

[Hello World本](https://blog.ymgyt.io/entry/helloworld-book/)で学んだことですが、これはx86 + linuxの仕様であって、system callの引数をregisterではなくstack経由で渡すというのも設計上はありえるという理解です。  

また、ゼロ除算やページフォールトの例もあります。


## 第9章 マルチプロセッサ

2つ以上のCPUによって構成される場合について。  
マルチプロセッサとマルチコアの文脈による使い分けの説明がなるほどでした。  
自分はマルチコアと言った際に想定されるハードウェア構成は一つだと思っていたのですが、多様な構成が可能なのが勉強になりました。  
特に、メッセージ交換型でメモリ共有がなされていない場合があるとは思ってもみなかったです。

## 第10章 キャッシュコヒーレンス制御

前章で説明された共有メモリ型における問題点と対処法について。  
具体的には、CPUごとにcacheを保持することとなるので、同一メモリアドレスのコピーが複数存在するため、他のCPUの更新結果が別のCPUから読めないといったキャッシュ間の整合性が崩れる問題に対処する必要がある。  
キャッシュコヒーレンスの問題状況を丁寧に説明してくれるので、MSIプロトコルの立ち位置が理解しやすかったです。  
最初にキャッシュコヒーレンスの話を知った際は、変数に書き込むと裏ではCPU間で当該キャッシュを無効にするやり取りが行われているなんて思いもしませんでした。  

### コヒーレンスミスの実験

本章の実験では、2つのthreadで、互いにメモリを変更し合うプログラムを動かします。  
その際、変更対象のメモリのキャッシュラインが同じか異なるかでどのような影響が観測されるかを検証します。

まずthread間でキャッシュラインを共有しない場合です。

```sh
$ sudo perf stat -e "cycles,instructions,L1-dcache,L1-dcache-load-misses" ./cacheline_different
main(): start
child1(): start
child2(): start
child2(): finish
child1(): finish
main(): finish

 Performance counter stats for './cacheline_different':

        71,827,869      cycles                                                      
        61,149,657      instructions              #    0.85  insn per cycle         
        10,288,943      L1-dcache                                                   
            19,262      L1-dcache-load-misses     #    0.19% of all L1-dcache accesses

       0.012914616 seconds time elapsed

       0.024334000 seconds user
       0.000000000 seconds sys
```

ミス率が0.19%とほとんどないことがわかります。  
次はキャッシュラインを共有する場合です。

```sh
$ sudo perf stat -e "cycles,instructions,L1-dcache,L1-dcache-load-misses" ./cacheline_same
main(): start
child1(): start
child2(): start
child2(): finish
child1(): finish
main(): finish

 Performance counter stats for './cacheline_same':

       341,254,050      cycles                                                      
        61,221,311      instructions              #    0.18  insn per cycle         
        10,306,873      L1-dcache                                                   
         1,431,930      L1-dcache-load-misses     #   13.89% of all L1-dcache accesses

       0.041625362 seconds time elapsed

       0.080869000 seconds user
       0.000000000 seconds sys
```

キャッシュミス率が70倍程度増加し、実行時間が3倍程度増加しました。 
キャッシュラインのフォールスシェアリングの影響があることが確かめられました。


## 第11章 メモリ順序付け

1つのCPUから複数のメモリアクセスに何らかの順序関係を強制する手段としてのmemory orderingについて。  
なぜメモリアクセスが一つのCPU内で入れ替わるのかの説明が参考になります。  
fence命令の必要性や、acquire, release命令の動作が具体例つきでわかりやすいです。  
また、本章で説明されるメモリ順序付けは1つのCPUからのメモリアクセスについてである点が強調されています。そのため、本章とRust Atomics and Locksを併せて読むのがオススメです。  
fenceやldar, stlr命令があくまで1CPUに対する制約であり、happens-before relationshipとは別の話と整理できて非常に理解が進みました。 

### メモリオーダリングの実験

本章の実験では実際にCPUが命令を入れ替えて実行していることを実験します。  
具体的には、0に初期化された変数x,yに対して、以下の二つのthreadを実行します。  

* thread1: x = 1を実施したのち、yをload
* thread2: y = 1を実施したのち、xをload

命令がインオーダーに実行されていればthreadの実行順序に関わらず、x = 0, y = 0という状態には至らないはずです。  
しかしながら、x86であってもloadとstore間では実行順序の入れ替えが起こることが許容されていることから、実際にx = 0, y = 0という状態が観測されます。  
実際に試してみると以下のようになりました。

```sh
$ ./ordering_unexpected 
main(): start
child1(): start
child2(): start
child2(): UNEXPECTED!: r14 == 0 && r15 == 0; loop-variable = 5
child1(): UNEXPECTED!: r14 == 0 && r15 == 0; loop-variable = 5
main(): finish
```

続いて、storeとload間にメモリフェンス命令を挿入した例を試します。  

```
mov     [rip + value_x], rax    /* value_x = 1   */
mfence                          /* FORCE ORDERING */
mov     r14, [rip + value_y]    /* r14 = value_y */
```

```sh
$ ./ordering_force
main(): start
child1(): start
child2(): start
child1(): finish: loop-variable = 5000000
child2(): finish: loop-variable = 5000000
main(): finish
```

メモリフェンス命令が実際に命令の入れ替えを抑止していることが確かめられました。



## 第12章 不可分操作

本章では共通のメモリを2つ以上のCPU間で相互に更新する場合についてです。  
メモリオーダリングに比べて、不可分操作の話は解決したい問題がわかりやすく、解決法も専用の命令使うという話で意外とわかりやすい印象があります。  
swapやcompare and swap命令がどのように動作するのかの説明があります。このあたりはプログラム言語でもそのままapiになっている気がするので、内部動作を知るのが結局近道だと思いました。  

### 不可分操作の実験

本章の実験では、共有変数をthread間でインクリメントする際にatomic命令を使わないとどうなるかを検証します。  

具体的には以下のようにatomic命令を使ってインクリメントする場合

```
lock xadd [rip + counter], rax
```

と単純なadd命令を使う場合を比較します。
```
add     rax, 1
```

```
$ ./counter_atomic
main(): start
child1(): start
child2(): start
child2(): finish: loop-variable = 5000000
child1(): finish: loop-variable = 5000000
main(): finish: counter = 10000000

$ ./counter_bad
main(): start
child1(): start
child2(): start
child2(): finish: loop-variable = 5000000
child1(): finish: loop-variable = 5000000
main(): finish: counter = 5133651 
```

add命令を利用する`./counter_bad`の方では、counterが意図通りになっていないことが確認できました。  
またadd命令を使った場合でもthread間のアクセス頻度ではcounterの値がより意図通りになる例も載っており、この種のバグの厄介さがわかります。


## 第13章 高速なソフトウェアを書く際には何に注目すべきか

これまでのまとめ。  
高速なソフトウェアを書くうえで、何に着目するかは、実行対象のソフトウェアだけでなくプログラミング言語、OS、CPU等にも依存するため難しい問題。  
そんな中、大枠としてどのようにアプローチできるかについて教えてくれます。

## 付録A CPUについてさらに広く深く知るには

CPUについてさらに詳しく知りたい人に向けた情報源の紹介。  
書籍だけでなく、論文や特許、講義資料も載っておりすごいです。
自分は、Systems Performance Second Edition(詳解システム・パフォーマンス 第2版)を読んでみようと思っております。  
あとがきにも著者のオススメがのっているので要チェックです。

## 付録B 各CPUの基本的な命令

x86, Arm, RISC-Vそれぞれの基本的な命令を解説してくれます。  
自分のアセンブリの学習ソースが基本的に本のappendixなので非常にありがたいです。  
RISC-Vは比較命令で暗黙的なレジスタを更新しないという学びもありました。


## 付録C 現代的なCPUの実装例 (BOOM)

[BOOM](https://boom-core.org/)というRISC-Vの実装について。  
まったく読めてないです。  
Chiselで書かれているらしいです。いつもハードウェア記述言語の文脈で突然Scalaでてきて驚きます。

## 付録D マイクロオペレーション方式と、その命令レイテンシ

x86のようなCISCで出てくるマイクロオペレーションについて。  
今まで、アセンブリってCPUが実際に実行している機械語と1:1対応していると思っていたのですが、もはやアセンブリでさえ抽象化されたレイヤーなのかと思ってしまいます。


## 付録E GPUおよびベクトル方式におけるパイプラインの高密度化の工夫

本章で扱えなかったGPUについて。  
自分はCPUとGPUって具体的にどう連携しているのかが知りたいです。  
7章によるとCPUからはI/OデバイスとしてGPUが見えているはずなので、I/O処理としてGPUに処理を依頼する感じになるのでしょうか。  
でもそうなるとプログラミング言語からどうやって扱うのだろうか。

## 付録F CPUの性能向上の物理的な難しさ

CPUの物理的な側面について。  
~~物理も学びたいです~~


