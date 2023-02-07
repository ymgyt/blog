+++
title = "🔖 Rustでgitのtagをbumpする"
slug = "bump-git-tags-with-rust"
date = "2020-04-05"
draft = false
[taxonomies]
tags = ["rust"]
+++

同じチームのメンバーが[nodegit](https://github.com/nodegit/nodegit)というnodeの[libgit2](https://libgit2.org/)のbindingを利用して、便利なツールを作っているのをみて各言語にgitを操作するためのライブラリーへのbindingがあることを知りました。
そこで、今回はRustのlibgit2 bindingである[git2-rs](https://github.com/rust-lang/git2-rs)を利用して、gitのtagをbumpして、remoteにpushするcliを作ってみようと思います。
[sourceはこちら](https://github.com/ymgyt/git-bump)


## 作ったcli

{{ figure(caption="git-bump", images=["images/git_bump.gif"]) }}

実行するとlocalのtag一覧を取得して、semantic versionでsortし、bumpするversionを選択します。
versionを選択してもらったら、現在のHEADを対象にtagを作成し、remoteにpushします。


## Bump処理

```toml
[dependencies]
clap = "2.33.0"
git2 = "0.13.0"
tracing = "0.1.13"
tracing-subscriber = "0.2.3"
log = "0.4.8"
semver = "0.9.0"
anyhow = "1.0.27"
colored = "1.9.3"
dialoguer = "0.5.0"
```

```rust

pub mod cli;

use anyhow::anyhow;
use colored::*;
use dialoguer::theme::ColorfulTheme;
use semver::{SemVerError, Version};
use std::io::{self, Write};
use std::result::Result as StdResult;
use std::borrow::Cow;
use tracing::{debug, warn};

#[derive(Debug, PartialEq, Eq)]
pub enum Bump {
    Major,
    Minor,
    Patch,
}

type Result<T> = std::result::Result<T, anyhow::Error>;

pub struct Config {
    pub prefix: Option<String>,
    pub repository_path: Option<String>,
    #[doc(hidden)]
    pub __non_exhaustive: (), // https://xaeroxe.github.io/init-struct-pattern/
}

impl Default for Config {
    fn default() -> Self {
        Self {
            prefix: Some("v".to_owned()),
            repository_path: None,
            __non_exhaustive: (),
        }
    }
}

impl Config {
    pub fn bump(self) -> Result<()> {
        self.build()?.bump()
    }

    fn build(self) -> Result<Bumper> {
        let repo = match self.repository_path {
            Some(path) => git2::Repository::open(&path)?,
            None => git2::Repository::open_from_env()?,
        };
        Ok(Bumper {
            prefix: self.prefix,
            repo,
            cfg: git2::Config::open_default()?,
            w: io::stdout(),
        })
    }
}

struct Bumper {
    prefix: Option<String>,
    repo: git2::Repository,
    cfg: git2::Config,
    w: io::Stdout,
}

impl Bumper {
    fn bump(mut self) -> Result<()> {
        let pattern = self.prefix.as_deref().map(|p| format!("{}*", p));
        let tags = self.repo.tag_names(pattern.as_deref())?;
        debug!(
            "found {} tags (pattern: {})",
            tags.len(),
            pattern.unwrap_or("".to_owned())
        );

        let (mut versions, errs) = self.parse_tags(tags);
        errs.into_iter().for_each(|e| match e {
            (tag, semver::SemVerError::ParseError(e)) => {
                warn!("malformed semantic version: {} {}", tag, e)
            }
        });
        versions.sort();

        let current = match versions.last() {
            None => {
                writeln!(
                    self.w.by_ref(),
                    "{} (pattern: {})",
                    "version tag not found".red(),
                    self.prefix.as_deref().unwrap_or("")
                )?;
                return Ok(());
            }
            Some(v) => v,
        };

        let mut bumped = current.clone();
        match self.prompt_bump(&current)? {
            Bump::Major => bumped.increment_major(),
            Bump::Minor => bumped.increment_minor(),
            Bump::Patch => bumped.increment_patch(),
        }

        if !self.confirm_bump(&current, &bumped)? {
            writeln!(self.w.by_ref(), "canceled")?;
            return Ok(());
        }

        let tag_oid = self.create_tag(&bumped)?;
        debug!("create tag(object_id: {})", tag_oid);

        self.push_tag(&bumped)
    }

    fn parse_tags(
        &mut self,
        tags: git2::string_array::StringArray,
    ) -> (Vec<Version>, Vec<(String, SemVerError)>) {
        let (versions, errs): (Vec<_>, Vec<_>) = tags
            .iter()
            .flatten()
            .map(|tag| tag.trim_start_matches(self.prefix.as_deref().unwrap_or("")))
            .map(|tag| Version::parse(tag).map_err(|err| (tag.to_owned(), err)))
            .partition(StdResult::is_ok);
        (
            versions.into_iter().map(StdResult::unwrap).collect(),
            errs.into_iter().map(StdResult::unwrap_err).collect(),
        )
    }

    fn prompt_bump(&mut self, current: &Version) -> Result<Bump> {
        let selections = &["major", "minor", "patch"];
        let select = dialoguer::Select::with_theme(&ColorfulTheme::default())
            .with_prompt(&format!("select bump version (current: {})", current))
            .default(0)
            .items(&selections[..])
            .interact()
            .unwrap();
        let bump = match select {
            0 => Bump::Major,
            1 => Bump::Minor,
            2 => Bump::Patch,
            _ => unreachable!(),
        };
        Ok(bump)
    }

    fn confirm_bump(&mut self, current: &Version, bumped: &Version) -> Result<bool> {
        let branch_name = git2::Branch::wrap(self.repo.head()?)
            .name()?
            .unwrap_or("")
            .to_owned();

        let head = self.repo.head()?.peel_to_commit()?;
        let w = self.w.by_ref();
        writeln!(w, "current HEAD")?;
        writeln!(w, "  branch : {}", branch_name)?;
        writeln!(w, "  id     : {}", head.id())?;
        writeln!(w, "  summary: {}", head.summary().unwrap_or(""))?;
        writeln!(w, "")?;
        dialoguer::Confirmation::new()
            .with_text(&format!(
                "bump version {prefix}{current} -> {prefix}{bumped}",
                prefix = format!("{}", self.prefix.as_deref().unwrap_or(""))
                    .red()
                    .bold(),
                current = format!("{}", current).red().bold(),
                bumped = format!("{}", bumped).red().bold(),
            ))
            .default(false)
            .interact()
            .map_err(anyhow::Error::from)
    }

    fn create_tag(&mut self, version: &Version) -> Result<git2::Oid> {
        let head = self.repo.head()?;
        if !head.is_branch() {
            return Err(anyhow!("HEAD is not branch"));
        }
        let obj = head.peel(git2::ObjectType::Commit)?;
        let signature = self.repo.signature()?;
        self.repo
            .tag(&format!("v{}", version), &obj, &signature, "", false)
            .map_err(anyhow::Error::from)
    }

    fn push_tag(&mut self, version: &Version) -> Result<()> {
        let mut origin = self.repo.find_remote("origin")?;

        let mut push_options = git2::PushOptions::new();
        let mut cb = git2::RemoteCallbacks::new();
        cb.transfer_progress(|_progress| {
            debug!(
                "called progress total_objects: {}",
                _progress.total_objects()
            );
            true
        })
        .push_update_reference(|reference, msg| {
            match msg {
                Some(err_msg) => println!("{}", err_msg.yellow()),
                None => println!("successfully pushed origin/{}", reference),
            }
            Ok(())
        })
        .credentials(|url, username_from_url, allowed_types| {
            debug!(
                "credential cb url:{} username_from_url:{:?} allowed_type {:?}",
                url, username_from_url, allowed_types
            );
            if allowed_types.contains(git2::CredentialType::USER_PASS_PLAINTEXT) {
                let user_name = match username_from_url {
                    Some(u) => Some(Cow::from(u)),
                    None => match self.user_name() {
                        Ok(Some(u)) => Some(u),
                        _ => None,
                    },
                };
                return match git2::Cred::credential_helper(&self.cfg, url, user_name.as_deref()) {
                    Ok(cred) => {
                        debug!("credential helper success");
                        Ok(cred)
                    }
                    Err(err) => {
                        debug!("{}", err);
                        // TODO: cache user credential to avoid prompt every time if user agree.
                        let cred = prompt_userpass()
                            .map_err(|_| git2::Error::from_str("prompt_userpass"))?;
                        git2::Cred::userpass_plaintext(&cred.0, &cred.1)
                    }
                };
            }
            // TODO: currently only USER_PASS_PLAINTEXT called :(
            git2::Cred::ssh_key_from_agent("xxx")
        });

        push_options.remote_callbacks(cb);

        let ref_spec = format!("refs/tags/v{0}:refs/tags/v{0}", version);
        debug!("refspec: {}", ref_spec);

        origin
            .push(&[&ref_spec], Some(&mut push_options))
            .map_err(anyhow::Error::from)
    }

    fn user_name(&self) -> Result<Option<Cow<str>>> {
        for entry in &self.cfg.entries(Some("user*"))? {
            if let Ok(entry) = entry {
                debug!("found {:?} => {:?}", entry.name(), entry.value());
                return Ok(entry.value().map(|v| Cow::Owned(String::from(v))));
            }
        }
        Ok(None)
    }
}

fn prompt_userpass() -> Result<(String, String)> {
    let username = dialoguer::Input::<String>::new()
        .with_prompt("username")
        .interact()?;
    let password = dialoguer::PasswordInput::new()
        .with_prompt("password")
        .interact()?;
    Ok((username, password))
}

```

`Bumper::bump()` がentry pointです。  
流れとしては、まず`git2::Repository::open_from_env()`で[`Repository`](https://docs.rs/git2/0.13.1/git2/struct.Repository.html)を取得します。  
この`Repository`に各処理の起点となるmethodが定義されています。  
今回は、tagの一覧がほしいので、`Repository::tag_names()` を呼び出し、[`StringArray`](https://docs.rs/git2/0.13.1/git2/string_array/struct.StringArray.html)を取得します。
`&'a StringArray` は`Iterator`を実装しているので、perseしてsemantic versionの一覧に変換します。  
ユーザにbumpするversionを選択してもらったあとは、bumpされたversionでtagを作成します。

```rust
    fn create_tag(&mut self, version: &Version) -> Result<git2::Oid> {
        let head = self.repo.head()?;
        if !head.is_branch() {
            return Err(anyhow!("HEAD is not branch"));
        }
        let obj = head.peel(git2::ObjectType::Commit)?;
        let signature = self.repo.signature()?;
        self.repo
            .tag(&format!("v{}", version), &obj, &signature, "", false)
            .map_err(anyhow::Error::from)
    }
```

`Repository::tag()`が定義されているので、tagを作るのはこれを呼ぶのかなと思い、docをみてみると以下のように定義されています。
```rust
pub fn tag(
    &self,
    name: &str,
    target: &Object,
    tagger: &Signature,
    message: &str,
    force: bool
) -> Result<Oid, Error>
```
ここで、`Object`なる聞き慣れない型がでてきました。ここで、`git object`で検索すると公式?の[Chapter 10 Git Internal](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects)の記事がでてきました。
どうやら、Gitは内部的に、key-value storeを備えており、valueはblobとして保持しているようです。このblobを特定の型(データモデル)として扱うことをpeelと呼んでいるみたいです。
ということで、cliから`git tag vX.Y.Z`と実行したときはHEADが対象になることにならって、`Repository::head()` でHEADを取得するようにしてみました。

### 認証がやっかい

localにtagを作成したあとはremoteにpushするだけなのですが、ここがやっかいでした。
まず、`Repository::find_remote()` で[`Remote`](https://docs.rs/git2/0.13.1/git2/struct.Remote.html)を取得し、`Remote:push()`を実行します。`push`は以下のように定義されています。
```rust
pub fn push<Str: AsRef<str> + IntoCString + Clone>(
    &mut self,
    refspecs: &[Str],
    opts: Option<&mut PushOptions>
) -> Result<(), Error>
```

refspecsについては、`refs/tags/vX.Y.Z:refs/tags/vX.Y.Z`のように、refs以下をそのまま対応させたらうまくいきました。
次の引数、`PushOptions`にcallbackとして認証処理をわたせるようになっています。

```rust
pub fn credentials<F>(&mut self, cb: F) -> &mut RemoteCallbacks<'a>
where
    F: FnMut(&str, Option<&str>, CredentialType) -> Result<Cred, Error> + 'a, 
```
ここでdocumentにあまり情報がなく、困ったのですが、[issue](https://github.com/rust-lang/git2-rs/issues?q=is%3Aissue+authentication+required+but+no+callback+set)と[cargoのコメント](https://github.com/rust-lang/cargo/blob/6a7672ef5344c1bb570610f2574250fbee932355/src/cargo/sources/git/utils.rs#L409)から、callbackの第3引数(`allowed_types`)に応じて、[`git2::Cred`](https://docs.rs/git2/0.13.1/git2/struct.Cred.html)を生成して返せばよさそうだったので、`git2::Cred::user_pass_plaintext()`を実行したところ、githubに認証してもらえました。

毎回認証のpromptをだすのはさすがに煩わしいので、このあたりは改善したいです。
[libgit2にもdoc](https://libgit2.org/docs/guides/authentication/)があります。

## まとめ

Rustからgitの処理を安全に(FFIをwrapしてもらった形で)扱える。

