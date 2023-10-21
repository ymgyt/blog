+++
title = "❄️ NixOSとRaspberry Piで自宅server | Part 5 CPUの温度をmetricsとして取得"
slug = "homeserver-with-nixos-and-raspberrypi-get-cpu-temperature"
description = "CPUの温度を取得してopentelemetryのmetricsとして扱えるようにします"
date = "2023-10-22"
draft = false
[taxonomies]
tags = ["nix", "opentelemetry", "rust"]
[extra]
image = "images/emoji/snowflake.png"
+++

[Part 1 NixOSをinstall](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-install-nixos/)  
[Part 2 deply-rsでNixOS Configurationを適用](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-deploy-with-deploy-rs/)  
[Part 3 ragenixでsecret管理](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-secret-management-with-ragenix/)  
[Part 4 opentelemetry-collectorとopenobserveでmetricsを取得](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-export-metrics-with-opentelemetry-collector/)  
Part 5 CPUの温度をmetricsとして取得(👈 この記事)

[Part 4]でopentelemetry-collectorを導入してmetricsを取得してbackend(openobserve)に送れるようになりました。  
Part 5ではopentelemetry-collectorの機能だけでは取得できないCPUの温度を取得して、metricsとして扱えるようにしていきます。  
ゴールは以下のようにCPU温度をdashboardに表示するところまでです。    
{{ figure(images=["images/ss-cpu-temp.png"]) }}

