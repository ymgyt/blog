+++
title = "⚙️ Ironies of Automationを読んだ感想"
slug = "ironies-of-automation"
description = "自動化するほどつらいところだけ人に残されて逆に大変になる"
date = "2024-09-28"
draft = false
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/gear.png"
+++


## 読んだもの

[Ironies of automation](https://www.sciencedirect.com/science/article/abs/pii/0005109883900468)

Lisanne Bainbridge, Ironies of automation, Automatica, Volume 19, Issue 6, 1983, Pages 775-779, ISSN 0005-1098, https://doi.org/10.1016/0005-1098(83)90046-8.

リンク先から$25でPDFが読めました。

## きっかけ

[プラットフォーム エンジニアリングに関する5つの誤解](https://cloud.google.com/blog/ja/products/application-development/common-myths-about-platform-engineering) ([続編](https://cloud.google.com/blog/ja/products/application-development/another-five-myths-about-platform-engineering)もあって全部で10の誤解がある)の中の

> 4. 誤解: プラットフォーム エンジニアリングとは「単なる自動化」のことである

という章で、自動化とプラットフォームエンジニアリングの関係が述べられていました。  
その中で

> [自動化で、解決がより困難な問題が新たに発生してしまうこともあります。](https://en.wikipedia.org/wiki/Automation#Limitations)したがって、自動化の品質ではなく、シグナルの誤解釈、設計の誤解、不適切な仮定、インセンティブの不一致などの社会技術的な圧力を原因としたシステムの不具合の発生を回避するために、やみくもに自動化を進めないようにするというのは理にかなっています。

と、やみくもな自動化をたしなめている箇所があり、リンク先のwikipediaに[Paradox of automation](https://en.wikipedia.org/wiki/Automation#Paradox_of_automation) という項目がありました。  
そこで今回読んだ、Ironies of automationが引用されており、個人的に刺さったので読んでみることにしました。  

## おいしいところだけ自動化される問題

> The second irony is that the designer who tries to eliminate the
operator still leaves the operator to do the tasks which the
designer cannot think how to automate. It is this approach which
causes the problems to be discussed here, as it means that the
operator can be left with an arbitrary collection of tasks, and little
thought may have been given to providing support for them.

(２つ目の皮肉は、自動化の設計者が自動化できないところはオペレータに残すということです。その結果、オペレータにはつらいところだけ残され、それを自力で解決しなければいけなくなります。)

非常に心当たりがあります。  
特に、あー、あれのことじゃんと思うのが、kubernetesのoperatorです。  
Operatorのversionを上げる際や外部のリソースが期待されている状態でない場合等でエラーが起きると、operatorが抽象化していたリソース + operator自身の挙動(code)を調べる必要がありました。  
さらにそのリソース自身についてあまりわかっていないと、今までoperatorがいい感じにしてくれていたので、基本的なところから調べる必要があります。(~~そもそもoperatorなしで運用できないものを扱うなという話ですが~~)

## 監視してるだけだとスキル身につかない問題

> One result of skill is that the operator knows he can take-over adequately if required. Otherwise the job is one of the worst types, it is very
boring but very responsible, yet there is no opportunity to aquire
or maintain the qualities required to handle the responsibility.
The level of skill that a worker has is also a major aspect of his
status, both within and outside the working community. If the job
is 'deskilled' by being reduced to monitoring, this is difficult for
the individuals involved to come to terms with. It also leads to the
ironies of incongruous pay differentials, when the deskilled
workers insist on a high pay level as the remaining symbol of a
status which is no longer justified by the job content.

(スキル不足により、オペレータは必要とあらば自動化されたタスクを引き継げるという自信をもてない場合、その仕事は最悪のものとなる。つまらないのに責任が重く、にもかかわらず必要なスキルを習得する機会は与えられない。作業者のスキルは、職場の内外の地位を決める主要な要因であるにもかかわらず、それが見てるだけというのは、受け入れがたいものがあるし、高い給与にもつながらない。)

Operator運用する場合はoperatorのcodeを読むようにしていたのですが、その心情が的確に書かれています。  
いざとなったら自分で実装理解して問題解決できるという自信を持てるか否かは私個人としては非常に重要な要素でした。私がeditorとしてhelixを使っているのも、いざとなったら自分で直せるという自信をもてる点が一番大きいです。  

自動化によって、作業者から運用の負担を取り除けますが、同時に作業者の技術取得の機会も減らすというのは薄々思っていたので、使うツールのソースは読んでいこうという気持ちを改めてもちました。(~~なので全部Rustで書いてほしい~~)


## 成功した自動化ほど、訓練が必要になる問題 

> Perhaps the final irony is that it is the most successful automated
systems, with rare need for manual intervention, which may need
the greatest investment in human operator training.

(おそらく最後の皮肉は、人の介入をほとんど必要としないもっとも成功した自動化ほど、オペレータの訓練に投資が必要になりうるということ。)

自動化が高度化するほど、人の介入頻度は下がっていきます。が、逆に介入が必要な状況は、事前に想定されておらず、自動の回復が不可能な場合なので、人の介入の難易度や緊急度が高いことになる。  

この話も非常に耳が痛いです。自動化するほど、手離れしていくものと思いきや、訓練が必要になるのは皮肉です。(~~まだ起きたことのない障害を想定した訓練って優先度あがらないんですよね~~)


## プログラムができることはプログラムにまかせて、人間は人間にしかできないことに集中すればいいというわけでもないかもしれない

> By taking away the easy parts of his task, automation can
make the difficult parts of the human operator's task more
difficult. Several writers (Wiener and Curry, 1980; Rouse, 1981)
point out that the 'Fitts list' approach to automation, assigning to
man and machine the tasks they are best at, is no longer sufficient.
It does not consider the integration of man and computer, nor how to maintain the effectiveness of the human operator by supporting his skills and motivation.

(自動化によって作業の容易な部分が取り除かれると、人間の作業をより難しくするかもしれない。何人かの著者は、人間と機会にそれぞれが得意なタスクを割り当てるアプローチがもはや十分でないと指摘している。それは、人間のスキル向上やモチベーションの維持を考慮していない。)

機械(コンピューター、プログラム)にできることはそれらにやらせて、人間は別のタスクに集中しようという主張はよく見かけますし、その通りだと思っていました。  
一方で、残されたつらみも経験があるし、ブラックボックス化した自動化を運用していてもスキルがつかないというのもわかるので、この考えが広まってくれるとうれしいと思いました。  


## まとめ

つまみ食い的にですが、刺さった点についての感想を書いてみました。  

> the more advanced a control system is, so the more crucial may be
the contribution of the human operator. 

ということで、運用の自動化を推進すればするほど、運用担当者の役割が重要になるという点を踏まえていきたいです。

