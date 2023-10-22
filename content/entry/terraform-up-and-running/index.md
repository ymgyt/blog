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
systemdもそうですが、依存関係のようなgraphを扱うtoolはdotlang出力するのが共通理解なんですかね?
