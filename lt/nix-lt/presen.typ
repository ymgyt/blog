#import "@preview/polylux:0.3.1": *
#import themes.bipartite: *

#show: bipartite-theme.with(aspect-ratio: "16-9")

#set text(
  size: 25pt,
  font: (
    "JetBrainsMono Nerd Font",
    "Noto Sans CJK JP",
))

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
  ```
]

#west-slide(title: "参考")[
- #link("https://github.com/serokell/deploy-rs/tree/master")[deploy-rs]
- #link("https://serokell.io/blog/deploy-rs")[Our New Nix Deployment Tool: deploy-rs]
- #link("https://discourse.nixos.org/t/deployment-tools-evaluating-nixops-deploy-rs-and-vanilla-nix-rebuild/36388")[Deployment tools: evaluating NixOps, deploy-rs, and vanilla nix-rebuild]
- #link("https://github.com/serokell/gemini-infra/blob/master/flake.nix")[serokell example]
]
