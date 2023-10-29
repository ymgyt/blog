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

### Memo

* この論文はsoftware deploymentについて。
  * software deploymentとは、computer programsをあるmachineを別のmachineから取得して、動くようにすること
* deploymentの方法やtoolはad hocなtoolによって行なわれており、fundamental issuesに対して体系的かつ規律だってaddressされてこなかった。
* nixはsystem for software deployment
* この章で、deploymentの問題をdescribeする

1.1 
* deploymentの問題は2つにcategorizeできる
  * environemnt issues
    * about correctness
    * systemに他のcomponentやfileが存在してほしい
    * dependenciesがidentifiedされている必要がある
    * componentがsourceでdeployされる場合は、build timeの依存も必要(compiler)
    * dependenciesは特定のfeature flagでbuildされている必要があったりする
    * またruntime時の依存は見つかるようになっている必要がある(dynamic linker search path, java CLASSPATH)
    * config file, user account, databaseにstateがあるといったsoftware artifact以外の依存もある
    * まとめるとcomponentsのrequirementsをidentifyし、どうにかいｓてそれをtarget environmentにrealiseする必要がある
  * manageability issues
    * 安全にcomponentをuninstallする必要ある
    * あるcomponentのupgradeによって他のcomponentに影響がでないようにする
    * rollbackできるようにする
    * deployの際にvariabilityをexposeする

1.2 the state of the art
* RPMについて
* source deployment models

1.3
1.2でとりあげた様々な手法は以下の問題をもっている
。これらの問題をもたないdeployment systemが必要。
* dependency specifications are not validated
* inexact
* multiple versionを共存させられない
* componentが相互に干渉する
* rollbackできない
* upgradeがatomicでない
* monolithicである必要がある。statically contain all dependencies
* sourceかbinary deploymentのどちらかしかsupportされない
* component framework が特定のprogramming言語に限定されている

1.4 The nix deployment system

Nixのapproachのmain ideaはcentral component storeにcomponentを分離された形で配置すること。
そのpathにはcomponentをbuildするためのinputのcryptographic hashが含まれる。
これにより、宣言されない依存をなくし、versionが違うcomponentを併存させることができる

1.5 contributions

nixによって達成される機能。  
* componentの分離による相互不干渉
* componentを独立にinstallしつつも、共有できるものは共有される
* upgradeはaotmic. systemがinconsistent stateになるtime windowがない
* O(1)-time rollback
* automatic garbase collection of unused components
* 


## 2 An Overview of Nix

## 3 Deployment as Memory Management

## 4 The Nix Expression Language

## 5 The EXtensional Model

## 6 The Intensional Model

## 7 Software Deployment

## 8 continuous Integration and Release Management

## 9 Service Deployment

## 10 Build Managment

## 11 Conclusion

