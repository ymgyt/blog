+++
title = "🕸  GraphQL Specificationを読んでみる"
slug = "graphql-specification-2021"
date = "2022-11-04"
draft = false
[taxonomies]
tags = ["book"]
+++

{{ figure(images=["images/gql_spec.png"] )}}

本記事ではGraphQLの[仕様]を読んだ感想について書きます。具体的にはOctober 2021 Editionです。  
[仕様]を読んでみようとおもったきっかけなのですが、Githubのgraphql apiにリクエストを送ろうとHttp requestを作っていた際に最終的にどういうjsonのbodyを作ればいいかわからず仕様でどうなっているのか気になったのがきっかけです。また[仕様]には具体例ものっており思ったより読みやすそうという印象もうけました。🕸


## 1 Overview

GraphQLの概要について。

> GraphQL is a query language designed to build client applications by providing an intuitive and flexible syntax and system for describing their data requirements and interactions.

GraphQLはclient applicationが欲しいデータを直感的かつ柔軟に表現できるsyntaxを提供する。

```graphql
{
  user(id: 4) {
    name
  }
}
```

確かに上記のqueryでuser idが4のuserのnameを取得したいと素直に読めます。

> GraphQL is not a programming language capable of arbitrary computation, but is instead a language used to make requests to application services that have capabilities defined in this specification. GraphQL does not mandate a particular programming language or storage system for application services that implement it.

* GraphQLはGraphQL serverへのrequestを作るためのlanguage
* 特定のprogramming言語を強制しない

### GraphQL design principals

GraphQLには以下のdesign principlesがあるそうです。

* Product-centric
* Hierarchical
* Strong-typing
* Client-specified response
* Introspective


#### Product-centric

> GraphQL is unapologetically driven by the requirements of views and the front-end engineers that write them. GraphQL starts with their way of thinking and requirements and builds the language and runtime necessary to enable that.

画面を作るfrontendのための言語であることが最初に宣言されているのが印象的です。

#### Hierarchical

> Most product development today involves the creation and manipulation of view hierarchies. To achieve congruence with the structure of these applications, a GraphQL request itself is structured hierarchically. The request is shaped just like the data in its response. It is a natural way for clients to describe data requirements.

今日のproductにおいてはview hierarchiesを扱うのが一般的。  
view hierarchiesの理解があやしいですが、例えばGithubのあるrepositoryのissueのtitle一覧が欲しいみたいな必要なdataが`aaa.bbb.ccc.ddd`のようにresourceの関係性で表現できるというようなことでしょうか。確かにあるrepositoryのissueのtitle一覧を取得しようと思った時に

```graphql
repository(owner: "kubernetes", name: "kubernetes") {
    id,
    issues(
        orderBy: {field: UPDATED_AT, direction: ASC },
        states: [OPEN],
        first: 10,
    ) {
        pageInfo {
            startCursor,
            endCursor,
            hasNextPage,
            hasPreviousPage,
        },
        totalCount,
        edges {
            cursor,
            node {
                id,
                number,
                title,
            }
        }
    }
}
```
のようなqueryをapiになげるのですが, responseとして

```json
 "data": {
    "repository": {
      "id": "MDEwOlJlcG9zaXRvcnkyMDU4MDQ5OA==",
      "issues": {
        "pageInfo": {
          "startCursor": "Y3Vyc29yOnYyOpK5MjAxOC0wMS0xNlQyMTo1OToxOSswOTowMM4Gha_N",
          "endCursor": "Y3Vyc29yOnYyOpK5MjAxOS0wNS0wN1QwNDoyNzo0NyswOTowMM4CkpIm",
          "hasNextPage": true,
          "hasPreviousPage": false
        },
        "totalCount": 1576,
        "edges": [
          {
            "cursor": "Y3Vyc29yOnYyOpK5MjAxOC0wMS0xNlQyMTo1OToxOSswOTowMM4Gha_N",
            "node": {
              "id": "MDU6SXNzdWUxMDk0MjQ1ODk=",
              "number": 14961,
              "title": "Write proposal for controller pod management: adoption, orphaning, ownership, etc. (aka controllers v2)",
            }
          },
          {
            "cursor": "Y3Vyc29yOnYyOpK5MjAxOC0wMS0xOFQxNDoxMzozMSswOTowMM4LjpVk",
            "node": {
              "id": "MDU6SXNzdWUxOTM4OTM3MzI=",
              "number": 38216,
              "title": "Expose enough information to resolve object references and label selectors generically",
            }
          },
```
のようにqueryの構造に対応するresponseが返ってきて非常に直感的です。

#### Strong-typing

> Every GraphQL service defines an application-specific type system. Requests are executed within the context of that type system. Given a GraphQL operation, tools can ensure that it is both syntactically correct and valid within that type system before execution, i.e. at development time, and the service can make certain guarantees about the shape and nature of the response.

型づけされている。

#### Client-specified response

> Through its type system, a GraphQL service publishes the capabilities that its clients are allowed to consume. It is the client that is responsible for specifying exactly how it will consume those published capabilities. These requests are specified at field-level granularity. In the majority of client-server applications written without GraphQL, the service determines the shape of data returned from its various endpoints. A GraphQL response, on the other hand, contains exactly what a client asks for and no more.

