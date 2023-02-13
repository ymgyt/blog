+++
title = "♻️  Rustのexponential retry実装 againのソースを読んでみる"
slug = "again"
date = "2022-06-26"
draft = false
[taxonomies]
tags = ["rust"]
+++

{{ figure(caption="again", images=["images/rust_again.png"]) }}

本記事では、Rustでexponential retryの機能を提供する[again](https://github.com/softprops/again)のソースを読んでいきます。  
(`lib.rs` 1ファイルだけの小さなcrateなのですぐ読めます)

基本的にproductionでnetwork callを行う際はretryが必要になってくると思います。sidecar等の透過的なinfra layerではなくapplication layerでこれを実現する場合、大体以下のような処理をいれることになるかと思います。

* 処理をloopで囲む
* 最大retry数を考慮する
* retry可能かどうかのエラー判定
* retry時のinterval(`Duration`)の調整

この処理を宣言的に抽象化してくれるのがagainです。

## 使用例

実際の利用例。

```rust
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use again::RetryPolicy;

#[derive(Debug)]
enum Error {
    Retryable,
    Fatal,
}

#[tokio::main]
async fn main() {
    tracing_init::init();

    let policy = RetryPolicy::exponential(Duration::from_secs(1))
        .with_jitter(false)
        .with_backoff_exponent(2.)
        .with_max_delay(Duration::from_secs(60))
        .with_max_retries(4);

    let retry_count = Arc::new(AtomicU64::new(0));

    let result = policy.retry_if(
         ||  {
            let retry_count = Arc::clone(&retry_count);
            async move {
                retry_count.fetch_add(1, Ordering::SeqCst);

                tracing::info!(?retry_count, "task run!");

                Err::<(), Error>(Error::Retryable)
            }
        },
        |err: &Error| match err {
            Error::Retryable => true,
            Error::Fatal => false,
        },
    ).await;

    tracing::info!("{result:?} {retry_count:?}");
}
```

`tracing_init::init()`は`tracing_subscriber`の初期化なので省略。  
`RetryPolicy`でretry時の挙動を設定します。  
`RetryPolicy::retry_if()`の第一引数に実際に実行したい処理をclosureで渡します。第二引数はErrorがretryできるかどうかの判定をおこなうclosureです。
これを実行すると以下の出力をえます。

```sh
2022-06-25T11:36:05.393876Z  INFO retry/examples/retry_closure.rs:35: task run! retry_count=1
2022-06-25T11:36:06.399287Z  INFO retry/examples/retry_closure.rs:35: task run! retry_count=2
2022-06-25T11:36:08.400343Z  INFO retry/examples/retry_closure.rs:35: task run! retry_count=3
2022-06-25T11:36:12.404406Z  INFO retry/examples/retry_closure.rs:35: task run! retry_count=4
2022-06-25T11:36:20.407705Z  INFO retry/examples/retry_closure.rs:35: task run! retry_count=5
2022-06-25T11:36:20.408518Z  INFO retry/examples/retry_closure.rs:46: Err(Retryable) 5
```
実行回数は最大retry数(4) + 1で5回となっています。  
またretry間の間隔も、1,2,4,8とexponentialになっていることがわかります。

また、実行する処理に`again::Task`traitを実装することでclosure以外のユーザ側で定義した型も利用することができます。

```rust
use std::future::{Future, ready, Ready};

struct MyTask {
    count: u32,
}

impl again::Task for MyTask {
    type Item = ();
    type Error = Error;
    type Fut = Ready<Result<Self::Item, Self::Error>>;

    fn call(&mut self) -> Self::Fut {
        self.count += 1;

        tracing::info!("MyTask call() {}", self.count);

        if self.count < 3 {
            ready(Err(Error::Retryable))
        } else {
            ready(Err(Error::Fatal))
        }
    }
}

#[tokio::main]
async fn main() {
    tracing_init::init();

    let policy = RetryPolicy::default();
    let my_task = MyTask { count: 0 };

    let result = policy.retry_if(
        my_task,
        |err: &Error| match err {
            Error::Retryable => true,
            Error::Fatal => false,
        },
    ).await;

    tracing::info!("{result:?}");
}

```

```sh
2022-06-25T11:12:22.640568Z  INFO retry/examples/retry_struct.rs:26: MyTask call() 1
2022-06-25T11:12:23.645944Z  INFO retry/examples/retry_struct.rs:26: MyTask call() 2
2022-06-25T11:12:25.651503Z  INFO retry/examples/retry_struct.rs:26: MyTask call() 3
2022-06-25T11:12:25.651825Z  INFO retry/examples/retry_struct.rs:51: Err(Fatal)
```

ということでまずは`RetryPolicy::retry_if`を見ていきます。


## `RetryPolicy::retry_if`

まず登場する型と`retry_if`のsignatureから見ていきます。

```rust
use std::future::Future;

pub async fn retry<T>(task: T) -> Result<T::Item, T::Error>
    where
        T: Task,
{
    retry_if(task, Always).await
}

pub async fn retry_if<T,C>(
    task: T,
    condition: C,
)  -> Result<T::Item, T::Error>
where
    T: Task,
    C: Condition<T::Error>,

{
    // RetryPolicy::default().retry_if(task,condition).await
    todo!()
}
```

`retry`はエラー判定を行わない場合です。  
`retry_if`はgenericsになっており、実際の処理を抽象化した`Task`とErrorの判定を抽象化した`Condition`を引数にとります。
`Task`の定義は以下。

```rust
/// A unit of work to be retried
/// A implementation is provided for `FnMut() -> Future`
pub trait Task {
    type Item;
    type Error: std::fmt::Debug;
    type Fut: Future<Output=Result<Self::Item, Self::Error>>;

    fn call(&mut self) -> Self::Fut;
}
```

Associate型の`Item`と`Error`をもち、`Result`をfutureで返せることを要求します。  
ユーザが`Task`を意識しなくてよいようにclosureへの`Task`の実装が提供されております。

```rust
impl<F, Fut, I, E> Task for F
    where
        F: FnMut() -> Fut,
        Fut: Future<Output=Result<I, E>>,
        E: std::fmt::Debug,
{
    type Item = I;
    type Error = E;
    type Fut = Fut;

    fn call(&mut self) -> Self::Fut {
        self()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn task_implemented_for_closure() {
        let f = || async { Ok::<u32, u32>(10) };

        retry(f).await.unwrap();
    }
}
```

このようにclosureに`Task`が定義してあるので`retry_if`に`|| async {..}`のようなclosureが渡せます。  
次に`Condition`ですが以下のように定義されています。

```rust
/// A type to determine if a failed Future should be retried
/// A implementation is provided for `Fn(&Err) -> bool` allowing yout
/// to use a simple closure or fn handles
pub trait Condition<E> {
   fn is_retryable(
       &mut self,
       error: &E,
   ) -> bool;
}

struct Always;

impl<E> Condition<E> for Always {
    fn is_retryable(&mut self, _: &E) -> bool {
        true
    }
}

impl<F,E> Condition<E> for F
where F: FnMut(&E) -> bool,
{
    fn is_retryable(&mut self, error: &E) -> bool {
        self(error)
    }
}
```

ここでも、`|err: &Error| -> bool`のclosureに`Condition`が定義されているので、ユーザ側では意識することなくclosureを渡せます。

`retry_if`のsignatureがわかったので肝心の実装を見ていきます。  

```rust
#[derive(Clone, Copy)]
enum Backoff {
    Fixed,
    Exponential { exponent: f64 },
}

/// A template for configuring retry behavior
#[derive(Clone)]
pub struct RetryPolicy {
    backoff: Backoff,
    #[cfg(feature = "rand")]
    jitter: bool,
    delay: Duration,
    max_delay: Option<Duration>,
    max_retries: usize,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            backoff: Backoff::default(),
            delay: Duration::from_secs(1),
            #[cfg(feature = "rand")]
            jitter: false,
            max_delay: None,
            max_retries: 5,
        }
    }
}
```

retry時の挙動を宣言的に定義する`RetryPolicy`は上記のようになっています。  

* `backoff`はretry時のintervalを固定(`Fixed`)にするかexponential(`Exponential`)に増加させるかの指定。
* `jitter`はintervalをランダムに調整するかの指定
* `delay`はintervalの期間。exponentialの場合はこれが2,4倍になっていきます。
* `max_delay`最大のinterval。`min(max_delay, calculated_delay)`のように使われます
* `max_retries`最大retry数。都合実行される処理は`max_retries` + 1です。API的にOptionになっておらず必ず指定することが要求されます。

この`RetryPolicy`に定義されている`retry_if`は以下のように実装されています。

```rust
use wasm_timer::Delay;

impl RetryPolicy {
    pub async fn retry<T>(&self, task: T) -> Result<T::Item, T::Error>
    where
        T: Task,
    {
        self::retry_if(task, Always).await
    }

    pub async fn retry_if<T, C>(&self, task: T, condition: C) -> Result<T::Item, T::Error>
    where
        T: Task,
        C: Condition<T::Error>,
    {
        let mut backoffs = self.backoffs();
        let mut task = task;
        let mut condition = condition;
        loop {
            return match task.call().await {
                Ok(result) => Ok(result),
                Err(err) => {
                    if condition.is_retryable(&err) {
                        // Backoff has two responsibilities.
                        //   * Control whether to retry or not.
                        //     backoff iter take care of max_retry policy.
                        //   * If it does, control the duration of the delay.
                        if let Some(delay) = backoffs.next() {
                            tracing::trace!(
                                "task failed with error {err:?}. will try again in  {delay:?}"
                            );
                            let _ = Delay::new(delay).await;
                            continue;
                        }
                    }
                    Err(err)
                }
            };
        }
    }
}
```

loopでユーザが渡したclosureを呼び出して、Errの場合にretry判定したのちに、retryするか、するとしたらどれくらい待機するかを`RetryPolicy::backoffs`が返す`Iterator`で判定します。  
ということで、exponentialや`RetryPolicy`に基づいた制御は`Backoff`側に定義されているようです。

```rust
impl RetryPolicy {
    fn backoffs(&self) -> impl Iterator<Item=Duration> {
        self.backoff.iter(self)
    }
}
```

```rust
#[derive(Clone, Copy)]
enum Backoff {
    Fixed,
    Exponential { exponent: f64 },
}

impl Backoff {
    const DEFAULT_EXPONENT: f64 = 2.0;

    fn iter(self, policy: &RetryPolicy) -> BackoffIter {
        BackoffIter {
            backoff: self,
            current: 1.0,
            #[cfg(feature = "rand")]
            jitter: policy.jitter,
            delay: policy.delay,
            max_delay: policy.max_delay,
            max_retries: policy.max_retries,
        }
    }
}

struct BackoffIter {
    backoff: Backoff,
    current: f64,
    #[cfg(feature = "rand")]
    jitter: bool,
    delay: Duration,
    max_delay: Option<Duration>,
    max_retries: usize,
}

impl Iterator for BackoffIter {
    type Item = Duration;
    fn next(&mut self) -> Option<Self::Item> {
        if self.max_retries > 0 {
            let factor = match self.backoff {
                Backoff::Fixed => self.current,
                Backoff::Exponential { exponent } => {
                    let factor = self.current;
                    let next_factor = self.current * exponent;
                    self.current = next_factor;
                    factor
                }
            };

            let mut delay = self.delay.mul_f64(factor);
            #[cfg(feature = "rand")]
            {
                if self.jitter {
                    delay = jitter(delay);
                }
            }
            if let Some(max_delay) = self.max_delay {
                delay = min(delay, max_delay);
            }
            self.max_retries -= 1;

            return Some(delay);
        }
        None
    }
}
```

ということで、`BackoffIter::next`の中で、exponential, jitter, max_retries, max_delayが実装されていました。  
このあたりの判定処理が`BackoffIter`に切り出されているので、`RetryPolicy::retry_if`の処理がとてもシンプルになっていて読みやすいと思いました。

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_relative_eq;
    use std::error::Error;

    #[test]
    fn exponential_backoff() {
        let mut iter = RetryPolicy::exponential(Duration::from_secs(1)).backoffs();
        assert_relative_eq!(iter.next().unwrap().as_secs_f64(), 1.0);
        assert_relative_eq!(iter.next().unwrap().as_secs_f64(), 2.0);
        assert_relative_eq!(iter.next().unwrap().as_secs_f64(), 4.0);
        assert_relative_eq!(iter.next().unwrap().as_secs_f64(), 8.0);
        assert_relative_eq!(iter.next().unwrap().as_secs_f64(), 16.0);
    }
}
```

jitterの実装は以下のようになっています。

```rust
use std::time::Duration;
use rand::{distributions::OpenClosed01, thread_rng, Rng};

