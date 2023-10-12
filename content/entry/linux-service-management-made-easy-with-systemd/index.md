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
また、unit fileがどのdirectoryから取得されるかは、`systemd-analyze unit-paths`で表示できることもわかった。   
stackoverflowのsystemd関連の回答ではこのmanの説明と同じことが説明されていた場合が結構多く、調べ方を教えてくれるのが一番助かる。



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
設定でわからない項目は`man systemd.directives`で調べられる。  
`[Unit]`については、`man systemd.unit`、`[Service]`については`man systemd.service`で調べられる。また、実行時に共通する話は`man systemd.exec`にも説明がある。

httpdやsshd serviceの具体例をみながらどんな項目があるのかの概要を説明してくれる。最初からmanをみるのは大変なので、説明があった箇所のmanあたりから読んでいくのが自分にはよかった。

また、`systemd-timesyncd`ではcapabilitiesの設定がなされており、それについても説明があった。

```ini
# ...
[Service]
AmbientCapabilities=CAP_SYS_TIME
CapabilityBoundingSet=CAP_SYS_TIME
ExecStart=!!/nix/store/qyxcg96wg1a21sj0sgbaxcapqc1vyq65-systemd-253.6/lib/systemd/systemd-timesyncd
# ...
User=systemd-timesync
```

自分でserviceを定義する際は、root userを利用せずにcapabilitiesをセットできるようにしていきたい。  
(`ExecStart=!!`の`!!`については`man systemd.service`に説明があった)

socket unitについても説明がある。  
が、いまいち使いどころがわかっていない。

path unitは、指定のfile pathの変更を監視して、変更があった場合に指定のserviceを起動してくれるものとのことです。  
これもいまいち使いどころがわかっていないです。


## Chapter 7 Understanding systemd Timers 

systemd timerを使うことでcronのようなscheduling処理ができる。

NixOS上で有効なtimerを確認したところ、logrotationとtmpfileのclean処理が起動していた。

```sh
$ systemctl list-units -t timer
  UNIT                         LOAD   ACTIVE SUB     DESCRIPTION
  logrotate.timer              loaded active waiting logrotate.timer
  systemd-tmpfiles-clean.timer loaded active waiting Daily Cleanup of Temporary Directories
```

systemdでtimerを利用して処理をschedulingするには、まずtimer unitを作成してそこからservice unitを起動するという構成にするらしい。  

ということで、logroate.timerを確認してみる。

```ini
$ systemctl cat logrotate.timer

# /etc/systemd/system/logrotate.timer
[Unit]

[Timer]
OnCalendar=hourly
```

起動する処理が指定されていないが、`man systemd.timer`によると

>  For each timer file, a matching unit file must exist, describing the unit to activate when the
       timer elapses. By default, a service by the same name as the timer (except for the suffix) is
       activated. Example: a timer file foo.timer activates a matching service foo.service.

ということで、`logrotate.timer`は`logrotate.service`を起動するようだった。  

`OnCalendar=hourly`と指定した場合、具体的にいつ実行されるかは`man systemd.time`の`CALENDAR EVENTS`に説明があり、`hourly → *-*-* *:00:00`と解釈されるようだった。

`AccuracySec=1h`のようにどの程度schedulingされた時間に対して精度を要求するかも指定できる。manによると消費電力を最適化するためにできるだけ大きい値を設定しておくのが望ましいらしい。

また、`Persistent=true`でschedulingされた期間に電源がoffだった場合、起動時に実行するかも制御できそうだった。  

`Nice=`,`IOSchedulingClass=`,`SchedulingPriority`等で、実行するserviceの優先度も指定できそうだったので、設定する際は調べておきたい。


## Chapter 14 Using journald

本章ではjournald,journalctlの説明をしてくれます。  
journaldとrsyslogの比較の話は勉強になりました。本書執筆時点(2021)では、journaldに完全移行したdistroはないそうで、journaldとrsyslogが並行稼働しているのが実情のようでした。

`journalctl --disk-usage`でlogのdisk使用量みれたりするのも知らなかったので、`man journald.conf`と`man journalctl`を読まないとだめだなと思いました。  

`journalctl --flush`して、`journalctl --rotate --vacuum-time=5d`のようにしてlogをrotateされる方法等についても解説されています。
`journalctl`についてもいろいろな使い方の具体例がのっているので、一度読んだ後man読むとだいぶ使い方がわかりそうです。  

自分はもっぱら、`journalctl -u opentelemetry-collector -f`のような感じでserviceごとのlogの見方がわかっただけで大変助かりました。  
logがどこに出力されるのかをきにしなくていいのが良いですね。

## memo

* `man systemd-system.conf`
* `man systemd.unit`