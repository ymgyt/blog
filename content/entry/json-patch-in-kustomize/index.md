+++
title = "🔧 Kustomizeで利用されるRFC6902 JSON Patchを読んでみる"
slug = "json-patch-in-kustomize"
description = "Kustomizeのpatchで用いられるJSON PatchについてRFCを読んで理解する"
date = "2023-07-13"
draft = true
[taxonomies]
tags = ["book"]
[extra]
image = "images/emoji/wrench.png"
+++


本記事では、Kubernetesのmanifestを管理するための(kustomize)[https://github.com/kubernetes-sigs/kustomize]で利用できる`patches`について、参照されているRFCを読みながら理解することを目指します。  


## patchesの具体例

まず、patchesの具体的な利用を確認します。  
以下のような`Ingress`にpatchを当てたいとします。  

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: example
spec:
  rules:
  - host: blog.ymgyt.io
    http:
      paths:
      - path: /
        backend:
          serviceName: service-1
          servicePort: 5001
```

`kustomization.yaml`は以下のようになります。

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ingress.yaml

patches:
- path: ingress_patch.yaml
  target:
    group: networking.k8s.io
    version: v1beta1
    kind: Ingress
    name: example
```

適用するpatchは`ingress_patch.yaml`に定義します。  
意図としては、`/ui`用のruleを追加することです。

```yaml
- op: add
  path: /spec/rules/0/http/paths/-
  value:
    path: '/ui'
    backend:
      serviceName: ui
      servicePort: 5002
```

全体としては以下のような構成です。 

```sh
> exa -T .
.
├── ingress.yaml
├── ingress_patch.yaml
└── kustomization.yaml
```

ここで、`kustomize build .`してみると

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: example
spec:
  rules:
  - host: blog.ymgyt.io
    http:
      paths:
      - backend:
          serviceName: service-1
          servicePort: 5001
        path: /
      - backend:
          serviceName: ui
          servicePort: 5002
        path: /ui
```

`Ingress`にpatchに定義した`/ui`のruleが追加できていることが確認できました。  

## patchの仕様

上記ではは以下のようなpatchを適用しました。  

```yaml
- op: add
  path: /spec/rules/0/http/paths/-
  value: # ...
```

ここから、patchには`op`,`path`,`value`を指定する必要がありそうなことがわかります。  
ただし、`op`に他にどんな値があるのかであったり、`/spec/rules/0/http/paths/-`の`-`の意味であったりは、kustomizeの公式docには定義されていませんでした。  

[Reference](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patches/)によりますと

> The patches field contains a list of patches to be applied in the order they are specified.  
    Each patch may:  
      * be either a strategic merge patch, or a JSON6902 patch  
      * be either a file, or an inline string  
      * target a single resource or multiple resources  

とあり、patchはJSON6902で指定することができる  
JSON6902とは、[patchJson6902](https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#patchjson6902)を指しており、これは[RFC6902](https://datatracker.ietf.org/doc/html/rfc6902)を参照しているとありました。  

ということで、patchをどう書けばいいかはRFC6902(JSON Patch)を読んでみればよさそうということがわかりました。


## RFC6902 JavaScript Object Notation (JSON) Patch

まず、[Introduction](https://datatracker.ietf.org/doc/html/rfc6902#section-1)にて

> JSON Patch is a format (identified by the media type "application/ json-patch+json") for expressing a sequence of operations to apply to a target JSON document

JSON PatchはJSONに適用する一連のoperationを表現するためのformatであるとされています。  

また、

> This format is also potentially useful in other cases in which it is necessary to make partial updates to a JSON document or to a data structure that has similar constraints 

とあり、JSONの一部を更新したいユースケースで便利と説明されています。kustomizeでの利用はまさにこのcaseのことでしょうか。

### Document structure

[Document structure](https://datatracker.ietf.org/doc/html/rfc6902#section-3)では、具体例として下記のjsonが挙げられていました。

```json
[
   { "op": "test", "path": "/a/b/c", "value": "foo" },
   { "op": "remove", "path": "/a/b/c" },
   { "op": "add", "path": "/a/b/c", "value": [ "foo", "bar" ] },
   { "op": "replace", "path": "/a/b/c", "value": 42 },
   { "op": "move", "from": "/a/b/c", "path": "/a/b/d" },
   { "op": "copy", "from": "/a/b/d", "path": "/a/b/e" }
]
```

そして、各operationの適用については

1. operationは定義された順序に従って、適用される
1. operationが適用された結果に対して、次のoperationが適用される
1. operationの適用は全て成功するか、errorが発生するまで続く

とされていました。  
試しに、意味がないですが、addした結果を直後にremoveしてみたところ意図通りになりました。

```yaml
- op: add
  path: /spec/rules/0/http/paths/-
  value:
    path: '/ui'
    backend:
      serviceName: ui
      servicePort: 5002

- op: remove
  path: /spec/rules/0/http/paths/1
```

### Operations

[Operations](https://datatracker.ietf.org/doc/html/rfc6902#section-4)に、具体的なoperationのfieldについて定められています。  

> Operation objects MUST have exactly one "op" member, whose value indicates the operation to perform.  
  Its value MUST be one of "add", "remove", "replace", "move", "copy", or "test"; other values are errors. 

* operationには`op` fieldが必須
* `op`の値は`"add"`,`"remove"`,`"replace"`,`"move"`,`"copy"`,`"test"`のいずれかでそれ以外はerror


> Additionally, operation objects MUST have exactly one "path" member. 
  That member's value is a string containing a JSON-Pointer value [RFC6901] that references a location within the target document (the "target location") where the operation is performed.

* operationには`path` fieldが必須
* `path` fieldでtarget documentの変更適用箇所を指定する

>  The meanings of other operation object members are defined by operation (see the subsections below).  
  Members that are not explicitly defined for the operation in question MUST be ignored (i.e., the operation will complete as if the undefined member did not appear in the object).

* `op`と`path`以外のfieldについては`op`の値による
* 定義されていないfieldは無視される


ということで、次に各種`op`に指定できる値をみていきます。

#### add

add operationはpathの指定に応じて以下の3つの効果を及ぼします。


> * If the target location specifies an array index, a new value is inserted into the array at the specified index.   
> * If the target location specifies an object member that does not already exist, a new member is added to the object.   
> * If the target location specifies an object member that does exist, that member's value is replaced.


* pathがarray indexなら指定されたindexにvalueをinsertする
* pathがobject memberの場合、存在しないなら新規作成、存在するならreplace

addですが、既存をreplaceするんですね。


#### remove

#### replace

#### mv

#### copy

#### test


