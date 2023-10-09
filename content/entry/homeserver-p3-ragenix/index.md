+++
title = "❄️ NixOSとRaspberry Piで自宅server | Part 3 ragenixでsecret管理"
slug = "homeserver-with-nixos-and-raspberrypi-secret-management-with-ragenix"
description = "ragenixによるsecretの管理について"
date = "2023-10-09T03:00:00Z"
draft = false
[taxonomies]
tags = ["nix"]
[extra]
image = "images/emoji/snowflake.png"
+++

[Part 1 NixOSをinstall](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-install-nixos/)  
[Part 2 deply-rsでNixOS Configurationを適用](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-deploy-with-deploy-rs/)  
Part 3 ragenixでsecret管理](👈 この記事)  
[Part 4 opentelemetry-collectorとopenobserveでmetricsを取得](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-export-metrics-with-opentelemetry-collector/)  

Part 3ではsecret管理について見ていきます。  
secretを扱いたいのは、次のPart 4で設定するopentelemetry-collectorにexport先のopenobsreveのtokenを渡したいからです 。 

secret管理では[ragenix]を利用します。[ragenix]は[agenix]のrust実装なので基本的な使い方は[agenix]を参照します。  
今回登場する`ragenix`を`agenix`に書き換えても動作します。  

## Secret管理の概要

概ね以下の手順を踏みます。  

1. Secretを`ragenix` cliとssh keyで暗号化する
2. 暗号化されたsecretをraspiを設定するflake(nixosConfiguration)で参照する
3. Deploy先でragenixが暗号化されたsecretを復号する
4. Secretをserviceが平文として参照する

図にするとこんな感じです。  

{{ figure(images=["images/ragenix-overview.svg"], caption="ragenixの概要") }}

これだけだとよくわからないと思うので具体的にみていきます。

## Secret fileの作成

secretはgitにcommitします。  
`FOO=BAR`を暗号化したfileは以下のようになります。  

```text
-----BEGIN AGE ENCRYPTED FILE-----
YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNzaC1lZDI1NTE5IEQ1NXVqZyB6MlU4
Rk9tTWR5MUY2bVdwNXpmRERzTEZMMTAJaXJ1M3VqWWdDKzBhMjFRClZ6aERoRGh4
cW5PUEJvR1lNbXBBRVpwbUNyOFFvK3BJTUFXS0FjWGdQUEUKLT4gfkhiLWdyZWFz
ZSBnaVd2Cit6YjZwVXMrRDYySkh5Nk4wQXQwVTlRRGNRWVpGMFlzUDlzUzVWMnc5
b2laOUpVcGpSdDdFYUtrRkxNS0czRkMKK2dETjdRCi0tLSBtdzJ6RnE0VjRkVjZl
aHpxQUE4ZFdJOT8BTml8OFdMTHcweURQMXJ1MmJFChz79iSwsWlQ20XLW6ET4GY4
rb49pvi3FUy+GKUx3w5trvIjXWALqA==
-----END AGE ENCRYPTED FILE-----
```

