+++
title = "🚛 BlogをZola + Github Pagesに移行した"
slug = "migrated-blog-to-zola-and-github-pages"
date = "2023-02-13"
draft = true
[taxonomies]
tags = ["etc"]
+++

Blogを[Hatena blog](https://hatenablog.com/)から[Github pages](https://docs.github.com/en/pages)に移行しました。  
Markdownで記事を書いて、Rust製のstatic site generator [zola](https://github.com/getzola/zola)でhtmlを生成する構成です。  
本記事では、移行にあたって調べた事や行った設定について書きます。  

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

## Sectionとpage

## Templateの書き方

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


