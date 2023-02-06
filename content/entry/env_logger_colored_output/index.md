+++
title = "Rustのenv_loggerに色をつける"
slug = "rust_env_logger_colored_output"
date = "2019-08-09"
draft = false
[taxonomies]
tags = ["rust"]
+++

env_loggerの出力に色をつけたかったのですが、exampleが見つからず、docを読んだ結果以下のような処理になりました。


```toml
[dependencies]
log = "0.4.8"
env_logger = "0.6.2"
```

```rust
use env_logger::{fmt::Color, Builder};
use log::{Level,trace,debug,info,warn,error};
use std::io::Write;

fn init_logger() {
    let mut builder = Builder::new();

    builder.format(|buf, record| {
        let level_color = match record.level() {
            Level::Trace => Color::White,
            Level::Debug => Color::Blue,
            Level::Info => Color::Green,
            Level::Warn => Color::Yellow,
            Level::Error => Color::Red,
        };
        let mut level_style = buf.style();
        level_style.set_color(level_color);

        writeln!(
            buf,
            "{level} {file}:{line} {args}",
            level = level_style.value(record.level()),
            args = level_style.value(record.args()),
            file = level_style.value(&record.file().unwrap_or("____unknown")[4..]), // src/file.rs -> file.rs
            line = level_style.value(record.line().unwrap_or(0)),
        )
    });
    builder.filter(None, log::LevelFilter::Trace);
    builder.write_style(env_logger::WriteStyle::Auto);

    builder.init();
}

fn main() {
    init_logger();

    trace!("trace");
    debug!("debug");
    info!("info");
    warn!("warn");
    error!("error");
}
```