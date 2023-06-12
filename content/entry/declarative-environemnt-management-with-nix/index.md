+++
title = "📦 Nixでlinuxとmacの環境を管理してみる"
slug = "declarative-environment-management-with-nix"
description = "Nixを利用してlinuxとmacの開発環境を宣言的に管理する。"
date = "2023-06-10"
draft = true
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


## Nixのinstall

Nixのinstallなのですが、現状選択肢が2つあると思っています。  
1つが[公式](https://nixos.org/download.html)で、もう1つがDeterminatesSystemsが提供している[nix-installer](https://github.com/DeterminateSystems/nix-installer)です。  
公式を選ばない理由があるのかと思いますが、DeterminateSystemsのnix-installerを選びたくなる理由は

* Uninstall機能を提供している
* Defaultでflakeが有効
* Rust製

裏を返すと公式にはuninstall機能がありません。ただし[doc](https://github.com/NixOS/nix/blob/master/doc/manual/src/installation/uninstall.md#macos)にはあります。  
またflakeはexperimentalなのでなんらかの方法で有効にする必要があります。(`~/.config/nix/nix.conf`を作成する)   
自分は両方試してどちらのほうほうでも問題なく使えています。  
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
なんというか、rustの場合、projectのbuild対象はlibraryか実行するbinaryかだと思いますが、nixはそれをなんらかのbuildするものに拡張したような仕組みなのかなと思っています。(つまりprojectのbuildをプログラミング言語に依らずにnixで管理できるということ)  

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




## 残された課題

* Secret管理
* Overlay

