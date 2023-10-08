+++
title = "❄️ NixOSとRaspberry Piで自宅server | Part 2 deploy-rsでdeploy"
slug = "homeserver-with-nixos-and-raspberrypi-deploy-with-deploy-rs"
description = "deploy-rsを使ってRaspberry Piにdeploy"
date = "2023-10-09T01:00:00Z"
draft = false
[taxonomies]
tags = ["nix"]
[extra]
image = "images/emoji/snowflake.png"
+++

[Part 1 NixOSをinstall](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-install-nixos/)  
Part 2 deply-rsでNixOS Configurationを適用(👈 この記事)  
[Part 3 ragenixでsecret管理](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-secret-management-with-ragenix/)  
[Part 4 opentelemetry-collectorとopenobserveでmetricsを取得](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-export-metrics-with-opentelemetry-collector/)  

本記事はNixOSとRaspberry Piで自宅serverをはじめる記事のPart 2です。   
Part 1でRaspberry Pi(以下raspi)にNixOSをinstallしてsshできるところまでを行いました。  
本記事ではraspiの設定をfalkeで管理して手元のhost machineからdeploy(適用)できるようにしていきます。  
実際のsourceは[こちら](https://github.com/ymgyt/mynix/tree/main/homeserver)で管理しています。 

概要としては[deploy-rs]を利用することでansibleで構成管理するのと近いことができます。  
違うのはprovisioningの設定を`nixosConfiguration`で行える点です。これによりhostのNixOSやMacと同じ設定の仕組みでraspiも管理できます。  
NixOSやMacをnixで管理していく方法については以前[Nixでlinuxとmacの環境を管理してみる](https://blog.ymgyt.io/entry/declarative-environment-management-with-nix/)で書いてみました。


raspiを管理するrepositoryの`flake.nix`の全体としては以下のようになります。 
この設定を理解するのが目標です。

```nix
{
  description = "Deployment for my home server cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, deploy-rs, flake-utils}:
    let
      spec = {
        user = "ymgyt";
        defaultGateway = "192.168.10.1";
        nameservers = [ "8.8.8.8" ];
      };
    in {
      nixosConfigurations = {
        rpi4-01 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = spec;
          modules = [ ./hosts/rpi4-01.nix ];
        };
        # ... per host...
        rpi4-04 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = spec;
          modules = [ ./hosts/rpi4-04.nix ];
        };
      };

      deploy = {
        # Deployment options applied to all nodes
        sshUser = spec.user;
        # User to which profile will be deployed.
        user = "root";
        sshOpts = [ "-p" "22" "-F" "./ssh.config" ];

        fastConnection = false;
        autoRollback = true;
        magicRollback = true;

        # Or setup cross compilation
        remoteBuild = true;

        nodes = {
          rpi4-01 = {
            hostname = "rpi4-01";
            profiles.system = {
              path = deploy-rs.lib.aarch64-linux.activate.nixos
                self.nixosConfigurations.rpi4-01;
            };
          };
          # ... per host
          rpi4-04 = {
            hostname = "rpi4-04";
            profiles.system = {
              path = deploy-rs.lib.aarch64-linux.activate.nixos
                self.nixosConfigurations.rpi4-04;
            };
          };
        };
      };

      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    } // flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default =
          pkgs.mkShell { buildInputs = [ pkgs.deploy-rs pkgs.nixfmt ]; };
      });
}
```

## Raspberry Piの設定

まずはraspiの設定を行っていきます。  

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # ...
  };

  outputs =
    { self, nixpkgs, ...}:
    let
      spec = {
        user = "ymgyt";
        defaultGateway = "192.168.10.1";
        nameservers = [ "8.8.8.8" ];
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
}
```

raspiのhost `rpi4-01`の設定は上記のようになります。  
host名は[Part 1]で設定してある前提です。  
設定自体は通常の`nixosConfigurations`で行います。  
`specialArgc = spce`を指定することでmoduleから各種設定参照できるようにしてあります。  
`system`はraspiなので`aarch64-linux`を指定しました。   

調べ方としては`nix repl`を利用しました。

```sh
$ nix repl
Welcome to Nix 2.17.0. Type :? for help.

nix-repl> builtins.currentSystem
"aarch64-linux"
```

moduleとして参照している`./hosts/rpi4-01.nix`は以下のようになっています。

```nix
{ defaultGateway, nameservers, ... }: {
  imports = [ ../modules/rpi4.nix ];

  networking = {
    inherit defaultGateway nameservers;
    hostName = "rpi4-01";
    interfaces.end0.ipv4.addresses = [{
      address = "192.168.10.150";
      prefixLength = 24;
    }];
    wireless.enable = false;
  };
}
```

`hosts/`配下はhost毎の設定を定義しています。  
基本的には[Part 1]でおこなった設定からhost固有の設定をここで定義しています。  
raspiそれぞれで共通する設定は`modules/rpi4.nix`に定義しました。  

```nix
# Common settings for Raspberry Pi4 Model B
{ pkgs, user, ... }: {

  boot = {
    # ...
  };

  fileSystems = {
    # ...
  };

  environment.systemPackages = with pkgs; [ helix git bottom bat ];

  # ...
  users = {
    # ...
  };
  security.sudo.wheelNeedsPassword = false;

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "23.11";
}
```

設定自体は[Part 1]と同じです。 

## deploy-rs

続いて定義したraspiの設定をdeployする方法を見ていきます。　

```nix
{
  inputs = {
    # ...
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };
  };

  outputs =
    { self, nixpkgs, deploy-rs, ...}:
    let
     # ...
    in {
      nixosConfigurations = {
        rpi4-01 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = spec;
          modules = [ ./hosts/rpi4-01.nix ];
        };
        # ...
      };

      deploy = {
        # Deployment options applied to all nodes
        sshUser = spec.user;
        # User to which profile will be deployed.
        user = "root";
        sshOpts = [ "-p" "22" "-F" "./etc/ssh.config" ];

        fastConnection = false;
        autoRollback = true;
        magicRollback = true;

        # Or setup cross compilation
        remoteBuild = true;

        nodes = {
          rpi4-01 = {
            hostname = "rpi4-01";
            profiles.system = {
              path = deploy-rs.lib.aarch64-linux.activate.nixos
                self.nixosConfigurations.rpi4-01;
            };
          };
          # for each node...
          rpi4-04 = {
            hostname = "rpi4-04";
            profiles.system = {
              path = deploy-rs.lib.aarch64-linux.activate.nixos
                self.nixosConfigurations.rpi4-04;
            };
          };
        };
      };
      # ...
}
```
[deploy-rs]はflakeのoutputsに`deploy`を期待します。  
`deploy.{sshUser,user}`等は各raspiへのdeploy共通の設定です。  
`deploy.autoRollback`はdeployが失敗した場合に前回のprofileを有効にしてくれるoptionです。  
ここでいうprofileは[nixのprofile](https://nixos.org/manual/nix/stable/package-management/profiles)のことだと理解しています。 
`deploy.magicRollback`については[README](https://github.com/serokell/deploy-rs#magic-rollback)によるとなんらかの理由で変更後にdeploy対象nodeへの疎通ができなくなった場合に自動でrollbackしてくれる設定です。  

`deploy.remoteBuild`はtrueを設定しています。 
自分のhost machineに`aarch64-linux`のものがなく、nixのcross compileをまだ設定できていないため、deploy先のraspi上でbuildするようにしています。  

`deploy.nodes.${node}`にdeploy対象のnodeを設定します。  
nodeごとにprofileを指定することができこれがdeployの単位となります。profile = roleという感じです。  
`deploy.nodes.${node}.profiles.${profile}.path`にさきほど定義したnixosConfigurationを指定します。  

これでdeployの設定は完了です。 


## 実際にdeploy

さっそく定義した設定をdeployしてみます。  
`flake.nix`の`devShell`に以下のようにdeploy-rsを追加します。  

```nix
{
  inputs = {
    # ...
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, deploy-rs, flake-utils}:
    let
      # ...
    in {
      nixosConfigurations = {
        # ...
      };

      deploy = {
       # ...
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default =
          pkgs.mkShell { buildInputs = [ pkgs.deploy-rs pkgs.nixfmt ]; };
      });
}
```

これで`nix develop -c nu`もしくは`direnv`で`deploy`が有効になります。

まずは1台にdeployしてみます。  

```sh
> deploy --interactive --skip-checks .#rpi4-01
🚀 ℹ [deploy] [INFO] Evaluating flake in .
🚀 ℹ [deploy] [INFO] The following profiles are going to be deployed:
[rpi4-01.system]
user = "root"
ssh_user = "ymgyt"
path = "/nix/store/x901jwam6nzwgfxyzy7wa5hahm33fb93-activatable-nixos-system-rpi4-01-23.11.20230920.fe97767"
hostname = "rpi4-01"
ssh_opts = ["-p", "22", "-F", "./etc/ssh.config"]