GraphQLではresponseの構造をclientが決める。  
これがやりたくてGraphQL使いたいみたいなところがあります。RESTでAPI開発していてこのendpointでどこまで関連するリソース返すかはいつも悩みどころでした。(だいたい最初の開発が画面に引きづられて負債になる)

#### Introspective

> GraphQL is introspective. A GraphQL service’s type system can be queryable by the GraphQL language itself, as will be described in this specification. GraphQL introspection serves as a powerful platform for building common tools and client software libraries.

GraphQLのapiはGraphQL自身で調べられる。便利だなくらいに思っていましたが仕様で最初から考慮されていたんですね。

#### Design principles まとめ

> Because of these principles, ... Product developers and designers building applications against working GraphQL services—supported with quality tools—can quickly become productive without reading extensive documentation and with little or no formal training.

これらの原則のおかげでextensive documentationを読むことなくほとんどformal trainingなしにproductiveになれるみたいです。  
(GraphQLやってみるにあたり割と色々解説記事探したりしていたので、quickly become productiveになれていなくて焦ります。)

まとめるとGraphQLは、frontend engineersが欲しいデータを関係性含めて型に基づいて表現できる言語という感じでしょうか。(+ Meta情報の公開の仕方も決まっている)


## 2 Language

GraphQLのoperation(query,mutation,subscription)やselection set, variable, data typeといったcomponentについて。

> Clients use the GraphQL query language to make requests to a GraphQL service. We refer to these request sources as documents. A document may contain operations (queries, mutations, and subscriptions) as well as fragments, a common unit of composition allowing for data requirement reuse.

GraphQL serverへのrequestにはdocumentを含める。documentにはoperationsやfragmentsを含めることができる。  
Githubのgraphql apiへhttp request作ろうとした際にどんなjson投げればいいのか知りたくて本仕様を見てみたのですが、仕様上はなんらかの方法で"document"を含めるというような書きぶりでした。

> A GraphQL document is defined as a syntactic grammar where terminal symbols are tokens (indivisible lexical units). These tokens are defined in a lexical grammar which matches patterns of source characters. In this document, syntactic grammar productions are distinguished with a colon : while lexical grammar productions are distinguished with a double-colon ::.

> The source text of a GraphQL document must be a sequence of SourceCharacter. The character sequence must be described by a sequence of Token and Ignored lexical grammars. The lexical token sequence, omitting Ignored, must be described by a single Document syntactic grammar.

GraphQLのdocumentはtokenを終端記号とするsyntactic grammarで定義される。syntactic grammarのproductionsは`:`で定義される。  
tokenはlexical grammarで定義される。lexical grammar productionsは`::`で定義される。  
ソース -> token列 -> documentという流れでparseされるという理解です。  
その他、Source Textとして有効なunicode code pointが定義されていたり、改行コードが定義されていたりします。UnicodeBOM入っていても仕様上有効という発見がありました。  

### Operations

実際に書くGraphQL queryやmutationはどのように規定されているか。

```
OperationDefinition :
  - OperationType Name? VariableDefinitions? Directives? SelectionSet
  - SelectionSet
 
OperationType : one of `query` `mutation` `subscription`
```

Operationは上記のように定義されています。  
GraphQLはじめた際に

```graphql
{
    repository(name: "xxx") {
        id,
    }
}
```
```graphql
query {
    repository(name: "xxx") {
        id,
    }
}
```
```graphql
query FetchRepository {
    repository(name: "xxx") {
        id,
    }
}
```
のように色々な書き方があって混乱していたのですがOperationTypeを省略した際はqueryと解釈されて、operation nameは省略可能ということだったんですね。

### Selection Sets

> An operation selects the set of information it needs, and will receive exactly that information and nothing more, avoiding over-fetching and under-fetching data.

必要な情報だけを宣言するselectionについて。

```
SelectionSet : { Selection+ }

Selection :
  - Field
  - FragmentSpread
  - InlineFragment
```

fieldかfragmentをかける。fragmentも別で定義するかinlineで書ける。

#### Field

```
Field : Alias? Name Arguments? Directives? SelectionSet?
```

Fieldは上記のように定義されている。aliasが書けることや、再帰的にSelectionSetが書けることがわかります。

> Some fields describe complex data or relationships to other data. In order to further explore this data, a field may itself contain a selection set, allowing for deeply nested requests. All GraphQL operations must specify their selections down to fields which return scalar values to ensure an unambiguously shaped response.

SelectionSetをnestさせても最終的にはscalarのfieldになる必要がある。

```graphql
query {
    user(id: 3) {
        id,
        birthday {
            month,
        },
        smallPic: profilePic(size: 64),
        bigPic: profilePic(size: 1024),
    }
}
```
のようなqueryが書けることがわかりました。

#### Fragment

GraphQLだとuserを取得のようなことはできず必ずuserのどのfieldを取得するか毎回指定しないといけない。そのため、SelectionSetを再利用したくなり、そのための仕組みという理解です。

> Fragments are the primary unit of composition in GraphQL.

> Fragments allow for the reuse of common repeated selections of fields, reducing duplicated text in the document. Inline Fragments can be used directly within a selection to condition upon a type condition when querying against an interface or union.

仕様にも"reuse of common repeated selections of fields"とありますね。

```graphql
query withNestedFragments {
  user(id: 4) {
    friends(first: 10) {
      ...friendFields
    }
    mutualFriends(first: 10) {
      ...friendFields
    }
  }
}
fragment friendFields on User {
  id
  name
  ...standardProfilePic
}
fragment standardProfilePic on User {
  profilePic(size: 50)
}
```

