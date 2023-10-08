+++
title = "❄️ NixOSとRaspberry Piで自宅server | Part 1 NixOSをinstall"
slug = "homeserver-with-nixos-and-raspberrypi-install-nixos"
description = "Raspberry PiへのNixOSのinstallについて"
date = "2023-10-09T00:00:00Z"
draft = false
[taxonomies]
tags = ["nix"]
[extra]
image = "images/emoji/snowflake.png"
+++

Part 1 NixOSをinstall (👈 この記事)  
[Part 2 deply-rsでNixOS Configurationを適用](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-deploy-with-deploy-rs/)  
[Part 3 ragenixでsecret管理](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-secret-management-with-ragenix/)  
[Part 4 opentelemetry-collectorとopenobserveでmetricsを取得](https://blog.ymgyt.io/entry/homeserver-with-nixos-and-raspberrypi-export-metrics-with-opentelemetry-collector/)  

本記事はNixOSとRaspberry Piで自宅serverをはじめる記事のPart 1です。 
まずはRaspberry PiにNixOSをinstallするところから始めていきます。  
先日、[Raspberry Pi 5](https://www.raspberrypi.com/products/raspberry-pi-5/)が発表されましたが、本記事で利用するのは[Raspberry Pi 4 Model B](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)です。RAMは4GBですが、8にすればよかったと思っています。台数は4で始めました。 

Part 1では、4台のRaspberry Pi(以下raspi)に手元のmachineからssh接続できるところまで行います。sshできるようになれば今後の設定の変更はdeploy-rsを利用できるので、sshして設定を変更といった作業がなくなります。  

実際に自分のraspiの管理は[このrepo](https://github.com/ymgyt/mynix/tree/main/homeserver)で行っています。

{{ figure(images=["images/ss-btm.png"], caption="4台のraspi")}}

## 準備するもの

* Raspberry Pi
  * 電源
  * Router/Switchへ接続するためのLANケーブル
* SD card(raspi分)
* USBキーボード
* モニター(Micro HDMI接続)

キーボードとモニターは初回設定時に必要です。  
LANケーブルは無線LAN利用する場合は不要です。今回は有線のみ使用。

## NixOS imageをSD Cardに書き込む

基本的にはnix.devの[Installing NixOS n a Raspberry Pi](https://nix.dev/tutorials/nixos/installing-nixos-on-a-raspberry-pi)にしたがって進めていきます。


### NixOS imageの取得

```sh
nix shell nixpkgs#wget nixpkgs#zstd

wget https://hydra.nixos.org/build/226381178/download/1/nixos-sd-image-23.11pre500597.0fbe93c5a7c-aarch64-linux.img.zst
unzstd -d nixos-sd-image-23.11pre500597.0fbe93c5a7c-aarch64-linux.img.zst
```

まずimageを取得してきます。imageは[こちら](https://hydra.nixos.org/job/nixos/trunk-combined/nixos.sd_image.aarch64-linux)から最新のものを選びました。


### SD Cardへの書き込み

以下のcommandを実行してからhost machineにSD cardを差し込みます。

```
dmesg --follow

[ 3381.230145] mmc0: cannot verify signal voltage switch
[ 3381.334038] mmc0: new ultra high speed SDR104 SDXC card at address 59b4
[ 3381.349488] mmcblk0: mmc0:59b4 SD128 119 GiB
[ 3381.399498]  mmcblk0: p1
```

これでSD cardが`/dev/mmcblk0`に対応することがわかりました。  
さきほど取得したimageを書き込みます。

```sh
sudo dd \
  if=nixos-sd-image-23.11pre500597.0fbe93c5a7c-aarch64-linux.img \
  of=/dev/mmcblk0 \
  bs=4096 conv=fsync status=progress
```

`of=/dev/`は`dmesg`の出力に対応させます。

## Raspberry Piの設定

raspiにsshする際に利用するkey pairを作成します。

```sh
ssh-keygen -t ed25519 -b 4096 -f nixos_key -C ymgyt
```

次にraspiに配布する`/etc/nixos/configuration.nix`をhost上で作成します。  
自分は以下のように設定しました。  

```nix
{ config, pkgs, lib, ... }:

let
  user = "ymgyt";
  password = "password";
  hostname = "rpi4-01";
in {

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  networking = {
    hostName = hostname;
    defaultGateway = "192.168.10.1";
    nameservers = [ "8.8.8.8" ];
    interfaces.end0.ipv4.addresses = [ {
      address = "192.168.10.150";
      prefixLength = 24;
    } ];
    wireless = {
      enable = false;
    };
  };

  environment.systemPackages = with pkgs; [ helix git ];

  services.openssh.enable = true;

  users = {
    mutableUsers = false;
    users."${user}" = {
      isNormalUser = true;
      password = password;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1l...EgT3Ma ymgyt"
      ];
    };
  };
  security.sudo.wheelNeedsPassword = false;

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "23.11";
}
```
  
```nix
{
  networking = {
    hostName = hostname;
    defaultGateway = "192.168.10.1";
    nameservers = [ "8.8.8.8" ];
    interfaces.end0.ipv4.addresses = [ {
      address = "192.168.10.150";
      prefixLength = 24;
    } ];
    wireless = {
      enable = false;
    };
};
```

`netroking.hostName`でhostnameを指定します。`rpi4-{01,02,03,04}`のように指定しました。  
`netroking.defaultGateway`は環境の設定にあわせます。  
raspiを外部に公開する際にrouterでportのmappingを設定したかったので、raspiのipを固定するようにしました。また、無線LANは無効にしました。

sshの設定は以下です。

```nix
{
  services.openssh.enable = true;

  users = {
    mutableUsers = false;
    users."${user}" = {
      isNormalUser = true;
      password = password;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1l...EgT3Ma ymgyt"
      ];
    };
};
```

passwordは無効にしてもよいと思いますが最初は有効にしてました。  
`users.users.ymgyt.openssh.authorizedKeys.keys`にさきほど生成したkey pairの公開鍵を登録します。

作成した`configuration.nix`をraspiから取得できるようにfile serverをたちあげました。  
今回は`sfz`を利用しましたが、なんでも良いです。  

```sh
nix run nixpkgs#sfz -- --bind 0.0.0.0 --port 8000
```

ここからはさきほど書き込んだSD Cardをraspiに差し込んでraspi側を操作します。 
host machineのprivate addressが192.168.10.10という前提です。 

```sh
sudo -i
cd /etc/nixos
curl -sSf  curl -sSO http://192.168.10.10:8000/configuration.nix
```

次にfirmwareのupdateを実施しました。

```sh
nix-shell -p raspberrypi-eeprom
mount /dev/disk/by-label/FIRMWARE /mnt
BOOTFS=/mnt FIRMWARE_RELEASE_STATUS=stable rpi-eeprom-update -d -a
```

最後に再起動します。

```
nixos-rebuild boot
systemctl reboot
```

これで上記のnetwork interfaceやsshの設定が適用されるので以下のようにhost machineからsshできれば成功です。  

```sh
ssh ymgyt@192.168.10.150 -i nixos_key
```

この手順を残りの3台でも繰り返しました。  
変更するのは`configuration.nix`のhostnameとnetwork interfaceの箇所です。

## 確認

4台の設定が完了したので、確認してみます。  
まずhost名でsshできるように`./etc/ssh.config`を作成します。  

```text
Host rpi4-01
  Hostname 192.168.10.150
Host rpi4-02
  Hostname 192.168.10.151
Host rpi4-03
  Hostname 192.168.10.152
Host rpi4-04
  Hostname 192.168.10.153

Host rpi4-*
  User ymgyt
  ForwardAgent yes
  StrictHostKeyChecking no
```

配置したsshは`ssh-add`してある前提です。  
次にraspiそれぞれにsshするのは面倒なのでssh用のzellij layoutを以下のように`./etc/rpi.layout.kdl`に作成しました。  

```kdl
layout {
	pane_template name="ssh" {
		command "ssh"
	}

	pane size=1 borderless=true {
		plugin location="zellij:tab-bar"
	}
	pane split_direction="vertical" {
		ssh {
			args "ymgyt@192.168.10.150"
		}
		ssh {
			args "ymgyt@192.168.10.151"
		}
	}
	pane split_direction="vertical" {
		ssh {
			args "ymgyt@192.168.10.152"
		}
		ssh {
			args "ymgyt@192.168.10.153"
		}
	}
	pane size=2 borderless=true {
		plugin location="zellij:status-bar"
	}
}
```

これで以下のcommandを実行すると各raspiにsshした状態のtabが開きます。  

```sh
zellij action new-tab --layout ./etc/rpi.layout.kdl
```
zellijのdefaultのkeybindで、Ctrl + t, sでsync modeになりtabのpanelそれぞれに一度に入力できます。

以下のようにsshできていれば成功です。

{{ figure(images=["images/ss-hostname.png"], caption="hostnamectlの実行") }}

Part 2ではraspiの設定をflakeで管理して、host machineから変更を適用できるようにします。
