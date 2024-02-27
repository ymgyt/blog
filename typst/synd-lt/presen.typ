#import "@preview/polylux:0.3.1": *
#import themes.bipartite: *

#show: bipartite-theme.with(aspect-ratio: "16-9")

#set text(
  size: 25pt,
  font: (
    "JetBrainsMono Nerd Font",
    "Noto Sans CJK JP",
))

#west-slide(title: "nix develop")[
  #figure(
    image("./nix-develop-1.png", width: 100%, height: 40%, fit: "stretch"),
    numbering: none,
    caption: [ nix developで開発環境が立ち上がる ],
  )
]

#west-slide(title: "Nixによる開発環境の管理")[
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

#west-slide(title: "Nixによる開発環境の管理")[
  そもそもNixとは

  > A build tool, package manager, and programming language
  
  https://zero-to-nix.com/concepts/nix
]

#west-slide(title: "Nixによる開発環境の管理")[
  このRustのprojectをNixで管理しました
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

#west-slide(title: "RustのTUI library")[
  + crossterm
  + ratatui
  + ...
]

#west-slide(title: "RustでTUI")[
  #figure(
    image("./ss-2.png", width: 80%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ Feedの一覧 ],
  )
]

#west-slide(title: "RustでTUI")[
  #figure(
    image("./ss-1.png", width: 80%, height: 80%, fit: "contain"),
    numbering: none,
    caption: [ FeedのEntry一覧 ],
  )
]

#west-slide(title: "話すこと")[

  作成したツールのライフサイクルについて

  - TUIのFeed Viewerを作った
  - Nixで開発環境,CI,Deployを管理した
  - Releaseではcargo-releaseとcargo-distを利用した
  - Trace,Metrics,LogsはOpenTelemetryを利用した
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
  TODO: 会社紹介の概要もらって載せる
]