fragmentからfragment参照できるのは知りませんでした。

```graphql
query FragmentTyping {
  profiles(handles: ["zuck", "coca-cola"]) {
    handle
    ...userFragment
    ...pageFragment
  }
}

fragment userFragment on User {
  friends {
    count
  }
}

fragment pageFragment on Page {
  likers {
    count
  }
}
```

fragmentは適用対象の型を明示する必要があり、上記の例では`profiles`が`User`か`Page`を返すので

```json
{
  "profiles": [
    {
      "handle": "zuck",
      "friends": { "count": 1234 }
    },
    {
      "handle": "coca-cola",
      "likers": { "count": 90234512 }
    }
  ]
}
```

それぞれの型に対応したfragmentが適用されます。

```
InlineFragment : ... TypeCondition? Directives? SelectionSet
```

fragmentはinlineでも書けて上記の例をinlineで書くと以下のようになります。

```graphql
query inlineFragmentTyping {
  profiles(handles: ["zuck", "coca-cola"]) {
    handle
    ... on User {
      friends {
        count
      }
    }
    ... on Page {
      likers {
        count
      }
    }
  }
}
```

またfragmentはdirectiveの適用範囲を指定するのにも使えるとのことです。

```graphql
query inlineFragmentNoType($expandedInfo: Boolean) {
  user(handle: "zuck") {
    id
    name
    ... @include(if: $expandedInfo) {
      firstName
      lastName
      birthday
    }
  }
}
```

### Values

Int, Float, Boolean, String, Enum, List, Objectについては割愛。

#### Null Value

複数のprogramming言語またぐとなにかと問題になりがちなnullについて。

```
NullValue : `null`
```

> Null values are represented as the keyword null.

> GraphQL has two semantically different ways to represent the lack of a value:
Explicitly providing the literal value: null.
Implicitly not providing a value at all.

値がないことを表現するには2種類の方法がある。一つは明示的に`null`を渡す。もう一つはvalueを渡さない。

```graphql
{
  field(arg: null)
  field
}
```

上記は異なって解釈される場合があるそうです。例えばmutationにおいて、nullを渡すと当該fieldを削除して、何も渡さない場合は変更しない等。

> The same two methods of representing the lack of a value are possible via variables by either providing the variable value as null or not providing a variable value at all.

変数についてもnullを渡す場合とvariableをそもそも渡さない場合の2種類がありえるということみたいです。  
個人的にはnull渡すのとなにも渡さないで挙動が変わるAPIは避けたい派です。二つの挙動あるならENUMで型として表現したいです。  
(null渡すのとfiledがそもそもないのを区別するのjsだけだと思うのでそれをAPIにまで伝播させないでほしいと思ったり)

### Variables

operationから動的な部分を分離するためにvariableが使える。

```
Variable : $ Name

VariableDefinitions : ( VariableDefinition+ )

VariableDefinition : Variable : Type DefaultValue? Directives[Const]?

DefaultValue : = Value[Const]
```

```graphql
query getZuckProfile($devicePicSize: Int) {
  user(id: 4) {
    id
    name
    profilePic(size: $devicePicSize)
  }
}
```

> A GraphQL operation can be parameterized with variables, maximizing reuse, and avoiding costly string building in clients at runtime.

> Variables must be defined at the top of an operation and are in scope throughout the execution of that operation. Values for those variables are provided to a GraphQL service as part of a request so they may be substituted in during execution.

ここでもvariableはrequestの一部という言及のみで具体的にどう渡すか書いていない。

#### Directives

GraphQLの表現力を向上させられて、運用上大事になってきそうだけどいまいち理解できていないdirectiveについて。

```graphql
Directives[Const] : Directive[?Const]+

Directive[Const] : @ Name Arguments[?Const]?
```

> Directives provide a way to describe alternate runtime execution and type validation behavior in a GraphQL document.

とあるので、runtimeの挙動を変えるのとvalidationが用途みたいです。

directiveは宣言する順番も影響するので下記の例ではdifferent semantic meaningをもつ

```graphql
type Person
  @addExternalFields(source: "profiles")
  @excludeField(name: "photo") {
  name: String
}
type Person
  @excludeField(name: "photo")
  @addExternalFields(source: "profiles") {
  name: String
}
```

## 3 Type System

GraphQLの型について。

> The GraphQL Type system describes the capabilities of a GraphQL service and is used to determine if a requested operation is valid, to guarantee the type of response results, and describes the input types of variables to determine if values provided at request time are valid.

GraphQLの型systemは

* GraphQL serverができることを表現
* Requestのoperationとvariableのvalidationに利用される
* Responseの型を保証

### Descriptions

> Documentation is a first-class feature of GraphQL type systems.

GraphiQL等でAPI触っていてもdocumentがすぐ出てくるので別で調べに行かなくてよくて便利だなと思っていましたが、仕様上からfirst classだったんですね。

### Schema

> A GraphQL service’s collective type system capabilities are referred to as that service’s “schema”. A schema is defined in terms of the types and directives it supports as well as the root operation types for each kind of operation: query, mutation, and subscription; this determines the place in the type system where those operations begin.

