+++
title = "🦈 AWS CDK Conference Japan 2022の感想"
slug = "aws_cdk_conference_japn_2022"
date = "2022-05-22"
draft = false
[taxonomies]
tags = ["event"]
+++

{{ figure(images=["images/aws_cdk_conference_japan_2022.png"]) }}

2022/4/9に行われた[AWS CDK Conference Japan 2022の動画](https://www.youtube.com/watch?v=O2JXUyOBjt8)を見たので感想を書きます。


## [Keynote: What is CDK v2?](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=2693s)

Speaker[^speaker] : 亀田治伸 (アマゾンウェブサービスジャパン) さん


### CDK v1とv2の主な違い

CDK v1
```json
"dependencies": {
  "@aws-cdk/core": "1.127.0",
  "@aws-cdk/aws-apigateway": "1.127.0",
  "@aws-cdk/aws-autoscaling": "1.127.0",
  "@aws-cdk/aws-dynamodb": "1.127.0",
  "@aws-cdk/aws-cloudwatch": "1.127.0",
  "@aws-cdk/aws-cloudwatch-actions": "1.127.0",
  "@aws-cdk/aws-eks": "1.127.0",
  "@aws-cdk/aws-events": "1.127.0",
  "@aws-cdk/aws-events-targets": "1.127.0",
  "@aws-cdk/aws-ec2": "1.127.0",
  "@aws-cdk/aws-ecs": "1.127.0",
  "@aws-cdk/aws-iot": "1.127.0",
}
```

```js
import { App, Stack } from "@aws-cdk/core";
import * as s3 from "@aws-cdk/aws-s3";
```

* 各AWS Serviceごとにlibraryとして独立している。
* 各libraryがそれぞれ依存関係を持つもので、あるlibraryの更新に破壊的変更があると苦労する場面があった
* 非安定板(alpha,beta版)も含まれる場合がある

CDK v2

```json
"dependencies": {
  "aws-cdk-lib": "2.0.0",
  "constructs": "^10.0.0",
  "@aws-cdk/aws-iot-alpha": "2.0.0-alpha.0" 
}
```

```js
import { App, Stack } from "aws-cdk-lib";
import * as s3 from "aws-cdk-lib/aws-s3";
```

* 安定板が`aws-cdk-lib`に集約された
  * 全てのserviceがサポートされている訳ではない(app runner, kinesis data firehose,...)
* 安定板でないものは`aws-cdk/aws-iot-alpha`のように別libraryになっている

ネット上のCDKに関する記事等でv1について書かれているものも多かったので最初にCDKについて調べた時戸惑いました。`@aws-cdk/xxx`はv1のlibで`@aws-cdk/xxx-alpha`はv2のlibのところがわかりづらかったです。

### Deployまでの流れ

```sh
cdk init
cdk synth
cdk diff
cdk deploy
```


### パラメータに関するCloudformationとの差異


* Cloudformationにはparameterを持たせることができる。stack作成の際に入力が必要
  * 一つのtemplateから複数のstackを生成できる
* CDKはtemplate作成段階でparameterを処理する
  * 1stack 1template

CDKを運用するに当たって、StackやAppでどこまで変数化して作るかについてまだいまいち基準を設けられていないです。


### Construct Levels

Construct L3+,L2,L1の区別について

* L3+: 複数のリソースを操作する。L2からの派生。ECS with ALB等。
* L2: 標準。Cfnの全てのパラメータは操作できない
* L1: Cfnパラメータと1:1マッピング

基本(最初)はL2から利用する。L2が提供するAPIでは要件を満たせない場合はL1を使う。  
L1を利用するとCDKの利点である高い抽象度でのリソース操作が犠牲になるので、まずはL2を使う。  
L3は複数のL2リソースの再利用の単位。


## [3年目のCDKを振り返って](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=5151s)

Speaker: 吉川幸弘 さん

### 初学者にCDKをオススメする理由

* Cloudformationに比べてdocが親切

個人的にはProductionで運用するに当たってAWSリソースの設定できるpropertyは全て理解したいと考えているので、CDKのdocだけでは完結しない印象を持っております。  

* 静的型チェックが効くこと

yaml/jsonでは許容されない値や存在しないproperty,誤ったデータ型も書けてしまう。  

これは本当にその通りだと思います。enumとか本当にありがたいです。  
ただし、全てチェックできる訳ではないのでどうしてもStack作成が失敗するケースには何度か遭遇しました。
L2が提供されていないApp Runnerを定義する際にL1 constructだとほとんどstring型で定義されて恩恵が十分に受けられないこともありました。

* editorのサポートが受けられる

plugin利用すれば何かしらの支援は受けられますが、やはりtypescriptになっていることによる恩恵は多いと思います。formatやlint等ecosystemもそのまま利用できますし。

### これまでの運用における成功と失敗

* プロジェクトに関わるリソースを可能な限りCDKで管理したこと

Excelによる管理を避けられたことがプロジェクトとメンバーを守ることに繋がったと表現されておりとても共感しました。

* スキルアップできる環境づくり

CDKが複数言語で記述できる点が利点に。  
実際チームでCDK運用するに当たって、どの範囲まで言語一致させるかは考えたことがなかったです。  
moduleのecosystemをそのまま利用できるのがCDKの最大のメリットの一つだと考えているので、これを生かすにはできるだけ言語が統一されているのが望ましいのではとは思っております。

* 初期にスナップショットテストを入れていなかったこと

CDKのversion upに伴い、defaultの値が変わったことで影響を受けた。  
この辺りはいい感じにdefault値設定してくれることのデメリットなんでしょうか。  
個人的には全property明示的に宣言したい派。


## [CDKでデプロイ先を量産したり環境ごとの差をどうにか埋めたりした話](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=6859s)

Speaker: 稲葉太一(inbaa) さん

### 本番もステージングも作りたい

* `--context`で値を渡せる

cdk.json
```json
{
    "context": {
        "production": {
            "fqdn": "hoge.example.com"
        },
        "staging": {
            "fqdn": "stg.hoge.example.dev"
        }
    }
}
```

```sh
npx cdk deploy --all --context stage=staging
```

```typescript
const stage = app.node.tryGetContext('stage') // staging
const context = app.node.tryGetContext(stage) // {fqdn: "stg.hoge.example.dev"}
```

のようにして環境ごとに異なる設定値を実行時に渡せるようにされていました。  
これは非常に参考になります。  
さらに発表では環境ごとの差分を扱う`Context`classを定義した例に触れられており真似してみようと思いました。

## [CDKのコードの読み方とコントリビューション](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=9212s)

Speaker: 山本達也(Classmethod) さん

aws-iotのL2 Constructを実装されたお話。

### CDKの予備知識

* CDKはtypescriptのコードから[jsii](https://github.com/aws/jsii)で他言語とDocを生成している
* L1はCloudformationの定義から生成している

### CDKのコードの中

概要としてはL2はL1をwrapする実装になっている。

### コントリビュートに向けて

* Unit Testを書く
* Integ Testを書く
* READMEを書く
* PRを作る
* CIを通す

詳細はブログに書かれてるとのことでした。(ブログ見つけられておらず)

### CDKの並列Deployサポート

* `cdk deploy`にconcurrent deploymentがサポートされる(かも)

### Terraformのような既存リソースのimport

* `cdk import`がmergeされた

## [AWS CDKを利用して、Next.js/Stripeで構築したフルスタックSaaSアプリケーションをデプロイ・管理する](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=10685s)

Speaker: 岡本秀高(Stripe) さん

Next.jsについては自分が[tutorial](https://nextjs.org/learn/foundations/about-nextjs)しかやったことがなく理解できていないので割愛。  
AmplifyでIAMの設定がつらいという話は共感しました。

## [Baseline Environment on AWS (BLEA) 開発にあたって検討したこと](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=12400s)

Speaker: 大村幸敬(AWS) さん

[BLEA](https://github.com/aws-samples/baseline-environment-on-aws)でブレアと読むらしいです。  
[README_ja](https://github.com/aws-samples/baseline-environment-on-aws/blob/main/README_ja.md)によりますと

> Baseline Environment on AWS(BLEA) は 単独の AWS アカウントまたは ControlTower で管理されたマルチアカウント環境で、セキュアなベースラインを確立するための リファレンス CDK テンプレート群です。

[usecases](https://github.com/aws-samples/baseline-environment-on-aws/tree/main/usecases/)を見てみますと、CDKのサンプル実装が載っておりました。
問題意識として、長期運用を見据えた引き継ぎのしやすさ、ブラックボックスにしない点を重視されているそうです。自分は開発と運用に携わることが多いので、運用者目線なのは大変ありがたいです。

typescriptやjsのecosystem(npm,lint)に馴染みのない方にも触れてもらうために開発環境をまずはVSCodeに絞ってサポートしているそうです。BLEAについてはあらためてブログ書こうと思います。

### cdk deploy の認証情報を持ちたくない

localで`cdk deploy`を実行する場合にlocalにdeployに必要な権限を持つAWS Credentialが必要になるが、これを避けるにはAWS SSOを利用できるというお話。

設定方法は
1. `~/.aws/config`にssoログイン用プロファイルを設定
2. `aws sso login`コマンドを実行して認証
3. cdkコマンドを実行

aws ssoコマンドを初めて知りました、この機能はcdkに限らずとても重要な機能だと思いました。  
開発用のマシンにaws credentialを持たなくてよくなるのは嬉しいです。


### パラメータを切り替えて使うには

prod/stagingといった環境の切り替え方法について、BLEAでの解決策。

1. `cdk.json`のcontextに設定値グループを保持
```json
{
  "context": {
    "dev": {
      "key1": "value1"
    },
    "prod": {
      "key1": "value1"
    }
  }
}
```
2. `--context`optionでグループを指定  
  `cdk deploy --context environment=prod`
3. CDKコードでパラメータを取得して利用

```typescript
const envKey = app.node.tryGetContext('environment');
const valArray = app.node.tryGetContext(envKey);
const value1 = valArray['key1'];
```

この方法がシンプルでわかりやすいと思うので自分のこの方法にならっていこうかと思います。

#### パラメータ挿入: BLEAでの考え方

* Cloudformationのparametersは使わないことが推奨。CDKのcontextと環境変数を利用する
* 環境変数はprofileで指定したアカウントとリージョンの取得に使う
* context(cdk.json)にdeploy先を限定したい場合環境(aws account idとregion)を設定しておく
  * 指定がない場合は環境変数を利用
  * `--profile`で渡されたaccountとregionと一致しない場合はエラーにする
```json
{
  "context": {
    "stage": {
      "env": {
        "account": "111111111111",
        "region": "ap-northeast-1"
      }
    }
  }
}
```

### パラメータについてあれこれ

* そもそもインフラを定義するコードには複雑な条件分岐がない方が良いのでは
  * 開発環境の通知はしない等
* 環境差分をパラメータで表現するのではなく環境ごとにStackを定義する方法もありうる
  * 複雑度私大なところがあるがdiffで管理する方法もあり
* public repoで管理する場合、`.gitignore`したい情報(社内のIPとか)をどう管理するか。BLEAで直面。
  * ベストプラクティスからは逸脱するが、`cdk.context.json`をignoreして手元で管理する方法を取っていた。
  * 他の選択肢としては、`${HOME}/.cdk.json`, SSM ParameterStore,S3,...
  * これが良いという答えはまだない
* そもそもcontext使うか
  * jsonなのでそのままでは型チェックができない
  * CDKのdefault libraryとしては提供されていないので独自で実装するしかない

CDKでパラメータと環境差分をどう管理するかは自分も悩んでおりました。この辺りはある程度おすすめの方法は確立されつつも、自分達のチームにあう形を選ぶ必要があるということがわかりました。(なんでもそうですが)

### パイプラインをどうデザインするか

* CDK Pipelineの実装例を公開している
* とりうる選択肢が多いので決定版が出にくい
  * Stackのどんなテストをどこで行うか
  * Ownerは誰か。運用チームがいるか、チームがどこまで管理するか。
  * `cdk deploy`をどこで実行するか
    * local, CI(Github Actions), pipeline account, target account
  * CI(`npm run test`)をどこで実行するのか

この辺りは皆様がどういった方法でやられているのか是非知りたいです。


### 複数のCDKプロジェクトをどう管理するか

* 多くのCDK toolkitはroot直下に1 projectがあることを想定している
* BLEAではusecase directoryを切って、複数projectを管理している
* BLEAではパッケージ管理はnpm workspacesを利用
* アプリコードとインフラコードをどう分離するかという話もあるが、今回は割愛。

今回は触れられていないのですが、アプリコードとインフラコードをどう分離するかはまさに悩んだ点でした。CDKのドキュメントの書きぶりではappとinfraを同じように管理できることがメリットとして説明されていたと思うのですが、CIのトリガーやら権限管理の観点からリポジトリ分けたりしていました。


### その他の検討

* SecurityGroup,IAM Policyの循環参照
* snapshot test以外に何をテストするか
* ALBが勝手にSGを管理するのをやめさせたい
* Route53とACMはCDKで管理した方がいいのか
* CloudFrontとWAFはus-east-1で設定しないと

全部気になる話題でCDK運用の旅ははじまったばかり感。


実装見てみて参考にしたいと思います。

## [AWS CDK と AWS SAM 実は仲良し！一緒にローカルで開発しませんか](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=14895s)

Speaker: 藤原麻希(ゆめみ) さん

### SAM

* cdk synthで生成されたCloudformationのyamlをSAMから読める。

SAM使ったことなく、使う予定もない今のところないです。CDKができた今使われなくなるのではと思ったりしました。  
個人的にはlambdaのtestはlambdaのレイヤーをできるだけ薄くして、普通のアプリケーションと同じunit/integration test書きたい派です。

## [それでも俺はAWS CDKが作るリソースに物理名を付けたい〜CDKのベストプラクティスは本当にベストなのか〜](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=16000s)

Speaker: 佐藤智樹(Classmethod) さん

### 問題提起: AWS CDKのベストプラクティスではリソースの自動名付けが推奨されてますけど、自動名付けのリソース辛くないですか??

これは最初にCDK触った時に思いました! が、IaCでリソース管理するとそういうものかと思ってました。(ベストプラクティスであっても疑う姿勢に欠けておりました..)

ソフトウェアアーキテクチャの基礎より

> アーキテクトには過去の時代から残されている前提や公理を疑うという重要な責任がある

という引用が紹介されておりました。ソフトウェアアーキテクチャの基礎はまだ読めていないのですが、MUST READな本のようなので読みたいです。

### AWS CDKのベストプラクティスとは

[Best practices for developing cloud applications with AWS CDK](https://aws.amazon.com/blogs/devops/best-practices-for-developing-cloud-applications-with-aws-cdk/)というCDKのベストプラクティスについて書かれた公式のblogがある。


### 自動で生成されるリソース名を使用し、物理的な名前を使用しない

* 物理名を使う場合のデメリット
  * インフラの一部を複数デプロイすることができない
    * -> 命名規則は実装に依存する、似ている名前のリソースが複数ある場合関連がわからず逆に不便では
    * -> リソース名の衝突は命名規則で回避可能
    * -> Stack名が違ってもConstructのidが同じだと重複するリソースが一部存在する
  * リソースに破壊的変更が伴う場合、再作成に失敗する
    * -> 危険性に気づけて失敗した方が良いのでは
  * `RemovalPolicy.RETAIN`を指定した場合、スタック削除後の再デプロイで失敗する
  
* 再デプロイ時に前回実行したリソース名が重複しない
  -> 以前のリソースが残るのでこまめに削除しないと大量のリソースが残り、どれがみたいものか、削除して良いものかが分かりづらくなる

* 自動名付けで生成されたリソースはhash値を含むのでサブリソースまで含めると認知的負荷が高い。(調査が大変)

リソースにhash値が含まれたリソースが複数あると認知的負荷が高いのは自分も経験がありました。hash値の最初と最後の数文字だけ覚えて頑張るみたいな感じになってました。

### 結局リソース名はどうすべきか

* 開発/調査/運用などでよく確認するリソース名は固定する
  * ECS,Lambdaなどのコンピューティングサービス
  * DynamoDBやS3などのストレージ
  * ダッシュボード名やアラート名
* 上記以外のサービスはできるだけ固定しない


## [CDKファンに捧ぐ! CDK for Terraformという選択肢](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=17464s)

Speaker: 草間一人 @jacopen (Hashicorp) さん

自分は最初にCDKを知った時にTerraformでいいのではと思っておりました。  
Mitchell hashimoto先生のコードでGoを勉強したのでHashicorp自体好きでした。  
CDKいいかもと思った理由としては

* テストが書ける
* HCLでもloopやifの制御、listやhash(dict)といったデータ構造を使うところが増えてきてyaml以上、プログラミング未満の表現力に若干疑問を持っていた

### Cloud Development Kit for Terraform

略してCDKTF。CDKの成果物をTerraformが利用できるjsonに変換する。

```sh
cdktf init --template=typescript --local
cdktf deploy
cdktf destroy
```
のようにCDKを書きつつ、適用をterraformで実行することができる。  
`cdktf init`の`--local`を省略すると、terraform cloudと連携してlocalにstateファイルを持たなくても良くなることもできるそうです。

また、内部的には`cdktf.out/stacks/{stack}/cdk.tf.json`が生成されておりこのファイルから直接terraformを実行することもできるそうです。terraform cloud上のstateも更新されます。

terraform cloudを初めて知ったのですが、CDもできそうで試してみたくなりました。  
cdktfだとgcpのリソースも同じ書き方ができるのもすごいです。  

### HCL or CDK ?

* HCL自体がそれなりの柔軟性と表現力を持つため、YAML->CDKと比べるとHCK->CDKには劇的なメリットはないかも
* terraformのmoduleとしてパーツ化するか、Constructsでパーツ化するか悩ましい
* CDKで自在な表現力を得るか、HCLの適度な制限の中で書いて品質を保つか

この点に関してはメンバーや組織構成に依るところが多いと思うので一概にはいえませんが、CDK(typescript)で書く派です。そもそもts読めないとフロントのコード読めないので、web開発に関わっている自分はCDKができたことでtsは必修と考えるようになりました。  
他のspeakerの方もおっしゃられていましたが、CDKにおいては高度な型定義は使わずに愚直にリソース宣言を上から書いていくようなコードになると思うので特に問題ないと思っています。

[Mozillaのプロジェクトで本番利用された話](https://www.hashicorp.com/blog/cdk-for-terraform-in-production-learning-from-pocket)の紹介もありました。

## [AWS Solutions Constructsで楽してシステム作りたいよ〜！](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=19302s)

Speaker: 渡邉洋平(NTTテクノクロス) さん

### AWS Solutions Constructsとは

https://docs.aws.amazon.com/solutions/latest/constructs/welcome.html  

> AWS Solutions Constructs (Constructs) is an open-source extension of the AWS Cloud Development Kit (CDK) that provides multi-service, well-architected patterns for quickly defining solutions in code to create predictable and repeatable infrastructure.

ということで、L3 Constructsに対応するものとのことです。(v2にも対応)  
発表時点では54個のConstructが提供されており、サーバレス構成の頻出パターンのサポートが厚いそうです。  
`@aws-solutions-constructs`はv1のようにserviceごとにmoduleが別れていました。まだ、`aws-cdk-lib`のlatestとはversionが違います。

CDKがL1,L2と抽象化してくれているのでより抽象度の高いL3ライブライ使ってこそメリットを最大限享受できると学べました。

### テスト

solutions constructsで生成したリソースのテストについて。  
方針としては、時間の関係で`@aws-cdk/assertions`は使わずに生成したCloudformation templateの設定値を確認する。

テスト用Toolとしては
* Security Hub Standard
  * 最も活発なFSDBを利用
* OSS(Linter)

## [全AWSアカウント×全CDKアプリで LegacyテンプレートをMigrationした話](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=20789s)

Speaker: 大越雄太／小笠原寛明(justInCase Technologies) さん

なんとjustInCaseさんでは、2019/6にすでにcdk v0.33をKotlinから動かされていたそうです。  
KotlinでCDKを書くためにAWS-CDK-Kotlin-DSLを独自開発されたのはすごいです。

v1からv2への移行においてcdk bootstrapにまつわるtemplateの影響でdeployが失敗するようになってしまった事例について。この辺りはわかっていなかったのですが今のチームではv1->v2への移行を行っているので参考になります。  
[CDK BootstrapのMdern templateで何が変わるのか](https://dev.classmethod.jp/articles/cdk-bootstrap-modern-template/)を読んでみようと思っております。

[justInCaseさんの技術ブログ](https://team-blog-hub.justincase-tech.com/)

## [アンチCDKだったわたしが「CDK、できる・・」と思ったところ](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=21915s)

Speaker: 岡智也(Accenture) さん

歳をとると新しいものに対して否定的になりがちということからお話しされておりました。  

> は? CDK? CFnとTerraformあるし

これなんかは自分も全く同じ感想でした。あとAWSとGCPの管理が異なる技術スタックになることもネガティブ要因でした。
[AWS Cookbook](https://www.oreilly.com/library/view/aws-cookbook/9781492092599/)は知らなかったのでぜひ読んでみようと思いました。著者はAWSの中の人だそうです!

## [AWS Outposts 上のリソースを CDK する](https://www.youtube.com/watch?v=O2JXUyOBjt8&t=23293s)

Speaker: 福田優真(NTT Communications イノベーションセンター) さん

### AWS Outpostsとは

AWS Outpostsとは、AWSの出すハイブリッドクラウド製品。  
ハイブリッドクラウドとは

* オンプレミスにクラウドサービスを導入するためのソリューション
* Azure/GCP/AWS 各社が展開中
  * Azure Stack Hub/HCI
  * GCP Anthos/Distributed Cloud
* データをPublicな場所に流さなくてもクラウドサービスを利用できるようになる

ユースケースとしては

* 低レイテンシーなコンピューティング
* ローカルなデータ処理
* データレジデンしー
* オンプレミス環境のモダナイズ

AWS Outposts上のリソースをCDKで管理されたお話しでした。AWSとオンプレ環境をどう管理していくかは興味があるところなので試してみたいと思いました。

### カスタムリソース

* Cloudformationが対応していないリソースを管理する仕組み
* 作成/更新/削除のライフサイクルをLambdaで管理
* CDKでやる場合はprovider frameworkというAWSが提供するフレームワークに則ってLambdaを用意するだけ　

Outpostsで対応できない処理はカスタムリソースを駆使して対応されたそうです。

## まとめ

* BLEAやcdktfを知れてよかった
* 問題意識は結構皆さん同じなんだなと思った
* AWS Cookbookを読む

[^speaker]: speakerの表記はyoutubeのdescriptionに準拠しています。