[source](https://github.com/ymgyt/mynix/tree/main/homeserver)

## きっかけ

{{ figure(images=["images/ss-bottom.png"], caption="btm出力") }}

[`btm`](https://github.com/ClementTsang/bottom)を実行しているとCPUの温度が表示されていました。(中段のTemperatures)  
家に置いているのでraspiが熱くなって火事になったら怖いなと思い、CPU温度をmetricsにしてalertを設定したくなりました。 

## 概要

{{ figure(images=["images/cpu-metrics-overview.png"]) }}

作成する処理の概要としては以下のようになります。  

1. systemd timerを利用してcpu温度を取得するscriptを定期実行する
2. scriptの中でcpu温度を取得してlocalで起動しているopentelemetry-collectorにmetricsをexportする
3. opentelemetry-collectorからopenobserveにexportする

systemd timerはcronのようなものです。[systemd本](https://blog.ymgyt.io/entry/linux-service-management-made-easy-with-systemd/)を読んで知ったので利用してみます。  

scriptの中で取得したcpu温度をopentelemetry-collectorに送るために[`opentelemetry-cli(otel)`](https://github.com/ymgyt/opentelemetry-cli)を作りました。

scriptから直接openobserveにexportしないのは以下の点からです。  

* Resource(そのmetricsがどこから来たかの情報)の取得や付与をcollector側で行いたい
* Retryやbatchもcollectorにまかせたい
* openobserveの認証情報を1箇所に置いておきたい


## systemd timer

まずはscriptを定期実行するためにsystemd timerを設定します。  
設定としてはいつどのserviceを呼び出すかを定義しておくとsystemd側でserviceを起動してくれます。  
自分がすごいなと思ったのは`AccuracySec=1m`のように設定しておくと、指定の時刻から1分の範囲内で起動時間をrandomにズラしてくれ、その際の消費電力を最小化するようなことも考慮してくれる点です。  

`man systemd.timer`の説明  

> Within this time window, the expiry time will be placed at a host-specific, randomized, but stable position that is synchronized between all local timer units. This is done in order to optimize power consumption to suppress unnecessary CPU wake-ups.

nixの設定は以下のように行いました。  
`modules/metrics/cpu-temperature/default.nix`  

```nix
{ pkgs, opentelemetry-cli, ...}:
{
  systemd.timers."cpu-temp-metrics" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "cpu-temp-metrics.service";
      OnCalendar = "minutely";
      Persistent = "false";
      AccuracySec = "1m";
     };
  };

  systemd.services."cpu-temp-metrics" = 
  let
    otel = opentelemetry-cli.packages."${pkgs.system}".opentelemetry-cli;
  in
  {
    path = [ 
      pkgs.gawk 
      otel
    ];
    script = builtins.readFile ./script.sh;
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = "true";
      Nice = "19";
    };
  };
}
```

`systemd.timers."cpu-temp-metrics"`がtimerの設定です。  
`man systemd.special`によると

>  timers.target  
    A special target unit that sets up all timer units (see systemd.timer(5) for details) that shall be active after boot.  
>    It is recommended that timer units installed by applications get pulled in via Wants= dependencies from this unit.   
This is best configured via WantedBy=timers.target in the timer unit's [Install] section.
とあるので、`wantedBy`には`timers.target`を指定しました。  

`timerConfig.Unit`には起動するserviceを指定します。  
省略すると同じunit名のserviceが起動されるようですが明示的に指定しました。  
`timerConfig.OnCalendar`が起動する時間です。`minutely`が具体的にはいつなのかは`man systemd.time`に定義されています。  
`timerConfig.Persistent`はschedule時に電源がoffだった場合に起動時に実行するかの指定です。不要なのでfalse。  
`timerConfig.AccuracySec`はさきほど述べた起動時間のwindowです。いつでもよいので、`1m`にしました。  

上記のような設定をおこなうとsystemd上は以下のような設定が出力されました。   
`systemctl cat cpu-temp-metrics.timer` 

```ini
# /etc/systemd/system/cpu-temp-metrics.timer
[Unit]

[Timer]
AccuracySec=1m
OnCalendar=minutely
Persistent=false
Unit=cpu-temp-metrics.service
```

## Scriptの作成

次に定期実行されるscriptを作成します。  
scriptをraspiに設定してsystemd timerから起動するために以下のように設定しました。  

`modules/metrics/cpu-temperature/default.nix`

```nix
{ pkgs, opentelemetry-cli, ...}:
{
  systemd.timers."cpu-temp-metrics" = {
    # ...
  };

  systemd.services."cpu-temp-metrics" = 
  let
    otel = opentelemetry-cli.packages."${pkgs.system}".opentelemetry-cli;
  in
  {
    path = [ 
      pkgs.gawk 
      otel
    ];
    script = builtins.readFile ./script.sh;
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = "true";
      Nice = "19";
    };
  };
}
```

`systemd.services.<name>.script`に実行したいscriptを指定するとscriptを実行するsystemd serviceを作れます。  
このserviceはtimerから利用されることを意図しているので、`serviceConfig.Type = "oneshot"`を指定しました。  
`path`を指定すると、scriptの中から指定されたpackageに`PATH`が通っている状態にできます。[opentelemetry-cli]はmetricsをexportするために利用します。  

これで必要な依存はnixが管理してくれるscriptが書けるようになりました。 
  

## CPU温度の取得

CPU温度を取得してopentelemetry-collectorにexportするscriptについてみていきます。  
`modules/metrics/cpu-temperature/script.sh`

```sh
function get_cpu_temperature() {
  cat /sys/class/thermal/thermal_zone0/temp
}

function main() {
  local raw_temp=$(get_cpu_temperature)
  local temp=$(awk "BEGIN { print $raw_temp / 1000 }")

  # export to local collector
  otel export metrics gauge \
    --endpoint http://localhost:4317 \
    --name system.cpu.temperature \
    --description "cpu temperature" \
    --unit Cel \
    --value-as-double ${temp} \
    --attributes "thermalzone:0" \
    --schema-url https://opentelemetry.io/schemas/1.21.0
}

main
```

CPU温度の取得自体は`/sys/class/thermal/thermal_zone0/temp`をcatするだけです。  
この処理は[bottomの処理](https://github.com/ClementTsang/bottom/blob/4174012b8f14cbf92536c103c924b280e7a53b58/src/app/data_harvester/temperature/linux.rs#L316)から盗みました。  
commentに記載されている[https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-thermal](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-thermal)では以下のような説明がありました。

> What:		/sys/class/thermal/thermal_zoneX/temp  
  Description:
		Current temperature as reported by thermal zone (sensor).  
	Unit: millidegree Celsius


## Metricsのexport

CPU温度を取得できたので、localで起動しているopentelemetry-collecotrにmetricsをexportしていきます。  

[opentelemetry-cli]では基本的にexportしたいmetricsを[grpc/protobufに詰め替えているだけ](https://github.com/ymgyt/opentelemetry-cli/blob/2c240ff81d55bf9801dca274d4705ea1d13510cc/src/cli/export.rs#L137)です。  
うれしいのは、otlp関連の処理は[`opentelemetry-proto`](https://github.com/open-telemetry/opentelemetry-rust/tree/main/opentelemetry-proto)のおかげで、生成されたrustのcodeを利用できるので、protobuf生成関連の処理をまかせることができる点です。なので1 metricsを送るだけなら本当に詰替えだけしか必要なかったです。  

Exportするmetricsのdata modelに関してはprotobufのcommentの説明がわかりやすかったので引用します。

```text
  Metric
//  +------------+
//  |name        |
//  |description |
//  |unit        |     +------------------------------------+
//  |data        |---> |Gauge, Sum, Histogram, Summary, ... |
//  +------------+     +------------------------------------+
//
//    Data [One of Gauge, Sum, Histogram, Summary, ...]
//  +-----------+
//  |...        |  // Metadata about the Data.
//  |points     |--+
//  +-----------+  |
//                 |      +---------------------------+
//                 |      |DataPoint 1                |
//                 v      |+------+------+   +------+ |
//              +-----+   ||label |label |...|label | |
//              |  1  |-->||value1|value2|...|valueN| |
//              +-----+   |+------+------+   +------+ |
//              |  .  |   |+-----+                    |
//              |  .  |   ||value|                    |
//              |  .  |   |+-----+                    |
//              |  .  |   +---------------------------+
//              |  .  |                   .
//              |  .  |                   .
//              |  .  |                   .
//              |  .  |   +---------------------------+
//              |  .  |   |DataPoint M                |
//              +-----+   |+------+------+   +------+ |
//              |  M  |-->||label |label |...|label | |
//              +-----+   ||value1|value2|...|valueN| |
//                        |+------+------+   +------+ |
//                        |+-----+                    |
//                        ||value|                    |
//                        |+-----+                    |
//                        +---------------------------+
//
```

`Gauge`や`Sum(Counter)`であってもnameやdescriptionは共通です。  
それぞれのmetricは複数の`DataPoint`をもち、datapointに値やtimestamp, attribute(例 `state=idle`)を保持します。

[Metrics data model](https://github.com/open-telemetry/opentelemetry-proto/blob/ac3242b03157295e4ee9e616af53b81517b06559/opentelemetry/proto/metrics/v1/metrics.proto#L89)

これを以下のようにしてexportしました。

```sh
  otel export metrics gauge \
    --endpoint http://localhost:4317 \
    --name system.cpu.temperature \
    --description "cpu temperature" \
    --unit Cel \
    --value-as-double ${temp} \
    --attributes "thermalzone:0" \
    --schema-url https://opentelemetry.io/schemas/1.21.0
```

### Collectorにreceiverを追加

opentelemetry-collectorにgrpcでmetricsを送れるようにreceiverを追加します。  

`modules/opentelemetry-collector/config.yaml`
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "127.0.0.1:4317"
# ...
service:
  extensions: [memory_ballast]
  pipelines:
    metrics:
      receivers: 
        - otlp
#...
```

## まとめ

{{ figure(images=["images/ss-cpu-temp-dashboard.png"], caption="取得したmetrics") }}

ここまでの設定をdeployすることで、CPUの温度をmetricsとして取得することができました。  
概ね、30 ~ 35℃になっていました。  
1台だけ(`rpi4-01`)だけ購入した時期が違うためか、若干、他のhostに比べて温度が高いということがわかりました。

ここまでお読みいただき、ありがとうございました。


[Part 1]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-install-nixos/
[Part 2]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-deploy-with-deploy-rs/  
[Part 3]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-secret-management-with-ragenix/  
[Part 4]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-export-metrics-with-opentelemetry-collector/  
[opentelemetry-cli]: https://github.com/ymgyt/opentelemetry-cli
