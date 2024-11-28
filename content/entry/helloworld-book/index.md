+++
title = "📕 ハロー\"Hello, World\" OSと標準ライブラリのシゴトとしくみを読んだ感想"
slug = "helloworld-book"
date = "2023-02-21"
draft = false
description = "ハロー\"Hello, World\"OSと標準ライブラリのシゴトとしくみを読んだ感想について"
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/closed_book.png"
+++


## 読んだ本

{{ figure(images=["images/helloworld-book.png"]) }}

[ハロー“Hello, World” OSと標準ライブラリのシゴトとしくみ](http://kozos.jp/books/helloworld/)  
著者: [坂井弘亮](http://kozos.jp/index.html)

main()の前にはなにがあるのかという見出しが気になって読んでみたので感想を書きます。  
環境再現用のVM imageが提供されているので、筆者が行っている調査を手元で実際に確かめられながら進められます。

(2024年11月26日に [第2版](https://www.shuwasystem.co.jp/book/9784798074146.html) が発売されました 🎉)


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

### ptrace()

ptrace()というシステムコールを用いて独自のtrace処理を行います。  
man ptraceで`/usr/include/sys/user.h`参照と書いてあるが実際には説明がないのでそんな時は、Linuxカーネルのソースコートを見るのが手っ取り早いとあって、そうなるのがすごいなと思いました。

### バイナリエディタ

{{ figure(caption="nop(0x90)でシステムコール命令を書き換える", images=["images/edit_helloworld.png"]) }}


バイナリエディタのhexeditを使って、システムコールの命令を`nop`(0x90)に書き換えてみます。  
実際にやってみたところ、本当に"Hello world!"が出力されませんでした。


## 第3章 Linuxカーネルの処理を探る

"Hello world!"を出力したシステムコールが実行されたときに何が起きるかをLinuxカーネル側から見ていきます。  
ここは追うのが難しかったです。  

システムコール実行直前のregisterの中身を確認して、eax registerに4が格納されていることを確認したのち、その値がカーネル側の割り込みハンドラで参照されていることを確認します。  
ただし、C言語からはeaxに値を格納するというような処理は(アセンブラを使わなければ)書けないので、システムコールラッパーが処理を仲介していると続きます。  

```sh
objdump -d hello | grep -A 10 '08053d7a <__write_nocancel>'
08053d7a <__write_nocancel>:
8053d7a:       53                      push   %ebx
8053d7b:       8b 54 24 10             mov    0x10(%esp),%edx
8053d7f:       8b 4c 24 0c             mov    0xc(%esp),%ecx
8053d83:       8b 5c 24 08             mov    0x8(%esp),%ebx
8053d87:       b8 04 00 00 00          mov    $0x4,%eax ;  👈
8053d8c:       ff 15 50 67 0d 08       call   *0x80d6750  
```

実際にアセンブリでeaxに4が保存されており、その後にcallされている`*0x80d6750`が下記のようにシステムコールであると確かめられます。


```
(gdb) disassemble *0x80d6750
Dump of assembler code for function _dl_sysinfo_int80:
   0x08055a80 <+0>:     int    $0x80
   0x08055a82 <+2>:     ret
```

また、システムコールの戻り値や上限を超える引数についてもシステムコールラッパーが間に入り、C言語に統一的なAPIを提供している例が説明されます。

ちなみに、`linux-2.6.32.65/arch/x86/kernel/entry_32.S`に  

```
/*
 *
 *  Copyright (C) 1991, 1992  Linus Torvalds
 */
```

が出てきて嬉しくなりました。


## 第4章 ライブラリからのシステムコール呼び出し


printf()がC言語から呼べれるのは標準ライブラリCがあるからで、CentOSではそれは、GNUプロジェクトによるGNU C Library(glibc)によって提供されている。  
そこで本章ではglibcのソースからprintf()の中で呼ばれていたシステムコールラッパーの実装を見ていきます。  

ただ、glibcでは実際にint命令を発行するソースはマクロとテンプレートで実装されており、追うのが難しかったです。  

### システムコールのABI

Linux/x86でシステムコールを呼ぶには、registerに引数をセットして、int $0x80を実行していた。  
これはLinuxにおけるx86の仕様で、CPUアーキテクチャが異なればまた変わってくる。(そもそもregisterが違う)  
また、FreeBSD等カーネルが違えばまた変わってくる。  

しかし、アプリケーション側で実行環境のカーネルやCPUを意識するのは大変なのでシステムコールを呼び出すアセンブラ処理を用意し、アプリケーションからはそれを呼ぶ様にする。  

実際に以下のようなアセンブリを用意して、C言語から呼び出せた。

`write.S`
```
.global _write
_write:
	push %ebx
	mov $4, %eax
	mov 8(%esp), %ebx
	mov 12(%esp), %ecx
	mov 16(%esp), %edx
	int $0x80
	pop %ebx
	ret
```

`main.c`
```c
int main() {
  _write(1, "Hello World!\n", 13);
  return 0;
}
```

```
gcc main.c write.S -o _write
./_write
Hello World!
```

**Linux/x86では引数はregister経由で渡すというシステムコール時のルールという意味でのABIと、x86では関数呼び出し時に引数をスタックで渡すという意味でのABIでは指しているものが違う**という説明が非常にわかりやすかったです。  
ABIについていまいちピンときていなかったのですが本書を読んでちょっとしっくりくるようになったのが嬉しいです。

また、システムコールラッパーを呼ぶ際の引数のsignatureこそが、POSIXで定められたAPIでこのAPIのレイヤーでLinux/ARMやFreeBSD/i386といったABIの差が吸収されているという説明も非常にわかりやすかったです。


### glibcをビルド

システムコールラッパーを提供してくれているglibcをソースコードからビルドしていきます。  
`./configure`, `make`, `make install`としていくのですが、`configure`や`make`で普通にエラーになります。  
そのエラーをコメントアウトしながら修正していくのですが、自分一人なら絶対できないだろうなと思います。

buildしたglibcを`/usr/local`配下にinstallしたのちに、helloとリンクします。  

```
gcc hello.c -o hello -Wall -O0 -static /usr/local/glibc-2.21/lib/libc.a  
```

こうすると, helloをgdbでdebugした際に、printf()の中でもソースコードがみれるようになりました。

```
(gdb) where
#0  write () at ../sysdeps/unix/syscall-template.S:81
#1  0x08050f08 in _IO_new_file_write (f=0x80df1e0, data=<value optimized out>, n=44) at fileops.c:1251
#2  0x08050bcc in new_do_write (fp=0x80df1e0, data=0xb7fff000 "Hello World! 1 /home/user/build/hello/hello\n", to_do=<value optimized out>)
    at fileops.c:506
#3  0x08050e95 in _IO_new_do_write (fp=0x80df1e0, data=0xb7fff000 "Hello World! 1 /home/user/build/hello/hello\n", to_do=44) at fileops.c:482
#4  0x08051a3d in _IO_new_file_overflow (f=0x80df1e0, ch=-1) at fileops.c:839
#5  0x08050d07 in _IO_new_file_xsputn (f=0x80df1e0, data=0x80be37e, n=1) at fileops.c:1319
#6  0x0807ce8d in _IO_vfprintf_internal (s=0x80df1e0, format=<value optimized out>,
    ap=0xbffff56c "\210\201\004\b\030\361\r\b\210\201\004\b\350\365\377\277v\205\004\b\001") at vfprintf.c:1673
#7  0x0804deb1 in __printf (format=0x80be36c "Hello World! %d %s\n") at printf.c:33
#8  0x080483c2 in main (argc=1, argv=0xbffff614) at hello.c:5
```

スタックトレースにもソースコードのfileが表示されました。


## 第5章 main()関数の前と後

まず, gdbでmain()で実行している`return 0;`の次の命令をnextで確認すると、`__libc_start_main()`であることがわかります。さらにbreakpointを貼ってみると、`_start()`から呼ばれていることがわかりました。 
ここで、`_start()`がプログラムの開始処理であるとするとその情報はELFに格納されているはず、ということでELFをみてみると、`Entry point address: 0x80481c0`とあります。  

``` 
readelf -a hello | head -n 20
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 03 00 00 00 00 00 00 00 00
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - Linux
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           Intel 80386
  Version:                           0x1
  Entry point address:               0x80481c0  👈
  Start of program headers:          52 (bytes into file)
  Start of section headers:          582884 (bytes into file)
  Flags:                             0x0
  Size of this header:               52 (bytes)
  Size of program headers:           32 (bytes)
  Number of program headers:         5
  Size of section headers:           40 (bytes)
  Number of section headers:         41
  Section header string table index: 38
```

これはgdbで確認した、`_start()`のアドレスと一致します。

```
(gdb) break _start
Breakpoint 1 at 0x80481c0
(gdb) run
Starting program: /home/user/hello/hello

Breakpoint 1, 0x080481c0 in _start ()
(gdb) where
#0  0x080481c0 in _start ()
```

また、以下のように`__libc_start_main()`から`main()`を呼んだ後に、eax registerの値をstackに積んで、exitをcallしているので、main()の戻り値が終了ステータスになることがわかりました。

```
0x8048475 <__libc_start_main+389>       call   *0x8(%ebp)    👈 main()
0x8048478 <__libc_start_main+392>       mov    %eax,(%esp)
0x804847b <__libc_start_main+395>       call   0x8048e60 <exit>
```

### スタートアップのソースコード

プログラムは`main()`から始まるというのは、アプリケーション作成者の観点での話であって、実際は`_start()`から始まっている。  
そしてこの処理は標準Cライブラリによって提供されているので、今度はglicで該当のソースを探していきます。  

glibc配下で、`grep -r __libc_start_main .`を実行し、`sysdeps/i386/start.S`に当たりをつけます。


```c
/* This is the canonical entry point, usually the first thing in the text
   segment.  The SVR4/i386 ABI (pages 3-31, 3-32) says that when the entry
   point runs, most registers' values are unspecified, except for:

   %edx         Contains a function pointer to be registered with `atexit'.
                This is how the dynamic linker arranges to have DT_FINI
                functions called for shared libraries that have been loaded
                before this code runs.

   %esp         The stack contains the arguments and environment:
                0(%esp)                 argc
                4(%esp)                 argv[0]
                ...
                (4*argc)(%esp)          NULL
                (4*(argc+1))(%esp)      envp[0]
                ...
                                        NULL
*/

        .text
        .globl _start
        .type _start,@function
_start:
        /* Clear the frame pointer.  The ABI suggests this be done, to mark
           the outermost frame obviously.  */
        xorl %ebp, %ebp

        /* Extract the arguments as encoded on the stack and set up
           the arguments for `main': argc, argv.  envp will be determined
           later in __libc_start_main.  */
        popl %esi               /* Pop the argument count.  */
        movl %esp, %ecx         /* argv starts just at the current stack top.*/

        /* Before pushing the arguments align the stack to a 16-byte
        (SSE needs 16-byte alignment) boundary to avoid penalties from
        misaligned accesses.  Thanks to Edward Seidl <seidl@janed.com>
        for pointing this out.  */
        andl $0xfffffff0, %esp
        pushl %eax              /* Push garbage because we allocate
                                   28 more bytes.  */

        /* Provide the highest stack address to the user code (for stacks
           which grow downwards).  */
        pushl %esp

        pushl %edx              /* Push address of the shared library
                                   termination function.  */

#ifdef SHARED
        /* Load PIC register.  */
        call 1f
        addl $_GLOBAL_OFFSET_TABLE_, %ebx

        /* Push address of our own entry points to .fini and .init.  */
        leal __libc_csu_fini@GOTOFF(%ebx), %eax
        pushl %eax
        leal __libc_csu_init@GOTOFF(%ebx), %eax
        pushl %eax

        pushl %ecx              /* Push second argument: argv.  */
        pushl %esi              /* Push first argument: argc.  */

        pushl main@GOT(%ebx)

        /* Call the user's main function, and exit with its value.
           But let the libc call main.    */
        call __libc_start_main@PLT
#else
        /* Push address of our own entry points to .fini and .init.  */
        pushl $__libc_csu_fini
        pushl $__libc_csu_init

        pushl %ecx              /* Push second argument: argv.  */
        pushl %esi              /* Push first argument: argc.  */

        pushl $main

        /* Call the user's main function, and exit with its value.
           But let the libc call main.    */
        call __libc_start_main
#endif

        hlt                     /* Crash if somehow `exit' does return.  */

```

わからないことのほうが多いのですが、stackになんらかの情報があることを前提に、前処理を行い、`__libc_start_main()`を実行しています。  
この時点で、stackを16byte alignしているのもおもしろいです。  
プログラムってどうやって実行されるんだろうと思っていたので、最初の処理を確認できてうれしいです。  
本章では終了処理のexitについても調べていきます。

## 第6章 標準入出力関数の実装をみる

printf()の実装を読んでいきます。自分のC力が足りないのと、マクロだらけで理解が難しかったです。  
Rustのmacroは読みやすいんだなと実感させられます。  
FreeBSDやNewlibの実装も対象です。  
FreeBSDというのをよく知らなかったのですが、カーネルのソースと標準Cライブラリ、基本コマンドがすべて同一プロジェクトで管理されていて、シンプルでいいなと思ってしまいました。


## 第7章 コンパイルの手順と仕組み

compileといったときに何が行われているかについて、cc1, as ,collect2といったツールが具体的に使われているのは知りませんでした。  
OSの定義についても述べられているのですが、汎用なのか、組み込みなのか、UNIXライクなのか等で、実は統一的な定義は難しいんだなと知りました。  
筆者が提唱されている万人にしっくりとくる定義はなるほどでした。

open()やwrite()等のPOSIXで定められたAPIを提供するのはカーネルではなくシステムコールラッパーなので、UNIXライクとは、POSIXインターフェースを実現するための機能をカーネルが持っているという説明は非常にわかりやすかったです。  
UNIXライクという言葉の意味はなんとなくしかわかっていなかったので、明確に説明されていて理解が進みました。  

この章を通して、自分がLinuxだと思っていたものの多くが実はGNUの話だったことがわかりました。


## 第8章 実行ファイル解析

バイナリーファイルをhexeditで確認して、"Hello world"を"HELLO WORLD"に書き換えてみたりします。  
バイナリーを見るだけでも、32ビットアーキテクチャであったり、リトルエンディアンであったが推測できるのは意外でした。

### ELFフォーマット

`readelf`でELFフォーマットの情報を確認できる。  
LinuxでELFフォーマットの実行fileを実行すると、カーネルは何らかの方法でELFの構造を知っているはずなので、そのソースを探します。  
すると, `linux-2.6.32.65/include/linux/elf.h`に以下のように定義されていました。  

```
typedef struct elf32_hdr{
  unsigned char e_ident[EI_NIDENT];
  Elf32_Half    e_type;
  Elf32_Half    e_machine;
  Elf32_Word    e_version;
  Elf32_Addr    e_entry;  /* Entry point */
  Elf32_Off     e_phoff;
  Elf32_Off     e_shoff;
  Elf32_Word    e_flags;
  Elf32_Half    e_ehsize;
  Elf32_Half    e_phentsize;
  Elf32_Half    e_phnum;
  Elf32_Half    e_shentsize;
  Elf32_Half    e_shnum;
  Elf32_Half    e_shstrndx;
} Elf32_Ehdr;
```

ここでhelloのELFを見てみます。  

```sh
readelf -S hello | head -n 11
There are 41 section headers, starting at offset 0x8e4e4:

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .note.ABI-tag     NOTE            080480d4 0000d4 000020 00   A  0   0  4
  [ 2] .note.gnu.build-i NOTE            080480f4 0000f4 000024 00   A  0   0  4
  [ 3] .rel.plt          REL             08048118 000118 000028 08   A  0   5  4
  [ 4] .init             PROGBITS        08048140 000140 000030 00  AX  0   0  4
  [ 5] .plt              PROGBITS        08048170 000170 000050 00  AX  0   0  4
  [ 6] .text             PROGBITS        080481c0 0001c0 069b4c 00  AX  0   0 16
```

`.text`の`Off`が`0001c0`になっており、これはファイルの先頭から`1c0`byte目からtext sectionが始まっていることを表しています。  
次にhexeditで`1c0`付近の`1f0`をみてみると、`55 89`となっています。`.text`の`Addr`は`080481c0`なので`080481f0`には`55 89`という命令があると予想できます。  

実際に`objdump -d hello`で確認してみると

```
080481f0 <__do_global_dtors_aux>:
 80481f0:       55                      push   %ebp
 80481f1:       89 e5                   mov    %esp,%ebp
```

`080481f0`から`55 89`という命令があり、ELF通りになっていることが確かめられました。

また、readelfには`--segments`と`--sections`というように、sectionとsegmentsという管理単位があり、sectionはlink時に、segmentsはprogram load時に参照されるという説明があります。  

ELFについては[最小限で理解しつつ作るELF parser入門 in Rust](https://zenn.dev/drumato/books/afc3e00a4c7f1d)という本をやってみたいなと思ってます。  


### 共有ライブラリ

標準Cライブラリを動的にリンクしたhelloで、共有ライブラリの仕組みを調べます。  
共有ライブラリでは仮想メモリの仕組みを通して、各プロセスで共有されるので、内部では絶対アドレスで呼び出しを行えず、これに対処するためにGOTとPLTという仕組みがあるそうです。  
いまいちこの辺りは理解出来ませんでした。


## 第9章 最適化

gccにはoptimization optionとして、`-O`があり、`-O0`,`-O1`,`-O2`,`-Os`等の指定ができる。  
これらを指定した際に実際にはどのような変化が起こるのかをみていきます。  
具体的にはELF上での変化や命令数、アセンブラの変化を調べます。  
`printf()`が`puts()`になるのは知りませんでした。


## 第10章 様々な環境と様々なアーキテクチャ

これまではLinux/x86上でのhello worldを見てきましたが、このCentOS上でcompileされた実行ファイルはFreeBSD上で動作するでしょうか。  
(FreeBSDのLinuxエミュレーション機能を利用しなければ)この実行ファイルは動作しません。理由は同じx86であってもFreeBSDのシステムコールABIが違うからです。  
この章ではいろいろな環境でのシステムコール関連の実装を見ていきます。  
システムコールのABIが違うとは具体的にどういうことなのか実際に見ることができて大変勉強になりました。  

APIがPOSIXに準拠していれば、OS間で互換性があるというのは具体的にこういうことだったのかというが少しわかった様な気がしました。


## 第11章 可変長引数の扱い

printf()は可変長引数なのですが、この機能はアセンブラでどのように実現されているかを見ていきます。  
x86では引数の個数と引数をスタックに積んで処理されていることがわかります。  
ARM版の解説もあります。


## 第12章 解説の集大成 - システムコールの切り替えを見る

この本を読んでみようとおもったきっかけの一つに[cfsamson先生](https://github.com/cfsamson)の[The Node Experiment - Exploring Async Basics with Rust](https://cfsamson.github.io/book-exploring-async-basics/3_1_communicating_with_the_os.html)という記事を読んでいた際にVDSOがでてきたからというのがあります。  
そこでは

> The syscall instruction is a rather new one. On the earlier 32-bit systems in the x86 architecture, you invoked a syscall by issuing a software interrupt int 0x80. A software interrupt is considered slow at the level we're working at here so later a separate instruction for it called syscall was added. The syscall instruction uses VDSO, which is a memory page attached to each process' memory, so no context switch is necessary to execute the system call.  

と述べられており、最初は理解できなかったのですが、本章を読んでみて、言いたいことの概要が理解できました。  
ただし、本章はかなり詳細にコード追っていくのですが現状の自分の力ではなかなか追いきれませんでした。  
ただ、VDSOがどのレイヤーの話なのかはなんとなくわかったのでそれだけで現状では十分ということにしてます。


## まとめ

非常に勉強になる本でした。現時点で理解できていない箇所も多いですがそれでも読んでみてよかったと思っております。  
実行ファイルを命令レベルで読んでいくので、再現環境を用意してもらえているのが非常に助かりました。  
ABI, UNIX互換、POSIX APIといった考えそれぞれが具体例付きで解説されており、非常に参考になりました。  

FreeBSDのdirectory構造やソースコードがとても綺麗で興味沸きました。


## 参考

* [本書のサポートページ](http://kozos.jp/books/helloworld/)
* [IntelとAT&T Syntaxの違い](https://imada.sdu.dk/u/kslarsen/dm546/Material/IntelnATT.htm)

