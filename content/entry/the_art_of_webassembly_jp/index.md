+++
title = "📕 入門WebAssemblyを読んでWASMをはじめた"
slug = "the_art_of_webassembly_jp"
date = "2022-07-06"
draft = false
[taxonomies]
tags = ["book"]
+++

## 読んだ本

{{ figure(caption="Rick Battagline 著", images=["images/the_art_of_webassembly_book.png"]) }}

[入門WebAssembly](https://www.shoeisha.co.jp/book/detail/9784798173597)  
[The Art Of WebAssembly](https://nostarch.com/art-webassembly)の翻訳書です。

本書を読みながらサンプルコードを写経したので感想を書いていきます。  
[著者のWebサイト](https://wasmbook.com/)には他にもWebAssemblyについてのトピックがあります。  
サンプルコードは[GitHub](https://github.com/battlelinegames/ArtOfWasm)から見れます。  
canvasに3000個のobjectの衝突判定をrenderingするサンプルを動かすところまでやりました。  
https://wasmbook.com/collide.html  

{{ figure(caption="collide.html", images=["images/wasm_object_collision.gif"] )}}


## きっかけ

RustでWASMのecosystemにふれていく前に素のWASMについてなんとなくでも理解したいと思っていました。(ある程度生成されたグルーコード読めないと落ち着かない)  
本書ではWATを書いてWASMに変換して動かしながらWASMの仕様を追っていくので、WASMだけを学べると思って読んでみました。

## まとめ

* 特にフレームワークを用いずにWATを書いてWASMに変換して、node/browserから動かせるようになりました
* WASMがスタックマシンとして動作していることがわかりました
* 現状のWASM(1.0)とJavascriptの役割分担がわかりました
* パフォーマンスのチューニングや、デバッグ方法についても書いてあります

## そもそもWASMとは

そもそもWebAssembly(WASM)とはなにかという話なのですが、以下のように定義されています。

WebAssemblyとは、スタックマシン用の仮想命令セットアーキテクチャ(Virtual ISA)。

> WebAssembly (abbreviated Wasm) is a binary instruction format for a stack-based virtual machine. Wasm is designed as a portable compilation target for programming languages, enabling deployment on the web for client and server applications.

https://webassembly.org/

スタックマシン用というのは、CPU命令にレジスターがでてこないという意味で、常に暗黙的に存在するグローバルなスタックを操作することでデータを処理していきます。

また、現時点のMVP(Minimum Viable Product) 1.0では、JavaScript(React,Vue)を置き換えるようなことはできないし、意図されてもいないそうです。  
このあたりもこれから見ていくのですが、WASMからDOMを操作できないのでjsを置き換えるというのはできなそうです。

## WATとは

WebAssembly Text(WAT)は、WASMのアセンブリ言語(のようなもの)です。  
WASM,WAT間で相互に変換できます。

## 準備

以下を準備します。  

* WASMの実行環境としてnode
* WATをWASMに変換するcli(`wat2wasm`)

```console
❯ node -v
v16.13.2
```

nodeはv16を利用しました、本書では`12.14.0`が前提となっています。  
余談ですが、nodeのversion管理はnvmからRust製の[fnm](https://github.com/Schniz/fnm)に切り替えました。  
nodeをinstallするとしたら以下のような感じです。

```console
❯ cargo install fnm
❯ fnm install v16.13.2
❯ fnm default v16.13.2
❯ eval "$(fnm env)"
```

次にWATをWASMに変換するための`wat2wasm`をinstallします。

```console
❯ npm install -g wat-wasm

❯ cat > file.wat  <<EOF
(module)
EOF

❯ wat2wasm file.wat

========================================================
  WAT2WASM
========================================================


  Need help?
  Contact Rick Battagline
  Twitter: @battagline
  https://wasmbook.com
  v1.0.43

no memory
Writing to file.wasm
WASM File Saved!
```

これでカレントディレクトリに`file.wasm`が生成されるので中身を見てみます。  
toolはなんでもよいのですが自分は`hexyl`を利用しています。(`cargo install hexyl`)

```console
❯ hexyl file.wasm
┌────────┬─────────────────────────┬─────────────────────────┬────────┬────────┐
│00000000│ 00 61 73 6d 01 00 00 00 ┊                         │0asm•000┊        │
└────────┴─────────────────────────┴─────────────────────────┴────────┴────────┘

```

[WASMのBinary Formatに関する仕様](https://webassembly.github.io/spec/core/binary/modules.html#binary-module)でmoduleは以下のように定義されています。

```text
magic   ::= 0x00 0x61 0x73 0x6D
version ::= 0x01 0x00 0x00 0x00
module  ::= magic
            version
            (省略)
```

ということで、先頭が`0asm`のMAGIC NUMBERで次の4byteがBinary Formatのversion 1になっています。(61=a, 73=s, 6d=m)    
[WASMはリトルエンディアン](https://webassembly.github.io/spec/core/binary/values.html#integers)なので、01が先頭にきていますね。  
WATをWASMに変換できていることが確認できれば準備完了です。

## WATのメンタルモデル

さっそくHello Worldに入りたいところなのですが、WASMにはString型のデータ構造がなかったり、組み込み環境(実行環境)とのimport/exportが最初はわかりづらかったりしたので、WATの書き方から見ていきます。

WATでは暗黙的なグローパルのスタックを操作することで演算や関数とのやり取りを行います。  
例えば定数の10と20を加算するには

```wat
i32.const 10 ;; [ 10 ]
i32.const 20 ;; [ 10 20 ]
i32.add      ;; [ 30 ]
```

のように書きます。各業の命令が実行されたあとのスタックの状態をコメントで書いてあります。  
レジスターを指定する命令がないのがスタックマシーン用ということなんだろうと思います。  
WATではもうひとつ、S expression(S式)という書き方がサポートされており、上記の加算は以下のようにも書けます。  

```wat
(i32.add (i32.const 10) (i32.const 20))
```
S式と通常の記法は混在させることができます。  
また、WASMの実行単位であるmoduleもひとつのS式として表現されます。

## Nodeからの動かし方

WATの書き方がなんとなくわかったのでnodeから動かしてみます。  
`node add.js 10 20`のように引数で与えられた数をWASMで加算して結果を表示する処理を作っていきます。  
[WATの推奨拡張子は`wat`らしいです](https://webassembly.github.io/spec/core/text/conventions.html#conventions)

`addInt.wat`
```wat
(module
    (func (export "addInt")                   ;; 1
    (param $value_1 i32) (param $value_2 i32) ;; 2
    (result i32)                              ;; 3

    local.get $value_1
    local.get $value_2
    i32.add                                   ;; 4
    )
)
```

まず、加算を行うWASM moduleを作成します。  
`(module)`はお決まりで必ず書きます。moduleはWASMにおける、[deploy,loading,compileの単位](https://webassembly.github.io/spec/core/syntax/modules.html#modules)です。
次にWASMでは関数単位で機能を定義していくので、jsから呼び出す関数を定義します。  

1. js側からこの関数を`addInt`として呼べるようになります。exportを変なところに定義するなと思うかもしれませんが、これは[syntactic sugar](https://webassembly.github.io/spec/core/text/modules.html#text-func-abbrev)のようです
2. 関数は二つのi32型の引数をとることを宣言しています。 
3. 関数はi32型の結果を戻り値として返すことを宣言しています。
4. `$value_1`と`$value_2`の加算結果をstackに残しておくことで結果を返します。

`wat2wasm addInt.wat`で``addInt.wasm`が生成できれば完了です。  
次にこのWASMを呼び出すjsを書きます。

`addInt.js`

```javascript
const fs = require('fs');

const bytes = fs.readFileSync(__dirname + '/addInt.wasm');           // 1
const value_1 = parseInt(process.argv[2]);
const value_2 = parseInt(process.argv[3]);

(async () => {
  const obj = await WebAssembly.instantiate(new Uint8Array(bytes));  // 2
  let add_value = obj.instance.exports.addInt(value_1, value_2);     // 3
  console.log(`${value_1} + ${value_2} = ${add_value}`);
})();
```

1. WASMをfileから読み込みます。browserの場合はここがfetch(ネットワーク越し)になります。
2. WASMをinstance化します。メンタルモデル的にはここで、読み込んだwasmのmoduleの初期化処理が走ります。
3. WASMからexportした関数は`instance.exports`に格納されているので呼び出します。

```console
❯ node addInt.js 1 2
1 + 2 = 3
```

jsからWASMを呼び出すことができました🎉  
このようにWASM側でexportした関数をjs側から呼び出すことで利用します。


## Browserからの動かし方

次にWASMをbrowserから実行してみます。  
WASMのbinaryを取得してinstantiateしたのちに、exportされた関数を呼び出すという基本的な流れは同じです。

まず、browserにWASMとhtmlをserveしたいので、http serverを建てられるようにします。(localのfileをserveできればなんでもよいです)

```console
❯ npm install --save-dev connect serve-static
```

次に以下の内容の`index.html`を作ります。

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name=”viewport” content=”width=device-width,initial-scale=1″>
    <title>Add Int</title>
    <script>
        let output = null;
        let addIntWasm;

        // 1
        let logAddInt = (a, b, sum) => {
            if (output == null) {
                console.log("page load not complete");
                return;
            }
            output.innerHTML += `${a} + ${b} = ${sum}<br>`;
        };

        // 2
        let importObject = {
            env: {
                logAddInt: logAddInt,
            }
        };

        (async () => {
            let obj = await WebAssembly.instantiateStreaming(fetch('addInt.wasm'), importObject); // 3
            addIntWasm = obj.instance.exports.addInt;                                             // 4
            let btn = document.getElementById("addIntButton");
            btn.style.display = "block";
        })();

        function onPageLoad() {
            (async () => {
                output = document.getElementById("output");
            })();
        }
    </script>
</head>
<body onLoad="onPageLoad()">
<input type="number" id="a_val" value="0"><br><br>
<input type="number" id="b_val" value="0"><br><br>
<button id="addIntButton" type="button" style="display:none"
        onclick="addIntWasm(
                document.getElementById('a_val').value,
                document.getElementById('b_val').value)">
    Add Values
</button>
<br>
<p id="output" style="float:left; width:200px; min-height:300px;">
</p>
</body>
</html>
```

1. `logAddInt`はjsからwasmに渡す関数です。wasmから呼ばれたら結果をDOMに追記していきます。
2. jsからwasmに渡すobjectです。`logAddInt`はwasm側と一致している必要があります。
3. wasmのinstance化です。binaryを`fetch()`で取得しています。第二引数でimport用のobjectを渡します。
4. jsからcallするwasmの関数です。buttonのonclickに設定します。

`addInt.wat`を以下のように変更します。

```wat
(module
    (import "env" "logAddInt" (func $logAddInt (param i32 i32 i32))) ;; 1
    (func (export "addInt")
    (param $value_1 i32) (param $value_2 i32)
    (local $sum i32)

    local.get $value_1
    local.get $value_2
    i32.add
    local.set $sum

    (call $logAddInt (local.get $value_1) (local.get $value_2) (local.get $sum)) ;; 2
    )
)
```

1. wasmが組み込み環境(実行環境/host環境)から取得する関数を宣言します。
2. importした関数の呼び出しです。

変更したら、`wat2wasm addInt.wat`でwasmに変換します。

最後にhtmlとwasmをserveするための`server.js`を作成します。

```javascript
const connect = require('connect');
const serveStatic = require('serve-static');
connect().use(serveStatic(__dirname+"/")).listen(8080, function() {
  console.log('localhost:8080');
});
```

これで以下のようにserverを起動したのちbrowserで`localhost:8080`にアクセスします。

```console
node server.js
```

[f:id:yamaguchi7073xtt:20220705044410p:plain]

このように組み込み環境(browser, node)とwasm間ではimport/exportをお互いの関数を呼び合うことができることが確かめられました。

## Hello World

WATをWASMに変換して組み込み環境(node,browser)から実行することができたので、Hello Worldをやってみます。  
まず以下のWATを作成します。

```wat
(module
    (import "env" "print_string" (func $print_string(param i32)))  ;; 1
    (import "env" "buffer" (memory 1))                             ;; 2
    (global $start_string (import "env" "start_string") i32)       ;; 3
    (global $string_len i32 (i32.const 12))
    (data (global.get $start_string) "hello world!")               ;; 4
    (func (export "helloworld")
        (call $print_string (global.get $string_len))              ;; 5
    )
)
```

1. WASMからI/Oをすることができないので、組み込み環境からhello world出力用の関数をimportします。
2. 線形メモリを利用することを宣言します。実際のメモリはjs側で確保してWASMに渡します。
3. 線形メモリのどの位置にhello world文字列を生成するかをjs側から指定します。
4. 指定された線形メモリ位置にUTF-8のbyte列を生成します。
5. importした文字列出力用関数に出力する文字列の長さを渡します。

jsとWASMの役割分担がややこしいですが以下のようになっています。

* js側
  * メモリ確保
  * 確保したメモリのどの位置にhello worldを出力するかを指定
  * 出力する文字列の長さを引数にとる関数をWASMに渡す
* WASM側
  * importしたメモリの指定された位置に"hello world" UTF-8 byte列を生成
  * 出力用関数に"hello world"の長さを引数にして呼び出す

js側は以下のように作成します。(`helloworld.js`)

```javascript
const fs = require('fs');
const bytes = fs.readFileSync(__dirname + '/helloworld.wasm')

let hello_world = null;
let start_string_index = 200;                       // 1
let memory = new WebAssembly.Memory({initial: 1});  // 2

let importObject = {
  env: {
    buffer: memory,                                 // 3
    start_string: start_string_index,
    print_string: function (str_len) {
      // 4  
      const bytes = new Uint8Array(memory.buffer,
          start_string_index,
          str_len);
      const log_string = new TextDecoder('utf8').decode(bytes);
      console.log(log_string);
    }
  }
};

(async () => {
  let obj = await WebAssembly.instantiate(new Uint8Array(bytes), importObject);
  ({helloworld: hello_world} = obj.instance.exports);
  hello_world();
})();
```

1. 開始200byte目にhello worldを出力することを指定
2. WASMに渡すメモリを確保します
3. 確保したメモリをWASMに渡します
4. 確保したメモリ位置をUTF8として解釈します

```console
❯ node helloworld.js
hello world!
```

無事、hello world!がWASMでできました🎉  
またここで登場した線形メモリ(`WebAssembly.Memory`)については6章で詳しく説明されています。  
自分の理解としてはWASMとjs間で共有できるBufferで、ページ(64KB)単位で確保するものと考えております。  
この線形メモリの実用的な利用例は最後のDOM操作でふれます。

## `is_prime`

Hello Worldが済んだので、WATの制御フロー(loop,if)を見ていきます。加算から一歩進んで、素数を判定するmoduleを作っていきます。  
まずWATからですが長くなるので少しつづみていきます。

```wat
(module
    ;; 偶数の判定
    (func $even_check (param $n i32) (result i32)
        local.get $n          ;; [ n ]
        i32.const 2           ;; [ n 2 ]
        i32.rem_u             ;; [ 0 ]   | [ 1 ] 
        i32.const 0           ;; [ 0 0 ] | [ 1 0 ]
        i32.eq ;; $n % 2 == 0 ;; [ 1 ] | [ 0 ] 
    )
)
```

helper関数として偶数を判定する`even_check`を定義します。  
コメントで命令実行後のスタックの様子を書いてあります。(`|`はまたはの意味です)  
WASMにはデータ型としてbooleanがなく0以外がtrue, 0がfalseとして扱われます。  
`rem_u`は除算の余りを出力します。

```wat
    ;; 2と等しいかの判定
    (func $eq_2 (param $n i32) (result i32)
        local.get $n
        i32.const 2
        i32.eq
    )
    ;; n = m * q. nがmの倍数かの判定。
    (func $multiple_check (param $n i32) (param $m i32) (result i32)
        local.get $n
        local.get $m
        i32.rem_u ;; $n % $m
        i32.const 0
        i32.eq
    )
```

次に2と等しいか判定する`eq_2`と第一引数が第二引数の倍数かを判定する`multiple_check`を定義します。

```wat
    ;; 素数の判定
    (func (export "is_prime") (param $n i32) (result i32)
        (local $i i32)

        ;; 1と等しいかの判定
        (if (i32.eq (local.get $n) (i32.const 1))
            (then
                i32.const 0
                return
            )
        )

        ;; 2と等しいかの判定
        (if (call $eq_2 (local.get $n))
            (then
                i32.const 1
                return
            )
        )

        (block $not_prime 
            (call $even_check (local.get $n))
            br_if $not_prime ;; 偶数なので素数ではない

            (local.set $i (i32.const 1))

            (loop $prime_test_loop
                ;; $i += 2
                ;; teeはsetと同じだがstackをpopしない
                (local.tee $i
                    (i32.add (local.get $i) (i32.const 2)))

                local.get $n ;; stack = [ $i $n ]

                i32.ge_u ;; $i >= $n
                if
                    ;; $nを調べきったので素数と判定
                    i32.const 1
                    return
                end
                ;; stack = [];

                ;; $nが$iの倍数なら素数ではない
                (call $multiple_check (local.get $n) (local.get $i))
                br_if $not_prime

                ;; loopを繰り返す
                br $prime_test_loop
            ) ;; $prime_test_loop end
        )
        ;; br $not_prime jump here
        i32.const 0
    )
```

ここで、条件分岐(`if`)とloopについて簡単に解説します。  
`if`は実行時のスタックの先頭を評価してtrue(0以外)なら`end`までの命令を実行します。ここでは利用していませんが`else`も書けます。  
blockは少々わかりづらいのですが、`br`(branch)命令でblockを抜け出すことができます。`br_if`はスタックの先頭を評価してtrueなら`br`する命令です。上の例では`br $not_prime`でblock分を抜け出すので結果的にfalse(0)が戻り値となります。  

loopも直感に反して自動ではloopしてくれません。明示的にloopの先頭にjumpする`br`命令を利用してはじめてloopできます。  
上の例では`br $prime_test_loop`でloopの先頭に戻ります。

`local.tee $i`は、スタックの先頭を`$i`に代入しつつ、その値をスタックに残します(出力します)  
loop制御用のindex変数をインクリメントしつつ、終了判定する場合によく使われていました。

このWATをWASMに変換して、呼び出すjsを作成します。

```javascript
const fs = require('fs');
const bytes = fs.readFileSync(__dirname + "/is_prime.wasm");
const value = parseInt(process.argv[2]);

(async () => {
  let obj = await WebAssembly.instantiate(new Uint8Array(bytes));
  if(!!obj.instance.exports.is_prime(value)) {
    console.log(`${value} is prime!`);
  } else {
    console.log(`${value} is NOT prime`);
  }
})();
```

```console
❯ node is_prime.js 57
57 is NOT prime
```

無事判定できました。

## DOM操作

最後にcanvasを操作する例を見ていきます。  
WASMからcanvasは操作できないので、canvasに描画するメモリをWASM側で操作してそれをjs側でレンダリングすることで実現します。  
ここで作るのは、ある移動する複数のオブジェクトをレンダリングし、オブジェクド同士が衝突しているかを判定するWASMです。  
オブジェクトはx,y座標とx,yそれぞれの速度を保持します。  
WASMはcanvasに描画されるメモリ領域とオブジェクトの状態を管理する領域を管理します。  

{{ figure(caption="メモリ領域の概要", images=["images/wasm_memory_overview.png"] )}}

まず、htmlは以下のようになります。

`collide.html`
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="widh=device-width,initial-scale=1.0">
  <title>Collision Detection</title>
</head>
<body>
  <canvas id="cnvs" width="512" height="512"></canvas>
  <script>
    const cnvs_size = 512;
    const no_hit_color = 0xff_00_ff_00 // green
    const hit_color = 0xff_00_00_ff; // red

    const pixel_count = cnvs_size * cnvs_size;

    const canvas = document.getElementById("cnvs");
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0,0,512,512);

    const obj_start = pixel_count * 4;
    const obj_start_32 = pixel_count;
    const obj_size = 4;
    const obj_cnt = 3000;
    const stride_bytes = 16;

    const x_offset = 0;
    const y_offset = 4;
    const xv_offset = 8;
    const yv_offset = 12;

    const memory = new WebAssembly.Memory({ initial: 80 });
    const mem_i8 = new Uint8Array(memory.buffer);
    const mem_i32 = new Uint32Array(memory.buffer);

    const importObject = {
      env: {
        buffer: memory,

        cnvs_size: cnvs_size,
        no_hit_color: no_hit_color,
        hit_color: hit_color,
        obj_start: obj_start,
        obj_cnt: obj_cnt,
        obj_size: obj_size,

        x_offset: x_offset,
        y_offset: y_offset,
        xv_offset: xv_offset,
        yv_offset: yv_offset,
      }
    };

    const image_data = new ImageData(
        new Uint8ClampedArray(memory.buffer, 0, obj_start), cnvs_size, cnvs_size
    );

    const stride_i32 = stride_bytes / 4;
    for (let i = 0; i < obj_cnt * stride_i32; i += stride_i32) {
      let temp = Math.floor(Math.random() * cnvs_size);
      mem_i32[obj_start_32+i] = temp;

      temp = Math.floor(Math.random() * cnvs_size);
      mem_i32[obj_start_32+i + 1] = temp;

      temp = (Math.round(Math.random() * 4) -2 )
      mem_i32[obj_start_32 + i + 2] = temp;

      temp = (Math.round(Math.random() * 4) -2 )
      mem_i32[obj_start_32 + i + 3] = temp;
    }

    let animation_wasm;
    function animate() {
      animation_wasm();
      ctx.putImageData(image_data, 0,0);
      requestAnimationFrame(animate);
    }

    (async () => {
      let obj = await WebAssembly.instantiateStreaming(fetch('collide.wasm'), importObject);
      animation_wasm = obj.instance.exports.main;
      requestAnimationFrame(animate);
    })();

  </script>
</body>
</html>
```

canvasのframeを描画するたびに、WASM側の`main`を呼び出します。  
WASM側は`main`の中で二つのことを行います。  

1. objectの状態変更
2. canvasの描画領域の更新

WATは以下のようになります。

```wat
(module
    (global $cnvs_size (import "env" "cnvs_size") i32)

    (global $no_hit_color (import "env" "no_hit_color") i32)
    (global $hit_color (import "env" "hit_color") i32)
    (global $obj_start (import "env" "obj_start") i32)
    (global $obj_size (import "env" "obj_size") i32)
    (global $obj_cnt (import "env" "obj_cnt") i32)

    (global $x_offset (import "env" "x_offset") i32)
    (global $y_offset (import "env" "y_offset") i32)
    (global $xv_offset (import "env" "xv_offset") i32)
    (global $yv_offset (import "env" "yv_offset") i32)
    (import "env" "buffer" (memory 80))

    (func $clear_canvas
        (local $i i32)
        (local $pixel_bytes i32)

        global.get $cnvs_size
        global.get $cnvs_size
        i32.mul

        i32.const 4
        i32.mul

        local.set $pixel_bytes;; $pixel_bytes = $width * $height * 4

        (loop $pixel_loop
            (i32.store (local.get $i) (i32.const 0xff_00_00_00))

            (i32.add (local.get $i) (i32.const 4))
            local.set $i ;; $i += 4

            (i32.lt_u (local.get $i) (local.get $pixel_bytes))
            br_if $pixel_loop
        )
    )

    (func $abs
        (param $value i32)
        (result i32)

        (i32.lt_s (local.get $value) (i32.const 0))
        if
            i32.const 0
            local.get $value
            i32.sub
            return
        end
        local.get $value
    )

    (func $set_pixel
        (param $x i32)
        (param $y i32)
        (param $c i32)

        (i32.ge_u (local.get $x) (global.get $cnvs_size))
        if
            return
        end

        (i32.ge_u (local.get $y) (global.get $cnvs_size))
        if
            return
        end

        local.get $y
        global.get $cnvs_size
        i32.mul
        local.get $x
        i32.add

        i32.const 4
        i32.mul

        local.get $c
        i32.store
    )

    (func $draw_obj
        (param $x i32)
        (param $y i32)
        (param $c i32)

        (local $max_x i32)
        (local $max_y i32)

        (local $xi i32)
        (local $yi i32)

        local.get $x
        local.tee $xi

        global.get $obj_size
        i32.add
        local.set $max_x

        local.get $y
        local.tee $yi
        global.get $obj_size
        i32.add
        local.set $max_y

        (block $break (loop $draw_loop
            local.get $xi
            local.get $yi
            local.get $c
            call $set_pixel

            local.get $xi
            i32.const 1
            i32.add
            local.tee $xi

            local.get $max_x
            i32.ge_u

            if
                local.get $x
                local.set $xi

                local.get $yi
                i32.const 1
                i32.add
                local.tee $yi

                local.get $max_y
                i32.ge_u
                br_if $break
            end

            br $draw_loop
        ))
    )

    (func $set_obj_attr
        (param $obj_number i32)
        (param $attr_offset i32)
        (param $value i32)

        local.get $obj_number
        i32.const 16
        i32.mul

        global.get $obj_start
        i32.add
        local.get $attr_offset
        i32.add

        local.get $value
        i32.store
    )

    (func $get_obj_attr
        (param $obj_number i32)
        (param $attr_offset i32)
        (result i32)

        local.get $obj_number
        i32.const 16
        i32.mul

        global.get $obj_start
        i32.add
        local.get $attr_offset
        i32.add

        i32.load
    )

    (func $main (export "main")
        (local $i i32)
        (local $j i32)
        (local $outer_ptr i32)
        (local $inner_ptr i32)

        (local $x1 i32)
        (local $x2 i32)
        (local $y1 i32)
        (local $y2 i32)

        (local $xdist i32)
        (local $ydist i32)

        (local $i_hit i32)
        (local $xv i32)
        (local $yv i32)

        (call $clear_canvas)

        (loop $move_loop
            (call $get_obj_attr (local.get $i) (global.get $x_offset))
            local.set $x1

            (call $get_obj_attr (local.get $i) (global.get $y_offset))
            local.set $y1

            (call $get_obj_attr (local.get $i) (global.get $xv_offset))
            local.set $xv

            (call $get_obj_attr (local.get $i) (global.get $yv_offset))
            local.set $yv

            (i32.add (local.get $xv) (local.get $x1))
            i32.const 0x1ff ;; 511
            i32.and
            local.set $x1

            (i32.add (local.get $yv) (local.get $y1))
            i32.const 0x1ff ;; 511
            i32.and
            local.set $y1

            (call $set_obj_attr
                (local.get $i)
                (global.get $x_offset)
                (local.get $x1)
            )

            (call $set_obj_attr
                (local.get $i)
                (global.get $y_offset)
                (local.get $y1)
            )

            local.get $i
            i32.const 1
            i32.add
            local.tee $i
            global.get $obj_cnt
            i32.lt_u
            if
                br $move_loop
            end
        )

        i32.const 0
        local.set $i

        (loop $outer_loop (block $outer_break
            i32.const 0
            local.tee $j

            local.set $i_hit

            (call $get_obj_attr (local.get $i) (global.get $x_offset))
            local.set $x1

            (call $get_obj_attr (local.get $i) (global.get $y_offset))
            local.set $y1

            (loop $inner_loop (block $inner_break
                local.get $i
                local.get $j
                i32.eq

                if
                    local.get $j
                    i32.const 1
                    i32.add
                    local.set $j
                end

                local.get $j
                global.get $obj_cnt
                i32.ge_u
                if
                    br $inner_break
                end

                (call $get_obj_attr (local.get $j) (global.get $x_offset))
                local.set $x2
                (i32.sub (local.get $x1) (local.get $x2))
                call $abs
                local.tee $xdist

                global.get $obj_size
                i32.ge_u

                ;; 衝突していない
                if
                    local.get $j
                    i32.const 1
                    i32.add
                    local.set $j
                    br $inner_loop
                end

                (call $get_obj_attr (local.get $j) (global.get $y_offset))
                local.set $y2
                (i32.sub (local.get $y1) (local.get $y2))
                call $abs
                local.tee $ydist

                global.get $obj_size
                i32.ge_u

                ;; 衝突していない
                if
                    local.get $j
                    i32.const 1
                    i32.add
                    local.set $j
                    br $inner_loop
                end

                i32.const 1
                local.set $i_hit
            ))

            local.get $i_hit
            i32.const 0
            i32.eq
            if
                (call $draw_obj
                    (local.get $x1) (local.get $y1) (global.get $no_hit_color))
            else
                (call $draw_obj
                    (local.get $x1) (local.get $y1) (global.get $hit_color))
            end

            local.get $i
            i32.const 1
            i32.add
            local.tee $i
            global.get $obj_cnt
            i32.lt_u
            if
                br $outer_loop
            end
        ))
    )
)
```

長いですが、最後の`main`から見ていくととても単純な処理をしているだけなのがわかります。  

```wat
    (func $main (export "main")
        (local $i i32)
        (local $j i32)

        (local $x1 i32)
        (local $x2 i32)
        (local $y1 i32)
        (local $y2 i32)

        (local $xdist i32)
        (local $ydist i32)

        (local $i_hit i32)
        (local $xv i32)
        (local $yv i32)

        (call $clear_canvas)
```

まず、必要なlocal変数を宣言します。  
Frame毎に各オブジェクトの状態を更新するので、`$i`は現在の処理対象のオブジェクトのindexです。`$j`は各オブジェクトとの衝突判定をするためのinner loopのindexです。  
最初に`$clear_canvas`を呼び出してレンダリング領域をリセットします。

```wat
    (func $clear_canvas
        (local $i i32)
        (local $pixel_bytes i32)

        global.get $cnvs_size
        global.get $cnvs_size
        i32.mul

        i32.const 4
        i32.mul

        local.set $pixel_bytes;; $pixel_bytes = $width * $height * 4

        (loop $pixel_loop
            (i32.store (local.get $i) (i32.const 0xff_00_00_00))

            (i32.add (local.get $i) (i32.const 4))
            local.set $i ;; $i += 4

            (i32.lt_u (local.get $i) (local.get $pixel_bytes))
            br_if $pixel_loop
        )
    )
```

1pixel 4byteなので4byteずつインクリメントしながら、黒色(`0xff_00_00_00`)にしていきます。  
次に
```wat
        (loop $move_loop
            (call $get_obj_attr (local.get $i) (global.get $x_offset))
            local.set $x1

            (call $get_obj_attr (local.get $i) (global.get $y_offset))
            local.set $y1

            (call $get_obj_attr (local.get $i) (global.get $xv_offset))
            local.set $xv

            (call $get_obj_attr (local.get $i) (global.get $yv_offset))
            local.set $yv

            (i32.add (local.get $xv) (local.get $x1))
            i32.const 0x1ff ;; 511
            i32.and
            local.set $x1

            (i32.add (local.get $yv) (local.get $y1))
            i32.const 0x1ff ;; 511
            i32.and
            local.set $y1

            (call $set_obj_attr
                (local.get $i)
                (global.get $x_offset)
                (local.get $x1)
            )

            (call $set_obj_attr
                (local.get $i)
                (global.get $y_offset)
                (local.get $y1)
            )

            local.get $i
            i32.const 1
            i32.add
            local.tee $i
            global.get $obj_cnt
            i32.lt_u
            if
                br $move_loop
            end
        )
```

処理対象のオブジェクトの`x,y,xv,xy`を取得して、それぞれの速度を加算したのち、メモリを更新します。  
`0x1ff`とandをとることで、描画領域をはみでたオブジェクトの位置がリセットされるようになっています。  
ビット演算でこんなことができるのかと思いました。本書ではビット演算についても丁寧に解説されております。  
ここまでで、frameの描画毎にオブジェクトの位置情報が更新されることがわかりました。  
最後に、オブジェクトの衝突判定を行い、描画領域を更新します。

```wat
        i32.const 0
        local.set $i

        (loop $outer_loop (block $outer_break
            i32.const 0
            local.tee $j

            local.set $i_hit

            (call $get_obj_attr (local.get $i) (global.get $x_offset))
            local.set $x1

            (call $get_obj_attr (local.get $i) (global.get $y_offset))
            local.set $y1

            (loop $inner_loop (block $inner_break
                local.get $i
                local.get $j
                i32.eq

                if
                    local.get $j
                    i32.const 1
                    i32.add
                    local.set $j
                end

                local.get $j
                global.get $obj_cnt
                i32.ge_u
                if
                    br $inner_break
                end

                (call $get_obj_attr (local.get $j) (global.get $x_offset))
                local.set $x2
                (i32.sub (local.get $x1) (local.get $x2))
                call $abs
                local.tee $xdist

                global.get $obj_size
                i32.ge_u

                ;; 衝突していない
                if
                    local.get $j
                    i32.const 1
                    i32.add
                    local.set $j
                    br $inner_loop
                end

                (call $get_obj_attr (local.get $j) (global.get $y_offset))
                local.set $y2
                (i32.sub (local.get $y1) (local.get $y2))
                call $abs
                local.tee $ydist

                global.get $obj_size
                i32.ge_u

                ;; 衝突していない
                if
                    local.get $j
                    i32.const 1
                    i32.add
                    local.set $j
                    br $inner_loop
                end

                i32.const 1
                local.set $i_hit
            ))

            local.get $i_hit
            i32.const 0
            i32.eq
            if
                (call $draw_obj
                    (local.get $x1) (local.get $y1) (global.get $no_hit_color))
            else
                (call $draw_obj
                    (local.get $x1) (local.get $y1) (global.get $hit_color))
            end

            local.get $i
            i32.const 1
            i32.add
            local.tee $i
            global.get $obj_cnt
            i32.lt_u
            if
                br $outer_loop
            end
        ))
```

オブジェクトの衝突判定は`|x1 - x2|` < `object_size` かつ `|y1 - y2| < object_size`で判定します。 
WATをWASMに変換して
```console
node server.js
```
を実行して、`localhost:8080/collide.html`にアクセスしてみると以下のように描画されました🎉

{{ figure(caption="完成", images=["images/wasm_object_collision.gif"] )}}


## ふれられなかったこと

本記事ではふれられませんでしたが、本書ではさらにここからWASMのパフォーマンスチューニングやデバッグをおこなうための実用的な知識が述べられております。

