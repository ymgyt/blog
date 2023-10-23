+++
title = "📗 Terraform: Up and Runningを読んだ感想"
slug = "terraform-up-and-running"
description = "Terraform: Up and Runningを読んだ感想について"
date = "2023-10-22"
draft = true
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/green_book.png"
+++

## 読んだ本

{{ figure(images=["images/terraform-book.jpeg"]) }}

[Terraform: Up and Running, 3rd Edition](https://learning.oreilly.com/library/view/terraform-up-and/9781098116736/)

会社の方が紹介されていて、おもしろそうだったので読んでみました。  
出版日は2022年9月で、第3版を読みました。


## Chapter 1 Why Terraform

Terraformの使い方の話の前にDevOpsやInfrastructure as Codeといった概念や背景の説明がなされます。

最初の書き出しの  

> Software isn’t done when the code is working on your computer. It’s not done when the tests pass. And it’s not done when someone gives you a “ship it” on a code review. Software isn’t done until you deliver it to the user.

がほんとそうですよねえと思いました。Software isn't done until you deliver it to the userはsoftwareはユーザに届けられて初めて価値をもつというニュアンスだと思うのですが翻訳でどう訳されるのか気になります。

### What is DevOps

DevOpsとは。  
devとopsにteamを分けて、opsがhardwareを管理する責務を追っていたけど、今はcloud使うので、opsもsoftware tool(kubernetes, terraform, docker, chef, ...)を使っているよね。devとopsを分けてはいるけど、より緊密な連携が必要になってきている。という話の流れと理解しました。  
自分が英語の本が好きな理由の一つに最初にはっきり定義書いてくれるというのがあります。  
What is DevOpsというパラグラフなので、DevOps is ...という定義を期待したのですが、歯切れが悪いように思いました。  
自分の理解としては、DevOpsがどうであれ、要はreleaseが高頻度で安定していればいるほど、よいのでそこがぶれなければなんでも良いのかなと思っています。

### What is Infrastrucutre as Code?

Terraform以外の色々なtoolの概要が紹介されます。  
NixOSもIaCだと思うのでそのうちここに含まれてほしいです。

### What Are the Benefits of Infrastructure as Code?

IaCのメリットはなんだと思いますか。再現性、version管理との親和性、CIでの自動化、... それだけではないです。

**Happiness**です。

TerraformやCDKを書いて、ちゃんと動いたときに感じるあの気持ちはHappinessだったのです。


### How Does Terraform Compare to Other Iac Tools?

Terraformと他のtoolとの比較が行なわれます。  
自分の場合は、CDKとTerraformで迷うことが多いのですが、CDKについては直接の言及がなかったです。  
もっとも、General-Purpose LanguageとDSLという観点での比較はなされていたので、この話は妥当しそうです。  
ただ、DSLが良いかどうかって、チームや会社の技術スタックに左右される部分が大きいと思うので、一概にDSLのほうが良い悪いって判断できないと思ってしまうんですよね。  

自分がInfra関連の技術選定で、各種toolの比較することになったとしてもここまでの比較はできないので、比較の観点の出し方がとても参考になりました。

~~terraform既に使っていてもっと知りたいという場合は思い切って1章は飛ばしてもいいかも~~


## Chapter 2 Getting Started with Terraform

本章からterraformの使い方についての説明が始まります。  
AWSでEC2建てるところから解説してくれます。  
terraformを使ったことがあればわかっていることかなと思っていたら`terraform graph`でdotlang出力できるの知りませんでした。  
systemdもそうですが、依存関係のようなgraphを扱うtoolはdotlang出力するのが共通理解なんでしょうか。  

またどこかでははまる、lifecycleの`create_before_destroy`の説明等もあります。


## Chapter 3 How to Manage Terraform State

terraformのstate管理について。  
stateにどういった情報が保持されているかや複数人での共有に対処するためにremote backendが紹介されます。  

stateをS3に置くためにs3 bucketを定義したいがそのためにはs3以外のところにstateを保持する必要がある問題についての対応も解説してくれています。  
自分は最初にlocal stateではじめてbucket定義したのち`terraform init -migrate-state`を実行したりしていました。  
また、backendのconfigを`terraform init -backend-config=backend.hcl`のようにして別fileに切り出せるのは知らなかったです。

### State File Isolation

Remote backendの導入でstate fileを共有できるようにはなったものの、そのままではproductionと開発環境の設定が同一のstate fileに保持されてしまっている。  
現実ではどうしてもproductionの設定を分離したくなり、そのための方法の一つとしてworkspaceが紹介されます。  
state fileの分離という文脈でworkspaceを説明するのはわかりやすいと思いました。 

もっともworkspaceによる分離は分離の程度としては弱く、より強い分離としてdirectoryを分ける方法が提案されます。  
概要としては以下のように環境とcomponentごとにterraform projectのdirectoryを切るというものです。  

```text
.
├── production
│  ├── services
│  │  ├── dependencies.tf
│  │  ├── main.tf
│  │  ├── outputs.tf
│  │  ├── providers.tf
│  │  └── variables.tf
│  ├── storage
│  └── vpc
└── staging
   ├── services
   ├── storage
   └── vpc
```

ただ、この方法ですとdirectoryをまたいだ依存を参照できないので、`terraform_remote_state`を使うことになります。

ここで紹介されていた`terraform console`でREPLできるの知りませんでした。


## Chapter 4 How to Create Reusable Infrastructure with Terraform Modules

前章で環境ごとにdirectoryを分けたので、微妙に違うが大体同じような設定を書かなければならなくなってしまった。  
そこで、moduleを導入して、共通部分と環境ごとの差異を分離できるようにしていく。  
moduleの作り方を実際にrefactorしながら解説してくれておりわかりやすいです。  

moduleのはまりどころとして、相対pathの解決やinline blockでリソースを定義する点についての説明もあり、参考になりました。  

また、stagingとproductionでmoduleを参照している際にstagingのためにmoduleを変更するとproductionにも影響してしまう。そこで、moduleを別のgit repositoryに定義して、tagでversioningする方法も説明してくれています。


## Chapter 5 Terraform Tips and Tricks: Loops, If-Statements, Deployment, and Gotchas

まずcountを紹介して、その欠点を補うためにfor_eachという流れで解説してくれます。  
for expressionの解説もあります。具体例が豊富で親切です。

またrescourceの作成をconditionalにしたり参照するparameterを切り替える例も解説されています。  
基本的に複数resourceの作成ではcountよりfor_eachが望ましいですが、作る作らないの制御ではcountでおこなうとsimpleにできると助言されていました。

### Terraform Gotchas

terraformのはまりどころについて。  
`terraform plan`は成功したけど、`terraform apply`したらalready existsで失敗した場合の対処法等については誰もが一度は経験するところなのではないでしょうか。  

terraformをrefactorする際にresourceの識別をrenameするのは影響が大きい。hcl側とstateの対応を更新したい場合は、`terraform state mv`が利用できるが、それに加えて下記のように`moved` block使うこともできる。

```hcl
moved {
  from = aws_security_group.instance
  to   = aws_security_group.cluster_instance
}
```

## Chapter 6 managing Secrets with Terraform

secret managementにおいて重要なruleが2つあって、ひとつがplain textで保持しないこと。もう一つもとても参考になります。  
最初にterraformでsecretが必要になるのが、providerの認証で、その際にどんな方法があるかを解説してくれます。  
さらに、CIからterraformを実行する例の具体例もあり、Circle CI, EC2, Github Actionのそのまま使えそうなコードも載っています。  
Github ActionはOIDCを利用してくれており、github action側にcredentialを保持しなくてよい構成になっています。

Providerの次はresourceにどうやってsecretを渡すかについて。  
```hcl
resource "aws_db_instance" "example" {
  // ...
  username = "???"
  password = "???"
}
```

最初は`var.db_username`のように変数にしたのち、環境変数経由で渡すことが考えられます。  
ただ、環境変数経由での管理にも良い点と問題点があります。  
その一つとして、version管理やterraform管理からはずれるのできちんと渡すのは呼び出し側の責任になり、ミスが介在しやすくなってしまう点にあると思います。  

そこで次にkmsで暗号化した上でsecretをterraformのresourceとして扱う方法が紹介されます。  
これでsecretをplain textで保持することを避けつつ、terraformの管理化で扱えるようになります。  

が、当然この方法にもいくつか問題があります。  
例えば、auditであったり、rotationやrevokeさせづらい等です。

ということで、AWS Secret ManagerやHashiCorp Vaultが紹介されます。

### State Files and Plan Files

どうにかしてsecretをplain textでなくしてもterraformに渡したsecretはstate fileではplain textで保持されてしまうそうです。[Storing sensitive vaules in state files](https://github.com/hashicorp/terraform/issues/516)  
したがって、secret管理とは別に、state fileのaccess管理や暗号化は必須ということになります。  
また、`terraform plan -out=plan`とした際にもplan fileにsecretが含まれてしまうので注意が必要です。

## Chapter 7 Working with Multiple Providers

本章では、これまでに作成したmoduleをAWSを例に、multi region, multi accountにdeployするにはどうするかについて説明してくれます。  

まずproviderの概要の説明があるのですが、terraformとproviderはRPCでやり取りしているそうです。そうなると、Ruseでprovider書けるのかなと思っていたら、[helloworldをRustで実装された方](https://github.com/palfrey/terraform-provider-helloworld)がおられました。

ひとつのmoduleの中で複数のAWS regionにresourceを定義したい場合にどのように複数providerを設定するかについての解説があります。