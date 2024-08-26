+++
title = "🌸 Kubernetes Upstream Training Japanに参加してきました"
slug = "kubernetes-upstream-traning-japan-2024-08"
description = "イベントの感想など"
date = "2024-08-26"
draft = false
[taxonomies]
tags = ["event"]
[extra]
image = "images/emoji/sakura.png"
+++

Cloud Native Community Japan(CNCJ)が主催している[Kubernetes Upstream Traning Japan](https://community.cncf.io/events/details/cncf-cloud-native-community-japan-presents-cncj-kubernetes-upstream-training-japan-2024-08/)というオンライン上のイベントに参加してきたので、その感想について書きます。

Zoom上で実施され、[事前に練習用のrepositoryのforkやslackに参加](https://github.com/kubernetes-sigs/contributor-playground/blob/master/japan/assets/attendee-prerequisites.md)したうえでのぞみました。


## Kubernetes コミュニティ

`Distribution is better than centralization`といった、[Kubernetes Community Values](https://github.com/kubernetes/community/blob/master/values.md#kubernetes-community-values)が紹介されました。  
Kubernetes系のrepositoryのPRはコメントで`/<command>`を参加者が実行して、botが処理を進めていく印象がありましたが、これは[`Automation over process`](https://github.com/kubernetes/community/blob/master/values.md#automation-over-process)の現れであることがわかりました。

次にcommunityは具体的にはSpecial Interest Groups(SIGs)やWorking Groups(WGs)といったgroupで構成されている旨の解説がありました。SIGとWGの違いは、WGがSIGを横断して特定の問題に取り組む一時的なgroupである一方、SIGは永続的な点ということがわかりました。

SIGのlistは[`kubernetes/community` repository](https://github.com/kubernetes/community/blob/master/sig-list.md)で管理されていました。

[スライド](https://github.com/kubernetes-sigs/contributor-playground/blob/master/japan/assets/slide.pdf)のgroupの概要図がわかりやすかったです。  

{{ figure(caption="Community Groups Overview", images=["images/group_overview.png"] )}}

Kubernetesの開発に参加するには、まず自分の興味にあった、SIGを見つけるところからはじまるということがわかりました。各SIGの概要であったり、見つけ方の話はとても参考になりました。

特定のSIGについて知りたい場合は、[KubeConのVideo](https://www.youtube.com/c/cloudnativefdn)をみてみるのが良いそうです。

## コントリビューション実践

Kubernetesに限らず、OSS一般にcontributionする際にどういった態度が期待されているかや、どういったLabelでissueやPRが運用されているかといった解説でした。  
自動でassigneされた、reviewerにreviewしてもらうだけでなくて、時には自分でapproverを探して、働きかける必要があるといった話もありました。   

{{ figure(caption="小さいPRが好まれる", images=["images/do_not_boil_the_ocean.png"] )}}

Kubernetesのrepositoryにいるk8s-ci-robotは[prow](https://github.com/kubernetes-sigs/prow)というツールだと知りませんでした。 
利用できるコマンドは[Command Help](https://prow.k8s.io/command-help)で確認できるという知見も得ました。 

{{ figure(images=["images/ci_bot.png"]) }}


## コミュニケーション

Kubernetesにおけるコミュケーションがどこで、どんな風に行われているかについて。  
Kubernetesのslackには、日本人ユーザ向けに、`#jp-users`や`#jp-mentoring`といったチャンネル等があり、困ったら日本語でも相談できそうでした。  
Slack以外では、メーリングリスト、Zoomがあることもわかりました。  
また、よく使われる英語表現や、英語を書く際に気を付ける点といったTipsの紹介もありがたかったです。


## ハンズオン

ハンズオンでは実際に[kubernetes-sigs/contributor-playground](https://github.com/kubernetes-sigs/contributor-playground)という練習用のリポジトリで、PRの作成からレビュー依頼、マージまでの流れを体験しました。  
[作成したPR](https://github.com/kubernetes-sigs/contributor-playground/pull/1380)。  
どうやらこのリポジトリはCLAのサインアップ用PRの作成にも使われているらしいです。  

{{ figure(images=["images/meow.png"], caption="自由にbotのコマンドを試せた") }}  

ここまでよくしてくれるOSSはなかなかないと思います。


## Kubernetes 開発環境

kubernetesのdirecotry構造の概要や、release cycle/process, localの開発環境の構築方法について。    
開発する際に、localで動かすためにどういったツールが利用できるかの解説が非常に参考になりました。  [`local-up-cluster.sh`](https://github.com/kubernetes/kubernetes/blob/master/hack/local-up-cluster.sh)というscriptの存在も知れました。  
その他、どういったテストが実施されていて、それぞれのtestをどうやって動かすかの解説もありました。  
[`kubetest2`](https://github.com/kubernetes-sigs/kubetest2)というテスト用のツールもあるそうです。  
localで動かせるとソースを読む際にはかどるので、各コンポーネントをlocalで動かせるようにしたいです。

## まとめ

非常に参考になり、おもしろかったです。  
どういう情報がどのあたりあるかといった土地勘がちょっとだけついた気がしました。  
[講師の方々](https://github.com/kubernetes-sigs/contributor-playground/tree/master/japan/cncj-202408#%E8%AC%9B%E5%B8%ABfacilitators)、ありがとうございました。
