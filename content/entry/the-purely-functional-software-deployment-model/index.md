+++
title = "📕 The Purely Functional Software Deployment Modelを読んだ感想"
slug = "the-purely-functional-software-deployment"
description = "Edolstra先生のNixの論文 The Purely Functional Software Deployment Modelを読んだ感想"
date = "2023-10-30"
draft = true
[taxonomies]
tags = ["book", "nix"]
[extra]
image = "images/emoji/closed_book.png"
+++

本記事では[The Purely Functional Software Deployment Model](https://github.com/edolstra/edolstra.github.io/blob/49a78323f6b319da6e078b4f5f6b3112a30e8db9/pubs/phd-thesis.pdf)を読んだ感想を書きます。  
Nixについて調べていると度々言及されており、Nixをやっている人は皆さん読まれている気配を感じたので読んでみることにしました。

TODO: 出版日はいつだろうか。google booksだと2006年だった


## まとめ

## 1 Introduction

この論文はsoftware deploymentついて述べている。  
ここでいう、software deploymentとはcomputer programをあるmachineから取得して動くようにすること。  
これまでdeployの手法やtoolはadhocに行われており、dundamentalなissueに対して体系的かつ規律だって扱われてこなかった。  
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

これらの問題を解決するためのNixの基本的なapproachはcentral component storeにcomponentを分離された形で配置すること。  
そのpathにはcomponentのinputのcryptographicなhashが含まれる。これにより宣言されていない依存をなくし、異なるversionを併存させることができる。

Nixにより以下の点が達成される。

* componentの分離による相互不干渉
* componentは独立しつつも、共有可能なものは共有される(resourceの有効活用)
* upgradeはatomicになされ、systemがinconsistentな状態にならない
* O(1)-timeでのrollback
* 利用されていないcomponentの自動的なgarbage collection
* componentのbuild方法だけでなく、compositionも表現できるpureなnix language
* 透過的なsource/binary deployment model
* multi-platform build

Nixが解決したいdeploymentにまつまる問題の概要がわかりました。  
Nixを始めた際に書いた[記事](https://blog.ymgyt.io/entry/declarative-environment-management-with-nix/#somosomonixtoha)で

> 現状の自分の理解ではNixとはpackage manager + build systemという認識です。 

と書いたのですが、nixはdeployment systemだったことがわかりました。

## 2 An Overview of Nix

これまでにでてきたcomponentとはbasic units of deploymentで、fileの集合。  
Nixは(通常は)`/nix/store`にcomponentを保持する。  

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

## 4 The Nix Expression Language

## 5 The EXtensional Model

## 6 The Intensional Model

## 7 Software Deployment

## 8 continuous Integration and Release Management

## 9 Service Deployment

## 10 Build Managment

## 11 Conclusion

