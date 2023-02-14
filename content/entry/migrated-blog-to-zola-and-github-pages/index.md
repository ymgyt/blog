+++
title = "🚛 BlogをZola + Github Pagesに移行した"
slug = "migrated-blog-to-zola-and-github-pages"
date = "2023-02-13"
draft = false
description = "Rust製 static site generator zolaとGithub Pagesでblogを公開するまで"
[taxonomies]
tags = ["etc"]
+++

Blogを[Hatena blog](https://hatenablog.com/)から[Github pages](https://docs.github.com/en/pages)に移行しました。  
Markdownで記事を書いて、Rust製のstatic site generator [zola](https://github.com/getzola/zola)でhtmlを生成する構成です。  
本記事では、移行にあたって調べた事や行った設定について書きます。 

Zolaのversionは[`0.16.1`](https://github.com/getzola/zola/releases/tag/v0.16.1)です。

## 機能の概要

最初にzolaでできることの概要をまとめました。 

* Markdownをtemplateでhtlmに変換する仕組み
  * Markdown中から呼び出せるDSL(shortcodes)
  * Markdownをparseしてtemplate rendering時に参照できる変数として提供
  * Template engine(tera)の拡張
* Draftsによる公開の制御機能(build対象のfilterling)
* Syntax highlight(codeblockからhtml+cssへの変換)
* Taxonomiesによる記事のtagging
* 記事(page)および記事グループ(section)のmetadataの拡張(extra)
* Sitemap生成
* Feed生成
* Localの確認環境
* Redirect設定
* Pathのslugify
* 外部Link,内部Linkの有効性確認
* Sassサポート(ただし`LibSass 3.6.4`)
* Github actions deploy用action
* Theme

また、本記事では言及できていないのですが、SearchやMultilingual対応機能もあります。

## 移行のきっかっけ

Hatena blogには特に不満はなかったです。  
ただ、記事をgitで管理して、完成したらHatena blogのUIに貼り付けていました。これがpushだけで完結したら楽だなーと思っていました。  
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
1. Build及び記事のlinkが生きていることを確認する`zola check`
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
❯ exa -T  -F
./
├── config.toml
├── content/
├── sass/
├── static/
├── templates/
└── themes/
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

Zolaでは[Tera](https://github.com/Keats/tera)というtemplate engineが利用されています。  
Goのtemplate等、なにかしらのtemplate engineを利用したことがあればすぐに使えると思います。 
使い方は[公式のdoc](https://tera.netlify.app/docs)があるので参照してください。  
以下ではとりあえずこれだけ知ってれば書き始められるくらいのことを書きます。  

* `{{ expression }}` `{{`と`}}`で囲むとexpressionを書けます。
  * `{{ config.base_url }}`のように変数にアクセスできます
  * `{{ page.date | date(format="%m/%d") }}`のように `|`でbuilt-in関数にpipeできます  
* `{% %}`がstatementでif, loop, include, extend等の制御が書けます
* `{# #}`がcommentでhtmlに出力されないcommentが書けます

上記を前提にしてまず、どのtemplateがどのpath用のhtmlを生成するためのものかはzolaの規約で決まっています。(ないしは指定できます)  
その際、zolaがtop levelで参照できる変数を用意してくれるのでtemplateではそれを前提にします。  
例えば、`/entry/hello-world`用のhtmlを生成する為に際はzolaは`/entry/hello-world/index.md`(もしくは`/entry/hello-world.md`)を参照することを知っているので、当該pageのmetadataを保持した変数をtemplateに渡してくれます。

```html
<h1>{{ page.title }}</h1>
<div>{{ page.date }}</div>
<div>{{ page.content | safe }}</div>
```

の様なことが書けるわけです。  
以降はzolaというよりはteraの話になってしまいますが、templateに関して調べたことを書いていきます。

まず、templateの共通処理に関しては`include`と`extend`があります。  
`include`は被include側のcontentがinclude側にそのまま展開されます。  
`extend`は被extend側で定義したblockをextend側のcontentで置き換えることができます。  

自分は各pageからextendするbase用のtemplateを一つ用意して使いました。child extend (parent extend root)のようにextendしていくこともできます。  

```html

<!DOCTYPE html>
<html lang="ja">

<head>
  {% include "base/head.html" %}

  {# head.html側に定義するとextend側でoverrideできない #}
  {% block title -%}
  <title>{{ config.title }}</title>
  {%- endblock title %}

  {% block description %}
  {% endblock description %}

</head>

<body>
  <div class="world">
    <div class="content-container">
      {% include "base/header.html" %}
      <main class="blog-main">
        {% block content %}
        {% endblock content %}
      </main>
      {% include "base/footer.html" %}
    </div>
  </div>
</body>

</html>
```

`{% block xxx %}`から`{% endblock xxx %}`までがextend側にcontentを提供してもらう想定の場所です。  
extendされなかった場合用にdefaultのcontentを書いておくこともできます。  
被include templateにblockが定義してあってもextendできなかったのがはまりポイントでした。

実際にentry pageで利用するtemplateから以下のようにしてextendしました。
```html
{% import "macro/title.html" as macro %}
{% extends "base/base.html" %}

{% block title %}
{{ macro::title(title=page.title) }}
{% endblock title %}

{% block description %}
{% if page.description %}
<meta name="description" content="{{ page.description }}">
{% endif %}
{% endblock description %}

{% block content %}
<article>
  <div class="entry-content">
    {{ page.content | safe }}
  </div>
</article>
{% endblock content %}
```

`{% import "macro/title.html" as macro %}`としているところはteraのmacroの処理です。  
`<head>`の`<title>`を"記事のtitle | Blog name"のようにしたかったので以下のようなmacroを用意しました。  

```html
{% macro title(title) %}
<title>{{ title }} | {{ config.title }}</title>
{% endmacro title %}
```

teraではfor,if,variableへのassignができるので、やろうと思えばなんでもできそうです。 

例えば、記事のTableOfContent(TOC)を作る場合、専用の機能があるのではなくtemplateで作ることができます。  

```html
<aside class="entry-toc">
  <nav>
    <ul class="entry-toc-toplevel-list">
      {% for h1 in page.toc %}
      <li>
        <a href="{{ h1.permalink | safe }}">{{ h1.title }}</a>
        {% if h1.children %}
        <ul>
          {% for h2 in h1.children %}
          <li>
            <a href="{{ h2.permalink | safe }}">{{ h2.title }}</a>
          </li>
          {% endfor %}
        </ul>
        {% endif %}
      </li>
      {% endfor %}
    </ul>
  </nav>
</aside>
```

`page`には`Array<Header>`型の`toc` fieldがあるのでそれをiterateしています。  
どんな変数が参照できるかは[公式doc](https://www.getzola.org/documentation/templates/pages-sections/)を参照してください。  

記事の一覧を表示する`/entry`も以下の様にして作成しました。

```html
{% block content %}
<h1>Entries</h1>

{% for year, pages in section.pages | group_by(attribute="year") %}
<div class="entry-group">
  <div class="entry-year">{{ year }}</div>
  <ul class="entry-list">
    {% for page in pages %}
    <li class="entry-item">
      <a href="{{ page.permalink | safe }}"><span class="entry-item-title">{{ page.title }}</span>
        <span class="entry-date">{{ page.date | date(format="%m/%d") }}</span>
      </a>
    </li>
    {% endfor %}
  </ul>
</div>
{% endfor %}

{% endblock content %}
```

## Shortcodes

基本的にmarkdown fileが先頭のmetadataの記述を除いてはzolaに処理されることを意識しなくて良いようになっています。  
ただし、markdown側から生成したいhtmlを指定したい場合もあるかと思います。その際にmarkdown側から呼び出せるDSLがshortcodesとして提供されています。  
自分はHatena blogから移行するにあたって、記事への画像の埋め込みにHatena blog側の機能を利用していたので、画像まわりの処理に利用しました。  

具体的には、記事中に画像を貼りたいところで  

`{{` `figure(caption="Component diagram", images=["images/cqrs_component_diagram.png"] )` `}}`

上記のような処理を書いて、`<figure>` tagを生成しました。  
この`figure()`呼び出しを有効にするには`templates/shortcodes/figure.html`を作成します。  
file名が関数(shortcodes)名になります。  
templateの中では、引数(`caption`, `images`)が変数として参照できるので下記のように参照できます。

```html
{% if href %}
<a href="{{ href }}">
{% endif %}
<figure class="{% if class %} {{ class }} {% endif %}">
  <div class="fig-images-row">
    {% for src in images %}
    <img 
      src="{{ src }}" 
      {% if width  %} width="{{ width }},"  {% endif %} 
      {% if height %} height="{{ height }}" {% endif %}
    >
    {% endfor %}
  </div>
  {% if caption %}<figcaption>{{ caption }}</figcaption>{% endif %}
</figure>
{% if href %}
</a>
{% endif %}
```

(`img.alt`が設定できていないので改善したい)


## Tag管理

よくある記事にtagをつける機能は[Taxonomies](https://www.getzola.org/documentation/content/taxonomies/)としてサポートされています。  
今回は`tags`というtaxonomyを定義して、記事ごとに`tags = ["rust", "etc"]`のようにtag付けしていきます。  

まず、`config.toml`に以下のように定義します。  

```toml
taxonomies = [
  { name = "tags", feed = true, render = true },
]
```

これでzolaに`tags`というtaxonomyがあると宣言できます。  
記事にtagを振るには記事のmetadata(`/content/entry/hello-world/index.md`)に`tags`を定義します

```
+++
title = "🚛 BlogをZola + Github Pagesに移行した"
// ...
[taxonomies]
tags = ["etc"]
+++
```

`tags`というtaxonomiesが定義されると、zolaは`/tags`と`/tags/etc`のようなtag一覧とtagごとの記事一覧のpageを用意しようとします。  
そして、`templates/tags/list.html`と`templates/tags/single.html`がそれぞれ対応するtemplateなのでこれを用意しておきます。  
Taxonomies用のtemplateがない場合それぞれ`templates/{taxonomy_single.html,taxonomy_list.html}`が参照されます。  

`list.html`,`single.html`ではそれぞれtaxonomyの情報を変数で渡してくれるのでtemplateではそれを利用します。 


## Syntax highlight

Markdownからhtmlに変換する際にどうしても必要になるのはsyntax highlightではないでしょうか。  
手元でcodeblockを書いている分にはplugin等でsyntax highlightが効いた状態で見えるかと思いますが、html化するにあたっては、markupした上でcss用のclass付与等が必要になると思います。  
Zolaでsyntax highlightを有効にするには`config.toml`で以下のように設定します。

```toml
[markdown]
highlight_code = true
highlight_theme = "monokai"
```

指定できるthemeについては[公式doc](https://www.getzola.org/documentation/getting-started/configuration/#syntax-highlighting)を参照してください。

markupとcssのclass付与だけ行い、cssは自分で管理したいというユースケースにも対応しています。  
その場合、`highlight_theme = "css"`を指定します。(`css`は特別扱いされます)  

さらに

```toml
[markdown]

highlight_themes_css = [
  { theme = "base16-ocean-dark", filename = "syntax-theme-dark.css" },
  { theme = "base16-ocean-light", filename = "syntax-theme-light.css" },
]
```

を指定すると適用されるcssを出力してくれます。  
自分は`highlight_theme = "css"`を指定して、[nord](https://github.com/crabique/Nord-plist/tree/0d655b23d6b300e691676d9b90a68d92b267f7ec)のthemeを`color`を調整して利用しました。


## Sass

cssに関しては[LibSass](https://github.com/sass/libsass)が利用されています。  
`sass/style.scss`を書いておくと、`public/style.css`が出力されます。  
`@use`は使えず、`@import`を利用しました。

## Theme

Themeの適用に関しては最初わかりづらかったです。  
結論からいうと自分はthemeは利用せずcssを書きました。  

themeを利用するには、`themes` directory配下に利用したthemeのrepositoryをgit cloneやsubmodule等でfetchします。  
その後、`config.toml`で`theme = "my_theme"`で指定します。  
これで何が起きるか最初はわからなかったのですが、現状の理解は以下です。  

Zolaのfile search pathに`themes`配下が含まれている。  
そのため、sectionのtemplateを検索する際に、userが専用のtemplateを指定しないと`section.html`にfallbackされる。さらにそのfileが`templates`以下に定義されていないと`themes`配下が検索される。  
利用するtheme側のrepositoryに`templates/section.html`があるとそれが利用される。  
結果的にthemeが適用される。  

なので、自分はthemeを適用する前に、page, entry section用のtemplateを既に作成して指定していたのでthemeを設定しても一向に反映されませんでした。  
また、自分はtaxonomiesに`tags`を定義しましたが、theme側ではuserが`tags`を定義するかはわからないので、taxonomiesのfallback用の`taxonomy_list.html`を用意するまでしかできません。


## Github actions

Github Pages公開にはGithub actionsを利用しました。  
[公式のexample](https://www.getzola.org/documentation/deployment/github-pages/)をほぼそのまま利用しました。  

```yaml
# On every push this script is executed
on:
  push:
    branches:
      - main
name: Build and deploy GH Pages
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: checkout
        uses: actions/checkout@v3.0.0
      - name: build_and_deploy
        uses: shalzz/zola-deploy-action@v0.16.1-1
        env:
          # Target branch
          PAGES_BRANCH: gh-pages
          TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

main branchにpushすると`gh-pages` branchのtop levelに`public`以下が展開されます。  
`gh-pages` branchをGithub pages側のbranchに設定します。


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

## Linkの確認

`zola check`でbuild及びLink(`anchor tagのhref`)の確認ができます。  
codeblockでsyntax highlighが効いていない場合もwarningを出してくれます。(watがなかった)  

Linkの確認では`mod.rs#L10-L20`のようなfragmentが有効かどうかまでチェックしてくれます。  
ただし、githubでの行間のhighlightを`#L10-L20`のようにしていると無効と判定されてしまいました。  
このような場合は以下の様に`config.toml`でskipすることができます。  

```toml
[link_checker]
skip_prefixes = [
    "http://[2001:db8::]/",
]

# Skip anchor checking for external URLs that start with these prefixes
skip_anchor_prefixes = [
    "https://caniuse.com/",
]
 
```

数年前の記事ですとfragmentが無効になっているケースも多々あったのでfragment付ければいいものでもないなと思いました。  
また、`zola check`をCIで回そうかとも考えたのですが、linkは外部の要因で壊れたりもするので、最初は見送りました。

## Draft

記事を作成中はまだ公開したくないという状態があるかと思います。  
その際は、pageのmetadataで`draft = true`を指定するとdraft扱いとなります。  
Draftのpageは`zola build`時に無視されるので、本番に公開されなくなります。  
Localでdraftを確認するには、`zola serve --drafts`のように`--drafts` flagを付与します。(buildも同様)


## その他ecosystem

### Feeds(RSS)

`config.toml`にて

```toml
generate_feed = true
feed_filename = "atom.xml"
```

を指定すると生成してくれます。


### Sitemap

defaultで`public/sitemap.xml`を出力してくれます。  
Google search consoleで指定したら問題なく認識されました。


### 404

`templates/404.html`を書いておくと404 pageを作成できます。

### robots.txt

defaultで以下のfileが作成されます。templateで上書きもできます。  

```text
User-agent: *
Disallow:
Allow: /
Sitemap: https://blog.ymgyt.io/sitemap.xml
```

## `zola serve`の注意点

`zola serve`でちょっとはまった点があったので書いておきます。  
serveで立ち上がるhttp serverは末尾の`/`がない場合にreedirectして`/`を付与するという挙動はしません。 

https://github.com/getzola/zola/issues/1781 

またこれに関連して、記事から画像等のassetへlinkを付与する際に以下の二つが候補になりました。  

1. `static/`配下に置く
1. `content/entry/hello-world/`等のpageと同一のdirectoryに置く(collocation)

pageと同一のdirectoryに置いた際に、linkは相対pathで`images/aaa.png`のように書くこともできます。  
そうすると末尾に`/`を付与せずにアクセスすると当該リソースはnot foundになります。  
この問題は`get_url(path="/images/path/to/aaa.png")`のように何らかの方法で絶対pathにすることで回避できます。  
また、Github pagesは末尾`/`へのredirectをしてくれる仕様のようでlocalでのみ問題となりました。  

個人的には関連するfileは近くに置いておきたいので、page用にdirectoryをきってそこに関連fileを置く様にしています。


## おわりに

ここまで駆け足でzolaの概要を見てきました。  
正直、全て[公式doc](https://www.getzola.org/documentation/getting-started/overview/)に書いてある内容ですが、自分の整理もかねて記事にしました。  

Zolaはとてもsimpleでありながらここ設定したいと思ったら大抵、設定させてくれるので使ってみたくなりました。 
多少のshortcodesというDSLとmetadataを受け入れられればmarkdownをほぼそのままで利用できるので別システムへの移行も特に問題なくできそうな点も良いと思っています。  

個人的にはまたひとつ開発toolのrust化が前進したので満足です。 


## 移行とは関係ない話

ここからは移行とは直接関係ない話です。  
今回の移行に際して、htmlとcssをtemplate/scssというlayerはあるにしても、ほぼ素でかけてとても楽しかったです。  
Frontendの複雑化(typescript, js-runtime, react, build system, module system,...)にともなって、なかなかhtmlやcssを直接扱う機会がなかったのが正直なところでした。  

なので、あれhtmlの`<head>`になに書けばいいんだっけ?となりました。 
そこで、[HTML解体新書-仕様から紐解く本格入門](https://www.amazon.co.jp/dp/4862465277)とかを読んだりしました。  

Faviconに関してはちょうど[How to Favicon in 2023: Six files that fit most needs](https://evilmartians.com/chronicles/how-to-favicon-in-2021-six-files-that-fit-most-needs)をTLで教えてもらったので参考にしました。

CSSに関してはもっと大変で、とりあえず本屋にいっておもしろそうな本をいくつか買ってきました。  
なかなか今の自分にちょうどいい本がなく、MDNに書いてあることだったり、大規模サイトを複数人でメンテできるようにいかに保守性高めるかの設計論だったりでちょうどいい本が見つかりませんでした。  

[Every Layout](https://every-layout.dev/)はとてもおもしろく、CSSはbrowserへの詳細な指示ではなく、ガイドであるというような趣旨のことが書いてあったり、intrinsicなlayoutではmedia-queryは不要みたいな考えに触れ視座が上がったけれど手が動かなかったりしました。

結局、自分に一番合っていたのは[CSS FOR JAVASCRIPT DEVELOPERS](https://css-for-js.dev/)でした。  

$400(5万くらい)払いましたが、かなりよかったです。  
おかげで、reset/normalize系のcssから自分で書けて、知らないcss propertyが適用されていないという状況を達成できました。(当たり前かもしれませんが)

いくつかとても参考になった記事も貼っておきます。

* [The Surprising Truth About Pixels and Accessibility](https://www.joshwcomeau.com/css/surprising-truth-about-pixels-and-accessibility/)
* [An Interactive Guide to Flexbox](https://www.joshwcomeau.com/css/interactive-guide-to-flexbox/)
  * ~~css flexboxの検索結果は汚染されていて、~~ これが最初にでればどれだけ助かったかと思います
* [Color Formats in CSS](https://www.joshwcomeau.com/css/color-formats/)
  * colorはhsl派になりました。devtoolでshiftでcolor formatを変換できるのも知りませんでした。

