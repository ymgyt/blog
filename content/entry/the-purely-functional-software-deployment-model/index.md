+++
title = "📕 The Purely Functional Software Deployment Modelを読んだ感想"
slug = "the-purely-functional-software-deployment"
description = "Edolstra先生のNixの論文 The Purely Functional Software Deployment Modelを読んだ感想"
date = "2023-11-06"
draft = false
[taxonomies]
tags = ["book", "nix"]
[extra]
image = "images/emoji/closed_book.png"
+++

本記事では[The Purely Functional Software Deployment Model](https://github.com/edolstra/edolstra.github.io/blob/49a78323f6b319da6e078b4f5f6b3112a30e8db9/pubs/phd-thesis.pdf)を読んだ感想を書きます。  
Nixについて調べていると度々言及されており、Nixをやっている人は皆さん読まれている気配を感じたので読んでみることにしました。

## まとめ

難してく読めなかったところも多々あったが、通して読んでみてよかった。  
Nixはdeployment systemであり、既存のdeploymentにはどんな問題があり、nixはどのようにアプローチしたかというのが全体の流れで、今まで触っていたnixの各機能はどんな問題に対処するためにあるのかを知れた。

## 1 Introduction

この論文はsoftware deploymentついて述べている。  
ここでいう、software deploymentとはcomputer programをあるmachineから取得して動くようにすること。  
これまでdeployの手法やtoolはadhocに行われており、fundamentalなissueに対して体系的かつ規律だって扱われてこなかった。  
本章ではまずsoftware deploymentにはどういった問題があるのかについて述べている。

deploymentに関する問題は大きく、environment issuesとmanageability issuesという問題に分類できる。  

Environmnet issuesの具体例としては

* systemに他のcomponentやfileが存在していてほしい
* dependenciesが特定されている必要がある
* componentがsourceでdeployされる場合は、build timeのdependenciesが必要(compiler等)
* dependenciesは特定のfeature(flag)でbuildされている必要がある
* runtimeの依存を見つけられること(dynamic linker search path)
* config file, user account, databaseに特定のrecordがあるといったsoftware artifact以外の依存

がある。まとめるとcomponentのrequirementsを特定(identify)し、deploy先の環境でrealiseしなければならないという問題。

Manageability issueとしては

* componentのuninstallは安全か
* あるcomponentのupgradeが他のcomponentを壊さないか
* rollbackできるか
* deploy時に様々な設定を行えるか

等がある。

1.2 The state of the artではRPMからはじまって、windowsやmac, .NET等でどのようにdeployがなされているかの説明がある。  
Zero install systemというものがあることを初めて知った。

既存のdeploymentの問題点を整理すると以下の点が挙げられる。

* dependency specificationが不正確で検証されていない。例えば`foo`というbinaryがあればよいだけ等。
* 複数versionが共存できない
* componentが相互に干渉してしまう
* rollbackできない
* upgradeがatomicでない。(systemに不完全な時間が生じる)
* 静的にすべてを含んでいる必要がある
* sourceかbinaryどちらかしかサポートされていない
* frareworkが特定のprogramming言語に限定されている

これらの問題を解決するためのnixの基本的なapproachはcentral component storeにcomponentを分離された形で配置すること。  
そのpathにはcomponentのinputのcryptographicなhashが含まれる。これにより宣言されていない依存をなくし、異なるversionを併存させることができる。

Nixにより以下の点が達成される。

* componentの分離による相互不干渉
* componentは独立しつつも、共有可能なものは共有される(resourceの有効活用)
* upgradeはatomicになされ、systemがinconsistentな状態にならない
* \\( \mathcal{O}(1) \\) -timeでのrollback
* 利用されていないcomponentの自動的なgarbage collection
* componentのbuild方法だけでなく、compositionも表現できるpureなnix language
* 透過的なsource/binary deployment model
* multi-platform build

本章でnixが解決したいdeploymentにまつまる問題の概要がわかった。  
Nixを始めた際に書いた[記事](https://blog.ymgyt.io/entry/declarative-environment-management-with-nix/#somosomonixtoha)で

> 現状の自分の理解ではNixとはpackage manager + build systemという認識です。 

と書いたのですが、nixはdeployment systemだった。

## 2 An Overview of Nix

これまでにでてきたcomponentとはbasic units of deploymentで、fileの集合。  
Nixは(通常では)`/nix/store`にcomponentを保持する。  

store pahtは`/nix/store/bwacc7a5c5n3qx37nz5drwcgd2lv89w6-hello-2.1.1` のようにhashを含む。このhashは

* source
* build script
* build scriptへのargmentsとenvironment variables
* build dependencies(compiler,linker, libraries,tools, shell,...)

に基づいて算出される。  
最初にnixをさわったときは、hashが使わていることの意義を理解できていなかったが、componentへのpathにinputをすべて含むhashを加えることで、dependencyの指定が完全になるということが理解できた。  
`hello`に依存していると宣言するだけでは、不十分で、`hello-2.1.1`のようにversionを足したところでたいして改善しない。inputに基づいて算出されたhashを加えることで、より適切な`hello`への依存を表現できる。

[Closures](https://zero-to-nix.com/concepts/closures)の説明もある。closureをよくわかっていなかったので、この説明がありがたかった。

以下のようなhelloのderivationを例に各行の解説もしてくれる。

```nix
{stdenv, fetchurl, perl}: # 2
  stdenv.mkDerivation { # 3
    name = "hello-2.1.1"; # 4
    builder = ./builder.sh; # 5
    src = fetchurl { # 6
      url = http://ftp.gnu.org/pub/gnu/hello/hello-2.1.1.tar.gz;
      md5 = "70c9ccf9fac07f762c24f2df2290784d";
    };
    inherit perl; # 7
}
```

また、`hello`を実行すると`/nix/store/bwacc7a5c5n3qx37nz5drwcgd2lv89w6-hello-2.1.1/bin/hello`が実行される仕組みとして、user-environmentやprofileの仕組みが解説される。  
これによって、rollbackやgarbage collectionが実現されることがわかる。

Nix expressionからcomponentがbuildされるまでに、store derivationという中間結果を経由する。nix-envはnix-instantiateとnix-store --realizeの合わせ技である旨が説明される。

### Transparent source/binary deployment

nixはsourceからcomponentをbuildsするので、source deployment modelといえる。  
ただ、sourceからのbuildには問題があり、例えば、hello componentの場合、その依存からbuildするので、stdenv-linux,gcc, bash, gnugar,curl, ...と60以上のderivationをbuildする必要がでてきてしまう。source deploymentはend-userには使いづらいものとなってしまう。  
そこで、nixはstore pathのderivation outputをあらかじめどこかにuploadしておき、build時に自分でbuildするのではなく、store pathのbuild結果を取得するように動作する。これはbuild結果を置換する点をとらえて、substituteと言われる。  

この仕組みのおかげで、userからみるとsource deploymentが自動でbinary deploymentに最適化される。  
Nix すごすぎる。


## 3 Deployment as Memory Management

まず"software component"が以下のように定義される。

> * A sofeware component is a software artifact that is subject to automatic composition.
  It can require, and be required by, other components.
> * A software component is a unit of deployment.

deployをプログラミング言語と対比させる話がおもしろかった。
programがmemoryを操作するようにdeploymentはfile systemを操作する。memory addressがfile pathに対応するので、`/usr/bin`に`gcc`を付与して、`/usr/bin/gcc`をえるのは、pointer操作に対応する。存在しないcomponentを参照するのは、dangling pointer等など。  
このアナロジーに従うと、assemblerのようなpointerに対する規律がまったくないのがunix styleのdeployment、pointer disciplineがあるC,C++にあたるのが、Nix、Javaのように完全なpointerに対する規律がある言語に対応するdeployment modelはまだない。ということになる。  
既存のfile pathを自由に扱うdeploymentはassemblerのようになんでもできると考える発想がなかった。

どうしてプログラミング言語の話がでてくるかというと、stackを走査して、pointerに見えるもの(実際はintegerかもしれない)があれば、pointerとみなしてgarbage collection時に利用する手法をdeploymentにも応用するため。具体的には、fileのcontentを走査して、file pathっぽく見えるものがあれば、そのfileはfile pathへ依存しているとみなして、deploymentにおける依存graphを作る。

fileの中身を自力で走査して依存を判別できるためには、file pathが判別できる必要がある。`/foo`をみたときにそれがfile pathかどうかはあやしい。nixはstore pathが`/nix/store/bwacc2gn3...-hello-2.1.1`になっているので、完全ではないが、file pathが判別しやすい。  
ただ、source code上で`["nix", "store", "bwacc2gn3...-hello-2.1.1"]`のようにelementの配列で保持されていたら見逃してしまうので、scanの対象はhash部分のみとするようだった。その他、文字コードであったり圧縮されていたりといろいろ考えられるが、実用上問題になっていないらしい。  

store pathにhashをいれることで、そのhashがsourceやbinaryに含まれていたら依存しているとみなすという発想はすごい。

## 4 The Nix Expression Language

Nix languageのuntypedで、purely functionalで、lazyな性質がcomponentとcompositionを表現するのに適しているという程度の理解。  

4.3.4のEvaluation rulesで

$$ SELECT: \frac{e \overset{*}{\mapsto} \lbrace as \rbrace \land \langle n = \acute{e} \rangle \in as }{e.n \mapsto \acute{e} } $$

のような記法がでてくるのですが、これの読み方がわかっていない。WASMのspecを読んでいる際にも登場して読めなかったので理解したい.. (ご存知の方おられましたら教えていただけると非常にありがたいです)

## 5 The Extensional Model

Nixにはextensional modelとintensional modelという2つのmodel(variant)がある。本章ではextensional modelについて。  
extensionalというのは、componentの中身が実際には異なっても外形的な振る舞いが同じなら同じとみなすというニュアンスと理解した。例えば、linkerが挿入したtimestampはプログラムの動作には影響を与えないので、実際にはbuildするたびに成果物はかわるが、同一(interchangeable)とみなすという考え(前提)  
裏をかえすとnixは同じinputであってもbinaryレベルでの同一のoutputまでは要求していないということだったんですね。

これまでに述べてきた、cryptographic hash, nix store, nix-instantiate(store derivation), nix-store --realize, substittutes, garbage collectionの詳細が解説される。

substituteやgarbage collectionについてよくわかっていなかったので、概要だけでも知れてよかった。(詳細は理解が及んだかあやしい)


## 6 The Intensional Model

前章のextensional modelの問題は、`/nix/store/a7wcgd..hello-3.1.2`のようなpathはそのdirectoryの実際のcontentに基づいているとは限らないという点にあった。なので、信頼できないuserのnix storeをshareできなかったり、substituteする際にも"信頼"するしかなかった。。  
Intensional modelはequalityを外部からの振る舞いではなく、内部のcontentに基づいて判定するという考え。

6.8ではNixでbuildしたりinstallできるためのcomponentに対する前提が記載されている。

## 7 Software Deployment

Nix packageについて説明がある。nix packageはcomponentのsourceやbinaryを含んでおらず、fetchして、buildするexpressionだけを含んでいる。  
また、static compositions are good(late static compositions are better)という原則が述べられている。  
static compositionを用いると、動的linkを使って、libraryのpatchを適用するといったことはできなくなるが

 > To deploy a new version of some shared component, it is neccessary to redeploy Nix expressions of all installed components that depend on it. 
 > This is expensive, but I feel that it is a worthwhile tradeoff against correctness.

と述べられており、自分もそう思った。

nixを利用していると、xxxWrapperというものを時々みかけたが、よくわかったいなかった。fifefoxのpluginを例にwrapperの機能が説明されており、わかりやすかった。
(plugin等のcomponentを環境変数で設定するscriptを1枚かませるという理解。これにより、pluginの変更がrebuildを伴わずに行える)


## 8 Continuous Integration and Release Management

CI環境にnixが適しているという話。  
CIでは適宜、依存しているcomponentをinstallする必要があるが、nixが面倒をみてくれる。  
自分はまだnixをGithub actions等でうまく利用できていないが、nixでの環境構築が魅力的なのはCIでも透過的に利用できるからと思っていたところもあったので、actionsで利用していきたい。

## 9 Service Deployment

Nixで、webserver, application server ,databaseのように複数processで機能が実現されるserviceをどのように記述できるかについて。  
Componentがtest環境で動いたことはproduction環境で動くことを保証しない。なぜなら、test環境では明示的に宣言されていないdependencyが提供されているかもしれないから。nixならcomponentをcomposeするやり方でserviceを記述できるので、こういった問題が起きない。  

Serviceという程でもないが、実際に[raspiでopentelemetry-collectorを動かす設定](https://github.com/ymgyt/mynix/blob/9af899f3f23b07ba2fe0161cddc92097e29a7499/homeserver/modules/opentelemetry-collector/default.nix)をnixで書いた際に、user account, secret, opentelemetry-collector binary, config file, systemd serviceを記述できたので、nixでserviceも表現できるというのは説得力あると思った。

## 10 Build Managment

Nixをmakeのようにlow level build managementとして使えるかについて。  
実際にCをbuildしていく具体例が載っている。

## 11 Conclusion

deployの正しさを向上させるという目的はこの論文での二つのideaで達成された。  

一つは、nix store pathにcryptographc hashを用いること。これにより、isolation, 複数versionの共存(automatic support for variability)、runtime dependenciesの検知が可能となった。この方法は、deploymentの問題に対して、file systemという最もfundamentalなlevelで対処している。  

二つ目が、purely functional deployment model。これは、componentがbuildされたあとは変化せず、build processが宣言されたinputにのみ依存するというもの。hashの仕組みと合わさり、deployment actionの相互干渉を防止し、componentやcompositionのidentificationを可能にし、deploymentに予測可能で決定的なsemanticsをもたらす。  

Nix languageのusabilityについては、nix langの経験者はhaskell等のfunctional languageの経験をもつので、まだ結論づけられないという記述があり、やっぱりそうなんだとなった。


