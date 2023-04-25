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

versionは現時点でのmaster branchの最新[0097e19](https://github.com/helix-editor/helix/tree/0097e191bb9f9f144043c2afcf04bc8632021281)を対象にしています。直近のreleaseは[`23.03`](https://github.com/helix-editor/helix/releases/tag/23.03)です。


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
Applicationのlifecycleは大きく以下の3つに分けられます。  

1. 初期化処理
1. `Application::new()`
1. `Application::run()`

### 初期化処理

初期化処理では、引数の処理や設定fileのparse、loggingのsetup等を行います。  
`Application::new()`に必要な引数の準備が主な処理です。

### `Application::new()`

`Application`は処理のtop levelの型でfieldにeditorに必要な各種componentを保持しています。  
型としては以下のように定義されています。 

```rust
pub struct Application {
    compositor: Compositor,
    terminal: Terminal,
    pub editor: Editor,

    config: Arc<ArcSwap<Config>>,

    #[allow(dead_code)]
    theme_loader: Arc<theme::Loader>,
    #[allow(dead_code)]
    syn_loader: Arc<syntax::Loader>,

    signals: Signals,
    jobs: Jobs,
    lsp_progress: LspProgressMap,
    last_render: Instant,
}
```

https://github.com/helix-editor/helix/blob/0097e191bb9f9f144043c2afcf04bc8632021281/helix-term/src/application.rs#L63  

これらのfieldは処理を追っていく中で役割がわかってくるので今は特に理解しておく必要はないです。  
rederingを追っていく本記事との関係では`Compositor`, `Terminal`, `Editor`が関わってきます。  
`arc_swap::ArcSwap`はhelix外の型なのですが、処理を理解するにはわかっていることが望ましいです。  
helix外の重要なcrateについては別記事でまとめて扱う予定です。  

一応各fieldの概要を説明しておくと

* `compositor: Compositor`: rederingを担う各種Componentを管理している
* `terminal: Terminal`: 実際にterminalへの出力や制御を担う
* `editor: Editor`: FileやViewの管理や履歴等の状態を保持
* `config: Arc<ArcSwap<Config>>`: 各種設定へのaccessを提供
* `theme_loader: Arc<theme::Loader>`:  Themeへのaccessを提供
* `syn_loader: Arc<syntax::Loader>`: syntax設定へのaccessを提供
* `signals: Signals`: signal handling
* `jobs: Jobs`: 非同期のtaskを管理
* `lsp_pregress: `LspProgressMap`: LSP関連の状態を保持
* `last_render: Instant`: render関連の状態

`Application::new()`の詳細については実際の処理でどのように利用されるかを見てからそれらがどう生成されたかを確認したほうがわかりやすいと思ったので後ほど戻ってきます。

### `Application::run()` 

`Appliation`が生成できると、`Application::run()`が呼ばれます。  
この処理が実質的な処理の開始で、userの入力を処理して結果をrenderingするevent loopに入ります。  
ここでterminalを初期化して、panic hookを設定したりするので、terminalの制御がhelixに移ります。  
このevent_loopの中で今回追っていく, `Application::render()`が登場します。  

### ここまでの話をcodeで

以上を念頭に、実際のcodeを掲載します。メンタルモデルを共有できればいいのでもろもろ割愛して載せています。  
Helixでは[GUIも検討](https://github.com/helix-editor/helix/issues/39)されていますが、現状はterminal editorなのでmainは`helix-term/src/main.rs`にあります。  

```rust
fn main() -> Result<()> {
    let exit_code = main_impl()?;
    std::process::exit(exit_code);
}
```

https://github.com/helix-editor/helix/blob/0097e191bb9f9f144043c2afcf04bc8632021281/helix-term/src/main.rs#L37

mainはexit codeの処理のみ行います。 
以下が実質的なmain処理です。 

```rust
use anyhow::{Context, Error, Result};
use crossterm::event::EventStream;

#[tokio::main]
async fn main_impl() -> Result<i32> {
    // ...

    let args = Args::parse_args().context("could not parse arguments")?;

    let config = { /* load config ... */ }

    let syn_loader_conf = { /* init syntax loader */ }

    let mut app = Application::new(args, config, syn_loader_conf)
        .context("unable to create new application")?;

    let exit_code = app.run(&mut EventStream::new()).await?;

    Ok(exit_code)
}
```

https://github.com/helix-editor/helix/blob/0097e191bb9f9f144043c2afcf04bc8632021281/helix-term/src/main.rs#L43

もろもろ省略するとこれまで見てきたとおり、mainでは`Application::new()`を実行したのち、`Application::run()`を呼んで、戻り値をexit codeとして返しています。  
helixではErrorの表現として、`anyhow`を利用しており、Errorを呼び出し側でhandlingしたい場合のみ専用の型を定義しています。  
また本記事ではuserからのkeyboard入力等のevent handlingを扱わないので詳しくはふれませんが、`crossterm::event::EventStream`がuserからの入力を表しています。  
ちなみにですが、`main()`以外に`#[tokio::main]` annotationを使っている例を初めて見ました。  

次に`Application::run()`ですが以下のようになっています。


```rust
impl Application {

    pub async fn run<S>(&mut self, input_stream: &mut S) -> Result<i32, Error>
    where
        S: Stream<Item = crossterm::Result<crossterm::event::Event>> + Unpin,
    {
        self.claim_term().await?;

        // Exit the alternate screen and disable raw mode before panicking
        let hook = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            // We can't handle errors properly inside this closure.  And it's
            // probably not a good idea to `unwrap()` inside a panic handler.
            // So we just ignore the `Result`.
            let _ = TerminalBackend::force_restore();
            hook(info);
        }));

        self.event_loop(input_stream).await;

        let close_errs = self.close().await;

        self.restore_term()?;

        for err in close_errs {
            self.editor.exit_code = 1;
            eprintln!("Error: {}", err);
        }

        Ok(self.editor.exit_code)
    }
}
```

https://github.com/helix-editor/helix/blob/0097e191bb9f9f144043c2afcf04bc8632021281/helix-term/src/application.rs#L1106

基本的にはevent loop前後の処理を実施しています。  
`self.claim_term()`でterminalを初期化しています。`std::panic_set_hook()`を呼んでいるのはhelixの処理中にpanicするとuserのshellに綺麗に戻れなくなることを防ぐためです。  

続いてevent_loop。 


```rust
impl Application {

  pub async fn event_loop<S>(&mut self, input_stream: &mut S)
    where
        S: Stream<Item = crossterm::Result<crossterm::event::Event>> + Unpin,
    {
        self.render().await;  //  👈
        self.last_render = Instant::now();

        loop {
            if !self.event_loop_until_idle(input_stream).await {
                break;
            }
        }
    }
}

```

https://github.com/helix-editor/helix/blob/0097e191bb9f9f144043c2afcf04bc8632021281/helix-term/src/application.rs#L291 

まず`Application::render()`を実行して初期化したterminalにhelixのviewをrenderingしたのち、実質的なevent loopである`Application::event_loop_until_idle()`に入ります。  
というわけで、今回の主題である`Application::render()`にたどり着きました。この処理を理解するのが本記事の目標です。


## `Application::render()`




## `Compositor`


## `EditorView`


## `Document`と`View`

 