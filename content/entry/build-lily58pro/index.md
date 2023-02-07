+++
title = "⌨️ 自作キーボードLily58Proを組み立てる"
slug = "build-lily58pro"
date = "2020-08-09"
draft = false
[taxonomies]
tags = ["device"]
+++

この記事では自作キーボード[Lily58 Pro](https://yushakobo.jp/shop/lily58-pro/)の組み立て工程について書いていきます。

普段はHHKBを使っていたのですが分離型キーボードを試してみたいと思っていました。
HHKBに近い感じがよく、CapsLock、FunctionKeyがなくてUS配列あたりで探していたのですがしっくりくるものが見つかりませんでした。
そんな中たまたま見つけた[Lily58 Pro](https://keyhive.xyz/shop/lily58)がよさそうだったので作ってみることにしました。
詳細な[ビルドガイド](https://github.com/kata0510/Lily58/blob/master/Pro/Doc/buildguide_jp.md)もあり自分でもできそうと思えました。

自作キーボードとは別にRustで組み込みがやってみたくて、オライリーからでている[Make: Electronics](https://www.oreilly.co.jp/books/9784873118970/)に手をだしており、はんだづけまわりの道具が一通り揃っていたのでキット買うだけで始められそうだったのもちょうどよかったです。


## 準備

{{ figure(caption="パーツと道具", images=["images/lily58pro_prepare.jpeg"]) }}

[キット](https://yushakobo.jp/shop/lily58-pro/)は遊舎工房で購入しました。このキット以外で必要なパーツは


* [TRRSケーブル](https://yushakobo.jp/shop/trrs_cable/) 左右のキーボードをつなぐケーブル。
* [USBケーブル](https://www.amazon.co.jp/gp/product/B077PRD1FT) 
* [キースイッチ](https://yushakobo.jp/shop/cherry-mx/?attribute_pa_stem=red-2)
* [キーキャップ](https://yushakobo.jp/shop/tai-hao-pbt-sakuramichi/)

USBケーブルはマグネット式がおすすめされていたのでそれに倣いました。(上下を間違えると物理的に接続はできるもののデータ通信ができないので注意)

キースイッチに関しては実際に触ってみないとわからないことが多いので静からしい赤軸にしました。次は[Holy Panda](https://drop.com/buy/massdrop-x-invyr-holy-panda-mechanical-switches)を買ってみようと思っています。


## 組み立て

{{ figure(caption="基盤表面", images=["images/lily58pro_assemble_1.jpeg"]) }}

基盤(PCB)の表側に目印としてテープをつけていきます。基盤自体には裏表はないので適当に決めます。


### ダイオードをつける

{{ figure(caption="ダイオードの取り付け", images=[
  "images/lily58pro_assemble_2.jpeg",
  "images/lily58pro_assemble_3.jpeg",
  "images/lily58pro_assemble_4.jpeg",
], width="32%") }}

ダイオードを基盤の裏側につけていきます。非常に小さいのでピンセットで扱いました。またわかりにくいですが片側に線がひいてあり基板側の矢印と向きをあわせる必要あります。
基盤の左右でダイオードの向きが逆になるので注意。

取り付けるにはまず、ダイオード取り付け部分の片側にあらかじめはんだを垂らしておきます。これを予備はんだというらしいです。
どのくらいが適量なのかがわからなかったので適当にやっています。
写真ではこのあとに取り付けるスイッチソケット部分の予備はんだも一緒にやっています。

{{ figure(caption="予備はんだづけ", images=[
  "images/lily58pro_assemble_5.jpeg",
  "images/lily58pro_assemble_6.jpeg",
  "images/lily58pro_assemble_7.jpeg",
], width="32%") }}


予備はんだが終わったら左手でダイオードをピンセットで持ちながら予備はんだ部分にはんだごてをあててはんだを溶かしダイオードをつけていきます。


{{ figure(caption="ダイオードの取り付け", images=[
  "images/lily58pro_assemble_8.jpeg",
  "images/lily58pro_assemble_9.jpeg",
], width="48%") }}


着け終わったらもう片方もはんだづけしていきます。この作業を左右とも行います。


### キースイッチ用ソケットをつける


{{ figure(caption="ソケットの取り付け", images=[
  "images/lily58pro_assemble_10.jpeg",
  "images/lily58pro_assemble_11.jpeg",
  "images/lily58pro_assemble_12.jpeg",
], width="32%") }}

ダイオードをつける際に一緒につけておいた予備はんだを利用してキースイッチ用ソケットをはんだづけしていきます。写真はMX用のものです。
作業時には気づけなかったのですがこの段階で導通確認をしておくべきでした。写真のソケットのうち3箇所はんだづけ不良のものがあります。


### TRRSケーブルソケット、リセット用トグルスイッチをつける


{{ figure(caption="ソケットとトグルスイッチの取り付け", images=[
  "images/lily58pro_assemble_13.jpeg",
  "images/lily58pro_assemble_14.jpeg",
], width="48%") }}

TRRSケーブル用ソケットとトグルスイッチをつけていきます。左右でとりつける位置が微妙に異なります。


### OELDモジュール取り付けの準備


{{ figure(caption="OELFモジュールの準備", images=[
  "images/lily58pro_assemble_15.jpeg",
  "images/lily58pro_assemble_16.jpeg",
], width="49lily58pro_assemble_%") }}

OELDモジュールをとりつけるために指定箇所にはんだづけをおこないジャンプさせます。またソケットをはめて裏からはんだづけします。写真のひとつだけ大きいなはんだづけ箇所はやり直しています。


### Pro Microをつける


{{ figure(caption="Pro Microの取り付け", images=[
  "images/lily58pro_assemble_17.jpeg",
  "images/lily58pro_assemble_18.jpeg",
  "images/lily58pro_assemble_19.jpeg",
], width="32%") }}

Pro Microを取り付けます。左右両方に必要なのでふたつあります。Pro Microのはんだづけは自信がなかったので、余分に買っておいて練習してからのぞみました。
後からおもうとこの段階でqmkの書き込みを行い、ジャンパー線等でソケットを押してみて各キーが認識されているかのチェックをおこなっておくべきだったなと思っております。

### キースイッチのとりつけ


{{ figure(caption="キースイッチの取り付け", images=[
  "images/lily58pro_assemble_20.jpeg",
  "images/lily58pro_assemble_21.jpeg",
  "images/lily58pro_assemble_22.jpeg",
  "images/lily58pro_assemble_23.jpeg",
], width="24%") }}

スペーサをとりつけてキースイッチをはめていきます。スイッチはめていく際にうまくはまらずに中で足がまがってしまうことがあったので注意です。
キースイッチを[ひきぬく道具](https://www.amazon.co.jp/%E3%83%A1%E3%82%AB%E3%83%8B%E3%82%AB%E3%83%AB%E3%82%AD%E3%83%BC%E3%83%9C%E3%83%BC%E3%83%89-%E3%82%AD%E3%83%BC%E3%83%88%E3%83%83%E3%83%97%E5%BC%95%E6%8A%9C%E5%B7%A5%E5%85%B7-%E3%82%AD%E3%83%BC%E3%82%AD%E3%83%A3%E3%83%83%E3%83%97%EF%BC%86%E3%82%AD%E3%83%BC%E3%82%B9%E3%82%A4%E3%83%83%E3%83%81-%E3%82%AD%E3%83%BC%E3%83%9C%E3%83%BC%E3%83%89%E3%83%A1%E3%83%B3%E3%83%86%E3%83%8A%E3%83%B3%E3%82%B9%E7%94%A8%E5%B7%A5%E5%85%B7-%E5%BC%95%E3%81%8D%E6%8A%9C%E3%81%91%E3%82%8B%E3%82%AD%E3%83%BC/dp/B07SDQ2ZGN/ref=pd_lpo_147_t_0/)を準備しておけばよかったです。


### OELDモジュールのとりつけ


{{ figure(caption="OELDモジュールの取り付け", images=[
  "images/lily58pro_assemble_24.jpeg",
  "images/lily58pro_assemble_25.jpeg",
  "images/lily58pro_assemble_26.jpeg",
], width="32%") }}

OELDモジュールをとりつけます。(アクリルの保護シートをとりはずすのにかなり苦労しました。)
 


### qmk_firmwareの書き込み

[qmk_firmware](https://github.com/qmk/qmk_firmware)を書き込んでいきます。

かなり詳しい[document](https://docs.qmk.fm/#/newbs_getting_started)が用意されているのでそれにしたがってセットアップします。
自分の環境はmacOSなので、git cloneしてきた後`brew install qmk/qmk/qmk`で必要な準備が整いました。
キーマップを書き込むには、`cd qmk_firmware && make lily58:default:avrdude`を実行します。resetまちになるので、リセットトグルスイッチをおしてやります。
TRRSケーブルははずした状態で左右それぞれでUSBケーブルを接続して`make lily58:default:avrdude`を実行します。

### キーマップのカスタマイズ

qmkを書き込みすべてのキーが動作することのを確認できたらキーマップをカスタマイズしていきます。
`qmk_firmware/keyboards/lily58/keymaps/custom` directoryを作成して`lily58/keymaps/default`以下をコピーしてきます。

```
ls -l keymaps/custom
total 8
-rw-r--r-- 1 ymgyt staff 1274 Aug  2 15:57 config.h
lrwxr-xr-x 1 ymgyt staff   48 Aug  4 09:11 keymap.c -> /Users/ymgyt/ws/kb/my_qmk_keymap/lily58/keymap.c
-rw-r--r-- 1 ymgyt staff 1481 Aug  2 15:57 rules.mk
```

[キーマップ](https://github.com/ymgyt/my_qmk_keymap/blob/master/lily58/keymap.c)はgit管理したかったのでsymlinkを貼りました。
このあたりは使いながらqmkのdocを読んでいろいろ試していこうと思っています。  
書き込む際は `make lily58:custom:avrdude`を実行します。左右それぞれにやらなくてはいけないのですこし面倒です。


### 完成

{{ figure(caption="完成", images=["images/lily58pro_assemble_27.jpeg"]) }}

キーキャップをはめてこのようになりました。
初めての自作キーボードでしたが動くものが作れて仕事で利用できています。道具さえ揃えてしまえばはんだづけは大変でしたがなんとかなったので電子工作の入門としてちょうどいいのではないかなと思います。
副作用としてHHKBが使えない体になってしまい、家用で2台目をつくるためにさっそく新しいキースイッチを購入してしまいました。

