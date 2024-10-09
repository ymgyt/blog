#import "@preview/polylux:0.3.1": *
#import themes.bipartite: *

#show: bipartite-theme.with(aspect-ratio: "16-9")
#show link: underline

#set text(
  size: 25pt,
  font: (
    "Noto Sans CJK JP",
))

#title-slide(
  title: [OpenTelemetryのSignalsを\
  Grafana Cloudに送る],
  author: [ymgyt],
  date: [2024-10-10],
)

#west-slide(title: "自己紹介")[
```toml
[speaker]
name = "Yamaguchi Yuta"
github = "ymgyt"

[company]
name = "FRAIM Inc."
```
]

#west-slide(title: "概要")[
  OpenTelemetryのLogs, Traces, MetricsをOpenTelemetry Collectorを利用してGrafana Cloudに送る方法について
\
\
  #figure(
    image("./images/overview.svg"),
    numbering: none,
  )
]

#west-slide(title: "OpenTelemetry とは")[
- CNCF Project
- Components
  - Data model
  - Instrumentation (API, SDK)
  - Procotol (OTLP)
  - Collector
  - Schema

#pause \
永続化、Query, Visualizeについてはスコープ外
]

#west-slide(title: "Vendor中立性とbig tent philosophyとの親和性")[
>  One of the biggest advantages of the OpenTelemetry project is its vendor neutrality.
\
> Vendor neutrality also happens to be a core element of our big tent philosophy here at Grafana Labs.

#link("https://grafana.com/blog/2024/09/12/opentelemetry-and-vendor-neutrality-how-to-build-an-observability-strategy-with-maximum-flexibility/")[OpenTelemetry and vendor neutrality: how to build an observability strategy with maximum flexibility]
]

#west-slide(title: "OpenTelemetry Collector とは")[

> The OpenTelemetry Collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data.  

#link("https://opentelemetry.io/docs/collector/")[opentelemetry.io/docs/collector/]
]

#west-slide(title: "Grafana Cloudの認証")[
OpenTelemetry CollectorからGrafana Cloudにexportするには以下の情報が必要

- OTLP Endpoint
- Grafana Cloud instance ID
- API Token
]

#west-slide(title: "Grafana Cloudの認証")[
- OTLP Endpoint

  #figure(
    image("./images/otlp_endpoint_ss.png"),
    numbering: none,
    caption: "https://grafana.com/orgs/{org}/stacks/{stack}/otlp-info"
  )

]

#west-slide(title: "Grafana Cloudの認証")[
- Grafana Cloud instance ID

  #figure(
    image("./images/instance_id_ss.png", height: 60%),
    numbering: none,
    caption: "https://grafana.com/orgs/{org}/stacks/{stack}/otlp-info"
  )

]

#west-slide(title: "Grafana Cloudの認証")[
- API Token

  #figure(
    image("./images/api_token_ss.png"),
    numbering: none,
    caption: "https://grafana.com/orgs/{org}/stacks/{stack}/otlp-info"
  )
]

#west-slide(title: "Grafana Cloudの認証 Collectorの設定")[
#set text(size: 18pt)
```yaml
extensions:
  basicauth/grafanacloud:
    client_auth:
      username: ${env:GC_INSTANCE_ID}
      password: ${env:GC_API_KEY}
receivers:
  otlp:
    protocols: { grpc: { endpoint: "127.0.0.1:4317"}}
exporters:
  otlphttp/grafanacloud:
    auth:
      authenticator: basicauth/grafanacloud
    endpoint: ${env:GC_OTLP_ENDPOINT}
service:
  extensions: [basicauth/grafanacloud]
  pipelines:
    traces: &pipeline
      receivers: [otlp]
      exporters: [otlphttp/grafanacloud]
    metrics: *pipeline
    logs: *pipeline```
]

#west-slide(title: "Logsの変換")[
 - labelの`"."`は`"_"`に変換される
 - 特定のResourceはindex labelとして扱われる
    - `deployment.environment`, `cloud.region`, `service.{namespace,name,id}`, `k8s.{cluster.name, container.name, ...}`
    - 変更するには、supportに連絡が必要
    - index labelとして扱われなかったものは#link("https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/")[strucuted metadata]として扱われる

#link("https://grafana.com/docs/grafana-cloud/send-data/otlp/otlp-format-considerations/#logs")[OTLP: OpenTelemetry Protocol format considerations]

]

#west-slide(title: "Logsの変換")[
2024年3月25日から90日前の間にotlpでlogをexportしていた場合、grafana cloud側の内部でloki exporterによる変換がなされているので、該当ユーザは注意が必要(該当するかはsupportに問い合わせる)

\

`service.namespace/service.name`が`job` labelに変換される等

#link("https://grafana.com/docs/grafana-cloud/send-data/otlp/adopt-new-logs-format/")[Why and How to Adopt the Native OTLP Log Format?]

  
]

#west-slide(title: "Metricsの変換")[
  MetricsはMimir(Prometheus compatible database)に保存される
  \
  \
  OpenTelemetryとPromehteusのmetricsがどのように変換されるかは#link("https://opentelemetry.io/docs/specs/otel/compatibility/prometheus_and_openmetrics/#otlp-metric-points-to-prometheus")[Prometheus and OpenMetrics Compatibility]という仕様に定められている
  \
  (StatusはDevelopmentなのでBreaking changeはありえる)
  
]

#west-slide(title: "Metricsの変換")[
- Metricsの名前やattributes(label)の`"."`や`"-"`は`"_"`に変換される\
`http.response.status.code` => `http_response_status_code`