🚀 ℹ [deploy] [INFO] Are you sure you want to deploy these profiles?
> yes
🚀 ℹ [deploy] [INFO] Building profile `system` for node `rpi4-01` on remote host
🚀 ℹ [deploy] [INFO] Activating profile `system` for node `rpi4-01`
🚀 ℹ [deploy] [INFO] Creating activation waiter
👀 ℹ [wait] [INFO] Waiting for confirmation event...
⭐ ℹ [activate] [INFO] Activating profile
activating the configuration...
setting up /etc...
reloading user units for ymgyt...
setting up tmpfiles
reloading the following units: dbus.service
⭐ ℹ [activate] [INFO] Activation succeeded!
⭐ ℹ [activate] [INFO] Magic rollback is enabled, setting up confirmation hook...
⭐ ℹ [activate] [INFO] Waiting for confirmation event...
👀 ℹ [wait] [INFO] Found canary file, done waiting!
🚀 ℹ [deploy] [INFO] Success activating, attempting to confirm activation
🚀 ℹ [deploy] [INFO] Deployment confirmed.
```

無事deployできました。  
`--skip-checks`は[hostとremoteのsystemが違うと現状だとうまくcheckが動かないようなので](https://github.com/serokell/deploy-rs/issues/216)つけています。

これでraspiのnixosConfigurationを反映させられるようになったのでさっそく設定を変更してみましょう。  
現状ではtime zoneを設定していないのでこれを設定してみます。  

`./modules/rpi4.nix`に`time.timeZone = "Asia/Tokyo";`を追加します。今度は全台に反映させたいので

```sh
deploy --skip-checks --interactive .
```

を実行してみます。
成功したら[Part 1]で作成したzellij layoutを使ってsshしたのち`timedatectl`を実行してみます。  

{{ figure(images=["images/ss-timedatectl.png"], caption="timedatectlの実行結果") }}

無事、time zoneが`Asia/Tokyo`に変更されていることが確認できました。

Part 3ではraspi上でserviceを動かすために必要なsecretを管理できるようにしていきます。


[Part 1]: https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-install-nixos/
[deploy-rs]: https://github.com/serokell/deploy-rs