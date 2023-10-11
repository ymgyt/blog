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

## TODO
* ch02のDefaultCPUAccountingについてcgourp読んでから言及する
* ch2 unit typeごとのchへの参照

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

systemdによってinterfaceは統一されたが、distributionsによって有効にしているcomponentは違うのでそこで差が生じる。  
というわけで設定fileを確認してみる。   
NixOSの`/etc/systemd/system.conf`を確認してみたところ以下の内容だった

```text
[Manager]
ManagerEnvironment=LOCALE_ARCHIVE='/run/current-system/sw/lib/locale/locale-archive' PATH='/nix/store/jq4cqqgggw3x4rl67ib0zs8mbgczhqqg-e2fsprogs-1.47.0-bin/bin:/nix/store/p27k6zns5rrv80326zkv88yfmfw1zb9v-dosfstools-4.2/bin:/nix/store/ixjl0rdryakqci8rf70i6zh0h9qg3c43-util-linux-minimal-2.39.2-bin/bin' TZDIR='/etc/zoneinfo'
DefaultCPUAccounting=yes
DefaultIOAccounting=yes
DefaultBlockIOAccounting=yes
DefaultIPAccounting=yes
DefaultLimitCORE=infinity
```

この設定値の意味については`man systemd-system.conf`で調べられる。  
`ManagerEnvironment`はmanager processにsetされる環境変数とのことだった。  nixらしく、`PATH`をnix storeにむけていて、globalをみないという意思を感じられる。  

TODO: Accountingについて調べる。

ここでsystemdにおけるunit fileの概要が説明される。 
defaultでは`/lib/systemd/system/`配下に格納されており、変更や追加したい場合は`/etc/systemd/system/`を利用する。  

これはどうしてかというと`man systemd.unit`に書いてあるから。  
この本の素晴らしい点は概要を説明したのち、詳しいことについては読むべき`man systed.*`を教えてくれるところだった。  
特に、設定file中でわからない項目は`man systed.directives`を調べるとそれがどのmanに載っているか教えてくれるというアドバイスが非常にありがたかった。  

例えば、serviceに設定する環境変数をfileで指定する`EnvironmentFile`については

```sh
man systemd.directives | grep 'EnvironmentFile=' -A 2

 EnvironmentFile=
           systemd.exec(5)
```

と表示され、`man systemd.exec`をみればよいことがわかる。  
stackoverflowのsystemd関連の回答では大抵、このmanの説明と同じことが説明されていた。調べ方を教えてくれるのが一番助かる。

TODO: 各service typeがどのchで説明されているか書く

unit fileは以下のtypeをもっている。  
逆にいうとunit fileとはこれらの設定を抽象化したものともいえると思った。
* service
* socket
* slice
* mount
* target
* timer
* path
* swap

systemでどんなunitが動いているかは`systemctl list-units`で調べられる。  
`-t`でtypeを指定できたり、`--all`で有効にされていないものも表示できる  
他にもいろいろな使い方があり、とても参考になった。  
詳しくは`systemctl -h`と`man systemctl`


## Chapter 3 Understanding Service, Path, and Socket Units

Service unitはSysVのinit scriptの役割を果たす。つまりdaemonを制御する。  
設定でわからない項目は`man systemd.directives`で調べる。  
`[Unit]`については、`man systemd.unit`、`[Service]`については`man systemd.service`で調べられる。また、実行時に共通する話は`man systemd.exec`にも説明がある。


## Chapter 7 Understanding systemd Timers 

systemd timerを使うことでcronのようなscheduling処理ができる。

## memo

* `man systemd-system.conf`
* `man systemd.unit`