- unitとtypeがsuffixに追加される
`graphql.duration` =>
`graphql_duration_seconds_bucket`
]

#west-slide(title: "Metricsの変換")[

promehteusの以下のlabelはotelのservice resourceからmappingされる

- `job`は`service.namespace/service.name`
- `instance`は`service.instance.id`

#link("https://opentelemetry.io/docs/specs/semconv/resource/#service")[仕様]で`service.name`, `service.namespace`, `service.instance.id`のtripletがユニークであることが求められている
]

#west-slide(title: "Metricsの変換")[
Resourceはtarget_info metricsに変換される
\

```
target_info{
  deployment_environment_name="production",
  instance="myhost",
  job="myservice/api",
  service_version="0.2.5"}
```
]

#west-slide(title: "Metricsの変換")[

collectorでresourceを明示的にattributeにsetしておくとmetricsにresourceの情報をのせることができる
#set text(size: 20pt)
```
processor:
  transform:
    metric_statements:
      - context: metric
        statements:
        - set(attributes["namespace"], resource.attributes["k8s_namespace_name"])
        - set(attributes["container"], resource.attributes["k8s.container.name"])
        - set(attributes["pod"], resource.attributes["k8s.pod.name"])
        - set(attributes["cluster"], resource.attributes["k8s.cluster.name"])
```
]


#west-slide(title: "PrometheusのOpenTelemetryへの取り組み")[
  - UTF-8 metric and label name
    - `.`をpromehteusでも使えるようになる
  - Native support for resource attributes
    - attributeとresourceがpromethuesではflatに表現されている
  - Delta temporality

#link("https://grafana.com/blog/2024/04/03/how-the-prometheus-community-is-investing-in-opentelemetry/")[How the Prometheus community is investing in OpenTelemetry]
]

#west-slide(title: "Tracesの変換")[
TempoはOpenTelemetryのAttributeとResourceをサポートしている\
OpenTelemetry上のTraceがそのままTempoのtraceとして表現されている
(`"."`が`"_"`に変換されたりしない)

#link("https://grafana.com/docs/tempo/latest/operations/best-practices/#best-practices-for-traces")[Best practices for traces]
]

#west-slide(title: "まとめ")[

- OTLPを利用してGrafana Cloudにlogs, metrics, tracesを簡単にexportできる
- OpenTelemetryのデータ構造がどのようにそれぞれのサービスでマッピングされるかを意識する必要がある
- OpenTelemetryを利用した際のexperienceの改善が日々進んでいる
]

#west-slide(title: "参考1")[

- #link("https://opentelemetry.io/community/mission/")[OpenTelemetry mission, vision, and values]
- #link("https://grafana.com/docs/grafana-cloud/send-data/otlp/")[OTLP: The OpenTelemetry Protocol]
- #link("https://grafana.com/docs/grafana-cloud/send-data/otlp/otlp-format-considerations/")[OTLP: OpenTelemetry Procotol format considerations]
- #link("https://grafana.com/blog/2024/09/12/opentelemetry-and-vendor-neutrality-how-to-build-an-observability-strategy-with-maximum-flexibility/")[OpenTelemetry and vendor neutrality]
- #link("https://grafana.com/blog/2024/04/03/how-the-prometheus-community-is-investing-in-opentelemetry/")[How the Prometheus community is investing in OpenTelemetry]
- #link("https://docs.google.com/document/d/1FgHxOzCQ1Rom-PjHXsgujK8x5Xx3GTiwyG__U3Gd9Tw/edit?pli=1#heading=h.unv3m5m27vuc")[Proper support for OTEL resource attributes]
]

#west-slide(title: "参考2")[
- #link("https://docs.google.com/document/d/1epvoO_R7JhmHYsII-GJ6Yw99Ky91dKOqOtZGqX7Bk0g/edit#heading=h.5sybau7waq2q")[OTel to Prometheus Usage Issues]
- #link("https://www.youtube.com/watch?v=mcabOH70FqU")[PromCon 2023 - Towrds making Prometheus OpenTelemetry native]
- #link("https://docs.google.com/document/d/1gG-eTQ4SxmfbGwkrblnUk97fWQA93umvXHEzQn2Nv7E/edit#heading=h.b79ugwqjcgse")[Ux of using target_info]
- #link("https://docs.google.com/document/d/1NGdKqcmDExynRXgC_u1CDtotz9IUdMrq2yyIq95hl70/edit")[Prometheus as an OTel native metrics backend]
- #link("https://grafana.com/blog/2024/08/06/prometheus-data-source-update-redefining-our-big-tent-philosophy/")[Prometheus data source update: Redefining our big tent philosophy]
- #link("https://grafana.com/blog/2023/12/18/opentelemetry-best-practices-a-users-guide-to-getting-started-with-opentelemetry/")[OpenTelemetry best practices: A user's guide to getting started with OpenTelemetry]
]

#west-slide(title: "参考3")[
- #link("https://opentelemetry.io/docs/specs/otel/compatibility/prometheus_and_openmetrics/")[Prometheus and OpenMetrics Compatibility]
- #link("https://grafana.com/docs/loki/latest/send-data/otel/")[Ingesting logs to Loki using OpenTelemetry Collector]
- #link("https://www.youtube.com/watch?v=snXhe1fDDa8")[Introduction to Ingesting OpenTelemetry Logs with Loki | Zero to Hero: Loki | Grafana]
- #link("https://grafana.com/docs/grafana-cloud/send-data/otlp/adopt-new-logs-format/")[Why and How to Adopt the Native OTLP Log Format?]
- #link("https://grafana.com/docs/tempo/latest/operations/best-practices/#best-practices-for-traces")[Best practices for traces]
]
