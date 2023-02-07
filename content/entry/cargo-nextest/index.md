+++
title = "📦 cargo-nextestの使い方と仕組み"
slug = "cargo-nextest"
date = "2022-03-17"
draft = false
[taxonomies]
tags = ["rust"]
+++

この記事では以下の点について書きます。
  
* [cargo-nextest](https://nexte.st/)の使い方
* ソースを読んで理解できた範囲内で仕組みの解説

# cargo-nextestの使い方

まずは使い方を見ていきます。🚀

## 概要

cargo-nextestはRustのTest Runnerです。  
`cargo test`を実行していたところで、`cargo nextest run`を実行することで利用します。  
[専用のwebpage](https://nexte.st/)もあります。
`cargo test`との最大の違いはtest caseごとに並列に実行するところです。


[The nextest model](https://nexte.st/book/how-it-works.html#the-nextest-model)でも仕組みについて述べられているのですが、いまいち理解できなかったのがソース読んでみたきっかけです。  
内部的には`cargo test`でtest binaryを生成しているので、実行されるtest自体は変わりません。

## Install

Installするには`cargo install`を使うか直接binaryを持ってきます。
```sh
cargo install cargo-nextest
```

```sh
# linux
curl -LsSF https://get.nexte.st/latest/linux | tar zxf - -C ${CARGO_HOME:-~/.cargo}/bin

# mac
curl -LsSf https://get.nexte.st/latest/mac | tar zxf - -C ${CARGO_HOME:-~/.cargo}/bin
```



[Nextest installation](https://nexte.st/book/installation.html)



## Testの実行

testの実行方法は`cargo test`と変わりません。`cargo test`でサポートされているoptionsはnextestでもサポートされています。

```sh
cargo nextest run

# run specified test
cargo nextest run aaa::a01
# or
cargo nextest run aaa::a01 aaa::a02

# show stdout
cargo nextest run --no-capture
```

`--no-capture`には`--nocapture` aliasが設定されているので従来通り、`cargo nextest run --nocapture`でも動きます。  
cargo自体のoptionとtest binaryに渡すoptionの違いを意識しなくてよくなっています。

### Retry Flaky Test

実行結果が不安定なtestをflakyなtestというらしいです(知りませんでした)。  
`--retry` optionを付与すると失敗したtestを再実行してくれ、retry時に成功すればコマンドの実行自体が成功になります。

```sh
cargo nextest run --retries 1
    Finished test [unoptimized + debuginfo] target(s) in 0.01s
    Starting 4 tests across 2 binaries
        PASS [   0.004s] nextest-handson aaa::a01::tests::aaa
        PASS [   0.004s] nextest-handson aaa::a02::tests::aaa
        PASS [   0.005s] nextest-handson tests::case_1
   1/2 RETRY [   0.006s] nextest-handson flaky::tests::rand

--- TRY 1 STDOUT:        nextest-handson flaky::tests::rand ---

running 1 test
test flaky::tests::rand ... FAILED

failures:

failures:
    flaky::tests::rand

test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 2 filtered out; finished in 0.00s


--- TRY 1 STDERR:        nextest-handson flaky::tests::rand ---
thread 'flaky::tests::rand' panicked at 'assertion failed: false', src/flaky.rs:8:13
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace

  TRY 2 PASS [   0.003s] nextest-handson flaky::tests::rand
     Summary [   0.009s] 4 tests run: 4 passed (1 flaky), 0 skipped
```
retry + 1回が都合実行される回数です。

### Partitioning Test

一度の実行でtest caseの一部のみを対象にできます。CIでtest jobを並列化させればテスト時間の短縮が狙えそうです。  
`--partition count:1/2`や`--partition hash:1/3`のように指定します。  
countとhashの違いは、countはtest caseに順番に番号を振って分類していくので、今まで`count:1/3`で実行されていたcaseがcaseの追加によって`count:2/3`で実行されるようになる場合があることです。hashはtest caseの名前でhashをとって分類するので、caseが追加されても分類が変動しません。

```sh
❯ cargo nextest run --partition count:1/2
    Finished test [unoptimized + debuginfo] target(s) in 0.00s
    Starting 3 tests across 2 binaries (1 skipped)
        PASS [   0.004s] nextest-handson aaa::a01::tests::aaa
        PASS [   0.004s] nextest-handson tests::case_1
        PASS [   0.004s] nextest-handson flaky::tests::rand
     Summary [   0.006s] 3 tests run: 3 passed, 1 skipped

❯ cargo nextest run --partition count:2/2
    Finished test [unoptimized + debuginfo] target(s) in 0.00s
    Starting 1 tests across 2 binaries (3 skipped)
        PASS [   0.003s] nextest-handson aaa::a02::tests::aaa
     Summary [   0.003s] 1 tests run: 1 passed, 3 skipped
```

## Testの一覧表示

実行するtest caseをtest binaryごとに表示できます。

```sh
❯ cargo nextest list       
    Finished test [unoptimized + debuginfo] target(s) in 0.01s
nextest-handson::integ_a:
    case_1
nextest-handson::integ_b:
    case_1
nextest-handson::bin/nextest-handson:
    (no tests)
nextest-handson:
    aaa::a01::tests::aaa
    aaa::a02::tests::aaa
    flaky::tests::rand
```

## Config

設定ファイルはwork space rootの`.config/nextest.yaml`に置きます。  
[defaultのconfig](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/default-config.toml)はbinaryに[埋め込まれている](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/config.rs#L37)のでなくても動きます。


### Profile

test実行時にprofileを指定でき、適用される設定群を変更することができます。localとCI用を用意したり等。

```toml
[profile.ci]
# Print out output for failing tests as soon as they fail, and also at the end
# of the run (for easy scrollability).
failure-output = "immediate-final"
# Do not cancel the test run on the first failure.
fail-fast = false
```
上記はCI時には失敗したtestのstdout/stderrを最後に表示し、test caseが失敗しても最後まで実行し切るような設定です。  
`cargo nextest run --profile ci` で適用できます。

## Github Actions

Github Actionsに組み込むのも非常に簡単です。  
`.github/workflows/ci.yaml`

```yaml
name: ci
on: push
jobs:
  test:
    name: Test
    runs-on: ubuntu-20.04
    steps:
    - name: Checkout
      uses: actions/checkout@v2
    - name: Install nextest
      shell: bash
      run: |
        curl -LsSf https://get.nexte.st/latest/linux | tar zxf - -C ${CARGO_HOME:-~/.cargo}/bin
    - name: Run test
      uses: actions-rs/cargo@v1
      with:
        command: nextest
        args: run
    # or
    - name: Run test without action
      run: cargo nextest run --profile ci --retries 1
```

[専用のaction](https://nexte.st/book/pre-built-binaries.html#using-nextest-in-github-actions)もできたらしいです。

# cargo-nextestの仕組み

ここまで簡単にcargo-nextestの使い方をみてきました。以降はこれらの機能がどうやって実現されているのかをソース読みながら追っていきます。  
ソースは本記事を書いてる時の[最新のmain](https://github.com/nextest-rs/nextest/tree/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5)を対象にしています。

出力のexampleで利用するdirectory構成は以下のようになっています。
```sh
❯ exa -T  src tests
src
├── aaa
│  ├── a01.rs
│  └── a02.rs
├── aaa.rs
├── flaky.rs
├── lib.rs
└── main.rs
tests
├── integ_a.rs
└── integ_b.rs
```



## `cargo nextest list`
`cargo nextest run`でもlistの機能を利用するので、まずはlistからみていきます。  

```sh
❯ cargo nextest list
    Finished test [unoptimized + debuginfo] target(s) in 0.03s
nextest-handson::integ_a:
    case_1
nextest-handson::integ_b:
    case_1
nextest-handson::bin/nextest-handson:
    (no tests)
nextest-handson:
    aaa::a01::tests::aaa
    aaa::a02::tests::aaa
    flaky::tests::rand

```
listはtest binaryごとのtest caseを表示してくれるので、これがどうやって表示されるのかを理解するのがゴールです。  
まず、`cargo nextest list`を実行するとclapのcli parse処理を行い、[`App:exec_list()`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L530)が実行されます。

```rust
impl AppOpts {
    /// Execute the command.
    fn exec(self, output_writer: &mut OutputWriter) -> Result<()> {
        match self.command {
            Command::List {
                build_filter,
                message_format,
                list_type,
                reuse_build,
            } => {
                let app = App::new(
                    self.output,
                    reuse_build,
                    build_filter,
                    self.config_opts,
                    self.manifest_path,
                )?;
                app.exec_list(message_format, list_type, output_writer)
            }
           // ...
            }
        }
    }
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L93](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L93)


### `App::exec_list()`

[`App::exec_list()`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L530)では`BinaryList`を`App::build_binary_list()`で生成して、`--list-type` optionの値に応じて表示処理を実行します。

```rust
fn exec_list(
        &self,
        message_format: MessageFormatOpts,
        list_type: ListType,
        output_writer: &mut OutputWriter,
    ) -> Result<()> {
        let binary_list = self.build_binary_list()?;

        match list_type {
            ListType::BinariesOnly => {
                let mut writer = output_writer.stdout_writer();
                binary_list.write(
                    message_format.to_output_format(self.output.verbose),
                    &mut writer,
                    self.output.color.should_colorize(Stream::Stdout),
                )?;
                writer.flush()?;
            }
            ListType::Full => {
                let target_runner = self.load_runner();
                let test_list = self.build_test_list(binary_list, &target_runner)?;

                let mut writer = output_writer.stdout_writer();
                test_list.write(
                    message_format.to_output_format(self.output.verbose),
                    &mut writer,
                    self.output.color.should_colorize(Stream::Stdout),
                )?;
                writer.flush()?;
            }
        }
        Ok(())
    }
```

`BinaryList`は`RustTestBinary`のVecを保持しており、`RustTestBinary`は`cargo test`がbuildしたtest binaryを表しています。  
test binaryはpackageのlib(lib.rs), あればbin(main.rs)と`tests`以下のそれぞれのfileごとに生成されます。
```rust
pub struct BinaryList {
    /// The list of test binaries.
    pub rust_binaries: Vec<RustTestBinary>,
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L75](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L75)

```rust
/// A Rust test binary built by Cargo.
pub struct RustTestBinary {
    /// A unique ID.
    pub id: String,
    /// The path to the binary artifact.
    pub path: Utf8PathBuf,
    /// The package this artifact belongs to.
    pub package_id: String,
    /// The unique binary name defined in `Cargo.toml` or inferred by the filename.
    pub name: String,
    /// Platform for which this binary was built.
    /// (Proc-macro tests are built for the host.)
    pub build_platform: BuildPlatform,
}
```
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L59](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L59)


cargo-nextestでのfile pathは`std::path::{Path,PathBuf}`でなく、[camino](https://docs.rs/camino/latest/camino/)の`camino::{Utf8Path, Utf8PathBuf}`が利用されております。  
これはfile pathがutf8であることを保証してくれる型です。 
`id`はbinaryの識別子で、上記のlist実行結果でいうと`nextest-handson::integ_a`や`nextest-handson:bin/nextest-handson`のような値をとります。  

ということでまずは、test対象のbinaryと関連するメタデータ(package_id, executable path,...)の一覧を取得する処理をみていきます。

### `TestBuildFilter::compute_test_list()`

まず、[`App::build_binary_list()`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L481) -> [`TestBuildFilter::compute_binary_list()`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L309)ときます。

[`TestBuildFilter`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L267)はtest対象のfilterling関連のcli optionを保持する型です。

```rust
#[derive(Debug, Args)]
#[clap(next_help_heading = "FILTER OPTIONS")]
struct TestBuildFilter {
    #[clap(flatten)]
    cargo_options: CargoOptions,

    /// Run ignored tests
    #[clap(long, possible_values = RunIgnored::variants(), default_value_t, value_name = "WHICH")]
    run_ignored: RunIgnored,

    /// Test partition, e.g. hash:1/2 or count:2/3
    #[clap(long)]
    partition: Option<PartitionerBuilder>,

    /// Filter test binaries by build platform
    #[clap(long, arg_enum, value_name = "PLATFORM", default_value_t)]
    pub(crate) platform_filter: PlatformFilterOpts,

    // TODO: add regex-based filtering in the future?
    /// Test name filter
    #[clap(name = "FILTERS", help_heading = None)]
    filter: Vec<String>,
}
```
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L267](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L267)

余談ですが、clap v3がリリースされ、structoptのderiveと統合されて非常に好きです。  
`#[clap(next_help_heading = "FILTER OPTIONS"]`と指定してあるので、
`cargo nextest list --help`を実行した時の
```sh
FILTER OPTIONS:
        --run-ignored <WHICH>
            Run ignored tests
            
            [default: default]
            [possible values: default, ignored-only, all]

        --partition <PARTITION>
            Test partition, e.g. hash:1/2 or count:2/3

        --platform-filter <PLATFORM>
            Filter test binaries by build platform
            
            [default: any]
            [possible values: target, host, any]
```
に対応してることがわかります。  
また、[`CargoPotions`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/cargo_cli.rs#L14)を定義して、`cargo test`で利用できるoptionsを自前で管理して`cargo test`に渡しています。

肝心の`TestBuildFilter::compute_binary_list()`ですが以下のように定義されております。

```rust
fn compute_binary_list(
        &self,
        graph: &PackageGraph,
        manifest_path: Option<&Utf8Path>,
        output: OutputContext,
    ) -> Result<BinaryList> {
        // Don't use the manifest path from the graph to ensure that if the user cd's into a
        // particular crate and runs cargo nextest, then it behaves identically to cargo test.
        let mut cargo_cli = CargoCli::new("test", manifest_path, output);

        // Only build tests in the cargo test invocation, do not run them.
        cargo_cli.add_args(["--no-run", "--message-format", "json-render-diagnostics"]);
        cargo_cli.add_options(&self.cargo_options);

        let expression = cargo_cli.to_expression();
        let output = expression
            .stdout_capture()
            .unchecked()
            .run()
            .wrap_err("failed to build tests")?;
        if !output.status.success() {
            return Err(Report::new(ExpectedError::build_failed(
                cargo_cli.all_args(),
                output.status.code(),
            )));
        }

        let test_binaries = BinaryList::from_messages(Cursor::new(output.stdout), graph)?;
        Ok(test_binaries)
    }
```
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L309](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L309)


`CargoCli`は`cargo`コマンドを別プロセスで実行するためのwrapperです。(内部的には[`duct::cmd()`](https://docs.rs/duct/latest/duct/)を利用しています)。
ここでは、`cargo --color=auto test --no-run --message-format json-render-diagnostics`コマンドを実行しています。  
`cargo test`に`--no-run`を付与するとtestを実行せずtest binaryのbuildだけが行われ、`--message-format`を付与すると、build結果をstdoutに出力してくれます。
試しに実行してみると
```
{"reason":"compiler-artifact","package_id":"libc 0.2.118 (registry+https://github.com/rust-lang/crates.io-index)","manifest_path":"/Users/ymgyt/.cargo/registr
        y/src/github.com-1ecc6299db9ec823/libc-0.2.118/Cargo.toml","target":{"kind":["custom-build"],"crate_types":["bin"],"name":"build-script-build","src_path":"/Us
        ers/ymgyt/.cargo/registry/src/github.com-1ecc6299db9ec823/libc-0.2.118/build.rs","edition":"2015","doc":false,"doctest":false,"test":false},"profile":{"opt_le
        vel":"0","debuginfo":2,"debug_assertions":true,"overflow_checks":true,"test":false},"features":[],"filenames":["/Users/ymgyt/ws/handson/rust/nextest-handson/t
        arget/debug/build/libc-83a03a0b79ece1f7/build-script-build"],"executable":null,"fresh":true}
```
のようなjsonが複数行出力されます。  
どうやら、`cargo test`コマンドの出力からbuildされたtest binaryの情報を取得していそうです。

### PackageGraph

`cargo --color=auto test --no-run --message-format json-render-diagnostics`の出力結果のparse処理の前にスルーしていた`PackageGraph`についてふれます。  
`list`,`run`コマンド共通で[`App::new()`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L443)実行時にtest対象packageのmeta dataを取得する[`guppy::PackageGraph`](https://github.com/facebookincubator/cargo-guppy/blob/c0549a91c8a4aab2182a78f0c7bf8d1c294b78ec/guppy/src/graph/graph_impl.rs#L40)生成処理があります。

`PackageGraph`の生成処理は

```rust
fn acquire_graph_data(manifest_path: Option<&Utf8Path>, output: OutputContext) -> Result<String> {
    let mut cargo_cli = CargoCli::new("metadata", manifest_path, output);
    // Construct a package graph with --no-deps since we don't need full dependency
    // information.
    cargo_cli.add_args(["--format-version=1", "--all-features", "--no-deps"]);

    // Capture stdout but not stderr.
    let output = cargo_cli
        .to_expression()
        .stdout_capture()
        .unchecked()
        .run()
        .wrap_err("cargo metadata execution failed")?;
    if !output.status.success() {
        return Err(ExpectedError::cargo_metadata_failed().into());
    }

    let json =
        String::from_utf8(output.stdout).wrap_err("cargo metadata output is invalid UTF-8")?;
    Ok(json)
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L607](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L607)


で、`cargo --color=auto metadata --format-version=1 --all-features --no-deps` コマンドを実行しpackageのmetadataを取得しそれをparseします。`--no-deps`を付与しているのでdependenciesの情報は出力されず、test対象の自packageの情報のみ取得します。

実行してみると以下のようなjsonが出力されました。
```sh
❯ cargo --color=auto metadata --format-version=1 --all-features --no-deps
{"packages":[{"name":"nextest-handson","version":"0.1.0","id":"nextest-handson 0.1.0 (path+file:///Users/ymgyt/ws/handson/rust/nextest-handson)","license":null,"license_file":null,"description":null,"source":null,"dependencies":[{"name":"rand","source":"registry+https://github.com/rust-lang/crates.io-index","req":"^0.8.5","kind":"dev","rename":null,"optional":false,"uses_default_features":true,"features":[],"target":null,"registry":null}],"targets":[{"kind":["lib"],"crate_types":["lib"],"name":"nextest-handson","src_path":"/Users/ymgyt/ws/handson/rust/nextest-handson/src/lib.rs","edition":"2021","doc":true,"doctest":true,"test":true},{"kind":["bin"],"crate_types":["bin"],"name":"nextest-handson","src_path":"/Users/ymgyt/ws/handson/rust/nextest-handson/src/main.rs","edition":"2021","doc":true,"doctest":false,"test":true},{"kind":["test"],"crate_types":["bin"],"name":"integ_a","src_path":"/Users/ymgyt/ws/handson/rust/nextest-handson/tests/integ_a.rs","edition":"2021","doc":false,"doctest":false,"test":true},{"kind":["test"],"crate_types":["bin"],"name":"integ_b","src_path":"/Users/ymgyt/ws/handson/rust/nextest-handson/tests/integ_b.rs","edition":"2021","doc":false,"doctest":false,"test":true}],"features":{},"manifest_path":"/Users/ymgyt/ws/handson/rust/nextest-handson/Cargo.toml","metadata":null,"publish":null,"authors":[],"categories":[],"keywords":[],"readme":"README.md","repository":null,"homepage":null,"documentation":null,"edition":"2021","links":null,"default_run":null,"rust_version":null}],"workspace_members":["nextest-handson 0.1.0 (path+file:///Users/ymgyt/ws/handson/rust/nextest-handson)"],"resolve":null,"target_directory":"/Users/ymgyt/ws/handson/rust/nextest-handson/target","version":1,"workspace_root":"/Users/ymgyt/ws/handson/rust/nextest-handson","metadata":null}
```

この出力から`PackageGraph`を生成します。
`let graph = guppy::CargoMetadata::parse_json(&graph_data)?.build_graph();`
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L457]

`PacakgeGraph`については詳しく触れられないのですが、イメージとしてはpackage_id(`Cargo.tomlの[pakcage.name])を渡すと`Cargo.toml`に書いてある情報を返してくれるくらいの理解です。


### `BinaryList::from_messages()` 

回り道をしてしまいましたが、`cargo --color=auto test --no-run --message-format json-render-diagnostics`の出力結果から`BinaryList`を生成する処理をみていきます。

```rust
impl BinaryList {
    /// Parses Cargo messages from the given `BufRead` and returns a list of test binaries.
    pub fn from_messages(
        reader: impl io::BufRead,
        graph: &PackageGraph,
    ) -> Result<Self, FromMessagesError> {
        let mut rust_binaries = vec![];

        for message in Message::parse_stream(reader) {
            let message = message.map_err(FromMessagesError::ReadMessages)?;
            match message {
                Message::CompilerArtifact(artifact) if artifact.profile.test => {
                    if let Some(path) = artifact.executable {
                        let package_id = artifact.package_id.repr;

                        // Look up the executable by package ID.
                        let package = graph
                            .metadata(&PackageId::new(package_id.clone()))
                            .map_err(FromMessagesError::PackageGraph)?;

                        // Construct the binary ID from the package and build target.
                        let mut id = package.name().to_owned();
                        let name = artifact.target.name;

                        // To ensure unique binary IDs, we use the following scheme:
                        // 1. If the target is a lib, use the package name.
                        //      There can only be one lib per package, so this
                        //      will always be unique.
                        if !artifact.target.kind.contains(&"lib".to_owned()) {
                            id.push_str("::");

                            match artifact.target.kind.get(0) {
                                // 2. For integration tests, use the target name.
                                //      Cargo enforces unique names for the same
                                //      kind of targets in a package, so these
                                //      will always be unique.
                                Some(kind) if kind == "test" => {
                                    id.push_str(&name);
                                }
                                // 3. For all other target kinds, use a
                                //      combination of the target kind and
                                //      the target name. For the same reason
                                //      as above, these will always be unique.
                                Some(kind) => {
                                    id.push_str(&format!("{}/{}", kind, name));
                                }
                                None => {
                                    return Err(FromMessagesError::MissingTargetKind {
                                        package_name: package.name().to_owned(),
                                        binary_name: name.clone(),
                                    });
                                }
                            }
                        }

                        let platform = if artifact.target.kind.len() == 1
                            && artifact.target.kind.get(0).map(String::as_str) == Some("proc-macro")
                        {
                            BuildPlatform::Host
                        } else {
                            BuildPlatform::Target
                        };

                        rust_binaries.push(RustTestBinary {
                            path,
                            package_id,
                            name,
                            id,
                            build_platform: platform,
                        })
                    }
                }
                _ => {
                    // Ignore all other messages.
                }
            }
        }

        rust_binaries.sort_by(|b1, b2| b1.id.cmp(&b2.id));

        Ok(Self { rust_binaries })
    }
}
```
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L80](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L80)

長いですがやっていることはシンプルです。  
第一引数の`reader`はcargo testの出力を`std::io::Cursor`でwrapしたもので、第二引数は先ほど見た`PackageMetadata`です。  
`for message in Message::parse_stream(reader) `のところで、jsonを[`cargo_metadata::Message`](https://github.com/oli-obk/cargo_metadata/blob/main/src/messages.rs#L104)にparseします。  
`cargo_metadata::Message`は以下のようなenumです。
```rust
// A cargo message
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[non_exhaustive]
#[serde(tag = "reason", rename_all = "kebab-case")]
pub enum Message {
    /// The compiler generated an artifact
    CompilerArtifact(Artifact),
    /// The compiler wants to display a message
    CompilerMessage(CompilerMessage),
    /// A build script successfully executed.
    BuildScriptExecuted(BuildScript),
    /// The build has finished.
    ///
    /// This is emitted at the end of the build as the last message.
    /// Added in Rust 1.44.
    BuildFinished(BuildFinished),
    /// A line of text which isn't a cargo or compiler message.
    /// Line separator is not included
    #[serde(skip)]
    TextLine(String),
}
```

[https://github.com/oli-obk/cargo_metadata/blob/f615f7164534eb52fb9525bdb5eee5731f652968/src/messages.rs#L104](https://github.com/oli-obk/cargo_metadata/blob/f615f7164534eb52fb9525bdb5eee5731f652968/src/messages.rs#L104)

今回の処理はこのうち、`Message::CompilerArtifact`のみを利用します。`Artifact`は
```rust
/// A compiler-generated file.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[cfg_attr(feature = "builder", derive(Builder))]
#[non_exhaustive]
#[cfg_attr(feature = "builder", builder(pattern = "owned", setter(into)))]
pub struct Artifact {
    /// The package this artifact belongs to
    pub package_id: PackageId,
    /// The target this artifact was compiled for
    pub target: Target,
    /// The profile this artifact was compiled with
    pub profile: ArtifactProfile,
    /// The enabled features for this artifact
    pub features: Vec<String>,
    /// The full paths to the generated artifacts
    /// (e.g. binary file and separate debug info)
    pub filenames: Vec<Utf8PathBuf>,
    /// Path to the executable file
    pub executable: Option<Utf8PathBuf>,
    /// If true, then the files were already generated
    pub fresh: bool,
}
```
[https://github.com/oli-obk/cargo_metadata/blob/f615f7164534eb52fb9525bdb5eee5731f652968/src/messages.rs#L34](https://github.com/oli-obk/cargo_metadata/blob/f615f7164534eb52fb9525bdb5eee5731f652968/src/messages.rs#L34)

のように定義されています。この`Artifact`に`PacakgGraph`で利用するpackage_idや、test binaryの実行path(`executable`)が保持されています。

```rust
 match message {
                Message::CompilerArtifact(artifact) if artifact.profile.test => { .. }
}
```
以下は分かりづらいですが要は、test binaryの一意の識別子を作ろうとしています。  
packageにはlib crateがたかだか1つなのでpackage名をそのまま利用、`tests`以下はfile名が一位になることが保証されているので、`<package>::<file_name>`のような組み立て、bin crateは複数存在しうるので、`<pacakge>::bin/<bin_name>`のようなことをやろうとしています。
結果的に`nextest-handson` packageでは

* `nextest-handson::integ_a` (`tests/integ_a.rs`に対応)
* `nextest-handson::integ_b` (`tests/integ_b.rs`に対応)
* `nextest-handson::bin/nextest-handson` ( `src/main.rs`に対応)
* `nextest-handson` ( `src/lib.rs`に対応)
のようなidを組み立てています。

まとめると、`cargo --color=auto metadata --format-version=1 --all-features --no-deps`と`cargo --color=auto test --no-run --message-format json-render-diagnostics`の出力結果をparseして`cargo`がbuildしたtest binaryに関する情報を取得した感じです。

### `TestBuildFilter::compute_test_list()`

ここまでで、test対象のbinaryの情報を取得できましたが、肝心の各binaryのtest caseの情報がまだ取得できていません。  
その情報を取得するのが、[`TestBuildFilter::compute_test_list()`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L290)です。

```rust
impl TestBuildFilter {
    fn compute_test_list<'g>(
        &self,
        graph: &'g PackageGraph,
        binary_list: BinaryList,
        runner: &TargetRunner,
        reuse_build: &ReuseBuildOpts,
    ) -> Result<TestList<'g>> {
        let path_mapper = reuse_build.make_path_mapper(graph);
        let test_artifacts = RustTestArtifact::from_binary_list(
            graph,
            binary_list,
            path_mapper.as_ref(),
            self.platform_filter.into(),
        )?;
        let test_filter =
            TestFilterBuilder::new(self.run_ignored, self.partition.clone(), &self.filter);
        TestList::new(test_artifacts, &test_filter, runner).wrap_err("error building test list")
    }
}
```
第三,四引数の`TargetRunner`と`ReuseBuildOpts`は今回は気にしなくて大丈夫です。  
処理の流れとしては、`Vec<RustTestArtifact>`を生成して、cliのfilter関連をparse(`--run-ignored`, `--partition count:1/3`)し、最終的に出力する`TestList`を生成します。

まず、`Vec<RustTestBinary>`から`Vec<RustTestArtiface<'g>`を生成するのですが、`RustTestArtifact<'g>`は先ほどcargoの出力結果をparseして作成した`RustTestBinary`と大々同じもので、packageのmetadataとcwdを追加しただけの情報です。(読んでいる時は処理の実行状態に応じた似たような構造体が多くて混乱しました。)

```rust
/// A Rust test binary built by Cargo. This artifact hasn't been run yet so there's no information
/// about the tests within it.
///
/// Accepted as input to [`TestList::new`].
#[derive(Clone, Debug)]
pub struct RustTestArtifact<'g> {
    /// A unique identifier for this test artifact.
    pub binary_id: String,

    /// Metadata for the package this artifact is a part of. This is used to set the correct
    /// environment variables.
    pub package: PackageMetadata<'g>,

    /// The path to the binary artifact.
    pub binary_path: Utf8PathBuf,

    /// The unique binary name defined in `Cargo.toml` or inferred by the filename.
    pub binary_name: String,

    /// The working directory that this test should be executed in. If None, the current directory
    /// will not be changed.
    pub cwd: Utf8PathBuf,

    /// The platform for which this test artifact was built.
    pub build_platform: BuildPlatform,
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L37](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L37)


### `TestList::new()`

ついに`cargo nextest list`の出力結果を表示するためのすべての情報が集まったのでここからはparseとfilter処理です。  
生成する`TestList`は以下のように定義されています。
```rust
/// List of test instances, obtained by querying the [`RustTestArtifact`] instances generated by Cargo.
#[derive(Clone, Debug)]
pub struct TestList<'g> {
    test_count: usize,
    rust_suites: BTreeMap<Utf8PathBuf, RustTestSuite<'g>>,
    // Computed on first access.
    skip_count: OnceCell<usize>,
}
```
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L300](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L300)

`rust_suites: BTreeMap<Utf8PathBuf, RustTestSuite<'g>>`の`Utf8PathBuf`がtest binaryのpathで、`RustTestSuite`がfilter処理適用後の最終的に出力(実行)するtest caseについての情報です。

```rust
/// A suite of tests within a single Rust test binary.
///
/// This is a representation of [`nextest_metadata::RustTestSuiteSummary`] used internally by the runner.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RustTestSuite<'g> {
    /// A unique identifier for this binary.
    pub binary_id: String,

    /// Package metadata.
    pub package: PackageMetadata<'g>,

    /// The unique binary name defined in `Cargo.toml` or inferred by the filename.
    pub binary_name: String,

    /// The working directory that this test binary will be executed in. If None, the current directory
    /// will not be changed.
    pub cwd: Utf8PathBuf,

    /// The platform the test suite is for (host or target).
    pub build_platform: BuildPlatform,

    /// Test case names and other information about them.
    pub testcases: BTreeMap<String, RustTestCaseSummary>,
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L311](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L311)

大体、`RustTestArtifact`(`RustTestBinary`)と同じ情報なのですが、`pub testcases: BTreeMap<String, RustTestCaseSummary>,`にtest caseごとの情報を保持しています。`String`は`module/submodule/test_func`のようなtest caseの識別子です。  
[`RustTestCaseSummary`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-metadata/src/test_list.rs#L214)は各test caseの処理結果に関する情報です。(filterにmatchしたか)
```rust
/// Serializable information about an individual test case within a Rust test suite.
///
/// Part of a [`RustTestSuiteSummary`].
#[derive(Clone, Debug, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "kebab-case")]
pub struct RustTestCaseSummary {
    /// Returns true if this test is marked ignored.
    ///
    /// Ignored tests, if run, are executed with the `--ignored` argument.
    pub ignored: bool,

    /// Whether the test matches the provided test filter.
    ///
    /// Only tests that match the filter are run.
    pub filter_match: FilterMatch,
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-metadata/src/test_list.rs#L214](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-metadata/src/test_list.rs#L214)

肝心のparseとfilter処理ですが

```rust
impl<'g> TestList<'g> {
    /// Creates a new test list by running the given command and applying the specified filter.
    pub fn new(
        test_artifacts: impl IntoIterator<Item = RustTestArtifact<'g>>,
        filter: &TestFilterBuilder,
        runner: &TargetRunner,
    ) -> Result<Self, ParseTestListError> {
        let mut test_count = 0;

        let test_artifacts = test_artifacts
            .into_iter()
            .map(|test_binary| {
                let (non_ignored, ignored) = test_binary.exec(runner)?;
                let (bin, info) = Self::process_output(
                    test_binary,
                    filter,
                    non_ignored.as_str(),
                    ignored.as_str(),
                )?;
                test_count += info.testcases.len();
                Ok((bin, info))
            })
            .collect::<Result<BTreeMap<_, _>, _>>()?;

        Ok(Self {
            rust_suites: test_artifacts,
            test_count,
            skip_count: OnceCell::new(),
        })
    }
}
```
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L379](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L379)


ざっくりいうと、test binaryを何らかの方法で実行してtest caseの情報を取得して、`TestList::process_output()`でfilter処理適用して`TestCaseSummary`を生成している感じでしょうか。

#### `RustTestArtifact::exec()`

```rust
impl<'g> RustTestArtifact<'g> {
    /// Run this binary with and without --ignored and get the corresponding outputs.
    fn exec(&self, runner: &TargetRunner) -> Result<(String, String), ParseTestListError> {
        let platform_runner = runner.for_build_platform(self.build_platform);

        let non_ignored = self.exec_single(false, platform_runner)?;
        let ignored = self.exec_single(true, platform_runner)?;
        Ok((non_ignored, ignored))
    }

    fn exec_single(
        &self,
        ignored: bool,
        runner: Option<&PlatformRunner>,
    ) -> Result<String, ParseTestListError> {
        let mut argv = Vec::new();

        let program: std::ffi::OsString = if let Some(runner) = runner {
            argv.extend(runner.args());
            argv.push(self.binary_path.as_str());
            runner.binary().into()
        } else {
            use duct::IntoExecutablePath;
            self.binary_path.as_std_path().to_executable()
        };

        argv.extend(["--list", "--format", "terse"]);
        if ignored {
            argv.push("--ignored");
        }

        let cmd = cmd(program, argv).dir(&self.cwd).stdout_capture();

        cmd.read().map_err(|error| {
            ParseTestListError::command(
                format!(
                    "'{} --list --format terse{}'",
                    self.binary_path,
                    if ignored { " --ignored" } else { "" }
                ),
                error,
            )
        })
    }
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L687](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L687)


ということで、nextestがどうやってtest caseの情報を取得しているか分かりました。  
buildされたtest binaryに`--list --format terse`optionを付与して実行しているだけでした。
試しに手元で実行してみると
```sh
❯ ./target/debug/deps/nextest_handson-b56b908ea854a424 --list --format terse 
aaa::a01::tests::aaa: test
aaa::a02::tests::aaa: test
flaky::tests::rand: test
```
と出力されtest case一覧が1行づつ表示されました。(これならparseは簡単そうです). 
`RustTestArtifact::exec()`の方では`#[ignore]` annotationを考慮して`--ignored` flagの付与あるなしで2回実行しています。

#### `TestList::process_output()`


[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L558](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L558)
test case名の出力を得たので、あとは1行づつfilter処理を適用していくだけです。  
filter処理の実装は[`TestFilter::filter_match()`(https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_filter.rs#L140)にあります。

`cargo nextest list aaa bbb`のようにfilter用引数を渡すと[`aho_corasick::AhoCorasick::is_match()`](https://github.com/BurntSushi/aho-corasick/blob/f8197afced3df41c47d05c9bbf8f84ddd197efdb/src/ahocorasick.rs#L183)が利用されます。

また、`--partition count:1/2`, `--partition hash:1/2`のようなpartitionのfilter実装はそれぞれ

* [https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/partition.rs#L163](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/partition.rs#L163)

* [https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/partition.rs#L187](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/partition.rs#L187)

に定義されています。


### `TestList::write_human()`

```rust
/// List of test instances, obtained by querying the [`RustTestArtifact`] instances generated by Cargo.
#[derive(Clone, Debug)]
pub struct TestList<'g> {
    test_count: usize,
    rust_suites: BTreeMap<Utf8PathBuf, RustTestSuite<'g>>,
    // Computed on first access.
    skip_count: OnceCell<usize>,
}
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L300](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L300)



`TestList`が生成できたのであとは出力するだけです。


[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L215](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L215)

出力に必要な情報とfilter処理ができているので
```sh
❯ cargo nextest list aaa
    Finished test [unoptimized + debuginfo] target(s) in 0.01s
nextest-handson::integ_a:
    case_1 (skipped)
nextest-handson::integ_b:
    case_1 (skipped)
nextest-handson::bin/nextest-handson:
    (no tests)
nextest-handson:
    aaa::a01::tests::aaa
    aaa::a02::tests::aaa
    flaky::tests::rand (skipped)
```
のように結果を表示できます。

### `list`処理のまとめ

ここまでnextestがtest case一覧を表示するまでの処理の流れを追ってみました。  

`cargo test --no-run --message-format json-render-diagnostics`を実行してcargoがbuildしたtest binaryの情報を取得したのち、各test binaryを`--list --format terse` option付きで実行して、test binaryごとのtest caseを保持。
その後、test caseごとにfilter処理を適用することで`cargo nextest list`を出力しているのことが理解できました。  
listで生成した`TestList`は`run`コマンドでも生成するのでこの処理の流れはnextest run実行時も同じです。
準備ができたので次はいよいよnextestがいうtest caseの並列実行の仕組みをみていきます。


## `cargo nextest run`

run実行時もlistと同様、`App::new()`処理で`PackageMetadata`を取得するところまでは共通です。

### `App::exec_run()`

```rust
fn exec_run(
        &self,
        profile_name: Option<&str>,
        no_capture: bool,
        runner_opts: &TestRunnerOpts,
        reporter_opts: &TestReporterOpts,
        output_writer: &mut OutputWriter,
    ) -> Result<()> {
        let config = self
            .config_opts
            .make_config(self.workspace_root.as_path())?;
        let profile = self.load_profile(profile_name, &config)?;

        let target_runner = self.load_runner();

        let binary_list = self.build_binary_list()?;
        let test_list = self.build_test_list(binary_list, &target_runner)?;

        let mut reporter = reporter_opts
            .to_builder(no_capture)
            .set_verbose(self.output.verbose)
            .build(&test_list, &profile);
        if self.output.color.should_colorize(Stream::Stderr) {
            reporter.colorize();
        }

        let handler = SignalHandler::new().wrap_err("failed to set up Ctrl-C handler")?;
        let runner_builder = runner_opts.to_builder(no_capture);
        let runner = runner_builder.build(&test_list, &profile, handler, target_runner);

        let mut writer = output_writer.stderr_writer();
        let run_stats = runner.try_execute(|event| {
            // Write and flush the event.
            reporter.report_event(event, &mut writer)?;
            writer.flush().map_err(WriteEventError::Io)
        })?;
        if !run_stats.is_success() {
            return Err(Report::new(ExpectedError::test_run_failed()));
        }
        Ok(())
    }
```
[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L564](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/cargo-nextest/src/dispatch.rs#L564)

runコマンドは`App::exec_run()`から始まります。  
第一引数の`profile_name`は`cargo nextest run --profile ci`のようなprofile指定です。  
第二引数の`no_capture`はtestのstdout/stderrを出力するかどうか、thread poolのthread数に影響します。  
第三引数の`runner_opts`は`cargo nexest run --test-thread=4 --retries=2 --fail-fast`のようなtest実行時の挙動制御用のパラメータです。  
第四引数の`reporter_opts`は成功/失敗時の出力制御とtestのstatus(pass, skip,fail,...)の出力レベルの指定です。
第五引数の`output_writer`は出力用のstdout/stderrの抽象化で、nextest自体のtest時はbuffer(Vec<u8>)渡せるようになっています。

```rust
let config = self
        .config_opts
        .make_config(self.workspace_root.as_path())?;
let profile = self.load_profile(profile_name, &config)?;

let target_runner = self.load_runner();

let binary_list = self.build_binary_list()?;
let test_list = self.build_test_list(binary_list, &target_runner)?;

let mut reporter = reporter_opts
    .to_builder(no_capture)
    .set_verbose(self.output.verbose)
    .build(&test_list, &profile);
if self.output.color.should_colorize(Stream::Stderr) {
    reporter.colorize();
}
```


ここまでで、configをloadして`TargetRunner`を取得します。今回は`TargetRunner`にはtest binary実行時に指定のbinaryを実行する仕組みのようです。(test binaryはその引数になる)

`binary_list`と`test_list`はlistコマンドで生成したものと同じです。したがってここまでで実行するtest caseの取得処理は完了しています。  
[`TestReporter`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/reporter.rs#L262)はoption(config)で指定した出力設定に応じた出力処理を行なってくれます。


```rust
let handler = SignalHandler::new().wrap_err("failed to set up Ctrl-C handler")?;
let runner_builder = runner_opts.to_builder(no_capture);
let runner = runner_builder.build(&test_list, &profile, handler, target_runner);

let mut writer = output_writer.stderr_writer();
let run_stats = runner.try_execute(|event| {
    // Write and flush the event.
    reporter.report_event(event, &mut writer)?;
    writer.flush().map_err(WriteEventError::Io)
})?;
```
ここがrunコマンドのメインの処理で、[`TestRunner`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L108)を生成して、testを実行していきます。まずは`TestRunner`の生成処理からみていきます。

### `TestRunnerBuilder::build()`

```rust
    /// Creates a new test runner.
    pub fn build<'a>(
        self,
        test_list: &'a TestList,
        profile: &NextestProfile<'_>,
        handler: SignalHandler,
        target_runner: TargetRunner,
    ) -> TestRunner<'a> {
        let test_threads = match self.no_capture {
            true => 1,
            false => self.test_threads.unwrap_or_else(num_cpus::get),
        };
        let retries = self.retries.unwrap_or_else(|| profile.retries());
        let fail_fast = self.fail_fast.unwrap_or_else(|| profile.fail_fast());
        let slow_timeout = profile.slow_timeout();

        TestRunner {
            no_capture: self.no_capture,
            // The number of tries = retries + 1.
            tries: retries + 1,
            fail_fast,
            slow_timeout,
            test_list,
            target_runner,
            run_pool: ThreadPoolBuilder::new()
                // The main run_pool closure will need its own thread.
                .num_threads(test_threads + 1)
                .thread_name(|idx| format!("testrunner-run-{}", idx))
                .build()
                .expect("run pool built"),
            wait_pool: ThreadPoolBuilder::new()
                .num_threads(test_threads)
                .thread_name(|idx| format!("testrunner-wait-{}", idx))
                .build()
                .expect("run pool built"),
            handler,
        }
    }
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L66](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L66)


この処理で、`cargo nextest run --no-capture`を指定するとthread数が1に設定されることがわかります。  
thread poolのbuilderとして利用されているのは[rayonの`ThreadPoolBuilder`](https://github.com/rayon-rs/rayon/blob/f45eee8fa49c1646a00f084ca78d362f381f1b65/rayon-core/src/lib.rs#L142)です。  
defaultのthread数は`num_cpus::get()`でCPUの論理コア数が利用されます。(蛇足ですが、間違えて`num_cpu` (sがない)を使った時警告が出ました。依存crateのtypoは結構危ない。[https://kerkour.com/rust-crate-backdoor]). 
ThreadPoolが`run_pool`と`wait_pool`の二つあるところがポイントで、二つ必要な理由は後述します。


### `Runner::try_execute()`

[`Runner::try_execute()`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L139)がtest実行処理です。

この長い処理をみていく前に`try_execute()`の簡易版を説明します。

```rust
fn main() -> anyhow::Result<()> {
    let n = num_cpus::get();
    let pool = rayon::ThreadPoolBuilder::new().num_threads(n + 1).build()?;
    let wait_pool = rayon::ThreadPoolBuilder::new().num_threads(n)
        .build()?;

    println!("num_cpus: {}", n);

    pool.scope(|scope| {
        for _ in 0..n {
            scope.spawn(|_scope| {
                let thread_id = std::thread::current().id();
                println!("thread: {:?}", thread_id);
                let cmd = duct::cmd("sleep", ["5"]);
                let handle = cmd.start().unwrap();


                wait_pool.in_place_scope(|scope| {
                    let (sender, receiver) =crossbeam_channel::bounded(1);

                    scope.spawn(move |scope| {
                        let _ = handle.wait();

                        let _ = sender.send(());
                    });

                    while let Err(err) = receiver.recv_timeout(std::time::Duration::from_secs(2)) {
                        match err {
                            crossbeam_channel::RecvTimeoutError::Timeout => {
                                println!("receive: {:?}", thread_id);
                            }
                            _ => unreachable!(),
                        }
                    }
                    println!("thread: {:?} done", thread_id);
                });
            })
        }
    });

    Ok(())
}

```
```toml
[dependencies]
anyhow = "1.0.56"
rayon = "1.5.1"
num_cpus = "1.13.1"
duct = "0.9.1"
crossbeam-channel = "0.5.2"
```

rayonのThreadPoolを使ったことがないとわかりづらいので読み方を説明します。  
`pool.scope()`はthread poolで実行するtaskを生成する`scope.spawn()`に渡すclosureで参照を利用するための仕組みくらいの理解で大丈夫です。(自分がその程度の理解)。
`pool.scope()`は渡されたclosureが生成したtaskがすべて終了するまでblockします。  
`scope.spawn()`に渡されたclosureが各test caseの実行処理だと思ってください。ここでは`sleep`で代替していますが、`doct::cmd`を利用する点は同じ。  
`cmd.start()`するとプロセスが実行され、制御用のhandleが返されます。ここでblockしてもよいのですが、test caseのtimeoutを捕捉するために、test case終了を待機するtaskを生成します。このtaskは先ほど生成した`wait_pool`側に生成します。  
ただし、`wait_pool.in_place_scope()`で待機処理を行なっているので、test case processの待機自体は`pool`のThreadPoolのthreadで実行されます。結果的に最大で並列に実行されるtest caseは指定されたthread数(`num_cpus::get()`)になります。

ThreadPoolの使われ方を抑えたところで実際の処理はこちらです。

```rust
    pub fn try_execute<E, F>(&self, callback: F) -> Result<RunStats, E>
    where
        F: FnMut(TestEvent<'a>) -> Result<(), E> + Send,
        E: Send,
    {
        // TODO: add support for other test-running approaches, measure performance.

        let (run_sender, run_receiver) = crossbeam_channel::unbounded();

        // This is move so that sender is moved into it. When the scope finishes the sender is
        // dropped, and the receiver below completes iteration.

        let canceled = AtomicBool::new(false);
        let canceled_ref = &canceled;

        let mut ctx = CallbackContext::new(callback, self.test_list.run_count(), self.fail_fast);

        // Send the initial event.
        // (Don't need to set the canceled atomic if this fails because the run hasn't started
        // yet.)
        ctx.run_started(self.test_list)?;

        // Stores the first error that occurred. This error is propagated up.
        let mut first_error = None;

        let ctx_mut = &mut ctx;
        let first_error_mut = &mut first_error;

        // ---
        // Spawn the test threads.
        // ---
        // XXX rayon requires its scope callback to be Send, there's no good reason for it but
        // there's also no other well-maintained scoped threadpool :(
        self.run_pool.scope(move |run_scope| {
            self.test_list.iter_tests().for_each(|test_instance| {
                if canceled_ref.load(Ordering::Acquire) {
                    // Check for test cancellation.
                    return;
                }

                let this_run_sender = run_sender.clone();
                run_scope.spawn(move |_| {
                    if canceled_ref.load(Ordering::Acquire) {
                        // Check for test cancellation.
                        return;
                    }

                    if let FilterMatch::Mismatch { reason } = test_instance.test_info.filter_match {
                        // Failure to send means the receiver was dropped.
                        let _ = this_run_sender.send(InternalTestEvent::Skipped {
                            test_instance,
                            reason,
                        });
                        return;
                    }

                    // Failure to send means the receiver was dropped.
                    let _ = this_run_sender.send(InternalTestEvent::Started { test_instance });

                    let mut run_statuses = vec![];

                    loop {
                        let attempt = run_statuses.len() + 1;

                        let run_status = self
                            .run_test(test_instance, attempt, &this_run_sender)
                            .into_external(attempt, self.tries);

                        if run_status.result.is_success() {
                            // The test succeeded.
                            run_statuses.push(run_status);
                            break;
                        } else if attempt < self.tries {
                            // Retry this test: send a retry event, then retry the loop.
                            let _ = this_run_sender.send(InternalTestEvent::Retry {
                                test_instance,
                                run_status: run_status.clone(),
                            });
                            run_statuses.push(run_status);
                        } else {
                            // This test failed and is out of retries.
                            run_statuses.push(run_status);
                            break;
                        }
                    }

                    // At this point, either:
                    // * the test has succeeded, or
                    // * the test has failed and we've run out of retries.
                    // In either case, the test is finished.
                    let _ = this_run_sender.send(InternalTestEvent::Finished {
                        test_instance,
                        run_statuses: ExecutionStatuses::new(run_statuses),
                    });
                })
            });

            drop(run_sender);

            loop {
                let internal_event = crossbeam_channel::select! {
                    recv(run_receiver) -> internal_event => {
                        match internal_event {
                            Ok(event) => InternalEvent::Test(event),
                            Err(_) => {
                                // All runs have been completed.
                                break;
                            }
                        }
                    },
                    recv(self.handler.receiver) -> internal_event => {
                        match internal_event {
                            Ok(event) => InternalEvent::Signal(event),
                            Err(_) => {
                                // Ignore the signal thread being dropped. This is done for
                                // noop signal handlers.
                                continue;
                            }
                        }
                    },
                };

                match ctx_mut.handle_event(internal_event) {
                    Ok(()) => {}
                    Err(err) => {
                        // If an error happens, it is because either the callback failed or
                        // a cancellation notice was received. If the callback failed, we need
                        // to send a further cancellation notice as well.
                        canceled_ref.store(true, Ordering::Release);

                        match err {
                            InternalError::Error(err) => {
                                // Ignore errors that happen during error cancellation.
                                if first_error_mut.is_none() {
                                    *first_error_mut = Some(err);
                                }
                                let _ = ctx_mut.begin_cancel(CancelReason::ReportError);
                            }
                            InternalError::TestFailureCanceled(None)
                            | InternalError::SignalCanceled(None) => {
                                // Cancellation has begun and no error was returned during that.
                                // Continue to handle events.
                            }
                            InternalError::TestFailureCanceled(Some(err))
                            | InternalError::SignalCanceled(Some(err)) => {
                                // Cancellation has begun and an error was received during
                                // cancellation.
                                if first_error_mut.is_none() {
                                    *first_error_mut = Some(err);
                                }
                            }
                        }
                    }
                }
            }

            Ok(())
        })?;

        match ctx.run_finished() {
            Ok(()) => {}
            Err(err) => {
                if first_error.is_none() {
                    first_error = Some(err);
                }
            }
        }

        match first_error {
            None => Ok(ctx.run_stats),
            Some(err) => Err(err),
        }
    }
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L139]([https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L139])

長いですがやっていることはシンプルです。

1. `self.test_list.iter_tests().for_each()` でtest caseをiterateする。
1.  runner thread poolに1つのtest caseを実行するprocessを立ち上げるtaskを登録する。`run_scope.spawn()`
  1. このtaskはretryが設定されている場合規定回数のretryを試みる
  1. test caseの実行結果を登録する
1. main threadはすべてのtest caseのtaskをspawnし終えたら各test case用のtaskに渡したevent channelをreceiveし続ける。
  1. その際、signal(ctrl-c)を考慮する
  1. test case実行にまつわる各種event(start, success,timeout,...)を渡されたcallbackに渡す。

ざっくりですがこれがメインのloop処理の概要です。  
次に実際のtest caseはどのように実行されているかみていきます。


### `TestRunner::run_test()`

```rust
    /// Run an individual test in its own process.
    fn run_test(
        &self,
        test: TestInstance<'a>,
        attempt: usize,
        run_sender: &Sender<InternalTestEvent<'a>>,
    ) -> InternalExecuteStatus {
        let stopwatch = StopwatchStart::now();

        match self.run_test_inner(test, attempt, &stopwatch, run_sender) {
            Ok(run_status) => run_status,
            Err(_) => InternalExecuteStatus {
                // TODO: can we return more information in stdout/stderr? investigate this
                stdout: vec![],
                stderr: vec![],
                result: ExecutionResult::ExecFail,
                stopwatch_end: stopwatch.end(),
            },
        }
    }

    fn run_test_inner(
        &self,
        test: TestInstance<'a>,
        attempt: usize,
        stopwatch: &StopwatchStart,
        run_sender: &Sender<InternalTestEvent<'a>>,
    ) -> std::io::Result<InternalExecuteStatus> {
        let cmd = test
            .make_expression(&self.target_runner)
            .unchecked()
            // Debug environment variable for testing.
            .env("__NEXTEST_ATTEMPT", format!("{}", attempt));

        let cmd = if self.no_capture {
            cmd
        } else {
            // Capture stdout and stderr.
            cmd.stdout_capture().stderr_capture()
        };

        let handle = cmd.start()?;

        self.wait_pool.in_place_scope(|s| {
            let (sender, receiver) = crossbeam_channel::bounded::<()>(1);
            let wait_handle = &handle;

            // Spawn a task on the threadpool that waits for the test to finish.
            s.spawn(move |_| {
                // This thread is just waiting for the test to finish, we'll handle the output in the main thread
                let _ = wait_handle.wait();
                // We don't care if the receiver got the message or not
                let _ = sender.send(());
            });

            // Continue waiting for the test to finish with a timeout, logging at slow-timeout
            // intervals
            while let Err(error) = receiver.recv_timeout(self.slow_timeout) {
                match error {
                    RecvTimeoutError::Timeout => {
                        let _ = run_sender.send(InternalTestEvent::Slow {
                            test_instance: test,
                            elapsed: stopwatch.elapsed(),
                        });
                    }
                    RecvTimeoutError::Disconnected => {
                        unreachable!("Waiting thread should never drop the sender")
                    }
                }
            }
        });

        let output = handle.into_output()?;

        let status = if output.status.success() {
            ExecutionResult::Pass
        } else {
            ExecutionResult::Fail
        };
        Ok(InternalExecuteStatus {
            stdout: output.stdout,
            stderr: output.stderr,
            result: status,
            stopwatch_end: stopwatch.end(),
        })
    }


```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L318](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L318)

ここが先ほどの簡易版で説明した、`wait_pool`を利用したtest case processの待機処理です。  
要はrunner_poolの各threadはtest case実行processが終了するまでblockします。

先ほどから、test case用のprocessと言っているのですが、そのprocess生成処理は出てきていませんでした。各test caseを一つだけ実行するprocessの生成処理は`TestInstance::make_expression()`で行われています。

#### `TestInstance::make_expression()`


```rust
    /// Creates the command expression for this test instance.
    pub(crate) fn make_expression(&self, target_runner: &TargetRunner) -> Expression {
        let platform_runner = target_runner.for_build_platform(self.bin_info.build_platform);
        // TODO: non-rust tests

        let mut args = Vec::new();

        let program: std::ffi::OsString = match platform_runner {
            Some(runner) => {
                args.extend(runner.args());
                args.push(self.binary.as_str());
                runner.binary().into()
            }
            None => {
                use duct::IntoExecutablePath;
                self.binary.as_std_path().to_executable()
            }
        };

        args.extend(["--exact", self.name, "--nocapture"]);
        if self.test_info.ignored {
            args.push("--ignored");
        }

        let package = self.bin_info.package;

        let cmd = cmd(program, args)
            .dir(&self.bin_info.cwd)
            // This environment variable is set to indicate that tests are being run under nextest.
            .env("NEXTEST", "1")
            // This environment variable is set to indicate that each test is being run in its own process.
            .env("NEXTEST_EXECUTION_MODE", "process-per-test")
            // These environment variables are set at runtime by cargo test:
            // https://doc.rust-lang.org/cargo/reference/environment-variables.html#environment-variables-cargo-sets-for-crates
            .env(
                "CARGO_MANIFEST_DIR",
                package.manifest_path().parent().unwrap(),
            )
            .env("CARGO_PKG_VERSION", format!("{}", package.version()))
            .env(
                "CARGO_PKG_VERSION_MAJOR",
                format!("{}", package.version().major),
            )
            .env(
                "CARGO_PKG_VERSION_MINOR",
                format!("{}", package.version().minor),
            )
            .env(
                "CARGO_PKG_VERSION_PATCH",
                format!("{}", package.version().patch),
            )
            .env(
                "CARGO_PKG_VERSION_PRE",
                format!("{}", package.version().pre),
            )
            .env("CARGO_PKG_AUTHORS", package.authors().join(":"))
            .env("CARGO_PKG_NAME", package.name())
            .env(
                "CARGO_PKG_DESCRIPTION",
                package.description().unwrap_or_default(),
            )
            .env("CARGO_PKG_HOMEPAGE", package.homepage().unwrap_or_default())
            .env("CARGO_PKG_LICENSE", package.license().unwrap_or_default())
            .env(
                "CARGO_PKG_LICENSE_FILE",
                package.license_file().unwrap_or_else(|| "".as_ref()),
            )
            .env(
                "CARGO_PKG_REPOSITORY",
                package.repository().unwrap_or_default(),
            );

        cmd
    }
```

[https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L764](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/test_list.rs#L764)

ということで、ついにcargo nextestがtest case単位でprocessを生成して並列に実行しているという処理にたどり着きました。  
`args.extend(["--exact", self.name, "--nocapture"]);`とあるように、test binaryに`--exact <test_case> --nocapture`を付与して実行していたんですね。
手元でやってみると
```sh
❯ ./target/debug/deps/nextest_handson-b56b908ea854a424 --exact aaa:a01::tests::aaa --nocapture

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 3 filtered out; finished in 0.00s
```
のように指定したcaseだけが実行できました。  
また、`cargo test`で同じ実行環境になるように地道に環境変数を設定していることもわかりました。

### `run`処理のまとめ

ざっくりですが、cargo nextest runがどうやってtest実行を並列化させているか大枠が理解できました。
test case単位でiterateして、rayonのThreadPoolを利用し、対象のtest caseだけを実行するプロセスを並列化させていたんですね。  
また、各種test処理は[`InternalTestEvent`](https://github.com/nextest-rs/nextest/blob/b647d946d2c2dcb8b6515c6f9152c30d4370a3d5/nextest-runner/src/runner.rs#L763)として表現され、testの実行方法とtest結果の表示方法が綺麗に分離されていました。

## まとめ

cargo nextestがtestを実行される処理の流れを見ていきました。  
基本的にcargoコマンドをwrapするようになっており、test自体はcargo testを使った時と同じで、test binaryの実行制御方法を工夫していることがわかりました。  
要はtest binaryに`--exact` optionを付与して最大同時実行数を制御しながらprocessを並列実行していることがわかり、nextestのブラックボックス度が少し減って嬉しいです。


## 今回ふれられなかったところ

本記事では、`list`と`run`のメインの実行の流れを追ってみました。他にも色々な機能があります。

* build結果の再利用処理
* `--target`に応じたtest runnerの切り替え処理
* terminalのcolor処理
