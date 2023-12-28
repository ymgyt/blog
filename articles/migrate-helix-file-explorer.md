---
title: "最新のHelixでFile explorerを使いたい"
emoji: "📁"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["rust", "helix"]
published: false
#publication_name: "fraim"
---

現在のdirectory構造を左側に表示する機能は各種editorに一般的に備わっているものかと思います。
[Helix]にその機能を追加しようとした[PR File explorer and tree helper (v3)](https://github.com/helix-editor/helix/pull/5768)は残念ながらmergeに至りませんでした。  
自分はこのPR branchを利用していたのですが、更新から10ヶ月程度経ち、masterとの乖離が大きくなってきました。
そこで、[Helix]を[fork](https://github.com/ymgyt/helix)して、このPRを最新のmasterに移植して利用することにしました。 
本記事では[Helix]にfile explorerというdirectory構造を表示するcomponentを追加するうえで必要だった変更について書きます。  
そもそもどうやって[Helix]がfileを表示しているかについては以前、[Helixがfileをrenderingする仕組みを理解する](https://blog.ymgyt.io/entry/how-helix-render-file/)で書いたりしていました。 
File explorerは下記の画像のdirectory構造を表示している左側のcomponentです。 

![Helix image](/images/migrate-helix-file-explorer/helix-ss-1.png)

(なお、同様の機能がfile treeであったり、file tree explorerとも呼ばれることもありますが、本記事ではfile explorerと呼びます)

# 背景

[Helix]にfile explorerを追加しようという[要望](https://github.com/helix-editor/helix/issues/200)は早くからありました。  
[File explorer and tree helper (v3)](https://github.com/helix-editor/helix/pull/5768)のPRができた際はすぐに使ってみて、とても気に入っていました。  
しかしながら、最終的にfile explorerはpluginで実装すべきで、[Helix]のcoreには含めないとの決断がなされました。

> A file tree explorer is a big feature and there's a lot of people who wouldn't benefit from it, including the maintainers, who would be "forced" to maintain it. This is precisely where plugins come into play, because they delegate maintenance to plugin authors and they are "opt-in" based.

https://github.com/helix-editor/helix/pull/5768#issuecomment-1722508888

[Helix]の主要な開発者の一人であられるpascal先生は以下のようにおっしゃられていました。

> Utimately different people have different preferences and we can't please everyone. There are a billion different file navigation plugins/tuis around and building them all into helix would bloat it quite a lot and ultimately would not end well.

https://matrix.to/#/!glLuldscRKMQxGWgjZ:matrix.org/$2zxk4ODb-g3lQcKTgRvSnCbC4szNhJxxkGgjO3cOXyQ?via=matrix.org&via=envs.net&via=tchncs.de

[Helix]ではplugin機構は[議論](https://github.com/helix-editor/helix/issues/122)されているものの、まだ実装に至っていないので結果的に最新の[Helix]を利用しつつ、file explorerを使うには自前でやるしかないことになりました。  

もう一つの選択肢としては[File explorer workaround until plugin system arrives #8314](https://github.com/helix-editor/helix/discussions/8314) discussionで提案されている、zellijやwezterm等のterminal multiplexer + brootやyazi等のfile explorerを組み合わせる手法です。  
こちらのほうがcomposableで筋が良いように思えますが、tool -> helixの連携で課題があり採用しませんでした。

このアプローチでは[Turning Helix into an IDE with the help of WezTerm and CLI tools](https://quantonganh.com/2023/08/19/turn-helix-into-ide.md)が参考になりました。




[Helix]: https://github.com/helix-editor/helix