#[cfg(feature = "rand")]
fn jitter(duration: Duration) -> Duration {
    let jitter: f64 = thread_rng().sample(OpenClosed01);
    let secs = (duration.as_secs() as f64) * jitter;
    let nanos = (duration.subsec_nanos() as f64) * jitter;
    let millis = (secs * 1_000_f64) + (nanos / 1_000_000_f64);
    Duration::from_millis(millis as u64)
}
```

## `RetryPolicy::collect_and_retry`

againでは、`retry_if`に加えて処理が成功した場合でも処理を繰り返しつつ、結果を`Vec`で返す、`collect_and_retry`も提供しています。  
signatureは以下のようになっています。

```rust
impl RetryPolicy {
    pub async fn collect_and_retry<T, C, D, S>(
        &self,
        task: T,
        success_condition: C,
        error_condition: D,
        start_value: S,
    ) -> Result<Vec<T::Item>, T::Error>
        where
            T: TaskWithParameter<S>,
            C: SuccessCondition<T::Item, S>,
            D: Condition<T::Error>,
            S: Clone,
    {
        todo!()
    }
}
```

* `TaskWithParameter`は引数をとる`Task`の拡張。
  * `|| { ... }`ではなく、`|input| { ... }`のようなclosureを渡せるようになる
* `SuccessCondition`は成功時の継続判定処理と次の処理への引数生成処理
* `Condition`は`retry_if`と同様。
* `S`は`TaskWithParameter`で渡すclosureの引数の型

```rust
/// A type to determine if a successful Future should be retried
/// A implementation is provided for `Fn(&Result) -> Option<S>`, where S
/// represents the next input value.
pub trait SuccessCondition<R, S> {
    fn retry_with(&mut self, result: &R) -> Option<S>;
}