GraphQL Serverの機能はschemaとして表現される。  
top levelに各query, mutation, subscriptionでできることが定義される。 
また、型やdirectiveはschema上でuniqueである必要がある。

```graphql
schema {
  query: MyQueryRootType
  mutation: MyMutationRootType
}

type MyQueryRootType {
  someField: String
}

type MyMutationRootType {
  setSomeField(to: String): String
}
```

schemaを上記のように定義すると

```graphql
query {
    someField
}
```
```graphql
mutation {
    setSomeField(to: "xxx") {
        newField
    }
}
```
のようにoperationを書ける。  
また、mutationとsubscriptionのroot typeはoptionalであり、`Query`型を定義するとqueryのroot typeとなるので、以下のschema定義は有効。

```graphql
type Query {
    someField: String
}
```

### Types

```
TypeDefinition :
  - ScalarTypeDefinition
  - ObjectTypeDefinition
  - InterfaceTypeDefinition
  - UnionTypeDefinition
  - EnumTypeDefinition
  - InputObjectTypeDefinition
```

> The fundamental unit of any GraphQL Schema is the type. There are six kinds of named type definitions in GraphQL, and two wrapping types.

6つのnamed typeと2つのwrapping typesがある。(wrapping typesはListとNonNull)  
ScalarとObjectはそのままの意味。

> GraphQL supports two abstract types: interfaces and unions.

abstract typeとしてinterfaceとunionがある。

> An Interface defines a list of fields; Object types and other Interface types which implement this Interface are guaranteed to implement those fields. Whenever a field claims it will return an Interface type, it will return a valid implementing Object type during execution.

Interfaceはfieldのlistで、schema上interfaceを返すと宣言されている場合、実際にはobject型が返ってくる。

> A Union defines a list of possible types; similar to interfaces, whenever the type system claims a union will be returned, one of the possible types will be returned.

Interfaceと同様にschema上でunionが返されると宣言されている場合、実際にはそのうちのどれかが返ってくる。

> Finally, oftentimes it is useful to provide complex structs as inputs to GraphQL field arguments or variables; the Input Object type allows the schema to define exactly what data is expected.

CreateXxxInput型定義しがちですが、Input型としてfirst classなのが他の型systemと違って特徴できだなと思ったりしました。

#### Wrapping Types

上記の型はすべてnullableかつsingular。  
`Non-Null`型と`List`が用意されておりwrapping typesとして他のnamed typesと区別される。

#### Input and Output Types

GraphQL serverへの入力に使われるかresponseの型定義に使われるかでinput typeとoutput typeが区別できる。

> Types are used throughout GraphQL to describe both the values accepted as input to arguments and variables as well as the values output by fields. These two uses categorize types as input types and output types. Some kinds of types, like Scalar and Enum types, can be used as both input types and output types; other kinds of types can only be used in one or the other. Input Object types can only be used as input types. Object, Interface, and Union types can only be used as output types. Lists and Non-Null types may be used as input types or output types depending on how the wrapped type may be used.

* Scalar,Enum: input/output両方使用化
* InputObject: inputのみ
* Object,Interface,Union: outputのみ

判定方法は以下

```
IsInputType(type) :
  * If {type} is a List type or Non-Null type:
    * Let {unwrappedType} be the unwrapped type of {type}.
    * Return IsInputType({unwrappedType})
  * If {type} is a Scalar, Enum, or Input Object type:
    * Return {true}
  * Return {false}

IsOutputType(type) :
  * If {type} is a List type or Non-Null type:
    * Let {unwrappedType} be the unwrapped type of {type}.
    * Return IsOutputType({unwrappedType})
  * If {type} is a Scalar, Object, Interface, Union, or Enum type:
    * Return {true}
  * Return {false}
```

### Scalars

> Scalar types represent primitive leaf values in a GraphQL type system. GraphQL responses take the form of a hierarchical tree; the leaves of this tree are typically GraphQL Scalar types (but may also be Enum types or null values).

SectionSetで最終的に取得するのはscalar。  
Built-inとして、Int,Float, String, Boolean, IDがある。

#### Custom Scalars

Built-in scalarsに加えてcustom scalarsを使うことができる。  
例えば`UUID`や`URL`を使う場合が考えられる。

> When defining a custom scalar, GraphQL services should provide a scalar specification URL via the @specifiedBy directive or the specifiedByURL introspection field. This URL must link to a human-readable specification of the data format, serialization, and coercion rules for the scalar.

Custom scalarsを定義する場合は`@specifiedBy`directiveで仕様のURLを明示する必要がある。(逆にBuiltinの仕様は本仕様に定められているので付与してはいけない)

```graphql
scalar UUID @specifiedBy(url: "https://tools.ietf.org/html/rfc4122")
scalar URL @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")
```

> A GraphQL service, when preparing a field of a given scalar type, must uphold the contract the scalar type describes, either by coercing the value or producing a field error if a value cannot be coerced or if coercion may result in data loss.

また、Scalarの型に応じてcoercionをすることが許されるようです。  
もっとも具体的にどのようにcoercionされるかは実装依存で仕様では定義されていないと思われますがBuilt-in scalarsについてはResult Coercion, Input Coercionそれぞれ仕様で定められています。

> Since this coercion behavior is not observable to clients of the GraphQL service, the precise rules of coercion are left to the implementation

### Interfaces

