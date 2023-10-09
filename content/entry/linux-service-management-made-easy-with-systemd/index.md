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