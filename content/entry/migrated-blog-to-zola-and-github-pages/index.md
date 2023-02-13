+++
title = "🚛 BlogをZola + Github Pagesに移行した"
slug = "migrated-blog-to-zola-and-github-pages"
date = "2023-02-13"
draft = true
description = "Rust製 static site generator zolaとGithub Pagesでblogを公開するまで"
[taxonomies]
tags = ["etc"]
+++

Blogを[Hatena blog](https://hatenablog.com/)から[Github pages](https://docs.github.com/en/pages)に移行しました。  
Markdownで記事を書いて、Rust製のstatic site generator [zola](https://github.com/getzola/zola)でhtmlを生成する構成です。  
本記事では、移行にあたって調べた事や行った設定について書きます。  

<!-- more -->

Zolaのversionは[`0.16.1`](https://github.com/getzola/zola/releases/tag/v0.16.1)です。

## 移行のきっかっけ

Hatena blogには特に不満はなかったです。  
ただ、記事はgitで管理して、完成したらHatena blogのUIに貼り付けていました。これがpushだけで完結したら楽だなーと思っていました。  
そんな時にzolaを知り、試してみたらsimpleで使いやすかったので移行してみることにしました。

## Zolaの使い方

Installについては[公式のInstallation](https://www.getzola.org/documentation/getting-started/installation/)を参照してください。  
自分はsourceからbuildしました。  

```sh
❯ git clone https://github.com/getzola/zola.git
❯ cd zola
❯ cargo build --release --quiet
❯ zola --version
zola 0.16.1
```

Zolaには以下のコマンドがあります。  

1. Project初期化用の`zola init`
1. 書いている記事を手元で確認するための`zola serve`
1. 記事のlinkが生きていることを確認する`zola check`
1. 最終的に公開するhtml等を生成する`zola build`

## Zolaのdirectory構造

まずは`zola init`から始めます。  

```sh
❯ mkdir zola-handson
❯ cd zola-handson
❯ zola init

Welcome to Zola!
Please answer a few questions to get started quickly.
Any choices made can be changed by modifying the `config.toml` file later.
> What is the URL of your site? (https://example.com): https://blog.ymgyt.io
> Do you want to enable Sass compilation? [Y/n]: Y
> Do you want to enable syntax highlighting? [y/N]: y
> Do you want to build a search index of the content? [y/N]: N

Done! Your site was created in /private/tmp/zola-handson

Get started by moving into the directory and using the built-in server: `zola serve`
Visit https://www.getzola.org for the full documentation.
```

`zola init`実行後にいくつか質問に答えるとdirectoryが作成されます。  
なお、messageにある通り設定は後から変えられるので適当に答えても特に問題ありません。  

directory構成を確認します。

```sh
❯ exa -T --icons
 .
├──  config.toml
├──  content
├──  sass
├──  static
├──  templates
└──  themes
```

* `config.toml`がzolaの設定fileです
* `content`がmarkdownを格納するdirectoryです
* `sass`は適用するcss(sass)を配置します
* `static`に公開される画像等のasset fileを置きます
* `templates`にmakrdown fileをhtmlに変換する方法を指示するtemplateを置きます
* `thems`適用するthemeの格納場所です

`zola`コマンドを実行するとcontent配下のmarkdown filesがtemplatesに従ってhtmlに変換され、sass配下のcssとstatic配下のasset fileと共に`public`(設定で変更可) directoryに出力されます。

## Sectionとpage

さっそくmarkdownを書いていきたいところですが、その前にzolaの[Section](https://www.getzola.org/documentation/content/section/)と[Page](https://www.getzola.org/documentation/content/page/)について説明させてください。  
まず、Pageはcontentとして公開するmarkdownのことです。Pageには以下のようにmetadataを付与することでtemplateで処理する際に参照することができます。  

```
+++
title = "🚛 BlogをZola + Github Pagesに移行した"
slug = "migrated-blog-to-zola-and-github-pages"
date = "2023-02-13"
draft = true
description = "Rust製 static site generator zolaとGithub Pagesでblogを公開するまで"
[taxonomies]
tags = ["etc"]
+++

Blogを...
```

上記は本記事のmetadataです。

* `title` 記事のtitle
* `slug` 記事のpathに利用される
* `date` 公開日、pageを日付でsortする場合に参照される
* `draft` draftの設定、後述します
* `description` description templateで必要なら参照できる
* `taxonomies` いわゆるtagでzolaが提供するpageの分類機能、こちらも後述

その他`aliases`でredirect用のpathを設定できたりもします。詳しくは[公式doc](https://www.getzola.org/documentation/content/page/#front-matter)を参照してください。  


次にSectionを作成します。`content`配下にdirectoryを作成し、`_index.md` fileを配置するとそのdirectoryがzolaからSectionとして認識されます。  
Sectionは作らなくても良いのですが、同じ分類のpageをSectionにまとめておくとtemplateでlistとして参照できて便利です。  
今回、blogの記事は`entry` Sectionとして作成することにしました。  
まずは、`content/entry/_index.md`を作成します。`content`配下はそのまま公開時のpath名になるので、記事のURLは`https://blog.ymgyt.io/entry/{page_metadata.slug}`になります。  
Page同様にSectionにも`_index.md`にmetadataを記述できます。  

```
+++
title = "Blog entries"
sort_by = "date"
template = "entry.html"
page_template = "entry/page.html"
insert_anchor_links = "heading"
+++
```

* `title` templateから参照できます
* `sort_by` pageのsort方法、templateでsortされている前提で扱えます
* `template` Section pageのtemplateの指定
* `page_template` defaultで利用するpage共通のtemplateの指定
* `insert_anchor_links` markdownの見出し(`## Chapter2`)にanchor(`#`)用のlinkを作成するかの指定

Page同様、詳しくは[公式doc](https://www.getzola.org/documentation/content/section/)を参照してください。 

Sectionで`/entry`や`/entry/hello-world`のようなpathでアクセスがあった際にrenderingに利用するtemplateが指定できたので、次はtemplateについて見ていきます。 


## Templateの書き方

Zolaでは[Tera](https://github.com/Keats/tera)というtemplate engineが利用されています。Goのtemplate等、なにかしらのtemplate engineを利用したことがあればすぐに使えると思います。 
 


### Macro

## Tag管理

## Syntax highlight

## Sass

## Theme


## Custom domainの設定

Hatena blogでは自分のdomain(`blog.ymgyt.io`)を利用していたのでGithub pagesでも[custom domain](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site)の機能を利用することにしました。  
実際にやってみたことろ以下の作業が必要でした。なお、DNS管理はAWS Route53を利用しています。 

1. zola `config.toml`の設定
1. `static/CNAME` fileの作成
1. Github pages custom domainの設定
1. Route53 CNAME Recordの作成

以下それぞれの作業を具体的に見ていきます。  
設定に利用したdomainは`blog.ymgyt.io`, github account名は`ymgyt`という前提です。

### Zola `config.toml`の設定

zola設定fileの`config.toml`に利用するurlを設定します。  

```toml
base_url = "https://blog.ymgyt.io"
```

### `static/CNAME` fileの作成  

Github pagesではcustom domainを利用する場合、top levelのdirectoryに`CNAME`というfileがあることを期待しています。 
意外とこの`CNAME`に何を書けばいいのか説明がなかったのですが、[Troubleshoot a custom domain](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/troubleshooting-custom-domains-and-github-pages#cname-errors)に説明がありました。

> * The CNAME file can contain only one domain. To point multiple domains to your site, you must set up a redirect through your DNS provider.
> * The CNAME file must contain the domain name only. For example, www.example.com, blog.example.com, or example.com.

ということで、domainを`CNAME`に記載します。  

```sh
echo "blog.ymgy.io" > static/CNAME
```

`static/`配下に置いておけばbuild時にtop levelで出力されるのでGithub pagesの期待通りになります。


### Github pages custom domainの設定

`CNAME` fileをpushした段階でGithub側でcustom domainの設定が有効になり、UI自体では特になにも設定しませんでした。  
一応documentにはRepository Settings > Pages > Custom domainにdomainを入力する必要があると書かれていました。

Enforce HTTPSは有効にしました。

### Route53 CNAME Recordの作成

Route53で以下のrecordを作成しました。(実際はhatena用のCNAME recordを更新しました)  

* Record name: `blgo.ymgyt.io`
* Record type: `CNAME`
* Value: `ymgyt.github.io.`

```sh
❯ dig blog.ymgyt.io +nostats +nocomments +nocmd

; <<>> DiG 9.10.6 <<>> blog.ymgyt.io +nostats +nocomments +nocmd
;; global options: +cmd
;blog.ymgyt.io.                 IN      A
blog.ymgyt.io.          300     IN      CNAME   ymgyt.github.io.
ymgyt.github.io.        3600    IN      A       185.199.110.153
ymgyt.github.io.        3600    IN      A       185.199.109.153
ymgyt.github.io.        3600    IN      A       185.199.108.153
ymgyt.github.io.        3600    IN      A       185.199.111.153
```

これでcustom domainの設定は完了です。

## その他ecosystem

### RSS

### Sitemap

### 404


## 移行とは関係ない話

ここからは移行とは直接関係ない話です。  

### favicon