> GraphQL interfaces represent a list of named fields and their arguments. GraphQL objects and interfaces can then implement these interfaces which requires that the implementing type will define all fields defined by those interfaces.

```graphql
interface NamedEntity {
  name: String
}

interface ValuedEntity {
  value: Int
}

type Person implements NamedEntity {
  name: String
  age: Int
}

type Business implements NamedEntity & ValuedEntity {
  name: String
  value: Int
  employeeCount: Int
}

type Contact {
    entity: NamedEntity
    phoneNumber: String
    address: String
}
```

自分は専らRustのcodeからgraphqlのschemaを生成するのがメインのユースケースなのですが、graphql的な観点から綺麗なinterface定義できるか課題です。  
例えば

```rust
struct Contact<E> {
    entity: E,
    phoneNumber: String,
    address: String
}

impl<E> Contact<E>
where  E: NamedEntity {
    fn xxx() {}
}
```

のようにstruct定義にはtrait bound設けないで, implでtrait bound設定するのがよしとされているのでここからgraphqlの型を生成したときに上記のようにならないなという課題感です。(code firstが前提の話)

### Unions

> GraphQL Unions represent an object that could be one of a list of GraphQL Object types, but provides for no guaranteed fields between those types. They also differ from interfaces in that Object types declare what interfaces they implement, but are not aware of what unions contain them.

responseのobjectがどれかになることを表す。unionのtype間で共通するfieldがあることは保証されない。またobjectはinterfaceを明示的にimplするがどのunionに含まれるかには関与しない。

> With interfaces and objects, only those fields defined on the type can be queried directly; to query other fields on an interface, typed fragments must be used. This is the same as for unions, but unions do not define any fields, so no fields may be queried on this type without the use of type refining fragments or inline fragments (with the exception of the meta-field __typename).

Unionではfieldに関する保証がないのでqueryする際は型を明示する必要がある。

```graphql
union SearchResult = Photo | Person

type Person {
  name: String
  age: Int
}

type Photo {
  height: Int
  width: Int
}

type SearchQuery {
  firstSearchResult: SearchResult
}
```

```graphql
{
  firstSearchResult {
    ... on Person {
      name
    }
    ... on Photo {
      height
    }
  }
}
```

### Non-Null

> By default, all types in GraphQL are nullable; the null value is a valid response for all of the above types. To declare a type that disallows null, the GraphQL Non-Null type can be used. This type wraps an underlying type, and this type acts identically to that wrapped type, with the exception that null is not a valid response for the wrapping type. A trailing exclamation mark is used to denote a field that uses a Non-Null type like this: name: String!.

原則として、GraphQLの型はnullable。nullを許容しない場合は、末尾に`!`をつける。  
Listと組み合わせると下記の宣言が可能。

* `[Int]`
* `[Int]!`
* `[Int!]`
* `[Int!]!`

### Directives

> A GraphQL schema describes directives which are used to annotate various parts of a GraphQL document as an indicator that they should be evaluated differently by a validator, executor, or client tool such as a code generator.

directiveとはなんなのかというと、仕様的にはvalidatorがexecutorかclient toolに異なる解釈を指示するindicatorという定義なんですね。

#### Built-in Directives

* `@skip`
* `@include`
* `@deprecated`
* `@specifiedBy`

上記がbuilt-inのdirective。それ以外はcustom directives。

##### `@skip`

```graphql
directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

query myQuery($someTest: Boolean!) {
    experimentalField @skip(if: $someTest)
}
```

引数の`if`で結果に当該filedを含めるか制御できる。

##### `@include`

```graphql
directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

query myQuery($someTest: Boolean!) {
    experimentalField @include(if: $someTest)
}
```

`@skip`の逆の挙動。`@skip`と`@include`が両方指定された場合についても規定されているがそんなApiにはならないほうがいいと思う。

##### `@deprecated`

```graphql
directive @deprecated(
  reason: String = "No longer supported"
) on FIELD_DEFINITION | ENUM_VALUE

type ExampleType {
    newField: String
    oldField: String @deprecated(reason: "Use `newField`.")
}
```

schemaの変更が初めから考慮されていて現代的だなと思いました。


##### `@specifiedBy`

```graphql
directive @specifiedBy(url: String!) on SCALAR

scalar UUID @specifiedBy(url: "https://tools.ietf.org/html/rfc4122")
```

custom scalarの仕様を明示するdirective。仕様上shouldでした。

#### Custom Directives

> When defining a custom directive, it is recommended to prefix the directive’s name to make its scope of usage clear and to prevent a collision with built-in directive which may be specified by future versions of this document (which will not include _ in their name).

custom directivesを定義する際は、将来的なcollisionを防止する観点からprefixつけることが推奨されています。

directiveの書き方は以下のように定義されています。

```
DirectiveDefinition : Description? directive @ Name ArgumentsDefinition? `repeatable`? on DirectiveLocations

DirectiveLocations :
  - DirectiveLocations | DirectiveLocation
  - `|`? DirectiveLocation

DirectiveLocation :
  - ExecutableDirectiveLocation
  - TypeSystemDirectiveLocation

ExecutableDirectiveLocation : one of
  - `QUERY`
  - `MUTATION`
  - `SUBSCRIPTION`
  - `FIELD`
  - `FRAGMENT_DEFINITION`
  - `FRAGMENT_SPREAD`
  - `INLINE_FRAGMENT`
  - `VARIABLE_DEFINITION`

TypeSystemDirectiveLocation : one of
  - `SCHEMA`
  - `SCALAR`
  - `OBJECT`
  - `FIELD_DEFINITION`
  - `ARGUMENT_DEFINITION`
  - `INTERFACE`
  - `UNION`
  - `ENUM`
  - `ENUM_VALUE`
  - `INPUT_OBJECT`
  - `INPUT_FIELD_DEFINITION`
```