これをraspiを管理している`flake.nix`と同じgit repositoryに置いてもよいのですが、[ryan4yin先生のsecrets README](https://github.com/ryan4yin/nix-config/tree/v0.1.1/secrets)では別のprivate repositoryに分けていたので見習って同じようにしました。

### SSH Keypairの準備

[ragenix]での暗号化にはssh keypairが必要です。secretを復号できる公開鍵を複数指定することができます。  
復号には指定された公開鍵に対応するいずれかの秘密鍵が必要です。  
自分の復号用にはraspiへのsshに利用するkeyが利用できます。  
今から作成するsecretはdeploy先のraspiで復号したいので、deploy対象のraspi nodeそれぞれのkeypairが必要です。(暗号化するだけなら公開鍵)  
新たにssh keypairを作成して、raspiに配布してもよいのですが、すでにraspi上に生成されているkeypairを使うこともできます。今回はraspi上に既に生成されているkeypairを利用してみます。  

以下のコマンドでraspi上の公開鍵を取得します。  

```sh
ssh-keyscan -t ed25519 192.168.10.150

# 192.168.10.150:22 SSH-2.0-OpenSSH_9.4
192.168.10.150 ssh-ed25519 AAAA...XXXX
```

これを対象nodeに対して行います。  

### Openobserveのsecretの取得

次に実際に暗号化するsecretを取得します。  
今回はmetricsをopenobserveに書き込むのでそのためのcredentialが必要です。openobserveについては[Part 4]で説明する予定です。  
Openobserveの画面からIngestion > Metrics > OTEL Collectorに遷移するとexporterの設定が表示されます。  

`v0.6.4`ではURLとしては`https://cloud.openobserve.ai/ingestion/metrics/otelcollector`でした。  

Localで立ち上げたSSとしては以下です。  

{{ figure(images=["images/ss-openobserve-metrics.png"], caption="localの値")}}

```yaml
exporters:
  prometheusremotewrite:
    endpoint: https://api.openobserve.ai/api/MY_ORGANIZATION/prometheus/api/v1/write
    headers:
      Authorization: Basic OPEN_OBSERVE_TOKEN
```

credentialとしてはendpointに含まれている`MY_ORGANIZATION`とAuthorization headerの`OPEN_OBSERVE_TOKEN`を取得します。

### ragenixで暗号化

ssh公開鍵とcredentialが用意できたので、[ragenix]で暗号化していきます。 

secret管理用のrepo(`mynix.secrets`)に`secrets.nix`を以下のよう作成します。  

```nix
let 
  my_key = "ssh-ed25519 AAAA...XXXX";

  rpi4_01 = "ssh-ed25519 AAAA...YYYY";
  rpi4_02 = "ssh-ed25519 AAAA...ZZZZ";
  rpi4_03 = "ssh-ed25519 AAAA...WWWW";
  rpi4_04 = "ssh-ed25519 AAAA...IIII";

in
{
  "openobserve.age".publicKeys = [ nixos_age rpi4_01 rpi4_02 rpi4_03 rpi4_04 ];
}
```

`openobserve.age`が暗号化対象のfileになります。  
`openobserve.age.publicKeys`に復号できる秘密鍵に対応する公開鍵を指定します。この値はさきほど`ssh-keyscan`で取得したものです。  

```sh
nix run github:yaxitech/ragenix -- -e openobserve.age  
```

このcommandを実行すると`$EDITOR`が開くのでさきほど取得したopenobserveのcredentialを入力します。  

```text
OPEN_OBSERVE_ORG=MY_ORGANIZATION
OPEN_OBSERVE_TOKEN=OPEN_OBSERVE_TOKEN
```

を入力して`$EDITOR`を終了します。  
暗号化された`openobserve.age` fileが作成されていれば完了です。

内容を更新したり、新しい公開鍵を追加した際は以下のcommandで更新できます。  

```sh
nix run github:yaxitech/ragenix -- --rekey -i path/to/key
```


## flake.nixでのsecretの参照

作成したsecretは以下のように参照できます。  

```nix
{
  inputs = {
    # ...

    # secrets management
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    mysecrets = {
      url =
        "github:ymgyt/mynix.secrets/a09e3d81f8e24657ea2cbd53f37f9e95b4576abb";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs,  ragenix, mysecrets }:
    let
      spec = {
        # ...
        inherit ragenix mysecrets;
      };
    in {
      nixosConfigurations = {
        rpi4-01 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = spec;
          modules = [ ./hosts/rpi4-01.nix ];
        };
        # ...
      };
      # ...
}
```

`inputs.mysecrets`で`secrets.nix`を定義したrepositoryを指定します。  
flakeでprivate git repositoryを参照する方法ですが  
`~/.config/nix/nix.conf`に

```
access-tokens = github.com=ghp_xxx  
```

のように書いておくことでgithubの認証を行ってくれます。  
次に`nixosConfigurations`から参照するmoduleで以下のように定義します。  

```nix
{ pkgs, config, ragenix, mysecrets, ... }: 
  let 
    otelColUser = "opentelemetry-collector";
    otelColGroup = otelColUser;
  in
{

  imports = [ ragenix.nixosModules.default ];

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

  # ...

  # Enable opentelemetry-collecotr service
  systemd.services.opentelemetry-collector = {
    # ...
    EnvironmentFile = [ 
      # referenced by environment variable substitution in config file like '${env:FOO}'
      config.age.secrets.openobserve.path
     ];
  };
}
```

```
age.secrets."openobserve" = {
  file = "${mysecrets}/openobserve.age";
  # ...
};
```
この指定でragenixは暗号化されたopenobserve.ageを復号します。  
復号後の平文のfileを参照するには  

```
systemd.services.opentelemetry-collector = {
  # ...
  EnvironmentFile = [ 
    config.age.secrets.openobserve.path
   ];
};
```
のように`config.age.secrets.${secret}.path`を参照します。  
実態としては`/run/agenix/openobserve`のようになっています。  
別途別のpathに書き出したりといったこともできます。  
raspi上ではsecretは平文で置かれているのでuserとgroupを指定するようにしました。  
systemdまわりの設定の話はPart 4で行います。

これでdeploy-rsでdeployするだけでsecretを配布できるようになりました。管理するものが既存のssh keyだけなので扱いやすいと思っています。  

[Part 4]ではraspi上でopentelemetry-collectorを動かしてmetricsを取得できるようにします。
　

## 参考

* [ryan4yin先生のsecrets README](https://github.com/ryan4yin/nix-config/tree/v0.1.1/secrets)



[agenix]: https://github.com/ryantm/agenix
[ragenix]: https://github.com/yaxitech/ragenix
[Part 1]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-install-nixos/
[Part 2]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-deploy-with-deploy-rs/  
[Part 3]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-secret-management-with-ragenix/  
[Part 4]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-export-metrics-with-opentelemetry-collector/  


