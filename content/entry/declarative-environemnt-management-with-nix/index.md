+++
title = "📦 Nixでlinuxとmacの環境を管理してみる"
slug = "declarative-environment-management-with-nix"
description = "Nixを利用してlinuxとmacの開発環境を宣言的に管理する。"
date = "2023-06-13"
draft = false
[taxonomies]
tags = ["etc"]
[extra]
image = "images/emoji/package.png"
+++

本記事では[Nix](https://nixos.org/)を利用して、linux(nixos)とmacの開発環境を宣言的に管理していく方法について書きます。  
設定は一つのrepositoryで管理し、git cloneして、`makers apply`を実行するだけという状態を目指します。  
依存していいのは`nix`のみとします。  
現状設定できている内容は以下です。

* SSH(daemonの起動, authentication方法, userのauthorized keyの設置)
* Font
* Timezone
* Input method
* Desktop environment
* User
* Package(実行コマンド+設定file)

作成した[repository](https://github.com/ymgyt/mynix/tree/main)  
Nixについてまだまだわかっていないことが多いのですが、ひとまず使い始められた感じです。


## そもそもNixとは

現状の自分の理解ではNixとはpackage manager + build systemという認識です。
文脈によってはprojectやecosystem全体を指す場合もあります。  
Installすると`nix` commandが使えるようになりこれ自体はpackage manager的な役割も担います。  
また、mac, linux共通で利用できます。  
Macでいうと`brew`の替わりに使うイメージです。必要に応じてinstall commandを実行するような使い方では`brew`でいいじゃんとなるので、installされているべきcommand一覧を定義しておくという運用になります。  
NixOSはnixを前提としてlinux distributionです。

### Nixの現状とflake

2023/06/12現在のnixにはflakeというexperimentalな機能が追加されています。  
このexperimentalというのがなんとも悩ましく、既存のnixの問題点を解消するために追加されたもので、documentによっては今からnixを始めるならflakeを利用することを薦められていたりします。  

> Although they are still experimental features as of 2023-05-05, they have been widely used by the Nix community and are strongly recommended.

https://thiscute.world/en/posts/nixos-and-flake-basics

> We strongly recommend, however, that you learn to use flakes if you're already a Nix user or to begin your Nix journey with flakes rather than channels if you're just getting started with Nix.

https://zero-to-nix.com/concepts/flakes

ということで以下ではflakeを利用することを前提としています。


## Flakeとは

それでは、そのflakeとは何なのかという話ですが、自分はnixにおけるrustのpackage(crateではなくて)と理解しています。要は成果物やその依存の単位です。  
形式的には`.git`があるとそのdirectory treeがgit repositoryになるのと同じで`flake.nix`があるとそのdirectory treeがflakeになります。  
もしgitのrepositoryで`flake.nix` fileが置いてあればそのrepositoryはflakeです。[Helixにも置いてありました](https://github.com/helix-editor/helix/blob/master/flake.nix)  

### `nix xxx`と`nix-xxx`

Nixのdocumentやblogをみると`nix-env`や`nix-shell`といった`nix-xxx`系のcommandと`nix shell`, `nix run`といった、subcommand likeな`nix xxx`の情報が混在しているかと思います。  
基本的に`nix xxx`のほうがflakeを前提としてexperimentalな機能ということみたいです。従って公式のdocはまだ`nix-xxx`系について書かれています。  
今がちょうどnixのecosystemの過渡期にあると思われ、公式のdocumentはexperimentalな機能がstableになってから整備されていくのではと思っております。  
というような話が最初はわからずにとても混乱しました。  
こちらの[nixのコマンドを解説してみる](https://qiita.com/Sumi-Sumi/items/6de9ee7aab10bc0dbead)のまとめはとても参考になりました。


## Nixのinstall

Nixのinstallなのですが、現状選択肢が2つあると思っています。  
1つが[公式](https://nixos.org/download.html)で、もう1つがDeterminatesSystemsが提供している[nix-installer](https://github.com/DeterminateSystems/nix-installer)です。  
公式を選ばない理由があるのかと思いますが、DeterminateSystemsのnix-installerを選びたくなる理由は

* Uninstall機能を提供している
* Defaultでflakeが有効
* Rust製

裏を返すと公式にはuninstall機能がありません。ただし[doc](https://github.com/NixOS/nix/blob/master/doc/manual/src/installation/uninstall.md#macos)には手順の説明があります。  
またflakeはexperimentalなのでなんらかの方法で有効にする必要があります。(`~/.config/nix/nix.conf`を作成する)   
自分は両方試してどちらの方法でも問題なく使えています。  
Uninstall機能までついているほうが他人やチームに薦めやすいと思います。

## `flake.nix`

ここまで抽象的な話だったので、いよいよ具体的に設定を見ていきます。  
まずprojectのrootに置く`flake.nix` fileです。

```nix
{
  description = "Nix configuration of ymgyt";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs
    , home-manager
    , ...
    }: {
      nixosConfigurations = {
        xps15 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/xps15

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.ymgyt = import ./home/linux;
            }
          ];
        };
      };
    };
}
```

上記がnixosの設定を管理するflakeです。  
まずflake含め、nixの設定は[nix language](https://nixos.org/manual/nix/stable/language/index.html)で書きます。  

### Nix Language

Nix languageは

> domain-specific
  It only exists for the Nix package manager: to describe packages and configurations as well as their variants and compositions. It is not intended for general purpose use.

https://nixos.org/manual/nix/stable/language/index.html

とあるように、nixの設定を管理するためのDSLです。以下では本記事を読むのに必要な限りでnix languageについて説明します。  

まず、`{ ... }`はattribute setで、jsonのobjectのようなものです。nixはfileを評価すると一つの値を返す必要があります。`flake.nix`は`{ ... }`で囲まれているのでattribute setを返しています。  
次に`:`がでてきたらそれは関数で左側が引数、右側が関数のbodyです。  

```nix
{
  outputs =
    { nixpkgs
    , home-manager
    , ...
    }: {
      nixosConfigurations = { /* ... */ };
  };
}
```

この部分はoutputsというkeyにnixpkgs,とhome-managerを引数として、nixosConfigurationsをkeyにしたattribute setを返す関数をsetしていると読めます。  

また

> lazy
  Expressions are only evaluated when their value is needed.  

https://nixos.org/manual/nix/stable/language/index.html

とあるように、値が参照されたときに初めて評価が走るようです、この点は後で重そうな処理いろいろ追加しても実際に実行する処理だけしか走らないことに影響します。  
~~あとは関数型なのでfor loopがでてきません~~

### inputsとoutputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs
    , home-manager
    , ...
    }: {
      nixosConfigurations = { /* ... */ };
}
```

あらためて`flake.nix`をみてみます。まず`inputs`はこのflake(project)の依存先を宣言しています。  
`nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";`とあるので、githubのnixpkgs repositoryに依存しています。  
この[nixpkgs repositor](https://github.com/NixOS/nixpkgs)もflakeで、nix package managerが管理しているpackageはここですべて管理されているようです。  
packageの探し方は[公式](https://search.nixos.org/packages)か、`nix search nixpkgs xxx`です。公式をみると80,000 package以上あると書いてあります。(cargo-nextestのようなcargoのsubcommandだけで100以上ありました)  
この`flake.nix`を参照して成果物を作成すると、`flake.lock`が作成されます。これはプログラミング言語のlock fileと同様に宣言された依存が実際に解決された際のrevision等を記録するものです。  
実際、に`flake.lock`には以下のような情報が記載されていました。  

```
"nixpkgs": {
  "locked": {
    "lastModified": 1686020360,
    "narHash": "sha256-Wee7lIlZ6DIZHHLiNxU5KdYZQl0iprENXa/czzI6Cj4=",
    "owner": "NixOS",
    "repo": "nixpkgs",
    "rev": "4729ffac6fd12e26e5a8de002781ffc49b0e94b7",
    "type": "github"
  },
  "original": {
    "owner": "NixOS",
    "ref": "nixos-unstable",
    "repo": "nixpkgs",
    "type": "github"
  }
},
```

依存先のflakeにも`flake.lock`があるので、結果的にbuild時に実際に依存しているものが一意に定まります。  
これがnixが謳っているreproducibleな点を実現していると考えています。  
なんというか、rustの場合、projectのbuild対象はlibraryか実行するbinaryかだと思いますが、nixはそれらをなんらかのbuildするものに拡張したような仕組みなのかなと思っています。(つまりprojectのbuildをプログラミング言語に依らずにnixで管理できるということ)  

ここでなんらかのbuildできるものと言いましたが、具体的には何という話になります。  
今回は`nixosConfiguration`なので、nixosの設定です。  
これ以外になにが設定できるかは[wiki](https://nixos.wiki/wiki/Flakes)に載っていました。

## `nixosConfiguration`

次にlinux(nixos)の設定箇所について見ていきます。  

```nix
{
  # ...

  outputs =
    { nixpkgs
    , darwin
    , home-manager
    , ...
    }: {
      nixosConfigurations = {
        xps15 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/xps15

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.ymgyt = import ./home/linux;
            }
          ];
        };
      };
    };
}
```

`xps15`というのは設定対象のhostの名前で任意です。`system`にはCPUとOSを指定します。(Macの場合は`system = "aarch64-darwin"`等)  
次の`modules = [ ... ]`のところが具体的な設定項目です。`home-manager`は後ほど触れるのでまずは`./hosts/xps15`の箇所から見ていきます。  
設定のDSLとあって、nix languageではfile path型はfirst classです。file pathでdirectoryを指定した場合そのdirectory配下の`default.nix`が評価されます。  
まずここでrepositoryのdirectory構造を確認します。  

```
.
├── flake.lock
├── flake.nix
├── home
├── hosts
│  ├── fraim
│  │  └── default.nix
│  ├── prox86
│  │  └── default.nix
│  └── xps15
│     ├── default.nix
│     └── hardware-configuration.nix
├── Makefile.toml
├── modules
│  ├── darwin
│  │  └── default.nix
│  ├── font.nix
│  ├── nixos
│  │  ├── default.nix
│  │  └── font.nix
│  └── ssh.nix
├── README.md
```

`home`配下は割愛しています。今回の参照先は`hosts/xps15`です。基本的にはhostごとに`hosts`配下にdirectoryを切っています。  
これはnixosConfigurationの規約等ではないです。  
hostごとにdirectoryを切っているのは、hostごとの固有の設定はここで吸収するからです。  
`hosts/xps15/default.nix`は以下のようになっています。  

```nix
{ ... }: {
  imports = [
    ../../modules/nixos
    ./hardware-configuration.nix
  ];

  users.users.ymgyt = {
    isNormalUser = true;
    description = "ymgyt";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8gnwsBvzfnFArlA8+tWWCJ64MjvzwoiTidWEgT3Mbf ymgyt"
    ];
  };

  networking.hostName = "xps15"; # Define your hostname.
}
```

まず全体としては`{ ... }: {}`となっているので関数であることがわかります。`...`は任意のfieldにマッチします。  
ここで、`users.users.ymgyt = { /* ... */ }`を返しているので、どうやらuserを設定していそうですが、型としてはどんな情報を返せばよいのでしょうか。  
このあたりは自分もわかっていないところなのですが、`nixpkgs.lib.nixosSystem`の引数は[こちら](https://www.reddit.com/r/NixOS/comments/13oat7j/what_does_the_function_nixpkgslibnixossystem_do/)で定義されているみたいです。  
結論としては、[search.nixos.org](https://search.nixos.org/options?channel=23.05&from=0&size=50&sort=relevance&type=packages&query=users.users)では、packageだけでなく、NixOsOptionsも検索でき、そこに`users.users`をいれると設定できる内容が確認できます。  
逆にいうとここで検索できる項目はすべて設定できる項目です。  
[Manual](https://nixos.org/manual/nixos/stable/index.html#ch-configuration)にはフレンドリーな説明が載っています。  
今回は設定していませんが、[kubernetesの設定](https://nixos.org/manual/nixos/stable/index.html#sec-kubernetes)もあり、以下のように設定するとkubernetesのmasterなりworkerなりになるそうです。  

```
services.kubernetes = {
  apiserver.enable = true;
  controllerManager.enable = true;
  scheduler.enable = true;
  addonManager.enable = true;
  proxy.enable = true;
  flannel.enable = true;
};
```

ここではhost固有の設定を行っているので基本的にはuserの設定とhostnameを設定しています。  
ただし、このfileにすべてを設定するともう一台、nixosのhostが増えた際に重複する箇所がでてくるかと思います。  
なのでhostに依存しない設定は別途、`modules/nixos`に定義しています。  
またhost固有のhardwareに関連する設定は`/hosts/xps15/hardware-configuration.nix`に定義しています。`hardware-configuration.nix`はnixosのinstall時に自動生成されたものです。  
概ね以下のような内容になっていました。  

```nix
# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/94af5bc6-cdac-489f-8212-fe089c3e155f";
      fsType = "ext4";
    };

  fileSystems."/boot/efi" =
    {
      device = "/dev/disk/by-uuid/0C11-5D62";
      fsType = "vfat";
    };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # high-resolution display
  # disable for error
  # hardware.video.hidpi.enable = lib.mkDefault true;
}
```
Nixos共通の`modules/nixos`は長いのでここでは、Input methodとfontの設定について書きます。

### Input method

```nix
{ config, pkgs, ... }: {

  imports = [
    ../ssh.nix
    ../font.nix
    ./font.nix
  ];

  # https://nixos.org/manual/nixos/unstable/index.html#module-services-input-methods-fcitx
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-mozc ];
  };
}
```

Input methodにfcitx5 + mozcを利用する設定はこれだけです。  
他にどんな設定が可能かは[Manual](https://nixos.org/manual/nixos/stable/index.html#module-services-input-methods-fcitx)に記載されています。  
Linux初心者に非常にやさしいです。

### Font

個人的にfontをmac,linux共通で宣言的に管理できるのはうれしいです。

まずinstallするfontを以下のように定義しました。  

```nix
# Configure common options in nixos and darwin
{ pkgs, ... }: {
  fonts = {
    fontDir.enable = true;

    fonts = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji

      # nerdfotns
      # https://www.nerdfonts.com/font-downloads
      # items are inferred from the actual downloaded file name
      (nerdfonts.override {
        fonts = [
          "JetBrainsMono"
        ];
      })
    ];
  };
}
```

利用できるfontは同様に[search.nixos.org](https://search.nixos.org/packages)から検索できます。  
ここで`with`がでてきたので、補足すると`with pkgs`とすると、`pkgs`のfield名に直接アクセスできます。したがって上記は以下と同じです。  

```
fonts = [ 
  pkgs.noto-fonts
  pkgs.fonts-cjk
  pkgs.noto-fonts-emoji
  # ...
];
```

次にnixosの場合はdefault fontを指定できるので指定しています。  
darwin(mac)の場合はこの指定ができませんでした。

```nix
# Configure nixos specific options
{ pkgs, ... }: {
  fonts = {
    enableDefaultFonts = true;
    # Make sure font match with alacritty font settings
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" "Noto Color Emoji" ];
      sansSerif = [ "Noto Sans CJK JP" "Noto Sans" "Noto Color Emoji" ];
      monospace = [ "Noto Sans Mono" "Noto Color Emoji" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
```

コメントに`# Make sure font match with alacritty font settings`とありますように、ここの指定はalacrittyのfont指定と一致していてほしいです。  
なので本来なら引数等で渡したいところなのですが、うまいこと渡せる方法を模索中です。(それできてないの致命的じゃんと言われるとその通りです。)

ざっくり上記のような要領で、host固有の設定 + os共通の設定をうまくdirectory構造で表現して適用することができます。  
次にterminalやshell, 各種コマンドのinstall設定についてみていきます。

### home-manager

再び、`flake.nix`の該当部分です。 `.hosts/xps15`をみてきたので、次はhome-managerの箇所を見ていきます。

```nix
  nixosConfigurations = {
    xps15 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./hosts/xps15

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.ymgyt = import ./home/linux;
        }
      ];
    };
  };
```

home-managerは個別のuserごとのhome配下を設定するmoduleです。  
重要なのは`home-manager.users.ymgyt = import ./home/linux;` の箇所でこの処理で、`ymgyt` user(さきほど宣言したuser)のhome配下の設定を行っています。  
home-managerではどんな項目が設定できるかは[options](https://nix-community.github.io/home-manager/options.html)に記載されています。  
まずimport先の`/home/linux/default.nix`ですが

```nix
{ pkgs
, ...
}: {

  imports = [
    ../base
  ];

  home = {
    username = "ymgyt";
    homeDirectory = "/home/ymgyt";

    stateVersion = "23.05";
  };

  programs.home-manager.enable = true;
}
```

となっており、userのhome directoryを作成したりしています。  

```
.
├── flake.lock
├── flake.nix
├── home
│  ├── base
│  │  ├── default.nix
│  │  ├── editor
│  │  │  ├── default.nix
│  │  │  └── helix
│  │  │     └── default.nix
│  │  ├── programs
│  │  │  ├── cloud
│  │  │  │  ├── aws.nix
│  │  │  │  └── default.nix
│  │  │  ├── default.nix
│  │  │  ├── filesystem.nix
│  │  │  ├── git.nix
│  │  │  ├── kubernetes.nix
│  │  │  └── languages
│  │  │     ├── default.nix
│  │  │     ├── go.nix
│  │  │     ├── nix.nix
│  │  │     └── rust.nix
│  │  ├── shell
│  │  │  ├── default.nix
│  │  │  ├── nushell
│  │  │  │  ├── config.nu
│  │  │  │  ├── default.nix
│  │  │  │  ├── env.nu
│  │  │  │  └── starship.toml
│  │  │  └── zsh
│  │  │     └── default.nix
│  │  └── terminal
│  │     ├── alacritty
│  │     │  ├── alacritty.yml
│  │     │  └── default.nix
│  │     ├── default.nix
│  │     └── zellij
│  │        ├── config.kdl
│  │        └── default.nix
│  ├── darwin
│  │  └── default.nix
│  └── linux
│     └── default.nix
├── hosts
├── Makefile.toml
├── modules
```

基本的にはlinux, macで共通の設定を適用しています。  
これを全部みていくと長くなってしまうので要点だけ記載します。  

まずpackageのinstallですが以下のように書くとpackageがinstallされた環境ができあがります。

```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [
    rustup
    cargo-criterion
    cargo-deps
    cargo-expand
    cargo-insta
    cargo-make
    cargo-nextest
    cargo-udeps
    cargo-sort
    cargo-vet
  ];
}
```

また、packageではなく、home-managerで個別の設定があるものがあります。例えばnushellには以下のようなoptionがあります。  

```nix
{ ... }: {
  programs.nushell = {
    enable = true;
    configFile.source = ./config.nu;
    envFile.source = ./env.nu;
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
  };

  # generate by `starship preset nerd-font-symbols -o ./starship.toml`
  xdg.configFile."starship.toml".source = ./starship.toml;
}
```

`programs.starship.enableNushellIntegration = true`を指定すると、nushellの起動時に読み込まれる`env.nu`に

```
let starship_cache = "/home/ymgyt/.cache/starship"
if not ($starship_cache | path exists) {
  mkdir $starship_cache
}
/etc/profiles/per-user/ymgyt/bin/starship init nu | save --force /home/ymgyt/.cache/starship/init.nu
```
のようなstarship用の初期化処理が挿入された状態でfileが生成されます。

```nix
{ pkgs
, ...
}: {
  programs.git = {
    enable = true;
    userName = "ymgyt";

    includes = [
      { path = "~/.gitlocalconfig"; }
    ];

    aliases = {
      a = "add";
      b = "branch -vv";
      d = "diff";
      s = "status";
      l = "log";

      co = "checkout";
      cm = "commit";
    };
  };

  home.packages = with pkgs; [
    git-trim
  ];
}
```

gitのconfigも定義できるので、最初にpushしようとしたら、nameとemailを設定してねというようなwarningがでなくて済みます。  
home-managerのoption経由で設定するか、設定fileをそのまま管理するかは選べます。  
nix上で変数を操作したりする場合にはhome-manager経由での設定が良いのかもと思っていたりします。

## 適用

これまで設定の概要をみてきましたので、次にこの設定を適用します。  
taskは以下のように定義しています。

```toml
[env]
HOST = { script = ["hostname"] }

[tasks.apply]
linux_alias = "nixos:apply"
mac_alias = "darwin:apply"

[tasks."xps15:apply"]
description = "Run nixos-rebuild switch"
extend = "nixos:apply"
env = { HOST = "xps15" }

[tasks."nixos:apply"]
script = '''
sudo nixos-rebuild switch --flake ".#${HOST}" --show-trace
'''

[tasks."prox86:apply"]
extend = "darwin:apply"
env = { HOST = "prox86" }

[tasks."fraim:apply"]
extend = "darwin:apply"
env = { HOST = "fraim" }

[tasks."darwin:apply"]
script = '''
nix build .#darwinConfigurations.${HOST}.system --extra-experimental-features 'nix-command flakes' --debug
sudo ./result/sw/bin/darwin-rebuild switch --flake ".#${HOST}"
'''
```

task runnerにはcargo-maker(makers)を利用しています。  
最終的に実行するcommandは`sudo nixos-rebuild switch --flake .#xps15` となります。この`--flake`の指定ですが、projectのcurrent directoryに`flake.nix`がある想定なので、`.`を`#`以降はoutputを指定します。  
`nixos-rebuild switch`はoutputのnixosConfigurationsを対象にするのが前提となるので結果的にhost名を渡します。  
これを適用するとgenerationなるものが作成されます。これはPC起動時のBIOSからも選択可能なので、設定の切り戻し等が行なえます。

設定管理しているのに、`cargo-make(makers)`に依存していいのかと思われるかもしれませんが初回だけ以下のようにするとnixがgitやcargo-makeを使える環境を用意してくれます。  

```
nix run nixpkgs#git -- clone https://github.com/ymgyt/mynix.git

nix shell nixpkgs#cargo-make -c makers `apply`
```

## Mac(darwin)

今まではnixosの設定をみてきましたが、darwinも基本的には同じです。違うのはnixosConfigurationではなく、[nix-darwin](https://daiderd.com/nix-darwin/manual/index.html)のmanualを参照する点です。  
さきほどまで省略していたdarwin関連の`flake.nix`です。

```nix
{
  # ...
  outputs =
    { nixpkgs
    , darwin
    , home-manager
    , ...
    }: {
      darwinConfigurations = {
        prox86 = darwin.lib.darwinSystem {
          system = "x86_64-darwin";

          modules = [
            ./hosts/prox86
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.me = import ./home/darwin;
            }
          ];
        };

        fraim = darwin.lib.darwinSystem {
          system = "aarch64-darwin";

          modules = [
            ./hosts/fraim
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.ymgyt = import ./home/darwin;
            }
          ];
        };
      };
    };
}
```

現状は、intel(`x86_64-darwin`)とm1(`aarch64-darwin`)のhostを管理しているので設定が2つあります。  
ただ構成の粒度はnixosとかわらないと思います。macでもfont設定やpackageのinstallがまったく同じ設定で行えています。  
また、nix-darwinを利用せずにmacではhome-managerのみでhome directory配下の管理に留めるという選択肢もありかと思います。



## 課題

まだ対応できていない箇所としては以下の点を認識しています。

* Secret管理
  * 実際問題としてなんだかんだlocalにsecretはあるのでこれをどうするか(Yubikeyでなくせる..?)
  * [Agenix](https://nixos.wiki/wiki/Agenix)という機構があるらしい
  * 個人的にはvaultとうまく連携したいが外部APIでてきたらもうpureではなくなってしまう気もする
* Overlay
  * Overlayやoverrideといった仕組みの使い所がわかっていない
* そもそものNixの仕組み
  * Derivationsやstdenv等わかっていない
  * [Nix Pills](https://nixos.org/guides/nix-pills/pr01.html)やってみようとは思っている

## 参考

以下に自分が参考にさせていただいたdocやblogを載せておきます。  
公式はもちろんなので載せていないです。

| Link      | Description    |
| --- | --- |
| [Zero to Nix](https://zero-to-nix.com/) | nix-installerを提供しているDeterminate Systemsが提供しているtutorial<br>とりあえず触ってみることができる<br>各種conseptの解説もありがたい |
| [NixOS & Nix Flakes - A Guide for Beginners](https://thiscute.world/en/posts/nixos-and-flake-basics/) | 一番オススメできるblog記事。<br>この記事のおかげでnixを始めることができた |
| [Practical Nix Flakes](https://serokell.io/blog/practical-nix-flakes) | Step by stepでflakeを解説してくれてわかりやすい。 |
| [What is Nix and Why You Should Use it](https://serokell.io/blog/what-is-nix) | Nixの背景や概要の説明がありがたい | 
| [Series: nix-flakes](https://xeiaso.net/blog/series/nix-flakes) | 全7回のnix-flakesのblog記事 |
| [What Is Nix](https://shopify.engineering/what-is-nix) | 2020年だけど、Shopifyの記事 |
| [How to Learn Nix](https://ianthehenry.com/posts/how-to-learn-nix/) | 全47回のnix学習記録。自分の物の調べ方は甘いんだなと思わされる。|
| [NIX FLAKES, PART 1: AN INTORODUCTION AND TUTORIAL](https://www.tweag.io/blog/2020-05-25-flakes/) | flakeの実装を主導したteamによる記事 |
| [Declarative management of dotfiles with Nix and Home manager](https://www.bekk.christmas/post/2021/16/dotfiles-with-nix-and-home-manager) | Home managerの解説記事 |
| [NixOS Series 1: Why I fell in love](https://lantian.pub/en/article/modify-website/nixos-why.lantian/) | 全4回の連載、nixが必要だった背景やユースケースが参考になる |
| [Japanese on NixOS](https://functor.tokyo/blog/2018-10-01-japanese-on-nixos) | Nixで日本語環境どう作るかについてとても参考なった |
| [NixOS4Noobs](https://jorel.dev/NixOS4Noobs/intro.html) | FlakeではなくNixOSの解説 |
| [Big list of Flakes tutorials](https://www.reddit.com/r/NixOS/comments/v2xpjm/big_list_of_flakes_tutorials/) | RedditのFlake関連のblog等のまとめ |

中でも[ryan4yinさん](https://twitter.com/ryan4yin)の[NixOS & Nix Flakes - A Guide for Beginners](https://thiscute.world/en/posts/nixos-and-flake-basics/)がとても参考になりました。  
現在も更新が続いており、[repository](https://github.com/ryan4yin/nix-config)もコメントが沢山書かれており、おすすめです。


## まとめ

非常に簡単にですがnixに入門しました。  
Nixすごいなと思います。システムの構成管理という副作用の塊のような領域で、pureを目指すという発想がなかったです。 

最後に自問自答したQ＆A

* Ansibleでよくないか
  * まずpythonの環境作る必要がある。でもtemplateは欲しくなる。

* dotfile管理でやりたいことの大部分できそう
  * terminal/shellまわりの操作感を管理する点に関してはそう思う。
  * nixの仕組みで5年,10年持つのかと言われるとわからないので結局シンプルな仕組みしか残らないのかもしれないとも思う。
  * やりたいことの順番としてはNixosというdistributionを使いたい -> macの設定も管理できるらしい -> ならnixで一元管理してみようという流れだったので、nixosは使いたい。

* トレードオフはどんな点にありそうか
  * storageすごい使いそう。(`nix store gc`コマンドとかある)
  * 宣言的(=ブラックボックス)なので処理が知りたいならソース読む必要がある。(でもc++)