`directive @ my_directive on`QUERY`のようにonで適用スコープを明示する必要があるようです。

具体例。

```graphql
directive @example on FIELD_DEFINITION | ARGUMENT_DEFINITION

type SomeType {
  field(arg: Int @example): String @example
}
```

```graphql
directive @delegateField(name: String!) repeatable on OBJECT | INTERFACE

type Book @delegateField(name: "pageCount") @delegateField(name: "author") {
  id: ID!
}

extend type Book @delegateField(name: "index")
```

## 4 Introspection

GraphQL serverのschemaはGraphQLを使って調べることができる。  
Ecosystemを念頭にmeta情報の公開方法まで仕様で決めているのはうれしいですね。

```graphql
type User {
  id: String
  name: String
  birthday: Date
}
```

このような型定義をもつGraphQL serverに対して

```graphql
{
  __type(name: "User") {
    name
    fields {
      name
      type {
        name
      }
    }
  }
}
```

このrequestに対して以下のようなresponseが得られる

```json
{
  "__type": {
    "name": "User",
    "fields": [
      {
        "name": "id",
        "type": { "name": "String" }
      },
      {
        "name": "name",
        "type": { "name": "String" }
      },
      {
        "name": "birthday",
        "type": { "name": "Date" }
      }
    ]
  }
}
```

introspection systemで利用するtypeやfieldは`__`から始まる。  
introspection systemで利用できるschema自身もGraphQL schemaで以下のように定義されている。

```graphql
type __Schema {
  description: String
  types: [__Type!]!
  queryType: __Type!
  mutationType: __Type
  subscriptionType: __Type
  directives: [__Directive!]!
}

type __Type {
  kind: __TypeKind!
  name: String
  description: String
  # must be non-null for OBJECT and INTERFACE, otherwise null.
  fields(includeDeprecated: Boolean = false): [__Field!]
  # must be non-null for OBJECT and INTERFACE, otherwise null.
  interfaces: [__Type!]
  # must be non-null for INTERFACE and UNION, otherwise null.
  possibleTypes: [__Type!]
  # must be non-null for ENUM, otherwise null.
  enumValues(includeDeprecated: Boolean = false): [__EnumValue!]
  # must be non-null for INPUT_OBJECT, otherwise null.
  inputFields: [__InputValue!]
  # must be non-null for NON_NULL and LIST, otherwise null.
  ofType: __Type
  # may be non-null for custom SCALAR, otherwise null.
  specifiedByURL: String
}

enum __TypeKind {
  SCALAR
  OBJECT
  INTERFACE
  UNION
  ENUM
  INPUT_OBJECT
  LIST
  NON_NULL
}

type __Field {
  name: String!
  description: String
  args: [__InputValue!]!
  type: __Type!
  isDeprecated: Boolean!
  deprecationReason: String
}

type __InputValue {
  name: String!
  description: String
  type: __Type!
  defaultValue: String
}

type __EnumValue {
  name: String!
  description: String
  isDeprecated: Boolean!
  deprecationReason: String
}

type __Directive {
  name: String!
  description: String
  locations: [__DirectiveLocation!]!
  args: [__InputValue!]!
  isRepeatable: Boolean!
}

