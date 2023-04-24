+++
title = " ✏️ helixがfileの中身をrenderingする仕組みを理解する"
slug = "how-helix-render-file"
description = "helix source code readingの第一弾。まずはrenderingの流れを確認します。"
date = "2023-04-24"
draft = true
[taxonomies]
tags = ["rust"]
[extra]
image = "images/emoji/pencil2.png"
+++


本記事ではRust製Editor, [helix](https://github.com/helix-editor/helix)において、fileの中身がどのようにrenderingされるかをソースコードから理解することを目指します。  
具体的には、`hx ./Cargo.toml`のようにして、renderingしたいfile pathを引数にしてhelixを実行した場合を想定しています。  
今後はkeyboardからの入力をどのように処理しているかのevent handling編, LSPとどのように話しているかのLSP編, 各種設定fileや初期化処理の起動編等を予定しています。  

versionは現時点でのmaster branchの最新[61ff2bc](https://github.com/helix-editor/helix/commit/61ff2bc0941be0ca99f34d8ba013978356612caf)を対象にしています。


## 本記事のゴール

本記事では以下の点を目指します。  

* helixのソースコードに現れる各種コンポーネントの概要や責務の理解
  * `Application`, `Editor`, `View`, `Document`, `Compositor`, `TerminalBackend` 等々..
  * rendering処理以外でも必ず登場する型達なので、他の処理を読む際にも理解が役立ちます
* 引数で渡したfileの中身が最終的にどのようにterminalにrenderingされるかの処理の流れ


 本記事で扱わないこと。

* 起動時の初期化処理
  * 各種設定はなんらかの方法で渡されている前提
* Fileの編集
  * Fileを開いて表示するまでがスコープです
* Inline text(`TextAnnotations`)
  * LSPの型ヒントのように表示はされているが、操作の対象にはならないtext
  * この処理を省くことで説明が大幅にシンプルになります


## Helixのinstall

もしもまだhelixをinstallされていない場合は、[公式doc](https://docs.helix-editor.com/install.html)を確認してください。  
公式docは最新release版とは別に[master版](https://docs.helix-editor.com/master/)もあります。ソースからbuildされた際はmaster版をみるといいと思います。  

sourceからbuildする方法は簡単で以下のように行います。 

```sh
git clone https://github.com/helix-editor/helix
cd helix
cargo install --path helix-term --locked
```

`--locked`はつけて大丈夫です。  
maintenerの一人であるpascal先生がcargo updateの変更commitを[一つ一つreview](https://github.com/helix-editor/helix/pull/6808)したりしていました。  

Editorとしてフルに活用するにはこの後にruntime directoryを作成したり、利用言語のlsp server(`rust-analyzer`等)を設定したりする必要がありますが、今回はそれらの機能を利用しないので、特に必要ありません。


## CLIの確認

次にhelixのbinary, `hx`の使い方について簡単におさらいします。  
基本的には開きたいfileを引数にして実行するだけです。  

```sh
hx ./Cargo.toml
```

この際`-v`をつけるとloggingのlevelが変わり`--log`でlog fileを指定することもできます。デフォルトでは`~/.cache/helix/helix.log`です。 
また、fileを開く際に行数と列数を指定することもできます。 

```sh
hx ./Cargo.toml:3:5
```

このように実行すると3行目の5文字目がフォーカスされた状態でfileを開けます。  
また、複数fileをwindowの分割方法を指定して開くこともできます。  

```sh
hx README.md Cargo.toml --vsplit
```

その他にも`--tutor`でtutorialであったり、`--health`で言語毎のsyntax highlightやlspの設定状況を確認できたりしますが、今回は触れません。


## Applicationの起動から終了までの概要

Helixもinstallして起動方法も確認したので、早速`main.rs`から読んでいきたいところですが、まずhelixというapplicationの起動から終了までの概要を説明させてください。  



## `Application`の概要

## `Application::render()`


## `Compositor`


## `EditorView`


## `Document`と`View`

 