+++
title = "📗 Linux Service Management Made Easy with systemdを読んだ感想"
slug = "linux-service-management-made-easy-with-systemd"
description = "Linux Service Management Made Easy with systemd本の概要だったり良かったところについて"
date = "2023-10-15"
draft = false
[taxonomies]
tags = ["book", "linux"]
[extra]
image = "images/emoji/green_book.png"
+++

## 読んだ本

{{ figure(images=["images/systemd-book.jpg"]) }}

[Linux Service Management Made Easy with systemd](https://learning.oreilly.com/library/view/linux-service-management/9781801811644/)

systemdについて説明してくれている本、ないかなと思っていたら見つけたので読んでみました。　　

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

systemdの利点の一つとして、linux distributions間での統一性にも言及されていた。用はdistroに限らず同じsystemdのcommandだけ覚えればよくなる。  
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

## Chapter 4 Controlling systemd Services

`systemctl`の使い方についての解説があります。  
serviceをserver起動時に起動する`systemctl enable`を実行した際に、`/etc/systemd/system/multi-user.target.wants/`配下にsymlinkが作成されるといった点も解説されます。


## Chapter 5 Creating and Editing Services

本章ではserviceをつくる過程の解説があります。  
`systemctl edit [--full]`で既存を直接編集することもできるみたいです。  

`systemd-analyze security opentelemetry-collector`のように実行するとserviceの設定のsecurity的な評価を表示してくれます。  
試しに実行してみたところ  

```
systemd-analyze security opentelemetry-collector
  NAME                                                        DESCRIPTION                                                             EXPOSURE
✗ RemoveIPC=                                                  Service user may leave SysV IPC objects around                               0.1
✗ RootDirectory=/RootImage=                                   Service runs within the host's root directory                                0.1
✓ User=/DynamicUser=                                          Service runs under a static non-root user identity
✗ CapabilityBoundingSet=~CAP_SYS_TIME                         Service processes may change the system clock                                0.2
✓ NoNewPrivileges=                                            Service processes cannot acquire new privileges
✓ AmbientCapabilities=                                        Service process does not receive ambient capabilities
# ...
```

上記のような出力を得ました。  
設定fileの改善の余地がありそうです。  

また、podmanを使って新しいserviceを作る例も解説されています。  
kubernetesのようなcontainer orchestration使うほどでもない場合はsystemdのserviceからcontainer起動するでいいかもと思ってしまいました。

## Chapter 6 Understanding systemd Targets

targetについて。  
targetとはなにかというと

> In systemd, a target is a unit that groups together other systemd units for a particular purpose. The units that a target can group together include services, paths, mount points, sockets, and even other targets. 

[link](https://learning.oreilly.com/library/view/linux-service-management/9781801811644/B17491_06_Final_NM_ePub.xhtml#:-:text=In%20systemd%2C%20a,even%20other%20targets.)

ということで、他のserviceやpathといったunitをまとめる役割を果たすのがtargetということです。

`systemctl list-units -t target`で確認できます。  

```sh
 systemctl list-units -t target
  UNIT                      LOAD   ACTIVE SUB    DESCRIPTION
  basic.target              loaded active active Basic System
  cryptsetup.target         loaded active active Local Encrypted Volumes
  getty.target              loaded active active Login Prompts
  local-fs-pre.target       loaded active active Preparation for Local File Systems
  local-fs.target           loaded active active Local File Systems
  machines.target           loaded active active Containers
  multi-user.target         loaded active active Multi-User System
  # ...
```

`strings systemd | grep '\.target'`を実行することでいくつかのtargetはsystemdのsourceに直接定義されていることもわかりました。  
ただ、手元のNixOSで実行してみたところ、本文より出力されるtargetが少なかったです。

```sh
 strings  /nix/store/410cjrblagp3kbzlfwn6qxxn5m663jg5-systemd-253.3/lib/systemd/systemd |rg '\.target'
initrd.target
default.target
rescue.target masked
Failed to load rescue.target
Falling back to default.target.
Falling back to rescue.target.
```

`man systemd.special`にsystemdに特別扱いされるtargetの説明もあります。

また、SysV initのrunlevelとsystemd targetの比較も参考になりました。

target間の依存関係のvisualizeには  
`systemd-analyze dot default.target | dot -Tsvg out> /tmp/target.svg`  
が便利でした。


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

## Chapter 8 Understanding the systemd Boot Process

systemdのboot時の挙動について。  
`default.target`が起動の対象となり、その依存関係が解決されていく。  `default.target`は大抵、`graphical.target`か`multi-user.target`へのsymlinkになっている。  
`man systemd.special`や`man bootup`にも解説がある。  

`man bootup`のこの図がわかりやすかった。　

```text
                                       cryptsetup-pre.target veritysetup-pre.target                                                             |
           (various low-level                                v
            API VFS mounts:             (various cryptsetup/veritysetup devices...)
            mqueue, configfs,                                |    |
            debugfs, ...)                                    v    |
            |                                  cryptsetup.target  |
            |  (various swap                                 |    |    remote-fs-pre.target
            |   devices...)                                  |    |     |        |
            |    |                                           |    |     |        v
            |    v                       local-fs-pre.target |    |     |  (network file systems)
            |  swap.target                       |           |    v     v                 |
            |    |                               v           |  remote-cryptsetup.target  |
            |    |  (various low-level  (various mounts and  |  remote-veritysetup.target |
            |    |   services: udevd,    fsck services...)   |             |              |
            |    |   tmpfiles, random            |           |             |    remote-fs.target
            |    |   seed, sysctl, ...)          v           |             |              |
            |    |      |                 local-fs.target    |             | _____________/
            |    |      |                        |           |             |/
            \____|______|_______________   ______|___________/             |
                                        \ /                                |
                                         v                                 |
                                  sysinit.target                           |
                                         |                                 |
                  ______________________/|\_____________________           |
                 /              |        |      |               \          |
                 |              |        |      |               |          |
                 v              v        |      v               |          |
            (various       (various      |  (various            |          |
             timers...)      paths...)   |   sockets...)        |          |
                 |              |        |      |               |          |
                 v              v        |      v               |          |
           timers.target  paths.target   |  sockets.target      |          |
                 |              |        |      |               v          |
                 v              \_______ | _____/         rescue.service   |
                                        \|/                     |          |
                                         v                      v          |
                                     basic.target         rescue.target    |
                                         |                                 |
                                 ________v____________________             |
                                /              |              \            |
                                |              |              |            |
                                v              v              v            |
                            display-    (various system   (various system  |
                        manager.service     services        services)      |
                                |         required for        |            |
                                |        graphical UIs)       v            v
                                |              |            multi-user.target
           emergency.service    |              |              |
                   |            \_____________ | _____________/
                   v                          \|/
           emergency.target                    v
                                       graphical.target
```

ここでも`systemd-analyze`が登場する。  
引数をつけないと`systemd-analyze time`が実行され起動時の実行時間を出力してくれる。

```sh
# 手元のlaptop
> systemd-analyze
Startup finished in 5.128s (firmware) + 5.824s (loader) + 2.590s (kernel) + 7.575s (userspace) = 21.118s
graphical.target reached after 7.551s in userspace.

# raspi
$ systemd-analyze
Startup finished in 5.496s (kernel) + 33.766s (userspace) = 39.263s
multi-user.target reached after 33.766s in userspace.
```

さらに`systemd-analyze blame`で何に時間を要しているかもわかる。  
```sh
$ systemd-analyze blame
30.169s dhcpcd.service
 1.646s mount-pstore.service
 1.220s firewall.service
 # ...
```

手元のraspiの場合、dhcp関連で時間がかかっているようだった。  
`systemd-analyze critical-chain`というのもあり、実行してみたところ以下の出力をえた。

```sh
systemd-analyze critical-chain
The time when unit became active or started is printed after the "@" character.
The time the unit took to start is printed after the "+" character.

multi-user.target @33.766s
└─network-online.target @33.765s
  └─network.target @3.106s
    └─network-pre.target @2.822s
      └─firewall.service @964ms +1.220s
        └─systemd-journald.socket @764ms
          └─system.slice @726ms
            └─-.slice @726ms
```

`blame`だとdhcpが遅そうだったが、そういうわけでもないのだろうか。manをもう少し読んで見方を理解したい。

また、systemd generatorの解説もありました。

## Chapter 9 Setting System Parameters

systemの設定にまつわる話。  
以下の解説があります。  

* localeを制御できる`localectl`
* timezone関連の`timedatectl` 
* hostname関連の`hostnamectl`

この手の話もlinux弱者の自分には非常にありがたいです。

## Chapter 10 Understanding Shutdown and Reboot Commands

systemdのshutdownは`systemctl poweroff`で実行できる。  
`man systemctl`のpoweroffの説明によるとこのcommandは`systemctl start poweroff.target --job-mode=replace-irreversibly --no-block`とほぼ同じらしい。

rebootは`systemctl reboot`。こちらも同様に実際にはreboot.targetの起動になっている。

また、`shutdown`コマンドもsystemctlへのsymlinkになっていることがわかった。ただ、`systemctl now`を実行してもshutdownが実行されるわけではないので、おそらくsystemctl側で、自身の実行commandを取得して、shutdownとして振る舞うような処理があるのではと思われる。

systemdのtargetの仕組みを利用して、終了時に実行したい処理を定義する例ものっている。

## Chapter 11 Understanding cgroups Version 1

systemdとcgroupについて。
cgroupの歴史についても説明してくれます。
執筆時点(2021)ではFedora, Arch, Debian, Ubuntu 21.10がcgroup v2を利用しているそうです。

cgroupを用いることでsystem管理者は例えば以下のことができる。  

* resourceの使用をuserやprocess単位で行える
* multi-tenantのようなシステムにおいてbillingのための正確なresourceの利用量を追跡できる
* 実行中のprocessを隔離できる
* processを同じCPUで実行することでperformanceを向上

`systemd-cgls`でsystemで実行中のcgroupを表示できる。


## Chapter 12 Controlling Resource Usage with cgroups Version 1

本章では実際にcgroupのcontrollerを利用して、cpuやmemory割当を変えてみる例が解説されます。


## Chapter 13 Understanding cgroup Version 2

本章ではcgroup Version 2について扱います。  
ちなみにcgroup**s** Version 1とcgroup Version 2は意図的な変更のようです。  
cgroup難しい。

## Chapter 14 Using journald

本章ではjournald,journalctlの説明をしてくれます。  
journaldとrsyslogの比較の話は勉強になりました。本書執筆時点(2021)では、journaldに完全移行したdistroはないそうで、journaldとrsyslogが並行稼働しているのが実情のようでした。

`journalctl --disk-usage`でlogのdisk使用量みれたりするのも知らなかったので、`man journald.conf`と`man journalctl`を読まないとだめだなと思いました。  

`journalctl --flush`して、`journalctl --rotate --vacuum-time=5d`のようにしてlogをrotateされる方法等についても解説されています。
`journalctl`についてもいろいろな使い方の具体例がのっているので、一度読んだ後man読むとだいぶ使い方がわかりそうです。  

自分はもっぱら、`journalctl -u opentelemetry-collector -f`のような感じでserviceごとのlogの見方がわかっただけで大変助かりました。  
logがどこに出力されるのかをきにしなくていいのが良いですね。


## Chapter 15 Using systemd-networkd and systemd-resolved

networkdとresolvedの概要について。  
ubuntuのnetplanの説明やnetworkctl, resolvectlの使い方の説明もあります。

## Chapter 16 Understanding Timekeeping with systemd

Network Time Protocol(NTP)について。  
systemd-timesyncdだけでなく、ntpdやchronyについての概要の説明もあります。

NixOSだと`/etc/systemd/timesyncd.conf`は以下のように設定されていました。  

```ini
[Time]
NTP=0.nixos.pool.ntp.org 1.nixos.pool.ntp.org 2.nixos.pool.ntp.org 3.nixos.pool.ntp.org
```

## Chapter 17 Understanding systemd and Bootloaders

systemd-bootについて。systemd-boot**d**ではない。  
systemd-bootの話に入る前にGRUB2についての解説もありありがたい。


## Chapter 18 Understanding systemd-logind

systemdがloginまで管理するのはcgroupと関連するからという話。  
loginctlやpolkitの説明もあります。

## まとめ

簡単にですが感想を書いてみました。  
当初はRaspberry PiでNixOSを動かす際に、[systemd.services](https://search.nixos.org/options?channel=23.05&from=0&size=50&sort=relevance&type=packages&query=systemd.services)の設定を理解したいと思い読んだのですが、services以外にもいろいろな解説があったので非常に参考になりました。  

systemctlやjournalctlだけでなく、systemd-analyze,localectl,timedatactl,loginctl,networkctl等も使えるようになっていきたいです。  
自分の理解が至らない箇所も多かったですが、ひとまずsystemd関連わからないことがあればまずはman読んでみようという心持ちになれたのがよかったです。  

~~ちなみに筆者は読者の心を読む能力をもっているので注意してください。~~

