#import "@preview/polylux:0.3.1": *
#import themes.bipartite: *

#show: bipartite-theme.with(aspect-ratio: "16-9")

#set text(
  size: 25pt,
  font: (
    "JetBrainsMono Nerd Font",
    "Noto Sans CJK JP",
))

#west-slide(title: "各種link")[
  - #link("https://github.com/crate-ci/cargo-release")[cargo-release]
  - #link("https://github.com/axodotdev/cargo-dist")[cargo-dist]
  - #link("https://github.com/serokell/deploy-rs")[deploy-rs]
  - #link("https://github.com/ymgyt/syndicationd")[syndicationd]
  - #link("https://github.com/ymgyt/mynix/tree/main/homeserver")[raspi nix configuration]
]

#west-slide(title: "まとめ")[
  Nix,cargo-{release,dist},OpenTelemetryで \
  楽しいツール開発
]

#west-slide(title: "RustでOpenTelemetry")[
    #figure(  
    image("./trace-ss.png", width: 100%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ Entri取得時のTrace ]
  )
]

#west-slide(title: "RustでOpenTelemetry")[
    #figure(  
    image("./dashboard-ss.png", width: 100%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ 公開しているGrafana dashboard ]
  )
]

#west-slide(title: "RustでOpenTelemetry")[
  Rustで`tracing`を使っている場合 \
  `tracing-opentelemetry`と`opentelemetry_sdk`を使うと\
  Logs, Traces, Metricsを取得できる
]

#west-slide(title: "監視もしたい")[
  DeployとReleaseができたので次に監視がしたい #pause \

  OpenTelemetryを使う
]

#west-slide(title: "cargo-distがやってくれる")[
  cargo-releaseと一緒に使うことが想定されており \
  cargo publishとgitのtag pushまでがcargo-release \
  それ移行の配布処理がcargo-distという役割分担がよかったので使ってみた
]

#west-slide(title: "cargo-distがやってくれる")[
  #figure(  
    image("./cargo-dist-plan.png", width: 100%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ `cargo dist plan`を実行するとCIで実行される内容を確認できる ]
  )
]


#west-slide(title: "cargo-distがやってくれる")[
  cargo-distが以下をやってくれる(設定次第)
  - 各種platform(aarch64,x86のdarwin,windows, linux gnu,musl)向けのbinary
  - shell,powershellのinstall script作成
  - homebrew用repositoryの更新(push権限を渡す必要あり)
]

#west-slide(title: "cargo-distがやってくれる")[
  #figure(  
    image("./release-ss.png", width: 100%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ Github releaseと各種installerが作成される ]
  )
]

#west-slide(title: "cargo-distがやってくれる")[
  `cargo dist init`を実行して質問に答えると
  - Cargo.tomlの`[workspace.metadata.dist]`に設定が追加
  - `.github/workflows/release.yml`を生成 
  #pause
  この状態でcargo-releaseでgit tagをpushすると
]

#west-slide(title: "homebrewでも公開したい")[
  専用のrepository(`homebrew-syndicationd`)に以下のような記述が必要
  #set text( size: 15pt )
```ruby
class Synd < Formula
  desc "terminal feed viewer"
  version "0.1.6"
  on_macos do
    on_arm do
      url "https://github.com/ymgyt/syndicationd/releases/download/synd-term-v0.1.6/synd-term-aarch64-apple-darwin.tar.gz"
      sha256 "c02751ba979720a2a24be09e82d6647a6283f28290bbe9c2fb79c03cb6dbb979"
    end
    on_intel do
      url "https://github.com/ymgyt/syndicationd/releases/download/synd-term-v0.1.6/synd-term-x86_64-apple-darwin.tar.gz"
      sha256 "3be81f95c68bde17ead0972df258c1094b28fd3d2a96c1a05261dba2326f31d8"
    end
  end
```
]

#west-slide(title: "homebrewでも公開したい")[
  brew installもしたい
]

