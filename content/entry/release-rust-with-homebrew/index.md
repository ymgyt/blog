+++
title = "🍺 RustのcliをHomebrewで公開する"
slug = "release-rust-with-homebrew"
date = "2020-02-06"
draft = false
aliases = ["/2020/02/02/213031"]
[taxonomies]
tags = ["rust"]
+++

この記事ではRust製のcliを`brew install`できるようになるまでの手順について書きます。(CI上で実行できるようにしたいのですが、まずは手でやります)
サンプルとして利用するのは、[前回の記事](https://blog.ymgyt.io/entry/2020/02/02/213031)で紹介した、MySQLにpingをうつだけのcli, `mysqlpinger`です。


## Build

```bash
$ cd path/to/mysqlpinger
$ cargo build --release
$ cd target/release
$ tar -czf mysqlpinger-0.3.0-x86_64-apple-darwin.tar.gz mysqlpinger
$ shasum -a 256 mysqlpinger-0.3.0-x86_64-apple-darwin.tar.gz
f253213e27eaec55a9c58029de92c84c4bd11f311f77d273e15053a21ba5684c  mysqlpinger-0.3.0-x86_64-apple-darwin.tar.gz
```

`--release`でbuildして、tarにします。file名は[他のproject](https://github.com/BurntSushi/ripgrep/releases/tag/11.0.2)にならって、`<binname>-<version>-<target>.tar.gz`としました。
また、あとで利用するので、hash値を取得しておきます。


## Github release

{{ figure(caption="Github release作成page", images=["images/gh_release_ss.png"]) }}

buildしたbinaryを公開するために、githubのreleaseを利用します。新しいreleaseを作成し、さきほど作成したtar fileをuploadします。
releaseが作成されると、Assetsにリンクが生成されます。



## Homebrew Formulaの作成

`homebrew-mysqlpinger` という名前のrepositoryをgithub上に作成して、cloneしてきます。

```sh
$ cd homebrew-mysqlpinger
$ exa -T
.
└── Formula
   └── mysqlpinger.rb

$ bat Formula/mysqlpinger.rb -p
class Mysqlpinger < Formula
  desc "cli mysql utility written in Rust"
  homepage "https://github.com/ymgyt/mysqlpinger"
  url "https://github.com/ymgyt/mysqlpinger/releases/download/v0.3.0/mysqlpinger-0.3.0-x86_64-apple-darwin.tar.gz"
  sha256 "f253213e27eaec55a9c58029de92c84c4bd11f311f77d273e15053a21ba5684c"
  version "0.3.0"

  def install
    bin.install "mysqlpinger"
  end
end
```

上記のように`Formula/mysqlpinger.rb`を作成して、classを定義します。
`url`には、github releaseのasset fileのlinkを指定します。
`sha256`にはtar fileのhash値を指定します。
(class名を`MySQLPinger`のようにするとエラーになりました)

ここまでを作成して、pushします。

## Install

```sh
$ brew tap ymgyt/mysqlpinger
$ brew install mysqlpinger
$ mysqlpinger --version
mysqlpinger 0.3.0
```

無事、installすることができました。🎉
github releaseの作成、fileのupload, formula repositoryの更新までをコマンドでできたらこの作業をci上でおこなえそうです。
Rust製でよさそうなツールを探して、なければ作ってみようと思います。


## 参考にさせていただいたブログ

* https://federicoterzi.com/blog/how-to-publish-your-rust-project-on-homebrew/
