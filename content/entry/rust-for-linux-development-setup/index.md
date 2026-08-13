+++
title = "Rust で Kernel module をビルドして動かす環境を作る"
slug = "rust-for-linux-development-setup"
description = "Nix と libvirt で作る rust module 開発環境"
date = "2026-08-11"
draft = true
[taxonomies]
tags = ["rust", "linux"]
[extra]
image = "images/emoji/crab.png"
+++


## 概要

本記事では、Rustで書いたLinux kernel moduleをビルドして動かすための環境を構築します。
<!-- TODO: kernel はじめての人でも理解できるようにする -->
ホストで kernel image および module をビルドして、KVM/QEMU による VM を libvirt 経由で動かします。
KVM/QEMU という表記でピンとこなかったり、libvirt が初めてという方は [Mastering KVM Virtualization](https://www.packtpub.com/en-us/product/mastering-kvm-virtualization-9781784396916) がオススメです。KVM とはなにか、QEMUとどう協力して、"VM" を実現しているかの説明があります。

ゴールは、以下の Rust module を `.ko` としてビルドして、VM上で、`insmod` するところまでです。

```rust
use kernel::prelude::*;

module! {
    type: MiscDrv,
    name: "miscdrv",
    authors: ["ymgyt"],
    description: "Rust misc device lab",
    license: "GPL",
}

struct MiscDrv;

impl kernel::Module for MiscDrv {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("loaded\n");
        Ok(Self)
    }
}

impl Drop for MiscDrv {
    fn drop(&mut self) {
        pr_info!("unloaded\n");
    }
}
```

code は [ymgyt/drivers](https://github.com/ymgyt/drivers) repo で確認できます。
qemuやlibvirtの依存は `flake.nix` で宣言しているので、`nix develop` で有効にします。

```sh
git clone https://github.com/ymgyt/drivers.git
cd drivers
nix develop
```


## Base VMの作成

まず debian VM を作成します。ホストで kernel image をビルドする際の基準となる設定を取得するためです。

<!-- TODO: moduleがkernel imageを必要とする理由を説明したい -->

<!-- TODO: poolについて補足 -->
```sh
just vm pool define
command: virsh --connect qemu:///system pool-define-as drivers dir --target <repo>/vm/storage
Pool drivers defined


❯ just vm pool start
command: virsh --connect qemu:///system pool-start drivers
Pool drivers started
```

VM の base image として利用する debian image を取得します。

```sh
❯ just vm image

image: downloading debian-13-nocloud-amd64-20260810-2566.qcow2
image: verifying SHA-512
image: checksum verified
pool: refreshing drivers
command: virsh --connect qemu:///system pool-refresh drivers
Pool drivers refreshed

volume: debian-13-nocloud-amd64-20260810-2566.qcow2
command: virsh --connect qemu:///system vol-info debian-13-nocloud-amd64-20260810-2566.qcow2 --pool drivers
Name:           debian-13-nocloud-amd64-20260810-2566.qcow2
Type:           file
Capacity:       3.00 GiB
Allocation:     387.25 MiB
```

```sh
❯ just vm overlay deb13

volume: creating deb13.qcow2
command: virsh --connect qemu:///system vol-create-as drivers deb13.qcow2 3221225472 --format qcow2 --backing-vol debian-13-nocloud-amd64-20260810-2566.qcow2 --backing-vol-format qcow2
Vol deb13.qcow2 created

volume: deb13.qcow2
command: virsh --connect qemu:///system vol-info deb13.qcow2 --pool drivers
Name:           deb13.qcow2
Type:           file
Capacity:       3.00 GiB
Allocation:     196.00 KiB
```

```sh
❯ just vm define deb13

domain: rendered vm/domains/deb13/domain.xml
domain: defining deb13
command: virsh --connect qemu:///system define vm/domains/deb13/domain.xml --validate
Domain 'deb13' defined from vm/domains/deb13/domain.xml

command: virsh --connect qemu:///system dominfo deb13
Id:             -
Name:           deb13
UUID:           6e62dce4-6248-4db5-bfbb-2049bcbc5dc5
OS Type:        hvm
State:          shut off
CPU(s):         2
Max memory:     2097152 KiB
Used memory:    2097152 KiB
Persistent:     yes
Autostart:      disable
Autostart Once: disable
Managed save:   no
Security model: none
Security DOI:   0
```

VM に接続します。

```sh
just vm boot deb13

<boot log...>

Linux localhost 6.12.101+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.101-1 (2026-08-05) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
root@localhost:~# uname -a
Linux localhost 6.12.101+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.101-1 (2026-08-05) x86_64 GNU/Linux
```