enum __DirectiveLocation {
  QUERY
  MUTATION
  SUBSCRIPTION
  FIELD
  FRAGMENT_DEFINITION
  FRAGMENT_SPREAD
  INLINE_FRAGMENT
  VARIABLE_DEFINITION
  SCHEMA
  SCALAR
  OBJECT
  FIELD_DEFINITION
  ARGUMENT_DEFINITION
  INTERFACE
  UNION
  ENUM
  ENUM_VALUE
  INPUT_OBJECT
  INPUT_FIELD_DEFINITION
}
```

試しにGithub GraphQL apiにdirectiveを問い合わせてみると

```graphql
{
  __schema {
    directives{
      name
    }
  }
}
```

以下のようなresponseが得られた。

```json
{
  "data": {
    "__schema": {
      "directives": [
        {
          "name": "include"
        },
        {
          "name": "skip"
        },
        {
          "name": "deprecated"
        },
        {
          "name": "requiredCapabilities"
        }
      ]
    }
  }
}
```

## 5 Validation

> Typically validation is performed in the context of a request immediately before execution, however a GraphQL service may execute a request without explicitly validating it if that exact same request is known to have been validated before. For example: the request may be validated during development, provided it does not later change, or a service may validate a request once and memoize the result to avoid validating the same request again in the future. Any client-side or development-time tool should report validation errors and not allow the formulation or execution of requests known to be invalid at that given point in time.

validationはrequestの実行前になされるが、事前にvalidであるとわかっている場合には省略することもある。

> As GraphQL type system schema evolves over time by adding new types and new fields, it is possible that a request which was previously valid could later become invalid. Any change that can cause a previously valid request to become invalid is considered a breaking change. GraphQL services and schema maintainers are encouraged to avoid breaking changes

以前はvalidだったrequestがinvalidになるような変更はbreaking changeとみなされる。breaking changeはできるだけ避けることが望ましい。  
このあとに続く以下の文章はいまいち理解できませんでした。

> however in order to be more resilient to these breaking changes, sophisticated GraphQL systems may still allow for the execution of requests which at some point were known to be free of any validation errors, and have not changed since.  

このあとはfragmentのmergeのruleだったり、argumentやvariableのvalidation ruleが記載されています。素直に使えばあまり意識しなくてよさそうと思われるので割愛。

## 6 Execution

GraphQLの実行方法について。  
Requestは以下の情報から構成される。

* schema
* document(operationとfragmentのdefinitionを含む)
* operation name(optional)
* operationで定義されているvariablesのvalues(optional)
* an initial value corresponding to the root type being executed(これいまいち理解できず)

### Executing Requests

> To execute a request, the executor must have a parsed Document and a selected operation name to run if the document defines multiple operations, otherwise the document is expected to only contain a single operation. The result of the request is determined by the result of executing this operation according to the “Executing Operations” section below.

まずdocumentをparseして実行するoperationを特定する。operationの実行結果がrequestの実行結果になる。  
validationが必要なら実行前に行う。また、variablesが定義されている場合はここで必要なvariablesがrequestに含まれるかのvalidationが行われる。

### Executing Operations

Schemaで述べたようにschemaのtop levelでquery root typeが指定されている。mutationとsubscriptionをサポートするならそれらも同様。  
ExecuteOperationの実行結果はそれぞれの実行結果。

#### Query

> If the operation is a query, the result of the operation is the result of executing the operation’s top level selection set with the query root operation type.

operationのtop level selection setに対応するquery rootの処理を実行する。

> allowing parallelization

とあるのでselection setの実行を並列化してもよい。

#### Mutation

> If the operation is a mutation, the result of the operation is the result of executing the operation’s top level selection set on the mutation root object type. This selection set should be executed serially.

Query同様にoperationのtop level selectionに対応するmutation rootの処理を実行する。ただし、mutationの場合はserialに実行することが仕様で規定されている。

> It is expected that the top level fields in a mutation operation perform side-effects on the underlying data system. Serial execution of the provided mutations ensures against race conditions during these side-effects.

ここからunderlying data systemに対するside effectあるかどうかがqueryとmutationを分ける基準になると考えられる。(queryとmutationという名前から明らかではあるが)

#### Subscription

Queryとmutationはデータの取得と変更でわかりやすいのですが、subscriptionって具体的にはなんだってなりました。websocket等のconnectionはってserver側から変更を通知する処理の抽象化なんだろうなと思っていたので仕様でどう定義されているか気になります。

> If the operation is a subscription, the result is an event stream called the “Response Stream” where each event in the event stream is the result of executing the operation for each new event on an underlying “Source Stream”.

とあるので、responseとしてはResponse Streamで、response streamはeventを返す理解でしょうか。そのeventはなにかというとunderlying Source Streamの新規eventに対するoperationの実行結果のことみたいです。  
ようはSource Streamに対するeventのiterationということでしょうか。  
具体例として以下が挙げられています

```graphql
subscription NewMessages {
  newMessage(roomId: 123) {
    sender
    text
  }
}
```

```json
{
  "data": {
    "newMessage": {
      "sender": "Hagrid",
      "text": "You're a wizard!"
    }
  }
}
```

##### Supporting Subscriptions at Scale

> Supporting subscriptions is a significant change for any GraphQL service. Query and mutation operations are stateless, allowing scaling via cloning of GraphQL service instances. Subscriptions, by contrast, are stateful and require maintaining the GraphQL document, variables, and other context over the lifetime of the subscription.

Subscriptionはquery,mutationと違って状態管理が必要になる。

> Consider the behavior of your system when state is lost due to the failure of a single machine in a service. Durability and availability may be improved by having separate dedicated services for managing subscription state and client connectivity.

subscriptionの状態管理のためにseparate dedicated serviceを用意することが提案されている。  
(実装したことないので実装してみたい..!)

##### Delivery Agnostic

> GraphQL subscriptions do not require any specific serialization format or transport mechanism. Subscriptions specifies algorithms for the creation of a stream, the content of each payload on that stream, and the closing of that stream. There are intentionally no specifications for message acknowledgement, buffering, resend requests, or any other quality of service (QoS) details. Message serialization, transport mechanisms, and quality of service details should be chosen by the implementing service.

subscriptionにおいてなにで実現するかは仕様で定めていない。  
また、messagingにおけるackの方法等も実装に委ねられている。  
Unsubscribeについても

> Cancel responseStream

とだけ記載されている。

### Executing Selection Sets

Selection setの実行方法について詳細に定められている。  
Fragmentとselectionでfieldが重複した場合やselection setのmerge等。  
filedのresolve時にエラーがあった場合については

> If a field error is raised while resolving a field, it is handled as though the field returned null, and the error must be added to the "errors" list in the response.

当該filedのresponseにはnullをいれてerrorを`errors`に追加することになっている。fieldが`Non-Null`の場合はその親をnullにする。親も`Non-Null`だった場合はresponseのdataがnullになる。  

自分でGraphQLのresponse直接ハンドリングする際はfiled resolve時にエラーあってもdataにはnullとして表現され、errors field調べないといけないので注意が必要ですね。

## 7 Response

GraphQL serverが返すresponseについて。  

> A response may contain both a partial response as well as any field errors in the case that a field error was raised on a field and was replaced with null.

成功か失敗でなく、一部成功のようなresponseがありえるのが特徴だなと思いました。

### Response format

> A response to a GraphQL request must be a map.

> If the request raised any errors, the response map must contain an entry with key errors. The value of this entry is described in the “Errors” section. If the request completed without raising any errors, this entry must not be present.

> If the request included execution, the response map must contain an entry with key data. The value of this entry is described in the “Data” section. If the request failed before execution, due to a syntax error, missing information, or validation error, this entry must not be present.

> The response map may also contain an entry with key extensions. This entry, if set, must have a map as its value. This entry is reserved for implementors to extend the protocol however they see fit, and hence there are no additional restrictions on its contents.

> To ensure future changes to the protocol do not break existing services and clients, the top level response map must not contain any entries other than the three described above.

* エラーの場合は`errors` fieldにいれる。
* 結果は`data` fieldにいれる
* それ以外の拡張は`extensions`にいれる。
* 将来の変更のためにtop levelでは3つ以外のfieldを含んではならない。(must not)

Responseがjsonであるとは限らないからentryというふうに抽象化されていて、entry = jsonのfieldと読み替えてます。

#### Data

request operationの実行結果は`data` fieldにいれる。  

> If an error was raised before execution begins, the data entry should not be present in the result.

executionの前にエラーが起きた場合は`data` fieldはresponseにいれない

> If an error was raised during the execution that prevented a valid response, the data entry in the response should be null.

fieldのresolve時のエラーの場合は`data` fieldにnullをいれる。

#### Errors

errorのformatについて。

> Every error must contain an entry with the key message with a string description of the error intended for the developer as a guide to understand and correct the error.

> f an error can be associated to a particular point in the requested GraphQL document, it should contain an entry with the key locations with a list of locations, where each location is a map with the keys line and column, both positive numbers starting from 1 which describe the beginning of an associated syntax element.

> If an error can be associated to a particular field in the GraphQL result, it must contain an entry with the key path that details the path of the response field which experienced the error. This allows clients to identify whether a null result is intentional or caused by a runtime error.

* `message`でdeveloperむけにdescriptionを含まなければならない(must)
* `locations`でgraphql documentのエラー箇所を明示すべき(should)
* `path`でerrorの原因となってfiledを明示しなければならない(must)

具体例として

```graphql
{
  hero(episode: $episode) {
    name
    heroFriends: friends {
      id
      name
    }
  }
}
```

のqueryでfriendsの一部のnameの取得に失敗した場合、以下のエラーが返る。

```json
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"]
    }
  ],
  "data": {
    "hero": {
      "name": "R2-D2",
      "heroFriends": [
        {
          "id": "1000",
          "name": "Luke Skywalker"
        },
        {
          "id": "1002",
          "name": null
        },
        {
          "id": "1003",
          "name": "Leia Organa"
        }
      ]
    }
  }
}
```

`name`が`Non-Null`だった場合、entry自体がnullになる。

```json
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"]
    }
  ],
  "data": {
    "hero": {
      "name": "R2-D2",
      "heroFriends": [
        {
          "id": "1000",
          "name": "Luke Skywalker"
        },
        null,
        {
          "id": "1003",
          "name": "Leia Organa"
        }
      ]
    }
  }
}
```

エラーコードを返したい場合は以下のように`extensions`を使う。

```json
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"],
      "extensions": {
        "code": "CAN_NOT_FETCH_BY_ID",
        "timestamp": "Fri Feb 9 14:33:09 UTC 2018"
      }
    }
  ]
}
```

以下のように`errors`のentryも独自拡張してはならない(should not)

```json
{
  "errors": [
    {
      "message": "Name for character with ID 1002 could not be fetched.",
      "locations": [{ "line": 6, "column": 7 }],
      "path": ["hero", "heroFriends", 1, "name"],
      "code": "CAN_NOT_FETCH_BY_ID",
      "timestamp": "Fri Feb 9 14:33:09 UTC 2018"
    }
  ]
}
```

### Serialization Format

> GraphQL does not require a specific serialization format. However, clients should use a serialization format that supports the major primitives in the GraphQL response.

基本はjsonだと思うが仕様的にはserialization formatについては規定していない。ただし、MapやList,Null等を表現できることは要求している。

> Since the result of evaluating a selection set is ordered, the serialized Map of results should preserve this order by writing the map entries in the same order as those fields were requested as defined by selection set execution.

mapのorderについてはoperationのselection setと対応することが要求されている。  
Protocol bufferのmapだとmapのorderは未定義なので地味に問題になりそうだなと思ったりしました。

## Appendix

仕様で使われているNotation Conventionsの説明がのっています。

## まとめ

* GraphQLの全体像がわかった
  * どこまでが仕様で定義されていて、これはlibrary側の話等。
* それぞれの機能がどんな意図で設計されたかが書いてあっておもしろかった
* 具体的にHttpレベルでどうリクエスト作るかについては規定されていないのが意外だった。
* extendまわりのユースケースがわかっていない
* [Spec Markdown](https://spec-md.com/)で書かれていたり、具体例豊富で読みやすかった

 
 
[仕様]: https://spec.graphql.org/October2021/

