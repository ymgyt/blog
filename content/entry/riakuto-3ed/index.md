+++
title = "⚛️ りあクト!第3版がすごくよかった"
slug = "riakuto-3ed"
date = "2020-10-10"
draft = false
[taxonomies]
tags = ["book"]
+++

　会社のフロントエンドエンジニアの方にReact/Typescript関連のおすすめのドキュメントを聞いたところりあクトを教えてもらいました。
読んでみてとてもおもしろく、おおげさですが感動してしまったので感想を書きます。

## 読んだ本

りあクト！ TypeScriptで始めるつらくないReact開発 第3版(200912)

{{figure(caption="りあクト!第3班", images=[
  "images/riakuto_1.jpeg",
  "images/riakuto_2.jpeg",
  "images/riakuto_3.jpeg",
], width="32%") }}

* [Ⅰ. 言語・環境編](https://oukayuka.booth.pm/items/2368045)
* [Ⅱ. React基礎編](https://oukayuka.booth.pm/items/2368019)
* [Ⅲ. React応用編](https://oukayuka.booth.pm/items/2367992)


## 私とフロントエンド

　普段仕事では[movo](https://movo.co.jp/)という物流業界向けのSaaSのバックエンドでGoを書いています。
各種プロダクトのフロントエンドはReact(16.9)/Typescript(3.7)で書かれているのですが、swagger/openapiの生成までしかタッチしていないので
フロントのコードを読めるようになりたいと思っていました。
ReactについてはUdemyのコースを買ってみてTODOを中途半端に作った感じで止まっていました。(https://todo.ymgyt.io/)

　Reactをやってみた感想はReact + TypeScript + Redux + その他ライブラリ(router/form/etc...)を同時に学ぶのは大変だな、でした。
りあクト!の目次を見てみると環境構築(linter周りも), 言語仕様(モダン?JavaScript,Typescript)、React(Hooks)、ルーティング/Reduxと自分がもやもやしていたところが
バランス良く触れられていそうだったので読んでみることにしました。


## よかったところまとめ

　なによりよかったのがReactのAPIやライブラリが登場してきた背景や解決したい問題についてしっかり触れられているところでした。
普段から業務等でフロントの開発にキャッチアップできていなかった自分にとって時系列的な変化の情報はなかなかドキュメントを読んだだけではわからなかったので
とてもありがたかったです。

　仕事で使えることを念頭にかかれていること。linterの設定やReactRouterではv5/v6両方について触れられていること等実際のコードを読む上で助けになる情報が多かったです。

　Reactが好きになる。自分の力不足で理解が至らない箇所もありましたが(特に13章)Reactが好きになりました。


## 第一部(言語/環境編)

　ここからは各章の感想を書いていきます。

### 第1章 こんにちはReact

　どうしてフロントエンドの開発にnodeが必要かはわかっていなかったのでここからきっちり説明してくれてこの本に対する好感度があがりました。
きちんとnodeenv/nvm等でversion固定しておく方法も例があって親切です。
Editorに関してはVSCodeが超絶推奨されています。(個人的には言語とEditor/IDEはあまり密結合せず各機能がcli等で提供されていてほしいですが)

　本番buildすると`/static/js/main.chunk.js`にcompile後の結果が出力されるのも知りませんでした。
`REACT_APP_API_TOKEN`のような環境変数で渡した値もここに表示されてしまいそうでした。CRA(create-react-app)のドキュメントにもsecret情報はのせないように注意されていました。(https://create-react-app.dev/docs/adding-custom-environment-variables/)ただそうするとフロントには一切secretわたせないのでしょうか。
　yarn upgrade-interactiveは便利ですね、nodeのcliはカラフルでemojiも使われていてフレンドリーですね。


### 第2章 エッジでディープなJavaScriptの世界

　jsのプリミティブ型へのアクセスがラッパーオブジェクトに自動変換される仕様は知りませんでした。
```sh
> 'Hello _'.replace('_', 'ymgyt')
'Hello ymgyt'
> (new String('Hello _')).replace('_', 'ymgyt')
'Hello ymgyt'
>
```

　メソッドとnew以外、thisはグローバルオブジェクト(window,global)を参照してるってすごい仕様だなと思います。

```javascript
class Persion {
  constructor(name) {
    this.name = name;
  }

  greet() {
    const doIt = function() {
      console.log(`Hi, ${this.name}`);
    };
    doIt();
  }
}

const ymgyt = new Person('ymgyt');
ymgyt.greet(); 
// => Uncaught TypeError: Cannot read property 'name' of undefined
```

`doIt`はメソッドでないのでthisはglobalを参照 -> class構文ではstrict modeが有効になっていて、thisのアクセスはundefinedになるという流れ。
このthisをundefinedでなくするためには

- `bind()`でthisを固定する
- `call()`,`apply()`でthisを指定する
- thisをを一時変数に代入する
- アロー関数

というアプローチが可能。Reactのコンポーネントをクラスで定義する際にcallbackで渡す関数をbindしておかないといけなかった理由がわかってうれしかったです。

　CommonJS, Browserify, AMD, ES Modulesとmoduleにもいろいろあったんですね。
webpackのやっていることをみるとフロントの技術はスクリプト言語で書いたままがユーザ空間でもそのまま実行されるみたいな認識はあらためないとけないと思わされました。ここまでくるとWASMのようにbinaryにcompileしてブラウザも一つのcompile targetみたいにとらえるのは自然の流れなんですかね。(Rustでフロント書きたい)


### 第3章 関数型プログラミングでいこう

　関数型プログラミングの説明についてはjs/ts特有の話はすくないのですんなり読めました。
Rustでasync/awaitが使えるようになったときは感動しましたが、jsやられてきた方はどうだったんですかね。


### 第4章 TypeScriptで型をご安全に

　ちょっと触って試したいとき等、ts-nodeがかなり便利。anyとunknownという型が用意されているところが多様な入出力を扱うjsらしいなと思いました。RustやGoならbyte列使いそう。
neverを使ってenum/string literal unionのswitchのcase漏れを捕捉できるのはすごくよいと思いました。

　継承より合成のほうがよい理由が説明されているのですが自分も著者(雪菜さん)のようにしっかり理由が説明できないとなと感じました。
Goに継承がないとディスり気味に言われたときに力強く擁護できず悔しい思いをしました。

　tsでクラスを定義するとinterface宣言とコンストラクター関数の宣言になるのは知りませんでした。そもそも型コンテキストという概念がなかったので型コンテキストというものが新鮮でした。

```typescript
const permissions = { 
  r: 0b100,
  w: 0b010,
  x: 0b001,
};
typePermsChar = keyof typeof permissions; //'r'|'w'|'x' 
const readable: PermsChar = 'r';
const writable: PermsChar = 'z';  // not assignable !
```

のように型を操作するような式が書けるのがすごい。

　組み込みのユーティリテ型`Pick`,`Ommit`なんてRustにもほしいです。entity定義しつつも、作成時に必要なproperty, ユーザに更新させるpropertyが微妙に違ったりするのでそのために3つ型定義するのではなく

```typescript
type struct Blog {
  id: Id,
  content: string,
  tags: Vec<Tag>,
}

type CreateBlogParam = Pick<Blog,"content">;
type UpdateBlogParam = Ommit<Blog, "id">;
```

のようにすることで作成時に必要な値、更新を許可する値みたいに意図がでていいかなと思うのですがどうでしょうか。

## 第二部(React基礎編)

第一部まではReactのためのjs/tsの準備的側面が強く第二部からいよいよReactの話にはいっていきます。第二部から本書の魅了全開といった感じです。

### 第5章 JSXでUIを表現する

　JSXはReactのDSLくらいなイメージだったのですが、`React.createElement`のSyntactic Sugarである点が強調されています。(Syntacs Sugarが和製英語であることを初めて知りました。)
　MVCは技術の役割による関心の分離でReactはコンポーネントを通じてアプリケーションの機能の単位による関心の分離という説明は蒙を啓かれた感じでした(語彙)

> 私たちが作ろうとしてるのは、ひとつのURLリクエストに対してひとつの静的なHTMLページを返すだけの単純なアプリじゃないからね。複数の外部APIとの並列的な非同期通信、取得データのキャッシュやローカルストレージへの永続化、ユーザーの操作によって即座に変化するUIの状態 管理、ときにはカメラやGPSといったデバイスへのアクセスまでをも備えた、インタラクティブでレスポンス性の高いアプリなんだよ。比べるべくはモバイルアプリやデスクトップアプリであって、サーバサイドWebアプリケーションの延長で考えるべきではないの
(p18)

という考えからフロントの技術派閥がHTMLテンプレートという観点から分類でき、Reactはどういう考えに基づいているかの説明はとても参考になりました。たしかに、テンプレート形式だとearly returnとかできないですよね。

　なんとなく肌感としてフロントのフレームワークはReactとVueの二大巨頭でついでAngularくらいに思っていたのですがnpmのDL数をみると圧倒的にReactが優勢なんですね。

　Reactのサンプルコードで最初に`react`と`react-dom`の２つをimportしていますが、どうしてdomだけ分離しているのかなと思っていました。"HTML is just the beginning."とあるように、Reactからするとdomはあくまでレンダー(出力)の対象環境のひとつにすぎないという設計になっているらしく視座の高さを感じました。

　Reactの解説をする際にいきなりJSXの書き方からはいるのではなくここまで厚く背景について解説してもらえてとてもありがたいです。こういう背景や考え方みたいなことってわりと口語的に伝わっていったり自分でいろいろ触ってみて体感していくことが多いと思うので本でここまではっきりいいきってくれる本書は本当に貴重だと思います。


### 第6章 Linterとフォーマッタでコード美人に

　フロントのlinterについてはなんとかLintがたくさんあってよくわかっていませんでした。Reactを触っていろいろ試そうと思うとどうしても自分で環境を作る必要があり、CRAもそこまでやってくれないので最初から作る過程をのせてくれていて本当にありがたいです。(ただ著者のtwitterによると新たに推奨設定が発表されたらしいです。)

　eslintの公式の推奨設定とtypescriptのバッティング箇所を調整するためにruleを優先度考慮して設定していくのはなかなか大変そうだなと思いました。実際にはやりながら都度都度チームに合う形で調整していくことになると思うのですが、言語的にIDE+linterの設定込で安全性担保しようとしているのである程度わかっていないとTypeScriptの良さが発揮できずこのあたりにつらみでているなと思いました。ここにさらにcode formatterも加わってformatしたらlint違反になったりします。(やはり公式のformatterは偉大)projectのtop levelに`.eslintignore`,`.eslintrc.js`,`.prettierrc`, `.stylelintrc.js`,`tsconfig.eslint.json`ができあがるので、Frontend DevOpsと呼ばれる職種があるのも納得です。(`eslint-config-prettier-check`という設定のconflictを検知する専用のcliまであるのはすごい)このあたりは、js/ts/cssといったパラダイムが違う技術スタックを統一的に扱ってる大変さがあるからなのかなと思います。


### 第7章 Reactをめぐるフロントエンドの歴史

> 7-1 React登場前夜 すべてはGoogleマップショックから始まった

　この書き出しからすでにおもしろい。Google MapのAjaxからはじまり、prototype.js,jQuery,Backbone.js,AngularJS,Knockout.js,Vueとフロントエンドの技術の変遷が語られていきます。Web Componentについても聞いたことしかなかったので勉強になりました。

　Reactの公式サイト(https://reactjs.org/)にはDeclartive, Component-Based, Lean Once, Write Anywhereと書かれていますがこれが変遷していった話はおもしろかったです。

　仮想DOMについてもまったくわかっていませんでしたがメンタルモデルレベルではなんとなくイメージできるようになりました。仮想DOMって`react-dom`の概念ではなく`react`の概念だとしたら、Reactはレンダリングされる環境に関与しない設計方針に反するような気はしました。それともDOM自体がブラウザに限定されない抽象的概念なんでしょうか。(なんて思っていたらしっかり秋谷さんが代弁してくれました。)

　VueのほうがReactよりシンプルで使いやすいというおっしゃられてる人もいますが大規模になっていくとそれはそれで大変になるみたいです。


### 8章 何はなくともコンポーネント

　クラスコンポーネントでEventHandlerにメソッド渡す際はアロー関数にして渡すようにしないとうまくいかない程度の認識でしたが、２章でthisの挙動について丁寧に解説してもらったおかげで理由が納得できました。
```
// NG
<Button onClick={this.handleClick}

// OK
<Button onClick={() => this.handleClick}
```
　 PresentationalComponentとContainerComponentは紹介されているブログ記事(https://medium.com/@dan_abramov/smart-and-dumb-components-7ca2f9a7c7d0)ではhooksで同じことできるから現在は推奨しないようなことが注記されていました。

> Update from 2019: I wrote this article a long time ago and my views have since evolved. In particular, I don’t suggest splitting your components like this anymore. If you find it natural in your codebase, this pattern can be handy. But I’ve seen it enforced without any necessity and with almost dogmatic fervor far too many times. The main reason I found it useful was because it let me separate complex stateful logic from other aspects of the component. Hooks let me do the same thing without an arbitrary division. This text is left intact for historical reasons but don’t take it too seriously.

影響力ある方が提唱するとwithout any necessityにdogmatic fervorでenforcedされるのは耳がいたいですね。大事なのはstateful logicを分離することみたいですね。

　もちろんりあクトでも、撤回されている件について触れられていて、そのうえで今でも有効な考えであると展開されていきます。理由は以下の２つ。

- デザインガイドと共存させやすいこと
- 分けて考えることがメンテナンス性の高い設計がうながされること

　デザインガイドとの共存についてはhooksって要は副作用なのでそれが分離されているとmockしやすいということなんでしょうか。StoryBookはプロダクトでも使われているのですが自分で使ったことがないのでピンときていません。

　メンテナンス性の高い設計につながる理由は、Reactの公式ドキュメントthinking in react(https://ja.reactjs.org/docs/thinking-in-react.html)の各ステップに対応するからということです。

#### Thinking in React(Reactの流儀)

　公式が開発の流れ/考え方まで示してくれるのは最高ですね。これは読まねばということで各ステップをみていきます。
- 英語(https://reactjs.org/docs/thinking-in-react.html)
- 日本語(https://ja.reactjs.org/docs/thinking-in-react.html)


##### Step1 UIをコンポーネントの階層構造に落とし込む

　画面のモックがあることは前提で、ここからコンポーネントに分解していきます。その際に、単一責任の原則(single responsibility principle)がひとつの基準になるようです。
ただ、テーブルコンポーネントとテーブルヘッダーコンポーネントを分離するかは好みの問題のようで(ソート等複雑になってきたらわければよい)このあたりは経験でやるみたいですね。最終的には以下のようなコンポーネントの階層構造を得ます。

```
- FilterableProductTable
  - SearchBar
  - ProductTable
    -  ProductCategoryRow
    -  ProductRow
```

##### Step2 Reactで静的なバージョンを作成する

> 表示の実装とユーザ操作の実装を切り離しておくことは重要です。静的な（操作できない）バージョンを作る際には、タイプ量が多い代わりに考えることが少なく、ユーザ操作を実装するときには、考えることが多い代わりにタイプ量は少ないからです。なぜそうなのかは後で説明します。

　とにかく表示の関心は分離しておくことが大事みたいですね。


##### Step3 UI状態を表現する必要かつ十分なstateを決定する

> それぞれについて見ていき、どれが state になりうるのかを考えてみます。各データについて、3 つの質問をしてみましょう。
  親から props を通じて与えられたデータでしょうか？ もしそうなら、それは state ではありません
  時間経過で変化しないままでいるデータでしょうか？ もしそうなら、それは state ではありません
  コンポーネント内にある他の props や state を使って算出可能なデータでしょうか？ もしそうなら、それは state ではありません

stateとpropsの違いは？と聞かれても即答できないのですが、このような観点で考えてみればいいのですね。既存の実装を読む際にはstateとpropsの切り分けにも注目してみようと思います。基本的にはユーザの入力や選択がstateになるのではと思っています。

##### Step4 stateをどこに配置するべきかのかを明確にする

stateについて

* その state を使って表示を行う、すべてのコンポーネントを確認する
* 共通の親コンポーネントを見つける（その階層構造の中で、ある state を必要としているすべてのコンポーネントの上位にある単一のコンポーネントのことです）
* 共通の親コンポーネントか、その階層構造でさらに上位の別のコンポーネントが state を持っているべきである
* もし state を持つにふさわしいコンポーネントを見つけられなかった場合は、state を保持するためだけの新しいコンポーネントを作り、階層構造の中ですでに見つけておいた共通の親コンポーネントの上に配置する

ということで、共通で利用されていたらどんどん上の階層に登っていく感じでしょうか。

##### Step5 逆方向のデータフローを追加する

　下位のコンポーネントから上位のコンポーネントのstateを更新できるように更新用のcallback関数をpropsとして下位コンポーネントに渡す。

> Hopefully, this gives you an idea of how to think about building components and applications with React. While it may be a little more typing than you’re used to, remember that code is read far more than it’s written, and it’s less difficult to read this modular, explicit code. As you start to build large libraries of components, you’ll appreciate this explicitness and modularity, and with code reuse, your lines of code will start to shrink. :)

　心にしみる深い教えだ..

　ということで、たしかにPresentational ComponentとContainer Componentをわけて書くとthinking in reactで言われているようにまず表示から作ってstate/ロジックを分離する流れが強制できそうです。自分のように初めてReact書くようなメンバーにとってはこれはここに書くと決まりごとあるほうがありがたいですよね。


### 第9章 Hooks, 関数コンポーネントの合体強化パーツ

　まず前提としてやりたいことはComponent間のstateを伴ったロジックの共有。そして当初はmixinといわれる手法が使われていたが公式からConsidered harmfulといわれるにいたってしまった。ということで言及されている、Mixins Considered Harmfulから見ていきます。(https://reactjs.org/blog/2016/07/13/mixins-considered-harmful.html)

#### Mixins Considered Harmful

> “How do I share the code between several components?” is one of the first questions that people ask when they learn React. Our answer has always been to use component composition for code reuse. You can define a component and use it in several other components.

> It is not always obvious how a certain pattern can be solved with composition. React is influenced by functional programming but it came into the field that was dominated by object-oriented libraries. It was hard for engineers both inside and outside of Facebook to give up on the patterns they were used to.
  To ease the initial adoption and learning, we included certain escape hatches into React. The mixin system was one of those escape hatches, and its goal was to give you a way to reuse code between components when you aren’t sure how to solve the same problem with composition.

どうやらmixinはオブジェクト指向に慣れている開発者が慣れ親しんだ手法でcodeの再利用をおこなえるためのescape hatch的側面が強かったようです。

また

> This doesn’t mean that mixins themselves are bad. People successfully employ them in different languages and paradigms, including some functional languages.

とあるようにmixinsそのものが悪いといっているわけではないです。mixinsが壊れやすい理由としては以下が挙げられています。

* mixinsは暗黙的な依存を招く。stateのrenameしようとするときにmixinのlistから探さないといけなくなったりする等。またmixin間でも依存が起きる。

* mixinxは名前空間を共有している。`FluxListenerMixin`と`WindowSizeMixin`が`handleChange()`をそれぞれ定義していたらバグる。mixinsの開発者が新しいmethodを追加すると潜在的に現在そのmixinを利用しているコードベースを壊すおそれがある。

* mixinsの複雑性がsnowballする。mouseのhoverをtrackする`HoverMixin`がtooltipの表示を制御するための`TooltipMixin`に利用され、tooltipの方向を制御するために`getTooltipOptions()`が`TooltipMixin`に追加され、同時にtooltipを表示したいcomponentがhoverの判定にdelayを追加したくなったので`getHoverOptions()`を`TooltipMixin`に追加。この時点で`HoverMixin`と`TooltipMixin`はtightly coupledになっている。といった具体例が紹介されていました。確かにこれはつらそう。

公式ドキュメントにはコードの具体例も乗っているので、りあクトで言及されているmixinsのつらさがなんとなく実感できました。

#### HOC

Mixins Considered Harmful(https://reactjs.org/blog/2016/07/13/mixins-considered-harmful.html)でも代替案として提示されているのがHOCです。紹介されているgist(https://gist.github.com/sebmarkbage/ef0bf1f338a7182b6775)

```javascript
import { Component } from "React";

export var Enhance = ComposedComponent => class extends Component {
  constructor() {
    this.state = { data: null };
  }
  componentDidMount() {
    this.setState({ data: 'Hello' });
  }
  render() {
    return <ComposedComponent {...this.props} data={this.state.data} />;
  }
};
```

```javascript
import { Enhance } from "./Enhance";

class MyComponent {
  render() {
    if (!this.data) return <div>Waiting...</div>;
    return <div>{this.data}</div>;
  }
}

export default Enhance(MyComponent); // Enhanced component
```

　利用する側は、提供されているHOCで自身をwrapするとAPIとして提供されているpropsがもらえる前提でコードかけるみたいな理解でよいのでしょうか。


#### Render Props

　HOCの理解もままならない中さらに別の方法が登場。ただrender propsを利用したライブラリもあるとのことなのである程度わかっておかないとライブラリのAPIが読めなそうです。

```javascript
const MyComposent: FC<{providerArg: number?> = ({ providerArg }) => (
  <XXXProvider providerArg={providerArg}>
    {({ logic }) => (
      <div>
        {logic()}
      </div>
    )}
   </XXXProvider>
);
```
　かなりあやしいですが、要は書いたときになにがProviderを制御する値で、何がProviderからもらえるかわかりやすいという感じなのでしょうか。
りあクトであげられているUse a Render Props!(https://cdb.reacttraining.com/use-a-render-prop-50de598f11ce)も読んでみます。

> A render prop is a function prop that a component uses to know what to render.

　HOCのようにwrapするのではなく、利用する側のComponentでchildrenとしてrenderしたいComponentをProviderに渡す処理を書く感じでしょうか。
HOCにせよrender propsにせよ今はhooksを使うらしいのでやりたいことだけなんとなく抑えておけばいいのかなと思ってます。

#### Hooks

　りあクト本のすごいところは個人の開発者名がバンバンでてきて、ライブラリ等が発表されたときの当時のコミュニティーの反応やREADMEの引用がのっていて
開発のダイナミズミみたいなものが追体験できるところです。ということでHooksが最初に発表されたカンファレンスのyoutubeをみてみます。(https://www.youtube.com/watch?v=dpw9EHDh2bM)

##### React Today and Tomorrow and 90% Cleaner ReactWith Hooks

　Opening key noteでReactの3つのsucks(problem)として

* Reusing logic
* Giant components
* Confusing class

が挙げられていました。そしてこれらは独立した問題ではなく、simpler smaller lightweight primitive to add state or lifecycleをReactが提供していないという問題の現れとしています。そして、Class Componentで書かれたsample codeをhooksを利用して書き換えています。(23:51)ではじめてhookが言及。react featuresをcomponentにhookするようなニュアンスなんですね。


```javascript
import React, { useState, useEffect } from 'react';
import Row from './Row';
import { ThemeContext } from './context';

export default function Greeting(props) {
  const name = useFormInput('Mary');
  const theme = useContext(ThemeContext);
  useDocumenTitle(name.value)
  
  const [width, setWidth] = useState(window.innerWidth);
  useEffect(() => {
    const handleResize = () => setWidth(window.innerWidth);
    window.addEVentListener('resize', handleResize);
    return () => {
      window.removeEventListener('resize', handleResize);
    }   
  })
 
  function handleNameChange(e) {
    setName(e.target.value);
  }

  return (
    <section className={theme}>
      <Row label="Name">
        <input {...name} />
      </Row>
    </section>
  );
}

function useFormInput(initialValue) {
  const [value, setValue] = useState(initialValue);
  function handleNameChange(e) {
    setValue(e.target.value);
  }

  return {
    value,
    onChange: handleChange
  };
}

function useDocumenTitle(title) {
  useEffect(() => {
    document.title = title;
  });
}
```

いやー、class componentとくらべると本当にhooksはflatになりますね。useXXXで関心のあるstateとロジックをいい感じに閉じ込められているよに思えます。Facebookがproductionで試してから発表してくれているようで採用するにしてもかなり安心感ありそう。
　そして、最後はRyan Florence先生の`useReducer()`のデモコードの中で`useState()`が複数行になってきてstateの変更箇所が散ってきたら`useReducer()`使う感じなのでしょうか。hookをifの中で呼んではいけないことにひきつけて、`unconditionally`っていうのがおもしろポイントみたいなのでフロントの人と話すときに使っていきたいです。

##### Effect Hookとライフサイクルメソッドの相違点

　Function Componentにライフサイクルメソッドの機能を提供するために`useEffect`が用意されています。りあクトでは`useEffect`と`componentDidMount`と`componentDidUpdate`の違いを3つに分類して説明してくれています。(Ryan Florence先生のdemoではコメントで`cDM`と`cDU`と略されていました。)

* 実行されるタイミング
* propsとstateの値の即時性
* 凝集の単位

##### 実行されるタイミング

　`useEffect`が実行されるタイミングは必ず抑えておかないといけなそうです。コンポーネントが初期値でレンダリングされたあとに実行されるということなのでAPI callとか時間がかかる処理をいれてもよさそうです。`useLayoutEffect`というhookもあるらしいのですが、使用頻度はあまり高くないみたいです。フロントの方になにが違うか聞いてみたことがありますが、DOMの値(高さとか)を使ってなにかしたいときに利用したりすると教えてもらいました。

##### propsとstateの値の即時性

　どうやらクラスコンポーネントと関数コンポーネントではpropsとstateの変数に対するメンタルモデルが違いそうです。いまいちピンとこないで参考としてあげられているブログ記事"関数コンポーネントはクラスとどうちがうのか？"(https://overreacted.io/ja/how-are-function-components-different-from-classes/)を読んでみます。

###### 関数コンポーネントはクラスとどう違うのか?

```javascript
class ProfilePage extends React.Component {
  showMessage = () => {
    alert('Followed ' + this.props.user);
  };

  handleClick = () => {
    setTimeout(this.showMessage, 3000);
  };

  render() {
    return <button onClick={this.handleClick}>Follow</button>;
  }
}
```

```javascript
function ProfilePage(props) {
  const showMessage = () => {
    alert('Followed ' + props.user);
  };

  const handleClick = () => {
    setTimeout(showMessage, 3000);
  };

  return (
    <button onClick={handleClick}>Follow</button>
  );
}
```

　ボタンを押したらFollowしましたと表示するコンポーネント。この２つの挙動は一見同じにみえるが、クラスコンポーネントの方はボタン押してからprops.userが変わって再レンダリングされると変更後のuserが表示されてしまうというバグがあるということです。理由はpropsの更新前後で`this`が参照しているobjectがかわるからという理解でよいのでしょうか。バグを修正するには

```javascript
class ProfilePage extends React.Component {
  render() {
    // propsを捕獲しましょう!
    const props = this.props;

    // 注: ここは*render内部*です。
    // なのでこれらはクラスメソッドではありません。
    const showMessage = () => {
      alert('Followed ' + props.user);
    };

    const handleClick = () => {
      setTimeout(showMessage, 3000);
    };

    return <button onClick={handleClick}>Follow</button>;
  }
}
```

　のようにして、保持して起きた値をclosureで補足しておきます。関数コンポーネントはこの`render()`の中に全部書いたのと結局は同じという理解でよいのでしょうか。

##### 凝集の単位

　これはhooksのdemo動画(https://www.youtube.com/watch?v=dpw9EHDh2bM)でも強調されておりわりとピンと来ました。戻り値にクリーンアップ処理を返すという発想はいろいろなAPIでも利用されていると思うで参考にしていきたいです。

##### memo化

　プロダクトのコードみていると、`useMemo`,`useCallback`がよく利用されているのですがよくわかっておらず、ここにも言及してもらって本当に助かります。公式doc(https://reactjs.org/docs/hooks-reference.html#usecallback)によりますと
`useCallback(fn, deps) is equivalent to useMemo(() => fn, deps)` みたいです。reactのソースコードはまったくわかりませんが検索してみた感じこれでしょうか。

```typescript
export function useCallback<T>(
  callback: T,
  deps: Array<mixed> | void | null,
): T {
  return useMemo(() => callback, deps);
}
```
https://github.com/facebook/react/blob/ddd1faa1972b614dfbfae205f2aa4a6c0b39a759/packages/react-dom/src/server/ReactPartialRendererHooks.js#L447

##### useRef

　useRefについても当然わかっておらず、プロダクトコードではform系のコンポーネントに`useRef`のもどり値を渡していてなんでこんなことしてるんだろうと思ってました。関数コンポーネントはクラスとどう違うのか(https://overreacted.io/ja/how-are-function-components-different-from-classes/)

> クラスにおいては、this.propsもしくはthis.stateを読み取ることでそれができるでしょう。なぜならthis自体がミュータブルだからです。Reactがそれを書き換えます。関数コンポーネントにおいても、あらゆるコンポーネントのrenderに共有されるミュータブルな値を持つことが可能です。それは「ref」と呼ばれています

> refはインスタンスフィールドと同じ役割を持ちます。それはミュータブルで命令型の世界への脱出口です。「DOMのref」という考えに馴染みがあるかもしれませんが、そのコンセプトははるかに汎用的です。それは中に何かを入れるための単なる入れ物なのです。

とあります。これはつまり関数コンポーネントにinstance fieldの機能を提供するためのhookと考えてよいのでしょうか。


### 第10章 Reactにおけるルーティング

　きちんとSAPのルーティングの考えから解説してくれていてとても参考になります。SPAにおいてブラウザに表示されるURLはUIの状態の識別子みたいな位置づけになりますよね。DOMの書き換えであたかもページ遷移してるってように振る舞うだけではなく、ブラウザのセッション履歴まで同期させる必要があるのが学びでした。

　SPAになるとAPIへのリクエストとページ遷移の関係が複雑になるので、pageviewみたいな指標をとろうと思うとアクセスログから分析するのではなく専用の機能を使う必要もありますよね。このあたりは皆さんどうされてるんですかね。紹介されているreact-ga等を利用したGoogle Analytics一択なんでしょうか。個人的にはmetrics APIのようなものを建てるかendpoint切りたいですがビジネスのコアに集中みたいな文脈からみるとあまりそういうことはやらないほうがいい気もしていて悩ましいです。

#### React Router

　React RouterとReach Routerの関係についてかなり丁寧に解説いただいています。特にReact Routerのv3,v4,v5,v6の変遷についてはとてもありがたかったです。プロダクトコードではv5とv6が利用されており、API変更の背景がわかって納得感でました。自分が知らなすぎるということもあるかもしれませんがりあクトはこの章だけで買う価値があると思える章で構成されていてすごいです。React Routerの公式doc(https://reactrouter.com/web/guides/quick-start)を読む前に簡単な説明をいれてくれているのも滲みます。

　SPAではページ遷移(History APIの履歴更新)時のスクロールまで考慮にいれる必要あるんですね。
　素朴に思うのがReactでWeb Application作ろうと思ったら必ずRouting必要になると思うので公式で提供してくれてもよさそうに思いましたがこのあたりもサードパーティ製に委ねるのがJust The UIゆえなんでしょうか。


### 第11章 Reduxでグローバルな状態を扱う

　ついに出ましたRedux。もほやフロント以外のブログ記事でも時々Redux/Fluxの考え方やAPIが言及されていたりして避けては通れない存在。個人的に特にわかりにくい点は、今までComponentにはpropsを通して値を受け渡していましたが突然そのコードが消えて、HOCのmapStateToPropsを呼ぶだけになる点でした。
 
　参考にあげらているfacebookが[Fluxを発表した記事](https://www.infoq.com/jp/news/2014/05/facebook-mvc-flux/)の[MVCの画像](https://res.infoq.com/news/2014/05/facebook-mvc-flux/ja/resources/flux-react-mvc.png)はコントローラが肥大化しすぎなようにも思えましたが。

　状態の更新ってそのまま扱うと副作用になってしまうと思いますがこれをActionで表現して、reduce(Action,State) => Stateの形で表現するのはすごくいい考えですよね。バックエンドの更新処理も同じような枠組みで処理できるように書いてみたいものです。

#### Redux Style Guide

　React/Reduxを利用しようと思ったときデェレクトリ構成で手が止まりました。チュートリアル等でも結構ディレクトリ構成バラバラでこのあたりはチームやプロダクトの規模に応じて決めるものなのかなと思っていました。そんな中で、りあクトではFlux Standard ActionやDucksといったデザインパターンが紹介されていて、そのうちRedux Style Guide(https://redux.js.org/style-guide/style-guide/)は公式ガイドラインとあっては読まないわけにはいきません。ちなみに会社のプロダクトではducksならぬ[reducks](https://github.com/alexnm/re-ducks)を採用しているとのことでした。

> You are encouraged to follow these recommendations, but take the time to evaluate your own situation and decide if they fit your needs.

とあるように公式でもあくまで教条的にならないようにいっています。

　Priority AのEssentialなものとして以下があげられています。

* Do Not Mutate State
* Reducers Must Not Have Side Effects
* Do Not Put Non-Serializable Values in State or Actions
* Only One Redux Store Per App

　りあクトでReduxの背景から説明してもらっているので割と自然に思えます。Non-SerializableなvalueとしてSetsがあげられているのは、Serializeするたびに要素の順序がかわってしまったりするためなのでしょうか。  
　複数人で開発する場合チームにはいろいろな背景のメンバーがいるので、やってはいけないことリストを公式が提示してくれているのはそれだけで結構大きいと思います。最初にこれ読んでおいてと伝えられるものがあるとドキュメント等書かなくてもよくなるわけですし。  
　りあクトではPriority B/Cに関しては重要と思われるものに整理してくれています。Actionに関する項目を読んでみますと、プロダクトコードのActionまわりがどうしてこう書かれているかの背景がわかりました。
　

##### Evaluate Where Each Piece Of State Should Live

　ReduxのThree Principles Single source of truthで言われている

> The global state of your application is stored in an object tree within a single store.

は全ての値をRedux storeに入れればよいというわけではないと注意されています。"local"と考えられる値はComponentで保持すべきであると。なのでこの値はstoreで保持して、この値はComponentのstateで保持するみたいな判断は必要になるんですね。自分も最初にReduxを知ったときは、全ての値をstoreで保持するものだと思っていて、どうしてFormの値はReduxで管理せずにForm用のライブラリで管理しているのか質問したりしました。(Redux Formというライブラリがあることを知ってちょっとうれしくなりました。)

#### Redux Toolkit

　redux-toolkit(https://github.com/reduxjs/redux-toolkit)について具体例でかなりわかりやすく解説してくれています。ここまで丁寧にReduxの流れを追ってきているのでこんなに短く書けるのは感動です。ただもし自分がReduxについてまったく知らずにいきなりこのtoolkitから入るとかなり、actionがsimpleなjsのobjectでreducerがただの関数というReduxの良さがわからないかもしれないなとは思いました。　

#### Redux DevTools

　神ツールとはこういうツールをいうのかという感じでこれなしでの開発は考えられないくらいすごいツールだと思います。バックエンドもこういう風に開発したい。

#### useReducer

　useReducerに関してはReact Conf 2018(https://www.youtube.com/watch?v=dpw9EHDh2bM)のRyan Florence先生のdemoでuseStateと更新処理が複雑になっていったComponentをuseReducerでシンプルに書き直すのがすごくわかりやすかったです。

　useStateの実体はuseReducerのwrapで、Fiberとhooksの関係について説明が続くのですがここはまったくわかりませんでした。


### 第12章 Reactは非同期処理とどう戦ってきたか

　非同期のAPI Callをどう扱うかという文脈でreduxのmiddlewareが説明されており、redux-thunkがどういう位置づけなのか整理できたような気がします。redux-thunkは始めやすいが気をつけないとカオスになりがちというのは意識しておかないといけないですね。

　わりとこのあたりはバックエンド的にもどのAPIのendpointがどういったタイミングで叩かれるのかにかかわってくるので、理解しておきたいと思っていました。  
　redux-sagaについてはDSLやAPIの学習コスト高そうですが、副作用を別機構に切り出せる点は魅力的ですしaction creatorがシンプルなほうがRedux wayな気もします。あとは自分がSagaパターンに馴染みがないのですが、マイクロサービス関連の理解が進めばsaga推しになるかもしれと思いました。マイクロサービスの文脈とフロントの文脈が繋がるのはわくわくします。

　最後のマイクロフロントエンドという概念は未来すぎてついていけませんでした。中央集権から分散みたいな大きな流れで捉えると分散によっていく流れがフロントまで波及するというのは説得力あるように思えました。

(みんなReduxじゃなくてRedux Devtoolsが使いだけなんじゃ..?)

#### 公式が示したEffect Hookという道

　useEffectとreduxのuseSelector/useDispatchを組み合わせたデータの取得のサンプルコードがまさに直近のプロダクトコードで利用されている方法で、なるほどこれが現在のベストなのかーと思ったら既に次の本命がきていることが示唆されておりアキレスと亀のような気分になりました。

#### New Context APIの登場

　フロントの方々がContextでいくかReduxでいくかみたいな話をされていたのですがその背景がなんとなくわかりました。公式のコンポーネント間のデータ共有というのはなかなか魅力的なように思えます。


### 第13章 Suspenseでデータ取得の宣言的UIを実現する

　Suspense...?という状態。useEffectはまったくもって宣言的でないというのはそのとおりですよね、Custom HooksでuseXXXがあっても実装読まないと怖くて使えないなとは思います。

　Errorでなくとも任意のオブジェクトをthrowできるとはさすがjsと思ってしまいました。(ReduxのactionもthrowしておれおれRedux作れんじゃ...)

　GraphQLについてはまだプロダクトでは採用できていないのですが、いずれは利用する想定なのでライブラリの動向等が参考になります。


#### Suspenseの優位性とConcurrentモード

　恥ずかしながらWebパフォーマンスにこういった指標(https://web.dev/lighthouse-performance/)があることを知りませんでした。DevToolのリクエストの時間かサーバサイドのelapsedくらいしか気にしていませんでした。

#### Concurrent モード

　ほとんどついていけませんでした。これもあくまでDOM等のレンダリング環境とは独立した話なのでしょうか。まだ公式からstableが正式にでていない機能をここまで具体例豊富に解説してくれていてすごいです。きっともうすこし時間が経つとあの時点でここまで解説してくれていたりあクトすごい!と思える時がくるんじゃないでしょうか。


## おわりに

　実用性と読み物としての楽しさが両立しているとても素晴らしい本だと思うので、是非おすすめしたい本です。個人的にかなりうれしかったことはdeno(node runtime)やswc(typescript compiler)でRustが使われていることが知れたことです。

