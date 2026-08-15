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
git clone https://github.com/Rust-for-Linux/linux.git
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
❯ just vm boot deb13

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

### Kernel configの取得

```sh
root@localhost:~# mkdir -p /mnt/drivers
root@localhost:~# mount -t virtiofs drivers /mnt/drivers
root@localhost:~# findmnt /mnt/drivers
TARGET       SOURCE  FSTYPE   OPTIONS
/mnt/drivers drivers virtiofs rw,relatime

root@localhost:~# cp /boot/config-$(uname -r) /mnt/drivers/
```

host 側で

```sh
❯ file vm/shared/config-6.12.101+deb13-amd64
vm/shared/config-6.12.101+deb13-amd64: Linux make config build file, ASCII text

❯ cp vm/shared/config-6.12.101+deb13-amd64 dev/kernel/config/debian-13-amd64

❯ just kernel initconfig
mkdir -p "<repo>/.build/rust-next"
cp --force "<repo>/dev/kernel/config/debian-13-amd64" "<repo>/.build/rust-next/.config"
```

### Kernel configの設定

```sh
❯ just kernel olddefconfig

make -C "<repo>/../linux" "O=<repo>/.build/rust-next" olddefconfig
make: Entering directory '/home/ymgyt/rs/linux'
make[1]: Entering directory '/home/ymgyt/rs/drivers/.build/rust-next'
.config:1420:warning: symbol value 'm' invalid for NETFILTER_NETLINK
.config:6870:warning: symbol value 'm' invalid for FB_BACKLIGHT
.config:8650:warning: symbol value 'm' invalid for HYPERV
.config:9969:warning: symbol value 'm' invalid for ANDROID_BINDER_IPC
.config:10916:warning: symbol value 'm' invalid for CRYPTO_LIB_CURVE25519_GENERIC
.config:10922:warning: symbol value 'm' invalid for CRYPTO_LIB_POLY1305_GENERIC
.config:11203:warning: symbol value 'n' invalid for BOOTPARAM_SOFTLOCKUP_PANIC
.config:11215:warning: symbol value 'n' invalid for BOOTPARAM_HUNG_TASK_PANIC
#
# configuration written to .config
#
make[1]: Leaving directory '/home/ymgyt/rs/drivers/.build/rust-next'
make: Leaving directory '/home/ymgyt/rs/linux'
```

rustを有効化

```sh
❯ just kernel rustconfig
"/home/ymgyt/rs/drivers/../linux/scripts/config" --file "/home/ymgyt/rs/drivers/.build/rust-next/.config" --enable GENDWARFKSYMS --enable RUST
```

VMに必要なdriverを有効化

```sh
❯ just kernel vmconfig
"/home/ymgyt/rs/drivers/../linux/scripts/config" --file "/home/ymgyt/rs/drivers/.build/rust-next/.config" --enable VIRTIO_MENU --enable VIRTIO_PCI --enable VIRTIO_BLK --enable EXT4_FS --enable EFI_PARTITION --enable FUSE_FS --enable VIRTIO_FS --enable SERIAL_8250 --enable SERIAL_8250_CONSOLE --enable VFAT_FS --enable NLS_CODEPAGE_437 --enable NLS_ASCII --enable EFIVAR_FS
```

### lsmodの取得

VM内で

```sh
lsmod > /mnt/drivers/lsmod-$(uname -r)
```

Hostで

```sh
❯ just kernel localmodconfig vm/shared/lsmod-6.12.101+deb13-amd64
yes "" | make -C "/home/ymgyt/rs/drivers/../linux" "O=/home/ymgyt/rs/drivers/.build/rust-next" LLVM=1 CC=/nix/store/kfhjmd11ml2i4kpn57577k89ag4makaw-clang-21.1.8/bin/clang HOSTCC=/nix/store/m59w5gavjx8db0ay3m1yzbw02l54109b-clang-wrapper-21.1.8/bin/clang HOSTCXX=/nix/store/m59w5gavjx8db0ay3m1yzbw02l54109b-clang-wrapper-21.1.8/bin/clang++ RUSTC=/nix/store/8qpzf385bdb0dgzz85dvb1lfvf2fxipk-rustc-wrapper-1.96.1/bin/rustc BINDGEN=/nix/store/cx56arfh32zkp60bh35rhmcb6wjf38rb-rust-bindgen-unwrapped-0.72.1/bin/bindgen "LSMOD=/home/ymgyt/rs/drivers/vm/shared/lsmod-6.12.101+deb13-amd64" localmodconfig
make: Entering directory '/home/ymgyt/rs/linux'
make[1]: Entering directory '/home/ymgyt/rs/drivers/.build/rust-next'
```

