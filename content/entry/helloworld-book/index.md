+++
title = "📕 ハロー\"Hello, World\" OSと標準ライブラリのシゴトとしくみを読んだ感想"
slug = "helloworld-book"
date = "2023-02-24"
draft = true
description = "ハロー\"Hello, World\"OSと標準ライブラリのシゴトとしくみを読んだ感想について"
[taxonomies]
tags = ["book"]
+++


## 読んだ本

{{ figure(images=["images/helloworld-book.png"]) }}

[ハロー“Hello, World” OSと標準ライブラリのシゴトとしくみ](http://kozos.jp/books/helloworld/)  
著者: [坂井弘亮](http://kozos.jp/index.html)

main()の前にはなにがあるのかという見出しが気になって読んでみたので感想を書きます。  
環境再現用のVM imageが提供されているので、筆者が行っている調査を手元で実際に確かめられながら進められます。

## まとめ

TODO

## 第1章 ハロー・ワールドに触れてみる

環境を準備して、main()のアセンブラを読んでみるまでを行います。  
自分は、VirtualBoxをMacBookPro11,4 Intel Core i7上で動かしました。  
実作業はVMにportforwardを設定し、手元のterminalからsshして行いました。
VMの設定の仕方についても画像付きで説明があるのでわかりやすかったです。  
提供されているVMを利用すると必要なfileやtoolが全て揃っているので、環境構築でつまづくことはないと思います。

ということで早速進めていきます。  

### `hello.c`

```c
#include <stdio.h>

int main(int argc, char *argv[])
{
  printf("Hello World! %d %s\n", argc, argv[0]);
  return 0;
}
```

本書で扱うプログラムです。実行すると引数の数と実行binaryのpathを出力します。

### 逆アセンブル

```
# objdump -d hello -M att | grep -A 25 '<main>'
080482bc <main>:
 80482bc:       55                      push   %ebp                 ; 1
 80482bd:       89 e5                   mov    %esp,%ebp            ; 2
 80482bf:       83 e4 f0                and    $0xfffffff0,%esp     ; 3
 80482c2:       83 ec 10                sub    $0x10,%esp           ; 4
 80482c5:       8b 45 0c                mov    0xc(%ebp),%eax       ; 5
 80482c8:       8b 10                   mov    (%eax),%edx          ; 6
 80482ca:       b8 0c 36 0b 08          mov    $0x80b360c,%eax      ; 7
 80482cf:       89 54 24 08             mov    %edx,0x8(%esp)       ; 8
 80482d3:       8b 55 08                mov    0x8(%ebp),%edx       ; 9
 80482d6:       89 54 24 04             mov    %edx,0x4(%esp)       ; 10
 80482da:       89 04 24                mov    %eax,(%esp)          ; 11
 80482dd:       e8 7e 10 00 00          call   8049360 <_IO_printf> ; 12
 80482e2:       b8 00 00 00 00          mov    $0x0,%eax            ; 13
 80482e7:       c9                      leave                       ; 14
 80482e8:       c3                      ret                         ; 15
 80482e9:       90                      nop
 80482ea:       90                      nop
 80482eb:       90                      nop
 80482ec:       90                      nop
 80482ed:       90                      nop
 80482ee:       90                      nop
 80482ef:       90                      nop

080482f0 <__libc_start_main>:
 80482f0:       55                      push   %ebp
```

`objdump`でdisassembleします。  `-M att`をつけなくても同じ結果になるのですが、Intel記法とAT&Tでいつも混乱するので明示的につけるようにしています。(末尾にコメントを付与しました)   
AT&T記法では、第一引数がsourceで第二引数がdestなので逆のIntel記法より直感的だと思います。`%`がでてきたらAT&Tと覚える様にしています。  

このアセンブリを読んでみる上での前提知識  

* x86のstackはzeroに向かって伸びるので、stack frameを確保するにはstack pointerをsubする
* push命令はstack pointerを4byte(32bitCPU)減算して、引数の値を書き込む 
* 関数からの戻り値はeax registerで返す

これらを念頭に上から読んでいくと

1. 現在のbase pointerをstackに退避
2. 現在のstack pointerをbase pointerとして保持
3. stack pointerを16byteにalign
4. stack frameを16byte確保
5. mainの第2引数(`argv`)をeaxに保存
6. eaxを参照(`argv[0]`)してedxに保存
7. 0x80b360cをeaxに保存
8. 6で保存した`argv[0]`の値をedxからprintfの第3引数に保存
9. mainの第1引数(`argc`)をedxに保存
10. `argc`の値をedxからprintfの第2引数に保存
11. 7でeaxに保持していた0x80b360cをprintfの第1引数に保存
12. printf呼び出し
13. 戻り値0をeaxに保存
14.  この時点では説明がなかったですがleaveは`mov %ebp %esp`, `pop %ebp`を行うらしいので, stack frameをmain呼び出し前の状態に戻し、1で保持していたebpの値を復元。
15. 呼び出し元に戻る

という風に理解しました。  
x86において関数の引数はstack経由で渡され,stack pointerは戻り先アドレスを指している状態になっており、+4のの位置には第1引数、+8の位置には第2引数が格納されているということらしいです。  
ただし、1のpushでebpが4byte減算されるので、c(+12)byteに第2引数があります。  

ということで雰囲気ではありますが、関数呼び出し規約に基づいてstack pointerの相対位置から渡された引数をprintfに渡していることがなんとなくわかりました。  
ちなみに最後の`nop`の連続は次の関数のalignするために埋められているもので、`__libc_start_main`が80482f0(下位4bitが0)のように16byte alignmentになっています。  

最近読んだ、CPU関連の本(CPUの気持ち本、Rust atomics and locks, プロセッサを支える技術) のおかげでcache lineのためにalignmentしたいという問題意識がなんとなくわかったのがうれしいです。


## 第2章 printf()の内部動作を追う

次はいよいよprintf()の内部を見ていきます。  
具体的にはgdbを使って、printf()の中で"Hello world!"を出力する命令の特定を試みます。  
gdbの使い方について丁寧に教えてくれます。  
結構地道な作業でnextiという次の命令を実行するコマンドを数十回繰り返したりします。  

最終的に

```
0x8055a80 <_dl_sysinfo_int80>   int    $0x80                                                                               │
0x8055a82 <_dl_sysinfo_int80+2> ret  
```

```
(gdb) where
#0  0x08055a82 in _dl_sysinfo_int80 ()
#1  0x08053d92 in __write_nocancel ()
#2  0x08067671 in _IO_new_file_write ()
#3  0x0806819b in _IO_new_do_write ()
#4  0x080683ea in _IO_new_file_overflow ()
#5  0x080673f4 in _IO_new_file_xsputn ()
#6  0x08059738 in vfprintf ()
#7  0x08049381 in printf ()
#8  0x080482e2 in main (argc=1, argv=0xbffff634) at hello.c:5
```

というint命令(システムコール)にたどり着きます。このint命令を実行すると"Hello world!"が出力されました。  
概念としては標準libの中でsystemcallが呼ばれるとわかっていましたが、実際にみてみるとうれしいですね。  
VMの再現のおかげで本とアドレスが完全に一致しているのも親切でした。








## 参考

* [本書のサポートページ](http://kozos.jp/books/helloworld/)
* [IntelとAT&T Syntaxの違い](https://imada.sdu.dk/u/kslarsen/dm546/Material/IntelnATT.htm)


## Memo

* login: user/helloworlduser
  * root: root/helloworldroot

* sshdの有効化
  * chkconfig sshd on
  * service sshd startl
 
* ssh -p 11122 user@192.168.10.104
  * ipはmacの設定から確認した

* 設定
  * LANG=C

* objdump
  * objdump -d hello -M att で結果が一致したのでdefaultではAT&T記法