impl<F, R, S> SuccessCondition<R, S> for F
where
    F: Fn(&R) -> Option<S>,
{
    fn retry_with(&mut self, result: &R) -> Option<S> {
        self(result)
    }
}
```

`Error`ではなく、`Result`で継続するか判定する。`Some`で返した値は次の処理の引数に利用される。

```rust
/// A unit of work to be retried, that accepts a parameter
/// A implementation is provided for `FnMut() -> Future`
pub trait TaskWithParameter<P> {
    type Item;
    type Error: std::fmt::Debug;
    type Fut: Future<Output = Result<Self::Item, Self::Error>>;
    fn call(&mut self, parameter: P) -> Self::Fut;
}

impl<F, P, Fut, I, E> TaskWithParameter<P> for F
    where
        F: FnMut(P) -> Fut,
        Fut: Future<Output = Result<I, E>>,
        E: std::fmt::Debug,
{
    type Item = I;
    type Error = E;
    type Fut = Fut;
    fn call(&mut self, parameter: P) -> Self::Fut {
        self(parameter)
    }
}
```

`Task`に引数の型の抽象化`P`を追加した型。genericsの拡張の仕方として参考になります。  
最終的な実装は

```rust
impl RetryPolicy {
    pub async fn collect_and_retry<T, C, D, S>(
        &self,
        task: T,
        success_condition: C,
        error_condition: D,
        start_value: S,
    ) -> Result<Vec<T::Item>, T::Error>
        where
            T: TaskWithParameter<S>,
            C: SuccessCondition<T::Item, S>,
            D: Condition<T::Error>,
            S: Clone,
    {
        let mut success_backoffs = self.backoffs();
        let mut error_backoffs = self.backoffs();
        let mut success_condition = success_condition;
        let mut error_condition = error_condition;
        let mut task = task;
        let mut results = vec![];
        let mut input = start_value.clone();
        let mut last_result = start_value;

        loop {
            return match task.call(input).await {
                Ok(item) => {
                    let maybe_new_input = success_condition.retry_with(&item);
                    results.push(item);

                    if let Some(new_input) = maybe_new_input {
                        if let Some(delay) = success_backoffs.next() {
                            tracing::trace!(
                                "task succeeded and condition is met. will run again in {delay:?}"
                            );
                            let _ = Delay::new(delay).await;
                            input = new_input.clone();
                            last_result = new_input;
                            continue;
                        }
                    }

                    Ok(results)
                }
                Err(err) => {
                    if error_condition.is_retryable(&err) {
                        if let Some(delay) = error_backoffs.next() {
                            tracing::trace!(
                                "task failed with error {err:?}. will retry again in {delay:?}"
                            );
                            let _ = Delay::new(delay).await;
                            input = last_result.clone();
                            continue;
                        }
                    }
                    Err(err)
                }
            };
        }
    }
}
```

`Err`時のretryは`retry_if`と同じで、違うのは成功時にもretry判定が走る点。  
以下のように第一引数のclosureが引数をとれるようになる。

```rust
#[tokio::test]
async fn collect_and_retry_retries_when_success_condition_is_met() -> Result<(), Box<dyn Error>>
{
    let result = RetryPolicy::fixed(Duration::from_millis(1))
        .collect_and_retry(
            |input: u32| async move { Ok::<u32, u32>(input + 1) },
            |result: &u32| if *result < 2 { Some(*result) } else { None },
            |err: &u32| *err > 1,
            0 as u32,
        )
        .await;
    assert_eq!(result, Ok(vec![1, 2]));
    Ok(())
}
```

## まとめ

* retry関連の処理がシンプルに書いてあって読みやすかったです。loopの実行制御と判定処理がきれいに分離されていました。
* async blockをもつclosureをwrapする処理を提供したいときの抽象化の仕方がとても参考になりました。(`Task` trait)