## Kernel imageのbuild

```sh
❯ just kernel image
make -C "/home/ymgyt/rs/drivers/../linux" "O=/home/ymgyt/rs/drivers/.build/rust-next" LLVM=1 CC=/nix/store/kfhjmd11ml2i4kpn57577k89ag4makaw-clang-21.1.8/bin/clang HOSTCC=/nix/store/m59w5gavjx8db0ay3m1yzbw02l54109b-clang-wrapper-21.1.8/bin/clang HOSTCXX=/nix/store/m59w5gavjx8db0ay3m1yzbw02l54109b-clang-wrapper-21.1.8/bin/clang++ RUSTC=/nix/store/8qpzf385bdb0dgzz85dvb1lfvf2fxipk-rustc-wrapper-1.96.1/bin/rustc BINDGEN=/nix/store/cx56arfh32zkp60bh35rhmcb6wjf38rb-rust-bindgen-unwrapped-0.72.1/bin/bindgen -j14 bzImage
make: Entering directory '/home/ymgyt/rs/linux'
make[1]: Entering directory '/home/ymgyt/rs/drivers/.build/rust-next'
  SYNC    include/config/auto.conf
  HOSTRUSTC scripts/generate_rust_target

...

Kernel: arch/x86/boot/bzImage is ready  (#4)
```

## Rust VMの初期化

```sh
❯ just vm define rust
exists: vm/storage/debian-13-nocloud-amd64-20260810-2566.qcow2
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

volume: creating rust.qcow2
command: virsh --connect qemu:///system vol-create-as drivers rust.qcow2 3221225472 --format qcow2 --backing-vol debian-13-nocloud-amd64-20260810-2566.qcow2 --backing-vol-format qcow2
Vol rust.qcow2 created

volume: rust.qcow2
command: virsh --connect qemu:///system vol-info rust.qcow2 --pool drivers
Name:           rust.qcow2
Type:           file
Capacity:       3.00 GiB
Allocation:     196.00 KiB

domain: rendered vm/domains/rust/domain.xml
domain: defining rust
command: virsh --connect qemu:///system define vm/domains/rust/domain.xml --validate
Domain 'rust' defined from vm/domains/rust/domain.xml

command: virsh --connect qemu:///system dominfo rust
Id:             -
Name:           rust
UUID:           5ecd39df-0b03-4cb6-9d9d-5ebed3d88a51
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

```sh
❯ just vm boot rust

root@localhost:~# uname -a
Linux localhost 7.2.0-rc1+ #4 SMP PREEMPT_DYNAMIC Sat Aug 15 13:21:42 JST 2026 x86_64 GNU/Linux
```


## Module の build

```sh
❯ just kernel modules
```

```sh
❯ cd handson/miscdrv/module/

❯ make modules

❯ modinfo miscdrv.ko
filename:       /home/ymgyt/rs/drivers/handson/miscdrv/module/miscdrv.ko
author:         ymgyt
description:    Rust misc device lab
license:        GPL
name:           miscdrv
depends:
vermagic:       7.2.0-rc1+ SMP preempt mod_unload modversions
retpoline:      Y
```

## Module の実行

```sh
❯ cp handson/miscdrv/module/miscdrv.ko vm/shared

❯ just vm console rust

root@localhost:~# mkdir -p /mnt/drivers
root@localhost:~# mount -t virtiofs drivers /mnt/drivers
root@localhost:~# ls /mnt/drivers
config-6.12.101+deb13-amd64  lsmod-6.12.101+deb13-amd64  miscdrv.ko

root@localhost:~# insmod /mnt/drivers/miscdrv.ko
[ 5930.419675] miscdrv: loading out-of-tree module taints kernel.
[ 5930.421134] miscdrv: module verification failed: signature and/or required key missing - tainting kernel
[ 5930.423638] miscdrv: loaded

root@localhost:~# lsmod | grep miscdrv
miscdrv                12288  0
root@localhost:~# rmmod miscdrv
[ 5982.685953] miscdrv: unloaded
```
