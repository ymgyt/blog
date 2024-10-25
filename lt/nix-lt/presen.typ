#import "@preview/polylux:0.3.1": *
#import themes.bipartite: *

#show: bipartite-theme.with(aspect-ratio: "16-9")

#show table.cell.where(y: 0): strong

#set text(
  size: 25pt,
  font: ( 
  "Noto Sans CJK JP", 
  )
)

#title-slide(
  title: [deploy-rsでNixをdeploy],
  author: [ymgyt],
  date: [2024-10-26],
)

#west-slide(title: "自己紹介")[
  ```toml
  [speaker]
  name   = "Yamaguchi Yuta"
  github = "https://github.com/ymgyt"
  blog   = "https://blog.ymgyt.io/"
  ```
]

#west-slide(title: "概要")[
  - deploy-rsの使い方
  - deploy-rsの仕組み
]

#west-slide(title: "Deploy Tools")[
#set text(font:("JetBrainsMono Nerd Font"))
#show table.cell.where(y: 0): set text(weight: "bold")
#table(
  columns: (33%, 33%, 33%),
  table.header[Tool][Lang][Star],
  [#link("https://github.com/NixOS/nixops")[nixops]],[python],[1,842],
  [#link("https://github.com/serokell/deploy-rs/tree/master")[deploy-rs]], [rust], [1,366],
  [#link("https://github.com/zhaofengli/colmena")[colmena]],[rust], [1,193],
  [#link("https://github.com/DBCDK/morph")[morph]], [go],[812],
  [#link("https://github.com/nlewo/comin")[comin]],[go],[368],
  [#link("https://github.com/rapenne-s/bento")[bento]], [shell],[240],
  [#link("https://github.com/krebs/krops")[krops]],[nix],[137]
)
]

#west-slide(title: "deploy-rsとは")[
#image("./images/deploy_rs_logo.svg")
> A Simple, multi-profile Nix-flake deploy tool

#pause - multi-profile: deployの単位はprofile

#pause - Nix-flake: 設定はflake.nixに定義
]

#west-slide(title: "flake.nix")[
#set text(size: 14pt)
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs }:
    {
      nixosConfigurations.myhost = 
        nixpkgs.lib.nixosSystem { system = "aarch64-linux"; };

      deploy = {
        user = "root";
        autoRollback = true;
        magicRollback = true;
        remoteBuild = false;

        nodes = {
          myhost = {
            hostname = "myhost";
            profiles.system.path = 
              deploy-rs.lib.aarch64-linux.activate.nixos 
                self.nixosConfigurations.myhost;
          };
        };
      };
    };
}
```
]

#west-slide(title: "deployの実行")[
```sh
# 全nodeのdeploy
deploy .

# nodeの指定
deploy .#myhost

# profileの指定
deploy .#myhost.foo
```
]

#west-slide(title: "Rollback")[
  2種類のRollbackがある
  \
  - Auto  Rollback
  - Magic Rollback
]

#west-slide(title: "Auto Rollback")[
  Auto rollbackはprofileのactivateが失敗した場合に前のprofileを再度有効にする  

  `nix-env -p <path> --rollback` \
  `nix-env -p <path> --delete-generations <id>`
]

#west-slide(title: "Magic Rollback")[
  Magic rollbackはprofileのactivateに成功した場合でもなんらかの理由でnetwork(ssh)の疎通がとれなくなった場合にrollbackする\
]

#west-slide(title: "Magic Rollback")[
#image("./images/magic_rollback_1.svg")

- profileのactivateはdeploy-rsが提供するactivate commandが行う
- activateはprofile有効後にcanary fileを作成して待機する
- activateは一定時間内にcanary fileが削除されない場合、失敗とみなしてrollbackする
]

#west-slide(title: "Magic Rollback")[
#image("./images/magic_rollback_2.svg")

- ssh越しの`rm canary`が失敗
- activateがprofileのdeactivateを実行
]

#west-slide(title: "deploy-rsの仕組み")[
  deploy-rsはどうやってNixのprofileをdeployしているのか
]

#west-slide(title: "deploy対象の取得")[
  
#set text(size: 14pt)
```nix
{
  outputs = { self, nixpkgs, deploy-rs }:
    {
      nixosConfigurations.myhost = /* ... */
      deploy = {
        # Node共通の設定
        autoRollback = true;
        magicRollback = true;

        nodes = {
          myhost = {
            hostname = "myhost";
            profiles.system.path = 
              deploy-rs.lib.aarch64-linux.activate.nixos 
                self.nixosConfigurations.myhost;
          };
    };};};
}
```

- deployの設定は`flake.nix`に定義されている
- `nix eval --json .#deploy`で取得
]

#west-slide(title: "deploy対象の取得")[
  #image("images/nix_eval.png")
]

#west-slide(title: "deploy対象の取得")[
  #image("images/nix_eval_2.png")

  nodeやprofileの指定は`--apply` でnixの関数を適用することで実現
]

#west-slide(title: "profileのdeploy")[
nixのbuildをlocalで行うか、deploy対象のremoteで行うか選択できる
]

#west-slide(title: "profileのdeploy")[
  remote buildの場合

```sh
nix copy -s
  --to ssh-ng://${ssh_user}@${hostname}
  --derivation /nix/store/abc...xyz-activatable-nixos-system-host-xyz.drv^out

nix build
  /nix/store/abc...xyz-activatable-nixos-system-host-xyz.drv^out
  --eval-store auto
  --store ssh-ng://${ssh_user}@${hostname}
```
]

#west-slide(title: "profileのdeploy")[
  local buildの場合

```sh
nix build /nix/store/abc...xyz-activatable-nixos-system-host-xyz.drv^out --no-link

nix copy 
  --substitute-on-destination 
  --to ssh://${ssh_user}@${hostname} 
  /nix/store/abc...xyz-activatable-nixos-system-host-xyz
```
]

#west-slide(title: "まとめ")[
- deploy-rsで簡単にNixOS configurationを複数hostにdeployできた
- deployやrollbackはnixの機能を利用していることがわかった
]


#west-slide(title: "参考")[
- #link("https://github.com/serokell/deploy-rs/tree/master")[deploy-rs]
- #link("https://serokell.io/blog/deploy-rs")[Our New Nix Deployment Tool: deploy-rs]
- #link("https://discourse.nixos.org/t/deployment-tools-evaluating-nixops-deploy-rs-and-vanilla-nix-rebuild/36388")[Deployment tools: evaluating NixOps, deploy-rs, and vanilla nix-rebuild]
- #link("https://github.com/serokell/gemini-infra/blob/master/flake.nix")[serokell example]
- #link("https://nixcademy.com/posts/nixos-rebuild-remote-deployment/")[Remote Deployments with nixos-rebuild]
]
