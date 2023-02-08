+++
title = "📗 RabbitMQ Essentials 2nd Editionを読んだ感想"
slug = "rabbitmq_essentials_2nd_edition"
date = "2022-08-17"
draft = false
[taxonomies]
tags = ["book"]
+++


## 読んだ本📗

{{ figure(caption="By Lovisa Johansson , David Dossot", images=["images/rabbitmq_essentials_book.png"] )}}

[RabbitMQ Essentials - Second Edition](https://www.packtpub.com/product/rabbitmq-essentials-second-edition/9781789131666)

2020出版でRabbitMQ関連の本で比較的新しめだったのと、Taxi ApplicationにRabbitMQを組み込んでいくという形がおもしろそうだったので読んでみました。

## 1 A Rabbit Springs to Life

概要やインストールについて。  
RabbitMQ/AMQP 0-9-1のコンセプトについて紹介されています。  

## 2 Creating a Taxi Application

Complete Car(CC)というタクシー予約システムを作りながらRabbitMQの使い方を学んでいきます。  
最初はDirect exchangeを利用しつつ、機能拡張という形でTopic exchangeを導入します。
その中で、Connection/Channelの説明や、基本的なPublish/Consumer APIの説明があります。  
RabbitMQ Serverのrestartをまたいでmessageを永続化させるには、queueのdurableとmessageのpersistentの両方が必要になります。  
messageの信頼性とパフォーマンスのトレードオフを見極めて利用する必要があるので、導入に際してはシステムに要求される信頼性を定義することが重要そうだなと考えました。  
サンプルコードはRubyでした。


## 3 Sending Messages to Multiple Taxi Drivers

Consumerに一度に送られるmessage数を制御するためのprefetch countとacknowledgeについて説明されます。messageの性質にもよりますが、prefetch countを1にしてmanual acknowledgeにしておくのが一番安全そう。
prefetch countはdefault値にたよらず明示的に指定しておくことも大事だなと思いました。

また、全taxiにback officeからメッセージを送りたいという機能要望に答えるためにFanout exchangeがCCに導入されました。

## 4 Tweaking Message Delivery

taxiのdriverにmessageを送るfanout exchangeをchapter3で導入した。  
ところが運用してみるとmessageをまったくconsumeしないdriverが存在しており、queueにmessageが溜まり続けてしまう。そこで一定期間経過後にmessageを削除し、その際messageが重要であればdriverにメール送る機能を実装したい。というシナリオでtime to live(TTL)やDead letter Queueについて学んでいきます。

messageのexpirationについては以下の3つの選択肢がある。

1. Standard AMQP message expiration property
2. QueueごとにmessageのTTLを定義できるRabbitMQ extension
3. Queue自体のTTLを定義できるRabbitMQ extension

1についてはAMQP標準ということで魅力的だが、落とし穴があり、messageがqueueの先頭にきてはじめてTTLがチェックされるという仕様でTTLが過ぎていてもqueue自体には残ってしまう。  
また、queue自体は削除したくないので3も除外。ということで選択肢2を採用することとなる。
TTLが過ぎたmessageはdead letterと判断される。RabbitMQはこうしたdead letterをDLXというexchangeにroutingする機能をもつ。

QueueにTTLやDLXを設定するには、queue declare時のargumentsに`x-message-ttl`や`x-dead-letter-{exchange,routing-key}`を指定するのですが、既存のqueueに対して宣言してしまうとargumentsが一致せずexceptionが発生してしまいます。  
そこで、RabbitMQにはpolicyという仕組みがあり、policyを通して既存のqueueやexchangeに変更を適用できます。

PolicyはAMQPの仕様ではないのでclientにAPIがありません。(あるlibもあるかもしれませんが)  
そこで、rabbitmqctlという専用のcliを利用します。  
dockerでRabbitMQをたちあげている場合は

```console
docker exec rabbitmq-rabbitmq-1 -it /bin/bash
rabbitmqctl set_policy -p / Q_TTL_DLX '.*' '{"message-ttl": 1000, "dead-letter-exchange": "dlx"}' --apply-to queues
```
のようにします。  
`-p`はvirtual hostの指定(なぜp?), `Q_TTL_DLX`はpolicyの名前。`'.*'`は適用するリソースの正規表現。jsonはpolicyのbody, `--apply-to`で適用対象をqueueかexchangeか指定といった感じです。  

続いての機能拡張は、backofficeからtaxi driverにメッセージを送る際に、driver用のqueueがセットアップされていなければemailを送るようにしたいというものです。ここで利用できるのが、publish時の`mandatory` flagです。これはexchangeに送られたmessageがどのqueueにも送られなかった場合にpublisherにmessageを送り返す機能を有効にします。  
lapinの[publisher_confirms example](https://github.com/amqp-rs/lapin/blob/lapin-1.x/examples/publisher_confirms.rs)で実際の利用例がみれます。

## 5 Message Routing

ConsumerからPublisherにresponseを返すRPCを実装します。やり方はRabbitMQ TutorialsのRPCと同じで、messageのbasic propertiesにあるreply-toにresponse用のqueueを指定するだけです。request-response毎にqueueを生成するか事前に作成しておくかの方法があります。

また、Single Text-Oriented Message Protocol(STOMP)用のpluginを利用して、browserからRabbitMQ Serverにwebsocketで接続してqueueをsubscribeする例も紹介されています。

最後にheaders exchangeを導入します。topic exchangeではユースケースに対応できない場合にはheaders exchangeを利用する感じなのでしょうか。紹介されている事例は新しくqueueをたててbindingすれば対応できるように思えたのでいまいち使い所がわかっていません。

## 6 Taking RabbitMQ to Production

今まではRabbitMQをsingle nodeで動かしていましたがこの章ではclusterを導入します。RabbitMQはErlangで実装されているらしく、clusterもErlang clustering featureを利用して実装されているみたいです。

Client libraryの実装によるかとは思うのですがcluster化した際にclient側でclusterを構成するnodeを把握してそれぞれの接続情報を保持しておく必要がありそうでした。Rustの実装であるlapinでは複数の接続先を渡せるようになっていないように見えるので、どう対応するかが課題です。(deadpool_lapinでConnection生成処理が隠蔽されているので、自分でurlをrotateするとかもできないので困りました)

RabbitMQのclusterではexchangeやqueueはnode間でsyncされるが、queueのmessageに関してはいくつか選択肢があるようです。  
まず、Mirroring queuesという選択肢があります。これはmaster, replica構成でmessageを冗長化する方式のようです。

次に、quorum queuesという方式があります。これもmaster replicaベースですが、queueの内容についてleaderとreplication間で合意をとることで信頼性を高めているようです。過半数のnode間でqueueの内容がsyncできたらclientにconfirmを返すことで実現されています。

最後にLazy queuesが紹介されます。
この機能が有効かされたqueueではmessageはdistに保存され、queueにmessageが大量に溜まる場合でもRAMの使用量が抑えられるみたいです。durableを有効にするのと違ってそもそもメモリにmessageを保持しなくなる点が特徴という理解でよいのでしょうか。

Clusterに続いてはlogのaggregationを実現するためのfederationについても説明がありました。RabbitMQをfluentdのagentのように位置付けることもでき柔軟性が高いなと思いました。


## 7 Best Practices and Broker Monitoring

RabbitMQを運用していくにあたってのBest Practicesについての紹介です。  
まずは、messageを失わないためのBest practicesについて。  

* 最低3台以上でclusterを組む
* quorum queueを使う
* queueをdurableにしてmessage publish時にpersistent delivery modeを有効にする
* transient messageを利用してもLazy queuesの場合にはperformance上のtrade-offが発生する。また、queueがdurableであってもmessageが失われる可能性があることを理解しておく

また、当然ではありますがdead letter exchangeを利用することも挙げられています。  
messageのTTLやqueueのmax length, nack等でmessageが処理されないケースがあるのでエラーハンドリングもプログラム的につくっておきましょうと言われています。

performance的な問題がない限りはpublisher/consumerともにconfirmも有効にすることをまずは検討したほうがよさそうです。

Messageのhandlingに関しては以下の点が挙げられています。

* message sizeは大き過ぎても小さ過ぎても問題
  * 小さすぎるiterableなdataはchunk化してみる
  * 大きすぎる場合は別のcomponentにoffloadできるか試みる
* consumerの処理時間に応じてprefetching valueを調整する

queueとbrokersをcleanに保とうという点について指摘されています。

* queueにはTTL(`x-message-ttl`)を設定する
* queueにはmax-lengthを指定する
* 使われていないqueueを削除する
  * `x-expires`で利用されなくなってから削除されるまでの期間を指定しておく
  * queueのauto-delete propertyを有効にする

その他、messageのrouting keyに応じてqueueを分散させるためのpluginが紹介されています。

### Monitoring

現在のRabbitMQ serverの情報を取得する方法としてはrabbitmqctlとREST APIの二つの手段がある。監視に有用なmetricsが紹介されています。  
node/clusterの状態からqueueごとの処理状況、file descriptorやsocketの利用状況もAPIで取得できるのは助かりそうです。

## まとめ

本書を読んだ感想を簡単に書いていきました。  
RabbitMQの各機能について具体例をふまえて紹介されており概要を把握するのに適していると思いました。  
[RabbitMQ in Depth](https://www.manning.com/books/rabbitmq-in-depth)という本を見つけたので次はこちらを読んでみようかなと思ってます。

