+++
title = "🦀 Rust で Kernel module をビルドして動かす環境を作る"
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
ゴールは、以下の Rust module を `miscdrv.ko` としてビルドして、VM上で、`insmod` するところまでです。

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

最終的には、VM 上で以下のように module を load/unload できるようになります。

```sh
root@localhost:~# insmod /mnt/drivers/miscdrv.ko
[ 5930.423638] miscdrv: loaded
root@localhost:~# rmmod miscdrv
[ 5982.685953] miscdrv: unloaded
```

ビルドはホストで行い、実行はVM 上で行います。
VM は KVM/QEMU で動かし、libvirt で管理します。KVM/QEMU/libvirt については前提の節で簡単に触れますが、より詳しくは [Mastering KVM
  Virtualization](https://www.packtpub.com/en-us/product/mastering-kvm-virtualization-9781784396916)がオススメです。

kernel module を作るのが初めての方を想定しています。

本記事のコードはすべて [ymgyt/drivers](https://github.com/ymgyt/drivers) repo で確認できます。

```sh
git clone https://github.com/Rust-for-Linux/linux.git
git clone https://github.com/ymgyt/drivers.git
cd drivers
nix develop
```

## 前提の確認

### Kernel Module とは

Kernel module とは、実行中の kernel に実行コードを動的に追加する仕組みです。
Kernel のビルドシステム(Makefile)に module を作成するためのレシピ(target)が用意されています。
本記事では、`miscdrv.rs` から `miscdrv.ko` を生成します。
`.ko` の実体は ELF Relocatable file(`ET_REL`) です。

```sh
❯ readelf --file-header miscdrv.ko | rg Type:
  Type:                              REL (Relocatable file)
```

`[f]init_module()` という module をロードするための system call があり、`insmod` も最終的に [`finit_module()`](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-module.c#L650) を呼んでいます。

kernel module は kernel と同じアドレス空間・同じ特権レベルで動作します。
module からは kernel 本体が `EXPORT_SYMBOL[_GPL]` した関数を呼ぶことができます。

これらのいわば内部APIには、メモリ割当処理(`kmalloc()`)や各種サブシステムへの登録処理(`misc_register()` など)が含まれています。
ただし、互換性については、userspace(system call, ABI) とは異なり、一切保証されません([stable-api-nonsense](https://www.kernel.org/doc/html/latest/process/stable-api-nonsense.html))。
したがって、ビルド時に想定していた `foo()` がロード時の kernel に同じ signature で存在する保証はありません。

そのため、ビルド時に参照していた関数(symbol) のメタデータ(CRC) を `.ko` に埋め込んでおき、ロード時に、検証する仕組みがあります。
このメタデータを埋め込むために、module のビルド前に、kernel image をビルドし、`Module.symvers` file を生成しておく必要があります。

以下のように、実際に moduleに埋め込まれている、`printk` のCRC `0xca2eebaa` はビルド時に参照したkernel の`Module.symvers` の値と一致していました。

```sh
❯ modprobe --show-modversions  handson/miscdrv/module/miscdrv.ko
0xca2eebaa      _RNvNtCse297zByDW5v_6kernel5print11call_printk
0xd272d446      __x86_return_thunk
0x7406cc83      module_layout

❯ rg _RNvNtCse297zByDW5v_6kernel5print11call_printk .build/rust-next/Module.symvers
4821:0xca2eebaa _RNvNtCse297zByDW5v_6kernel5print11call_printk  vmlinux EXPORT_SYMBOL_GPL
```

[`modprobe` の src](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-elf.c#L542) をみると、ELF の [`__versions` section](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-elf.c#L44) からこれらの情報を取得していることがわかります。

以上より、kernel module をビルドするには、事前にその module が処理の対象とする、kernel image をビルドし、`Module.symvers` を生成しておく必要があることになります。

### Kernel Config とは

次にkernel をビルドする際の設定方法についてです。
kernel のソースコードには以下のように `CONFIG_XXX` による conditional compile があります。

```c
struct task_struct {
/* ... */
#ifdef CONFIG_MEM_ALLOC_PROFILING
	struct alloc_tag		*alloc_tag;
#endif
/* ... */
```

rust では`#[cfg()]` が使われます。
以下は概要に載せた `module!` マクロの展開結果の一部([rust/macros/module.rs](https://github.com/Rust-for-Linux/linux/blob/rust-next/rust/macros/module.rs) が生成するコード)で、`MODULE` は「module としてビルドされているか」を表す cfg です。

```rust
#[cfg(MODULE)]
static THIS_MODULE: ::kernel::ThisModule = unsafe {
    extern "C" {
        static __this_module: ::kernel::types::Opaque<::kernel::bindings::module>;
    };

    ::kernel::ThisModule::from_ptr(__this_module.get())
};

#[cfg(not(MODULE))]
static THIS_MODULE: ::kernel::ThisModule = unsafe {
    ::kernel::ThisModule::from_ptr(::core::ptr::null_mut())
};
```

同じソースコードが、module としてビルドされる場合は kernel がロード時に用意する `__this_module` を参照し、kernel 本体に組み込まれる場合(built-in)は null を使う、というように分岐しています。

kernel をビルドする際には、最終的には全ての設定を解決した`.config` を用意します。
`.config` の項目は on/off だけではなく、多くの機能が `y`/`m`/`n` の 3 値(tristate)をとります。

- `y`: kernel image に組み込む(built-in)
- `m`: module(`.ko`)としてビルドし、実行時に load する
- `n`: ビルドしない

例えば virtio の block driver は、Debian の config では module ですが、本記事で最終的に使う config では kernel に組み込んでいます。

```sh
❯ rg '^CONFIG_VIRTIO_BLK=' dev/kernel/config/debian-13-amd64 .build/rust-next/.config

.build/rust-next/.config
1968:CONFIG_VIRTIO_BLK=y

dev/kernel/config/debian-13-amd64
2691:CONFIG_VIRTIO_BLK=m
```

Debian のような汎用 distro は、幅広いハードウェアに対応しつつ、使わない機能をメモリに載せないために、可能な限り `m` を選ぶ方針をとっています。実際、Debian の config では設定されている 6,896 項目のうち 4,049 項目が `=m` でした。
どの機能を `y` にし、どれを `m` のままにするかは、後の Kernel config の設定の節で行う作業の中心になります。

`.config` で設定できる項目は膨大でゼロから全てを設定して意図したビルドを実現するのは大変です。
そこで本記事では debian-13 のVM を用意してそこで利用されている`.config` を出発点にするアプローチを採りました。

### KVM/QEMU/libvirt

<!-- TODO: 後で書く -->


## 全体の流れ

上述の通り、kernel module をビルドするには、load 先となる kernel を先にビルドしておく必要があります。
まず、ビルドする kernel ですが、[Rust for Linux](https://rust-for-linux.com/) の開発 branch である [rust-next](https://github.com/Rust-for-Linux/linux) を利用します。Rust 関連の変更が mainline より先にここに取り込まれるため、常に最新の変更を試せるからです。
ただし、mainline でも問題ありません。rust-next の変更は merge window ごとに mainline に取り込まれ、rust-next 自体も mainline の rc 版を base にしているため、両者に大きな乖離はありません。

kernel のビルドに必要な `.config` は、Debian の config を出発点にします。このために、まず Debian VM(deb13)を作成し、config と lsmod を採取します。
lsmod には実際に load されている module 一覧が含まれています。これを利用して、kernel ビルド時にビルドする module(driver) の数を減らします。

ビルドした kernel は、VM に install する代わりに、QEMU の direct kernel boot で起動します。
QEMU は disk 内の bootloader を経由せずに、ホスト上の kernel image を直接 load して boot できます。
kernel を作り直すたびに VM 内での install 作業が不要になる一方、initramfs を使わない boot になるため、boot に必要な driver(virtio や ext4)は module ではなく `y` で kernel に組み込んでおきます。

最後に、この kernel に対して miscdrv module をビルドし、virtiofs の共有 directory 経由で VM に渡して `insmod` します。

{{ figure(images=["images/kernel-development-flow.svg"], caption="開発環境の全体像") }}

## Debian VM(deb13)の作成

まず debian VM を作成します。ホストで kernel image をビルドする際の基準となる設定(config と lsmod)を取得するためです。

libvirt では、VM の disk などの storage を pool という単位で管理します。[`dir` type の pool](https://libvirt.org/storage.html#directory-pool) の実体はただの directory で、その中の file が volume として扱われます。ここでは repo 内の `vm/storage/` を `drivers` という名前の pool として登録します。

```sh
❯ just vm pool define

command: virsh --connect qemu:///system pool-define-as drivers dir --target <repo>/vm/storage
Pool drivers defined

❯ just vm pool start
command: virsh --connect qemu:///system pool-start drivers
Pool drivers started
```

VM の base image として利用する [debian cloud image](https://cloud.debian.org/images/cloud/) を取得します。
image には nocloud variant を利用します。cloud-init が入っておらず、root にパスワードなしで serial console からログインできるため、実験用途に向いています。

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

取得した base image を VM の disk として直接使うのではなく、base image を backing file とする copy-on-write の volume(overlay)を VM ごとに作成します。書き込みは overlay 側にのみ記録され、base image は変更されません。後で作成する rust VM も同じ base image を共有し、それぞれ自分の overlay を持ちます。

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

作成直後の overlay は、Capacity 3.00 GiB に対して Allocation(実際に確保された容量)が 196.00 KiB しかないことから、まだほとんど何も書き込まれていないことが確認できます。

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

### config と lsmod の採取

ホストとの file のやりとりには virtiofs を利用します。domain XML で、ホストの `vm/shared/` directory を `drivers` という名前で guest に export しており、guest からは virtiofs として mount することでアクセスできます。

```sh
root@localhost:~# mkdir -p /mnt/drivers
root@localhost:~# mount -t virtiofs drivers /mnt/drivers
root@localhost:~# findmnt /mnt/drivers
TARGET       SOURCE  FSTYPE   OPTIONS
/mnt/drivers drivers virtiofs rw,relatime

root@localhost:~# cp /boot/config-$(uname -r) /mnt/drivers/
```

続けて、load されている module の一覧も採取します。これは後の Kernel config の作成で利用します。

```sh
lsmod > /mnt/drivers/lsmod-$(uname -r)
```

host 側で、採取した config を repo の管理下に copy します。

```sh
❯ file vm/shared/config-6.12.101+deb13-amd64
vm/shared/config-6.12.101+deb13-amd64: Linux make config build file, ASCII text

❯ cp vm/shared/config-6.12.101+deb13-amd64 dev/kernel/config/debian-13-amd64
```

## Kernel configの作成

採取した Debian の config を出発点に、rust-next 用の `.config` を作成します。まず seed となる config を build directory に copy します。

```sh
❯ just kernel initconfig
mkdir -p "<repo>/.build/rust-next"
cp --force "<repo>/dev/kernel/config/debian-13-amd64" "<repo>/.build/rust-next/.config"
```

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

採取した lsmod を用いて、ビルドする module を実際に load されていたものに絞り込みます。

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

kernel の version が `7.2.0-rc1+` となっているのは、rust-next が mainline の 7.2-rc1 を base にしているためです。`+` は、ビルド元の tree が release tag の commit と一致すると確認できなかった場合に付く印です。


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
