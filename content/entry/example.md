+++
title = "Example entry"
slug = "example"
date = "2023-02-06"
draft = true
[taxonomies]
tags = ["rust"]
+++

# H1 Content

## H2 Content1

## H2 Content2


# Example

## Rust code

```rust
#[tokio::main]
async fn main() -> Result<(),anyhow::Error> {
  println!("Hello");

  Ok(())
}
```

[Some link](https://tera.netlify.app/docs/#control-structures)

## List

* Item 1
  * Item 1 1
  * Item 1 2
* Item 2

## Quote

> Hello from zola!
>
> AAA BBB XXX
>> Nested!!

## Table

| AAA | BBB |
| --- | --- |
| aaaaaaaaa | bbbbbbbbbbb |

## HR

`---`

---

`***`
***

`___`
___
