+++
title = "📗 Terraform: Up and Runningを読んだ感想"
slug = "terraform-up-and-running"
description = "Terraform: Up and Runningを読んだ感想について"
date = "2023-10-18"
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

最初の書き出しの  

> Software isn’t done when the code is working on your computer. It’s not done when the tests pass. And it’s not done when someone gives you a “ship it” on a code review. Software isn’t done until you deliver it to the user.

がいきなりしびれました。Software isn't done until you deliver it to the userはsoftwareはユーザに届けられて初めて価値をもつというニュアンスだと思うのですが翻訳でどう訳されるのかきになります。

* What is DevOps
  * devと専用のops teamにわかれていた
  * releaseは規模が大きくなるに従い、遅く不安定になる
  * release頻度が週一、月1,半年と減っていき、変更の量が多くなるのでさらに不安定になる
  * 
   
* What is infrastructre as code
* What are the benefits of infrastructure as code
* How does Terraform work?
* How does Terraform compare to oter infrastructure-as-code tools?