#west-slide(title: "cargoでも公開したい")[
  `cargo release --package foo patch`を実行すると \
  - foo packageのCargo.toml `package.version`をbump(`v0.1.2` -> `v0.1.3`)
  - fooに依存しているworkspace内のpackageの`dependencies.foo.version`をbump
  - 設定に定義したreplace処理を実施(CHANGELOGの`[unreleased]` -> `[v0.1.3]`)
  - gitのcommit, tagging, push
  - cargo publish
]

#west-slide(title: "cargoでも公開したい")[
  cargo-releaseが全て面倒をみてくれる
]

#west-slide(title: "cargoでも公開したい")[
  `cargo publish`するには以下が必要
  - Cargo.tomlの`package.version`のbump
  - Workspace内に依存packageがある場合は合わせてbump
  - CHANGELOGの生成
  - gitのtagging

  これをworkspaceのmember crateごとに実施する必要がある
]

#west-slide(title: "cargoでも公開したい")[
  とはいえ、cargo installもしたい
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  - 開発環境をNixで管理できる
  - CIもNixで管理できる
  - CacheもNixが管理してくれる
  - InstallもNixで行える
  - DeployもNixで行える
]

#west-slide(title: "NixでDeploy")[
  #figure(  
    image("./deploy-rs.png", width: 100%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ deploy-rsでNixOSが入ったRaspberryPiにdeploy https://github.com/serokell/deploy-r]
  )
]

#west-slide(title: "Nixでsystemd serviceを宣言")[
  #set text(
    size: 19pt,
    font: (
      "JetBrainsMono Nerd Font",
      "Noto Sans CJK JP",
  ))
```nix
{ config, pkgs, syndicationd, ... }:
let
  syndPkg = syndicationd.packages."${pkgs.system}".synd-api;
in {
  config = {
    systemd.services.synd-api = {
      description = "Syndicationd api";
      wantedBy = [ "multi-user.target" ];
      environment = {
        SYND_LOG = "INFO";
      };
      serviceConfig = {
		ExecStart = "${syndPkg}/bin/synd-api"
      };
    };
  };
}
```
https://github.com/ymgyt/mynix/blob/main/homeserver/modules/syndicationd/default.nix
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  #text(fill: gray.lighten(50%),[- CIもNixで管理できる])
  #text(fill: gray.lighten(50%),[- CacheもNixが管理してくれる])
  #text(fill: gray.lighten(50%),[- InstallもNixで行える])
  - DeployもNixで行える
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  #figure(  
    image("./run-ss.png", width: 100%, height: 40%, fit: "contain"),
    numbering: none,
    caption: [ nix runで一時的に実行したり \ nix profileでinstallもできる ],
  )
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  #text(fill: gray.lighten(50%),[- CIもNixで管理できる])
  #text(fill: gray.lighten(50%),[- CacheもNixが管理してくれる])
  - InstallもNixで行える
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  #set text(
    size: 20pt,
    font: (
      "JetBrainsMono Nerd Font",
      "Noto Sans CJK JP",
  ))
```yaml
name: CI
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v25
        with:
          github_access_token: ${{ secrets.GITHUB_TOKEN }}
      - uses: cachix/cachix-action@v14
        with:
          name: syndicationd
          authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
      - run: nix develop .#ci --accept-flake-config --command just check
``` 

cacheを設定した最終的なCIのworkflow \
localとCIで同じcacheの仕組みを利用できる
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  #figure(
    image("./ci-cache.png", width: 100%, height: 40%, fit: "contain"),
    numbering: none,
    caption: [ cacheから取得 ],
  )
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[

`/nix/store/3sn5pij1hjvdlnq468c0m8vz8nibhrdc-cargo-release-0.25.0/bin/cargo-release`の \
`3sn5pij1hjvdlnq468c0m8vz8nibhrdc`が入力に対応するhashとなっており、cacheがあればbuildせずにbinaryを取得できる
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  #text(fill: gray.lighten(50%),[- CIもNixで管理できる])
  - CacheもNixが管理してくれる 
]

