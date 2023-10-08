+++
title = "❄️ NixOSとRaspberry Piで自宅server | Part 4 opentelemetry-collectorでmetricsを取得"
slug = "homeserver-with-nixos-and-raspberrypi-export-metrics-with-opentelemetry-collector"
description = "opentelemetry-collectorとopenobserveによるmetrics管理"
date = "2023-10-09T04:00:00Z"
draft = false
[taxonomies]
tags = ["nix"]
[extra]
image = "images/emoji/snowflake.png"
+++

[Part 1 NixOSをinstall](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-install-nixos/)  
[Part 2 deply-rsでNixOS Configurationを適用](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-deploy-with-deploy-rs/)  
[Part 3 ragenixでsecret管理](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-secret-management-with-ragenix/)  
Part 4 opentelemetry-collectorとopenobserveでmetricsを取得(👈 この記事) 

Part 4ではraspi上でopentelemetry-collector(contrib destribution)を動かしてmetricsをとれることを目指します。  metricsのexport先は[openobserve](https://openobserve.ai/)を利用します。今回はcloud版を利用します。  
現在のところ、openobserveのcloud版は月200GB ingestion, 15日間保持までならfree planで利用できます。  
またcluster構成でなければ自前でhostするのもやりやすいのでいずれはraspi上で動かせればと考えていますが、CHANGELOGをみているとまだまだ開発中といった感じなのでもうすこし安定してからにしようかと思っています。  

openobserveへのmetricsのexportには組織情報やcredentialが必要です。これはPart 3で準備してあり、既にdeploy済である前提です。

利用するopentelemetry-collectorのversionはcontrib版の`v0.78.0`です。

## systemdでopentelemetry-collectorを動かす

基本的にやることは簡単で、systemdからopentelemetry-collectorを起動する設定を行うだけです。  
自分はsystemdがよくわかっていなかったので、[Linux Service Management Made Easy with systemd](https://learning.oreilly.com/library/view/linux-service-management/9781801811644/)を読んでみました。  
こちらの本は非常に参考になり別で感想を書こうと思っています。　

opentelemetryやcollectorとはそもそもなにかについては以前[記事](https://blog.ymgyt.io/entry/starting_opentelemetry_with_rust/)を書いたのでよければ読んでみてください。

ということでnixの設定に戻ります。  
まず、opentelemetry-collecotr用に`modules/opentelemetry-collector/` directoryを作成して、そこに`default.nix`を以下のように定義します。  

```nix
{ pkgs, config, mysecrets, ... }: 
  let 
    otelColUser = "opentelemetry-collector";
    otelColGroup = otelColUser;
  in
 {
  # Create user statically for age to execute chown
  users = { 
    groups."opentelemetry-collector" = {
      name = "${otelColGroup}";
    };
    users."opentelemetry-collector" = {
      name = "${otelColUser}";
      isSystemUser = true;
      group = "${otelColGroup}";
    };
  };  

  # Credential for opentelemetry-collector to export telemetry to openobserve cloud
  age.secrets."openobserve" = {
    file = "${mysecrets}/openobserve.age";
    mode = "0440";
    owner = "${otelColUser}";
    group = "${otelColGroup}";
  };

  # Put opentelemetry-collector config file
  environment.etc = {
    "opentelemetry-collector/config.yaml" = {
      mode = "0440";
      user = "${otelColUser}";
      group = "${otelColGroup}";
      text = builtins.readFile ./config.yaml;
    };
  };

  # Enable opentelemetry-collecotr service
  systemd.services.opentelemetry-collector = {
    description = "Opentelemetry Collector Serivice";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = let
      conf =
        "${config.environment.etc."opentelemetry-collector/config.yaml".source.outPath}";
      ExecStart =
        "${pkgs.opentelemetry-collector-contrib}/bin/otelcontribcol --config=file:${conf}";
    in {
      inherit ExecStart;
      EnvironmentFile = [ 
        # referenced by environment variable substitution in config file like '${env:FOO}'
        config.age.secrets.openobserve.path
       ];
      # age executes chown on secret files, so user and group should exists in advance
      DynamicUser = false;
      User = "${otelColUser}";
      Group  = "${otelColGroup}";
      Restart = "always";
      ProtectSystem = "full";
      DevicePolicy = "closed";
      NoNewPrivileges = true;
      WorkingDirectory = "/var/lib/opentelemetry-collector";
      StateDirectory = "opentelemetry-collector";
    };
  };
}
```

このmoduleをimportしてdeployすればopentelemetry-collectorが起動して、openobserveにmetricsをexportしてくれます。  
実行コマンドはcontrib版なので`otelcontribcol`です。  
opentelemetry-collectorの設定fileは`modules/opentelemetry-collector/config.yaml`に定義しており、

```
environment.etc = {
  "opentelemetry-collector/config.yaml" = {
    mode = "0440";
    user = "${otelColUser}";
    group = "${otelColGroup}";
    text = builtins.readFile ./config.yaml;
  };
};
```

とすることで、raspi上に`/etc/opentelemetry-collector/config.yaml`が作成されます。

参照する際は

```
systemd.services.opentelemetry-collector = {
  # ...
  serviceConfig = let
    conf =
      "${config.environment.etc."opentelemetry-collector/config.yaml".source.outPath}";
    ExecStart =
      "${pkgs.opentelemetry-collector-contrib}/bin/otelcontribcol --config=file:${conf}";
  in {
    inherit ExecStart;
    # ...
  };
};
```

のように`config.environment.etc."opentelemetry-collector".config.yaml.source.outPath`を参照できます。

## opentelemetry-collector config.yaml

続いてopentelemetry-collectorの設定fileですが、以下のように定義しました。  

```yaml
receivers:
  hostmetrics:
    collection_interval: 1m
    scrapers:
      cpu:
        metrics:
          system.cpu.time: { enabled: false }
          system.cpu.utilization: { enabled: true }
      memory:
        metrics:
          system.memory.usage: { enabled: false }
          system.memory.utilization: { enabled: true }
      network:
        include:
          interfaces: ["end0"]
          match_type: strict
        metrics:
          system.network.connections: { enabled: true }
          system.network.dropped: { enabled: false }
          system.network.errors: { enabled: false }
          system.network.io: { enabled: true }
          system.network.packets: { enabled: false }
  hostmetrics/fs:
    collection_interval: 60m
    scrapers:
      filesystem:
        exclude_mount_points:
          mount_points: ["/nix/store"]
          match_type: strict
        metrics:
          system.filesystem.inodes.usage: { enabled: false }
          system.filesystem.usage: { enabled: false }
          system.filesystem.utilization: { enabled: true }

processors:
  memory_limiter:
    check_interval: 10s
    # hard limit
    limit_mib: 500
    # sort limit 400
    spike_limit_mib: 100
  resourcedetection/system:
    detectors: ["system"]
    override: false
    attributes: ["host.name"]
    system:
      hostname_sources: ["os"]
  filter/metrics:
    error_mode: propagate
    metrics:
      datapoint:
        - >-
          metric.name == "system.cpu.utilization" 
          and 
          ( 
            attributes["state"] == "nice" 
            or 
            attributes["state"] == "softirq" 
            or 
            attributes["state"] == "steal" 
            or 
            attributes["state"] == "interrupt" 
          ) 
        - >-
          metric.name == "system.network.connections"
          and
          attributes["state"] != "ESTABLISHED"
          and
          attributes["state"] != "LISTEN"
  batch/metrics:
    send_batch_size: 8192
    timeout: 3s
    send_batch_max_size: 16384

exporters:
  logging:
    verbosity: "normal"
  prometheusremotewrite/openobserve:
    endpoint: https://api.openobserve.ai/api/${env:OPEN_OBSERVE_ORG}/prometheus/api/v1/write
    headers:
      Authorization: Basic ${env:OPEN_OBSERVE_TOKEN}
    resource_to_telemetry_conversion:
      enabled: true

extensions:
  memory_ballast:
    size_mib: 64

service:
  extensions: [memory_ballast]
  pipelines:
    metrics:
      receivers: 
        - hostmetrics
        - hostmetrics/fs
      processors: 
        - memory_limiter
        - resourcedetection/system
        - filter/metrics
        - batch/metrics
      exporters: 
        - logging
        - prometheusremotewrite/openobserve

```

まずmetricsはhostmetricsを利用しました。  

processorsに関しては

```yaml
processors:
  memory_limiter:
    check_interval: 10s
    # hard limit
    limit_mib: 500
    # sort limit 400
    spike_limit_mib: 100
```

まずmemory_limiterを設定し

```yaml
  resourcedetection/system:
    detectors: ["system"]
    override: false
    attributes: ["host.name"]
    system:
      hostname_sources: ["os"]
```

次にresourcedetectionで、metricsにhost情報を付与しました。  
host名は、nixosの設定で定義しています。  
続いて
```yaml
  filter/metrics:
    error_mode: propagate
    metrics:
      datapoint:
        - >-
          metric.name == "system.cpu.utilization" 
          and 
          ( 
            attributes["state"] == "nice" 
            or 
            attributes["state"] == "softirq" 
            or 
            attributes["state"] == "steal" 
            or 
            attributes["state"] == "interrupt" 
          ) 
        - >-
          metric.name == "system.network.connections"
          and
          attributes["state"] != "ESTABLISHED"
          and
          attributes["state"] != "LISTEN"
```
filterでcpuのいくつかの状態とconnectionで知りたいものを取得するようにしました。  
最後にbatchを設定しました。

```yaml
  batch/metrics:
    send_batch_size: 8192
    timeout: 3s
    send_batch_max_size: 16384
```

exporterに関してはopenobserveはmetricsの書き込みにpromethesremotewriteを要求するので、指定された通りに行います。  

```yaml
exporters:
  logging:
    verbosity: "normal"
  prometheusremotewrite/openobserve:
    endpoint: https://api.openobserve.ai/api/${env:OPEN_OBSERVE_ORG}/prometheus/api/v1/write
    headers:
      Authorization: Basic ${env:OPEN_OBSERVE_TOKEN}
    resource_to_telemetry_conversion:
      enabled: true
```

`${env:OPEN_OBSERVE_ORG}`のように書くと環境変数で置換してくれます。  
環境変数は、systemdの`EnvironmentFile`経由で、復号したage fileを渡しています。


## まとめ

この設定をdeployし、openobserveでdashboardを設定することで以下のようなmetricsを確認できるようになりました。  

{{ figure(images=["images/ss-openobserve-dashboard.png"], caption="openobserveのdashboardの様子")}}

ここまでで、NixOSの設定をraspi上に反映し、metricsを取得できるようになりました。  
次はRustでraspiのcpu温度を取得し、opentelemetryのmetricsとしてexportするようなapplicationを作ってみようと思っています。

ここまでお読みいただき、ありがとうございました。