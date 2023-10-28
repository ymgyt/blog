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
  * manageability issues

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

