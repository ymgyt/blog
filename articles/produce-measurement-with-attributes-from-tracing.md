---
title: "tracingからAttributesを付与してmetricsを出力できるようtracing-opentelemetryにPRを送った"
emoji: "🔭"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["rust", "opentelemetry", "tracing"]
published: false
publication_name: "fraim"
---

現在、[FRAIM]では[OpenTelemetry]の導入を進めています。  
Applicationから出力するMetricsに関しても[OpenTelemetry]の[Metrics]を利用したいと考えています。  
既に[tracing]を導入しているので、[tracing-opentelemetry]を利用することでApplicationに[Metrics]を組み込めないか検討していました。  
その際に必要な機能があったので[PR](https://github.com/tokio-rs/tracing-opentelemetry/pull/43)を[tracing-opentelemetry]に送ったところマージしてもらえました。  
本記事ではその際に考えたことや学びについて書いていきます。 


# 前提

まず前提として[tracing-opentelemetry]の[`MetricsLayer`]を利用すると、[tracing]のEventを利用して[OpenTelemetry]の[Metrics]を出力することができます。  
例えば  
```rust
tracing::info!(monotonic_counter.foo = 1);
```

とすると、`foo` [Counter]をincrementすることができます。

# PRで実装した機能の概要

[tracing]から[Metrics]を出力する際に、[Attribute]を付与できないといった制約がありました。 
[Attribute]とは、[OpenTelemetry]におけるkey valueのペアです。  

例えば

```rust
tracing::info!(
  monotonic_counter.request_count = 1,
  http.route = "/foo",
  http.response.status_code = 200,
);
```

とした場合に、`request_counter` [Counter]は出力されるのですが、`http.route="/foo"`や`http.response.sattus_code=200`といった情報をmetricsに付与できませんでした。  
この点については、[feature requestのissue](https://github.com/tokio-rs/tracing-opentelemetry/issues/32)も上がっており、[`MetricsLayer`]にEventのkey valueをmetricsに紐付ける機能がリクエストされていました。  
この機能については自分も必要だったので、やってみることにしました。

# [`MetricsLayer`]の仕組み


# 機能を追加する上での問題点

## VisitするまでEventがmetricsのfieldを含んでいるか判断できない

## Allocationの発生


# 問題へのアプローチ

## Per filter layerの活用

## SmallVecの利用

## Benchmark

## Fraimgraph

## まとめ

[tracing]: https://github.com/tokio-rs/tracing
[tracing-opentelemetry]: https://github.com/tokio-rs/tracing-opentelemetry
[`MetricsLayer`]: https://docs.rs/tracing-opentelemetry/0.20.0/tracing_opentelemetry/struct.MetricsLayer.html
[OpenTelemetry]: https://opentelemetry.io/
[Metrics]: https://github.com/open-telemetry/opentelemetry-specification/tree/v1.24.0/specification/metrics
[Counter]: https://github.com/open-telemetry/opentelemetry-specification/blob/v1.24.0/specification/metrics/api.md#counter
[Attribute]: https://github.com/open-telemetry/opentelemetry-specification/tree/v1.24.0/specification/common#attribute
[FRAIM]: https://fraim.co.jp/
