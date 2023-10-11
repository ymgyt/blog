+++
title = "📗 Linux Service Management Made Easy with systemdを読んだ感想"
slug = "linux-service-management-made-easy-with-systemd"
description = "Linux Service Management Made Easy with systemd本の概要だったりよかったところについて"
date = "2023-10-10"
draft = true
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/green_book.png"
+++

## 読んだ本

{{ figure(images=["images/systemd-book.jpg"]) }}

[Linux Service Management Made Easy with systemd](https://learning.oreilly.com/library/view/linux-service-management/9781801811644/)

systemdについて説明してくれている本ないかなと思っていて見つけたので読んでみました。　　

## 良かったところ

TODO:

* 歴史的経緯
* distributionの違い
* cgroup
* timerd, logind, ...

## Chapter 1 Understanding the Need for systemd

SysV Initやupstartの歴史について。  
特にSysVの問題点としては  
* serviceの起動処理がsequentialであることから起動時間が長くなってしまうこと
* serviceの制御がbashのscriptで行なわれるので複雑

bashのscriptにしても

```sh
case "$ARG" in
  start)
    start
    ;;
  status)
    status
    ;;
  # ...
esac
```

のようにそれぞれのscriptで実装しているのでstatusの出力になにか決まったformatがあるわけではなかった。

systemdの利点の一つとして、linux distributions間での統一性にも言及されていた。用はdistroに限らず同じsystemdのcommandだけ覚えればよい。  
また、processをkillする際もsystemdが対象processのchild processも考慮してくれるのでzombieを気にしなくてよい。  

securityという観点からも、accessできるdirectoryを制限できたり、namespaces, cgroups, capabilitiesといった機能を利用できるように設計されている。  

systemd最高..!とおもいきや、systemdの採用には議論もあった。  
そのひとつにsystemdは多くを行いすぎており、unixのconceptである一つのことをうまくやるに反しているというものがあった。  
この点については、確かにinit systemを超えて、networkやbootloader, logging, loginまでsystemdは行なっているが、これらはoptionalであると反論されていた。  

systemdに関してはいろいろと議論もあるし、嫌いな人もいるが、主要なdistributionでは結局採用されているよねという感じで結ばれていました。  

といったようにsystemdが解決しようとした課題であったり、現在の状況が整理されておりこういった情報は自分のようなlinux弱者にはとてもありがたいです。


## Chapter 2 Understanding systemd Directories and Files