#west-slide(title: "CIでもnix develop")[
```yaml
name: CI
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: nix develop .#ci --accept-flake-config --command just check
```

 - install actionが不要
 - 開発環境と同一version
]

#west-slide(title: "Nixで管理すると何がうれしいのか")[
  - CIもNixで管理できる
]

#west-slide(title: "nix develop")[
  #figure(
    image("./nix-develop-1.png", width: 100%, height: 40%, fit: "stretch"),
    numbering: none,
    caption: [ nix developで開発環境が立ち上がる ],
  )
]

#west-slide(title: "Nixによる開発環境の管理")[
  #set text(
    size: 20pt,
    font: (
      "JetBrainsMono Nerd Font",
      "Noto Sans CJK JP",
  ))
flake.nixで開発時の依存を宣言
```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-23.11"; 
  outputs = { self, nixpkgs, ... }:
  	let dev_packages = with pkgs; [
      graphql-client
      git-cliff
      cargo-release
      cargo-dist
      oranda
    ];
    in { devShells.default = craneLib.devShell {
        packages = dev_packages;
      };
    });
}
```
]


#title-slide(
  title: [TUIのFeed Viewerを自宅のRaspbery Piで公開するまで],
  subtitle: [NixでRustの開発環境からCI,Deployまで管理する],
  author: [山口 裕太],
  date: [2024-03-05],
)

#west-slide(title: "自己紹介")[
  ```toml
  [speaker]
  name   = "Yamaguchi Yuta"
  github = "https://github.com/ymgyt"
  blog   = "https://blog.ymgyt.io/"
  ```
]

#west-slide(title: "会社紹介")[
  ```toml
  [company]
  name        = "FRAIM Inc."
  tech_blog   = "https://zenn.dev/p/fraim"
  ```
]

#west-slide(title: "話すこと")[

  作成したツールのライフサイクルについて

  - TUIのFeed Viewerを作った
  - Nixで開発環境,CI,Deployを管理した
  - Releaseではcargo-releaseとcargo-distを利用した
  - Trace,Metrics,LogsはOpenTelemetryを利用した
]

#west-slide(title: "RustでTUI")[
  #figure(
    image("./ss-1.png", width: 80%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ FeedのEntry一覧 ],
  )
]

#west-slide(title: "RustでTUI")[
  #figure(
    image("./ss-2.png", width: 80%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ Feedの一覧 ],
  )
]

#west-slide(title: "RustのTUI library")[
  + crossterm
  + ratatui
  + ...

  TODO: netflixのebpfでもratatuiが使われていたことの紹介
]

#west-slide(title: "ratatui")[
  ```rust
  let (header, widths, rows) = self.entry_rows(cx);

  let entries = Table::new(rows, widths)
      .header(header.style(cx.theme.entries.header))
      .column_spacing(2)
      .style(cx.theme.entries.background)
      .highlight_symbol(ui::TABLE_HIGHLIGHT_SYMBOL)
      .highlight_style(cx.theme.entries.selected_entry)
      .highlight_spacing(ratatui::widgets::HighlightSpacing::WhenSelected);

  ```
]

#west-slide(title: "crossterm")[
```rust
  async fn event_loop<S>(&mut self, input: &mut S)
  where
      S: Stream<Item = io::Result<CrosstermEvent>> + Unpin,
  {
      loop {
        tokio::select! {
          biased;
          Some(event) = input.next() => { }
          _ = self.background_jobs => { }
      };
  }
```
]

#west-slide(title: "crossterm")[
```rust
fn handle_terminal_event(&mut self, event: std::io::Result<CrosstermEvent>) {
    match event.unwrap() {
      CrosstermEvent::Resize(columns, rows) => { }
      CrosstermEvent::Key(key) => match key.code {
        KeyCode::Tab => { },
    }
  }
}
```
]

#west-slide(title: "Nixによる開発環境の管理")[
  そもそもNixとは

  > A build tool, package manager, and programming language
  
  https://zero-to-nix.com/concepts/nix
]

#west-slide(title: "Nixによる開発環境の管理")[
  このRustのprojectをNixで管理しました
]
