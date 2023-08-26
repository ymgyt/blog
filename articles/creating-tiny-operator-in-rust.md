---
title: "kube-rsを使ってRustで簡単なKubernetes Operatorを作ってみる"
emoji: "🦀"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["rust", "kubernetes"]
published: false
# publication_name: "fraim"
---

<!-- 記事で伝えたいこと -->
<!-- * kube-rsを利用すればRustからでも簡単にOperatorを作れる -->
<!-- * 自前のCRをapply, deleteできる -->
<!-- * kube-rsの仕組み -->
<!--   *  CRの生成 -->

先日、[kube-rs]を利用したKubernetes operatorという内容で社内のRust勉強会を行いました。  
本記事ではこの勉強会で扱ったトピックについて書きます。
概要としては、`Hello` [Custom Resource]を定義してmanifestをapplyすると、対応するServiceとDeploymentをOperatorが作成し、manifestを削除するとDeployment等をOperatorが削除するまでを実装します。

# TL;DR
* [kube-rs]を利用するとRustから簡単にkubernetes apiを利用できる。  
* Controllerの実装も提供されているのでreconcileの処理に集中できる

# 前提

[kube-rs]: https://github.com/kube-rs/kube
[Custom Resource]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
