+++
title = "🦀 Rust で Kernel module をビルドして動かす環境を作る"
slug = "rust-for-linux-development-setup"
description = "仕組みから理解する Rust for Linux 環境構築"
date = "2026-08-18"
draft = false
[taxonomies]
tags = ["rust", "linux"]
[extra]
image = "images/emoji/crab.png"
+++


## 概要

本記事では、Rust で書いた Linux kernel module をビルドして動かすための環境を構築します。
ゴールは、以下の Rust module を `miscdrv.ko` としてビルドして、VM 上で `insmod` するところまでです。

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

ビルドは host で行い、実行は VM 上で行います。
VM は KVM/QEMU で動かし、libvirt で管理します。KVM/QEMU/libvirt については前提の確認の節で簡単に触れますが、より詳しくは [Mastering KVM Virtualization](https://www.packtpub.com/en-us/product/mastering-kvm-virtualization-9781784396916) がオススメです。

kernel module を作るのが初めての方を想定しています。

本記事のコードはすべて [ymgyt/drivers](https://github.com/ymgyt/drivers/tree/blog-r4l-setup) repo で確認できます。qemu や rustc といった依存はすべて Nix で宣言しており、開発環境の節で準備します。

## 前提の確認

### Kernel module とは

kernel module とは、実行中の kernel に実行コードを動的に追加する仕組みです。
kernel のビルドシステム(Makefile)に module を作成するためのレシピ(target)が用意されています。
本記事では、`miscdrv.rs` から `miscdrv.ko` を生成します。
`.ko` の実体は ELF Relocatable file(`ET_REL`)です。

```sh
❯ readelf --file-header miscdrv.ko | rg Type:
  Type:                              REL (Relocatable file)
```

`[f]init_module()` という module を load するための system call があり、`insmod` も最終的に [`finit_module()`](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-module.c#L650) を呼んでいます。

kernel module は kernel と同じアドレス空間・同じ特権レベルで動作します。
module からは kernel 本体が `EXPORT_SYMBOL[_GPL]` した関数を呼ぶことができます。

これらのいわば内部 API には、memory 割当処理(`kmalloc()`)や各種 subsystem への登録処理(`misc_register()` など)が含まれています。
ただし、互換性については、userspace(system call、ABI)とは異なり、一切保証されません([stable-api-nonsense](https://www.kernel.org/doc/html/latest/process/stable-api-nonsense.html))。
したがって、ビルド時に想定していた `foo()` が load 時の kernel に同じ signature で存在する保証はありません。

そのため、ビルド時に参照していた関数(symbol)のメタデータ(CRC)を `.ko` に埋め込んでおき、load 時に検証する仕組みがあります。
このメタデータを埋め込むために、module のビルド前に kernel image をビルドし、`Module.symvers` file を生成しておく必要があります。

以下のように、実際に module に埋め込まれている `printk` の CRC `0xca2eebaa` は、ビルド時に参照した kernel の `Module.symvers` の値と一致していました。

```sh
❯ modprobe --show-modversions handson/miscdrv/module/miscdrv.ko
0xca2eebaa      _RNvNtCse297zByDW5v_6kernel5print11call_printk
0xd272d446      __x86_return_thunk
0x7406cc83      module_layout

❯ rg _RNvNtCse297zByDW5v_6kernel5print11call_printk .build/rust-next/Module.symvers
4821:0xca2eebaa _RNvNtCse297zByDW5v_6kernel5print11call_printk  vmlinux EXPORT_SYMBOL_GPL
```

[`modprobe` の src](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-elf.c#L542) をみると、ELF の [`__versions` section](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-elf.c#L44) からこれらの情報を取得していることがわかります。

以上より、kernel module をビルドするには、load 先となる kernel を先にビルドして `Module.symvers` を生成しておく必要があります。

### Kernel config とは

次に kernel をビルドする際の設定方法についてです。
kernel のソースコードには以下のように `CONFIG_XXX` による conditional compile があります。

```c
struct task_struct {
/* ... */
#ifdef CONFIG_MEM_ALLOC_PROFILING
	struct alloc_tag		*alloc_tag;
#endif
/* ... */
```

Rust では `#[cfg()]` が使われます。
以下は概要に載せた `module!` マクロの展開結果の一部([rust/macros/module.rs](https://github.com/Rust-for-Linux/linux/blob/dc59e4fea9d83f03bad6bddf3fa2e52491777482/rust/macros/module.rs) が生成するコード)で、`MODULE` は「module としてビルドされているか」を表す cfg です。

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

同じソースコードが、module としてビルドされる場合は kernel が load 時に用意する `__this_module` を参照し、kernel 本体に組み込まれる場合(built-in)は null を使う、というように分岐しています。

kernel をビルドする際には、最終的には全ての設定を解決した `.config` を用意します。
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

Debian のような汎用 distro は、幅広いハードウェアに対応しつつ、使わない機能を memory に載せないために、可能な限り `m` を選ぶ方針をとっています。実際、Debian の config では設定されている 6,896 項目のうち 4,049 項目が `=m` でした。
どの機能を `y` にし、どれを `m` のままにするかは、後の Kernel config の作成の節で行う作業の中心になります。

`.config` で設定できる項目は膨大でゼロから全てを設定して意図したビルドを実現するのは大変です。
そこで本記事では Debian 13 の VM を用意して、そこで利用されている `.config` を出発点にするアプローチを採りました。

なお、[How many ways are there to configure the Linux kernel?](https://lwn.net/Articles/1034811/) によると、6.16の段階で、x86_64 で、32,468の設定項目があるそうです。

### KVM/QEMU/libvirt

VM を作るとは、別の OS(kernel)を host 上の 1 つの process として動かすことだと考えてみます。
ただし kernel は、自分が HW を直接制御できる前提で書かれています。device の register を memory address に map して読み書きしたり(Memory-Mapped I/O、MMIO)、仮想アドレスと物理アドレスのマッピングを実行する process に応じて書き換えたりします。
userspace の process にこのような操作を許可することはできません。そこで、guest を実行して、guest 内で処理できない操作が起きたら制御が戻ってくるような API を考えます。

```rust
fn run_vm() {
    loop {
        match exec_guest() {
            Exit::Mmio(addr) => emulate_hw(addr),
            Exit::IoPort(port) => emulate_io(port),
            Exit::Halt => break,
        }
    }
}
```

CPU の仮想化支援機能(Intel VT-x / AMD-V)を抽象化して、概ね上記の機能を提供してくれるのが KVM です。
KVM は `/dev/kvm` という device file を userspace に公開しており、`KVM_RUN` ioctl を通じて guest を実行できます。(このあたりの話がピンとこなくても心配しないでください、一度 driver を書いてみると腹落ちします)
このとき guest の命令は、software が解釈・変換しているわけではなく、実 CPU が直接実行しています。KVM は `VMLAUNCH` / `VMRESUME` 命令(Intel の場合)で CPU を guest 用の実行 mode に切り替え、guest 内で処理できない操作が起きると CPU が host に制御を戻します(VM exit)。
VM exit で制御が戻る先は、`KVM_RUN` を呼び出した userspace process ではなく、まず host kernel 内の KVM です。KVM 内で処理できる場合は guest を再開し、userspace での処理が必要な場合に `KVM_RUN` が `KVM_EXIT_MMIO` のような exit reason とともに return します。
この切り替えを行っているのが [arch/x86/kvm/vmx/vmenter.S](https://github.com/Rust-for-Linux/linux/blob/dc59e4fea9d83f03bad6bddf3fa2e52491777482/arch/x86/kvm/vmx/vmenter.S) の `__vmx_vcpu_run` で、assembly で `vmlaunch` / `vmresume` を実行している箇所が確認できます。
思考実験では memory のマッピング変更も問題として挙げましたが、擬似コードの loop には登場していません。CPU の 2 段階のアドレス変換(Intel では EPT、AMD では NPT)を利用する場合、通常の `CR3` の変更や guest page table の更新を VM exit させる必要がないためです。CPU は guest の仮想アドレスを、guest が管理する page table で guest の物理アドレスに変換し、さらに host が管理する変換表で実際の物理アドレスに変換します。これにより guest kernel は、自分の page table の変更を KVM や QEMU に一つずつ emulate させることなく process ごとのマッピングを切り替えられます。一方、guest の物理アドレスに対応する二段目のマッピングが存在しない場合や権限に違反した場合は VM exit が発生するため、実際の物理アドレスへのマッピングは host の管理下に留まります。

そして KVM の実体は kernel module(`kvm` と `kvm_intel` / `kvm_amd`)です。本記事で扱う kernel module という仕組みの上に、仮想化基盤も実装されています。

ただし、KVM だけでは完全な VM にはなりません。KVM が userspace に返した device 操作を処理する、`emulate_hw()` の実装が別に必要です。guest 内で block device driver による書き込みが行われたら、host 側でなんらかの方法で永続化するといった処理が必要です。
これを提供してくれるのが QEMU です。上記の loop を回しているのも QEMU で、VM 1 台は host から見ると 1 つの QEMU process です。本記事では、qcow2 file がこの永続化先になります。
実際、擬似コードの loop は QEMU の [`kvm_cpu_exec()`](https://github.com/qemu/qemu/blob/20553466cc47af6a8c95f665b601fce3c852e503/accel/kvm/kvm-all.c#L3435) にほぼそのままの形で存在し、[`KVM_RUN` ioctl の呼び出し](https://github.com/qemu/qemu/blob/20553466cc47af6a8c95f665b601fce3c852e503/accel/kvm/kvm-all.c#L3472)と、返ってきた [`exit_reason` による分岐](https://github.com/qemu/qemu/blob/20553466cc47af6a8c95f665b601fce3c852e503/accel/kvm/kvm-all.c#L3517)(`KVM_EXIT_IO`、`KVM_EXIT_MMIO`、...)が確認できます。

さらに、QEMU や VirtualBox、Xen などを抽象化して、統一的な API(interface)で管理可能にしてくれるのが [libvirt](https://libvirt.org/) です。
host で libvirtd という daemon が動き、`virsh` はその client です。VM の定義は domain XML、disk は storage pool という単位で管理されます。以降の節のログに出てくる `--connect qemu:///system` は、この libvirtd への接続先を指定しています。
なお、`flake.nix` で入るのは virsh などの client 側なので、libvirtd は host で動かしておく必要があります(NixOS であれば `virtualisation.libvirtd.enable`)。

{{ figure(images=["images/kvm-execution-flow.svg"], caption="VM の管理と KVM による vCPU 実行") }}

そもそも仮想化とは何かについては、[作って理解する仮想化技術](https://gihyo.jp/book/2025/978-4-297-15012-9) が非常にオススメです。本記事で登場する virtio の説明や実装(virtio-blk)もあります。

### virtiofs による file 共有

本記事では、host と VM の file 共有に virtiofs を利用しています。

前提として、FUSE(Filesystem in Userspace)という仕組みがあります。filesystem の処理を kernel の外の process に移譲するためのもので、open/read/write といった処理の request/response 形式がプロトコルとして決まっています。
virtiofs は、この FUSE プロトコルを転用します。guest 内で mount した virtiofs への処理依頼を FUSE の request に serialize し、転送先を「同じマシンの userspace」ではなく「host 側」に差し替えたものが virtiofs です。
host 側では virtiofsd という daemon(libvirt が VM 起動時に立ち上げます)が request を受け、共有対象の directory 上で実際の file 操作を行って response を返します。guest から read すれば host の file の中身が返ってくるのはこのためです。

guest の virtiofs driver と host 側の backend との通信には virtio を利用します。virtio は、特定の physical device を再現するのではなく、guest driver と host backend が device request を受け渡すための共通 interface を定めています。request と buffer の位置を memory 上の queue(virtqueue)へ追加し、queue が更新されたことだけを host 側へ通知します。複数の request を memory 上でまとめて受け渡せるため、device 操作のたびに VM exit して内容を emulate する必要がありません。
つまり、VM(guest)内で実行されることを前提に、device に対する request/response をできるだけ memory に載せて、host に処理が戻る MMIO の頻度を抑える設計の device driver といえます。
本記事では file 共有(virtiofs)のほか、disk(virtio-blk)も同じ仕組みです。後の Kernel config の作成で `FUSE_FS` や `VIRTIO_FS`、`VIRTIO_BLK` を有効にするのは、この guest 側 driver を kernel に組み込むためです。
なお、virtiofsd は QEMU とは別の process なので、virtqueue を含む guest の memory にアクセスできるよう、VM の memory は共有可能な方式で確保する必要があります。domain XML の `memoryBacking`(memfd + shared)がその設定です。

## 全体の流れ

上述の通り、kernel module をビルドするには、load 先となる kernel を先にビルドしておく必要があります。
まず、ビルドする kernel ですが、[Rust for Linux](https://rust-for-linux.com/) の開発 branch である [rust-next](https://github.com/Rust-for-Linux/linux) を利用します。Rust 関連の変更が mainline より先にここに取り込まれるため、常に最新の変更を試せるからです。
ただし、mainline でも問題ありません。rust-next の変更は merge window ごとに mainline に取り込まれ、rust-next 自体も mainline の rc 版を base にしているため、両者に大きな乖離はありません。

kernel のビルドに必要な `.config` は、Debian の config を出発点にします。このために、まず Debian VM(deb13)を作成し、config と lsmod を採取します。
lsmod には実際に load されている module 一覧が含まれています。これを利用して、kernel ビルド時にビルドする module(driver)の数を減らします。

ビルドした kernel は、VM に install する代わりに、QEMU の direct kernel boot で起動します。
QEMU は disk 内の bootloader を経由せずに、host 上の kernel image を直接 load して boot できます。
kernel を作り直すたびに VM 内での install 作業が不要になる一方、initramfs を使わない boot になるため、boot に必要な driver(virtio や ext4)は module ではなく `y` で kernel に組み込んでおきます。

最後に、この kernel に対して miscdrv module をビルドし、virtiofs の共有 directory 経由で VM に渡して `insmod` します。

{{ figure(images=["images/kernel-development-flow.svg"], caption="開発環境の全体像") }}

## 開発環境

まず、rust-next と本記事の repo を clone します。drivers 側の task が `../linux` を参照するため、2 つの repo は同じ directory に並べる前提です。[Rust-for-Linux/linux](https://github.com/Rust-for-Linux/linux) は default branch が rust-next なので、branch の指定は不要です。

```sh
git clone https://github.com/Rust-for-Linux/linux.git
git clone https://github.com/ymgyt/drivers.git
cd drivers
git checkout blog-r4l-setup
nix develop
```

開発に必要な依存は `flake.nix` に宣言してあり、`nix develop` で有効になります。内訳は大きく 3 つです。

- VM の管理: libvirt(`virsh`)、QEMU、image の取得に使う curl など
- kernel のビルドに必要な host tool 群: make、flex、bison、bc、perl、python3 など
- Rust for Linux の toolchain: clang/LLVM、lld、rustc、bindgen(執筆時点では clang 21.1.8、rustc 1.96.1、bindgen 0.72.1)

kernel はビルドに必要な tool の最低 version を [changes.rst](https://docs.kernel.org/process/changes.html) で規定しています(執筆時点で Rust は 1.85.0、bindgen は 0.71.1 以上)。

`flake.nix` の shellHook では、環境変数もあわせて設定しています。

```nix
shellHook = ''
  export CC="${llvm.clang-unwrapped}/bin/clang"
  export HOSTCC="${llvm.clang}/bin/clang"
  export HOSTCXX="${llvm.clang}/bin/clang++"
  export BINDGEN="${pkgs.rust-bindgen-unwrapped}/bin/bindgen"
  export KERNEL_MAKE_ARGS="LLVM=1 CC=$CC HOSTCC=$HOSTCC HOSTCXX=$HOSTCXX RUSTC=$RUSTC BINDGEN=$BINDGEN"
  exec nu
'';
```

`KERNEL_MAKE_ARGS` は、以降の節で just が実行する make にそのまま渡されます。ログに出てくる `LLVM=1 CC=/nix/store/... RUSTC=/nix/store/...` という長い引数の正体はこれです。
`LLVM=1` は kernel を GCC ではなく clang/LLVM でビルドする指定です。Rust 側の bindgen が libclang を利用するため、C 側も同じ LLVM に揃えています。
`CC` にだけ unwrapped の clang を使っているのは Nix 特有の事情です。Nix の clang wrapper は Nix 環境向けの compile flag を暗黙に注入するため、flag を厳密に管理する kernel 本体のビルドには向きません。一方、ビルド中に host 側で動かす tool のビルド(`HOSTCC`)には、標準 library の解決をしてくれる wrapper の方が都合が良いためです。

toolchain が揃っているかは、kernel が用意している `rustavailable` target で確認できます。

```sh
❯ just kernel rustavailable
make -C "<linux>" "O=<drivers>/.build/rust-next" LLVM=1 CC=/nix/store/<hash>-clang-21.1.8/bin/clang HOSTCC=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang HOSTCXX=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang++ RUSTC=/nix/store/<hash>-rustc-wrapper-1.96.1/bin/rustc BINDGEN=/nix/store/<hash>-rust-bindgen-unwrapped-0.72.1/bin/bindgen rustavailable
make: Entering directory '<linux>'
make[1]: Entering directory '<drivers>/.build/rust-next'
Rust is available!
make[1]: Leaving directory '<drivers>/.build/rust-next'
make: Leaving directory '<linux>'
```

なお、shellHook の最後の `exec nu` により、`nix develop` 後の shell は [nushell](https://www.nushell.sh/) になります。この repo の task(just)が nushell を前提にしているためです。

## Debian VM(deb13)の作成

まず Debian VM を作成します。host で kernel image をビルドする際の基準となる設定(config と lsmod)を取得するためです。

libvirt では、VM の disk などの storage を pool という単位で管理します。[`dir` type の pool](https://libvirt.org/storage.html#directory-pool) の実体はただの directory で、その中の file が volume として扱われます。ここでは repo 内の `vm/storage/` を `drivers` という名前の pool として登録します。

```sh
❯ just vm pool define

command: virsh --connect qemu:///system pool-define-as drivers dir --target <drivers>/vm/storage
Pool drivers defined

❯ just vm pool start
command: virsh --connect qemu:///system pool-start drivers
Pool drivers started
```

VM の base image として利用する [Debian cloud image](https://cloud.debian.org/images/cloud/) を取得します。
Debian の cloud image は、AWS などの cloud platform 上で cloud-init という仕組みによって初期設定(user の作成や SSH 鍵の投入など)が行われることを前提とした variant が中心です。
今回は cloud ではなく手元の libvirt で使うため、cloud-init を含まず、boot 後そのまま serial console からログインして使い始められる nocloud variant を利用します。

> nocloud: Does not run cloud-init and boots directly to a root prompt. Useful for local VM instantiation with tools like QEMU.

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

host との file のやりとりには virtiofs を利用します。domain XML で、host の `vm/shared/` directory を `drivers` という名前で guest に export しており、guest からは virtiofs として mount することでアクセスできます。

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

## Kernel config の作成

採取した Debian の config を出発点に、rust-next 用の `.config` を作成します。
kernel のビルドは source tree を汚さない build(`make O=<dir>`)で行い、`.config` を含む成果物はすべて `.build/rust-next` に置きます。まず seed となる config を build directory に copy します。

```sh
❯ just kernel initconfig
mkdir -p "<drivers>/.build/rust-next"
cp --force "<drivers>/dev/kernel/config/debian-13-amd64" "<drivers>/.build/rust-next/.config"
```

seed は kernel 6.12 当時の config なので、rust-next(7.2-rc1 base)の Kconfig に合わせて更新します。これを行うのが `olddefconfig` target です。

既存の `.config` を base に、新しく増えた項目を対話なしで default 値に設定します。

```sh
❯ just kernel olddefconfig

make -C "<linux>" "O=<drivers>/.build/rust-next" olddefconfig
make: Entering directory '<linux>'
make[1]: Entering directory '<drivers>/.build/rust-next'
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
make[1]: Leaving directory '<drivers>/.build/rust-next'
make: Leaving directory '<linux>'
```

warning は、6.12 から 7.2 の間に項目の型が変わったことを示しています。例えば `NETFILTER_NETLINK` は tristate から bool に変わったため `m` が、`BOOTPARAM_SOFTLOCKUP_PANIC` は bool から int に変わったため `n` が、それぞれ invalid と報告されています。いずれも olddefconfig が新しい型の default 値で設定し直すので、対応は不要です。

次に Rust support を有効化します。`scripts/config` は `.config` を command line から編集するための kernel 付属の script です。

```sh
❯ just kernel rustconfig
"<linux>/scripts/config" --file "<drivers>/.build/rust-next/.config" --enable GENDWARFKSYMS --enable RUST
```

`RUST` と同時に `GENDWARFKSYMS` を有効化しているのは、[init/Kconfig](https://github.com/Rust-for-Linux/linux/blob/dc59e4fea9d83f03bad6bddf3fa2e52491777482/init/Kconfig) に依存が定義されているためです。

```text
config RUST
	bool "Rust support"
	...
	select EXTENDED_MODVERSIONS if MODVERSIONS
	depends on !MODVERSIONS || GENDWARFKSYMS
```

前提の確認で見た symbol の CRC は、C のコードでは genksyms という parser が計算しますが、genksyms は Rust のコードを解析できません。`GENDWARFKSYMS` は、CRC を DWARF debug 情報から計算する代替の仕組みです。seed の config は `CONFIG_MODVERSIONS=y` なので、`GENDWARFKSYMS` なしでは `RUST` を有効にできません。

次に、VM の boot に必要な driver を有効化します。全体の流れで述べたとおり、direct kernel boot では initramfs を使わないため、boot に必要な driver は module ではなく kernel 本体に組み込んで(`=y`)おく必要があります。

```sh
❯ just kernel vmconfig
"<linux>/scripts/config" --file "<drivers>/.build/rust-next/.config" --enable VIRTIO_MENU --enable VIRTIO_PCI --enable VIRTIO_BLK --enable EXT4_FS --enable EFI_PARTITION --enable FUSE_FS --enable VIRTIO_FS --enable SERIAL_8250 --enable SERIAL_8250_CONSOLE --enable VFAT_FS --enable NLS_CODEPAGE_437 --enable NLS_ASCII --enable EFIVAR_FS
```

有効にしているのは、root filesystem の mount に必要な virtio disk と ext4(`VIRTIO_PCI`, `VIRTIO_BLK`, `EXT4_FS`, `EFI_PARTITION`)、host との file 共有に使う virtiofs(`FUSE_FS`, `VIRTIO_FS`)、serial console(`SERIAL_8250`, `SERIAL_8250_CONSOLE`)、および EFI 関連(`VFAT_FS`, `EFIVAR_FS` など)です。

最後に、採取した lsmod を用いて、ビルドする module を実際に load されていたものに絞り込みます。`localmodconfig` は `.config` の `=m` の項目のうち、`LSMOD` で指定した一覧に載っていない module を無効にします(`=y` の項目には触れません)。`yes ""` を前置しているのは、途中で聞かれる質問にすべて default で回答するためです。

```sh
❯ just kernel localmodconfig vm/shared/lsmod-6.12.101+deb13-amd64
yes "" | make -C "<linux>" "O=<drivers>/.build/rust-next" LLVM=1 CC=/nix/store/<hash>-clang-21.1.8/bin/clang HOSTCC=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang HOSTCXX=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang++ RUSTC=/nix/store/<hash>-rustc-wrapper-1.96.1/bin/rustc BINDGEN=/nix/store/<hash>-rust-bindgen-unwrapped-0.72.1/bin/bindgen "LSMOD=<drivers>/vm/shared/lsmod-6.12.101+deb13-amd64" localmodconfig
make: Entering directory '<linux>'
make[1]: Entering directory '<drivers>/.build/rust-next'
```

これにより、seed の時点で 4,049 個あった `=m` の項目は最終的に 49 個まで減り、kernel のビルド時間が大幅に短くなります。

## Kernel image の build

config ができたので、kernel image をビルドします。

```sh
❯ just kernel image
make -C "<linux>" "O=<drivers>/.build/rust-next" LLVM=1 CC=/nix/store/<hash>-clang-21.1.8/bin/clang HOSTCC=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang HOSTCXX=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang++ RUSTC=/nix/store/<hash>-rustc-wrapper-1.96.1/bin/rustc BINDGEN=/nix/store/<hash>-rust-bindgen-unwrapped-0.72.1/bin/bindgen -j14 bzImage
make: Entering directory '<linux>'
make[1]: Entering directory '<drivers>/.build/rust-next'
  SYNC    include/config/auto.conf
  HOSTRUSTC scripts/generate_rust_target

...

Kernel: arch/x86/boot/bzImage is ready  (#4)
```

## Rust VM の初期化

ビルドした kernel で boot する VM を作成します。手順は deb13 と同じです。同じ base image から rust 用の overlay を作り、domain を定義します。

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

deb13 との実質的な違いは、domain XML の `<os>` だけです。

```diff
   <os firmware='efi'>
     <type arch='x86_64' machine='pc-q35-10.2'>hvm</type>
-    <boot dev='hd'/>
+    <kernel>${KERNEL_IMAGE}</kernel>
+    <cmdline>root=PARTUUID=6cf4a790-ccd9-46ad-a256-5f853165c65e ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0</cmdline>
   </os>
```

deb13 の `<boot dev='hd'/>` は disk から boot する指定です。EFI firmware が disk 内の bootloader を起動し、bootloader が disk に install された Debian の kernel と initramfs を load します。
rust VM ではこれを `<kernel>` に置き換えています。これが QEMU の [direct kernel boot](https://qemu-project.gitlab.io/qemu/system/linuxboot.html) で、bootloader を経由せずに、QEMU が host 上の kernel image を直接 load して起動します。`${KERNEL_IMAGE}` は domain XML の render 時に `.build/rust-next/arch/x86/boot/bzImage` に展開されるので、kernel をビルドし直したら VM を起動し直すだけで新しい kernel が boot します。

`<cmdline>` は、本来 bootloader が kernel に渡す command line を自分で指定するものです。
`root=PARTUUID=...` は root filesystem の場所を示します。initramfs がないため、kernel は自力でこの partition を見つけて mount できる必要があります。Kernel config の作成で `VIRTIO_BLK` や `EXT4_FS` を `=y` にしたのは、この一行のためです。
PARTUUID の値は deb13 内で `blkid` を実行すると確認できます。

```sh
root@localhost:~# blkid
/dev/vda15: SEC_TYPE="msdos" UUID="2041-A3EB" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="e65fb8b6-cb05-404f-ba6f-37e2770a43cf"
/dev/vda1: UUID="ed2d1185-cebf-4062-a788-eeab651e6ad2" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="6cf4a790-ccd9-46ad-a256-5f853165c65e"
/dev/vda14: PARTUUID="f6363e47-3332-4fac-8258-9f606b790ff1"
```

root filesystem である ext4 partition(`/dev/vda1`)の PARTUUID が cmdline に指定した値です。deb13 と rust は同じ base image から作った overlay なので、同じ値になります。PARTUUID は image の build ごとに変わるため、別の image で追試する場合は読み直す必要があります。
ちなみに vfat の partition(`/dev/vda15`)は EFI System Partition で、Kernel config の作成で `VFAT_FS` を有効にしたのは、boot 後にこれを mount できるようにするためです。
`console=ttyS0,115200` は kernel log の出力先を serial console にする指定で、`virsh console` で見えるのはこの出力です。

```sh
❯ just vm boot rust

root@localhost:~# uname -a
Linux localhost 7.2.0-rc1+ #4 SMP PREEMPT_DYNAMIC Sat Aug 15 13:21:42 JST 2026 x86_64 GNU/Linux
```

## Module の build

いよいよ miscdrv をビルドします。その前に、in-tree の module をビルドしておきます。

```sh
❯ just kernel modules
```

前提の確認で見たとおり、out-of-tree module のビルドには、kernel が export する symbol の CRC 台帳である `Module.symvers` が必要です。bzImage のビルドで生成されるのは vmlinux 分(`vmlinux.symvers`)までで、`Module.symvers` はこの `modules` target で生成されます。

miscdrv 側の Makefile は以下のとおりです。

```make
ifneq ($(KERNELRELEASE),)
obj-m := miscdrv.o
else
KDIR ?= ../../../.build/rust-next

.PHONY: modules modules_prepare clean

modules: modules_prepare
	$(MAKE) -C "$(KDIR)" M="$$PWD" $(KERNEL_MAKE_ARGS) modules

modules_prepare:
	$(MAKE) -C "$(KDIR)" $(KERNEL_MAKE_ARGS) modules_prepare

clean:
	$(MAKE) -C "$(KDIR)" M="$$PWD" clean
endif
```

out-of-tree module のビルドは、kernel のビルドシステム(kbuild)への依頼という形をとります([Documentation/kbuild/modules](https://docs.kernel.org/kbuild/modules.html))。`make -C <kernel build directory> M=<module の directory> modules` で、「`M=` にある module をビルドせよ」と伝えます。
この Makefile は 2 回読まれます。手元で `make modules` を実行すると `else` 側が評価され、kbuild に依頼が飛びます。kbuild が `M=` の directory を処理する際に再びこの Makefile を読み(このときは `KERNELRELEASE` が定義されています)、今度は `obj-m := miscdrv.o` だけが評価されます。
`obj-m` は module としてビルドする object の宣言です。kbuild は `miscdrv.o` の source として `miscdrv.rs` を見つけ、rustc でコンパイルして `miscdrv.ko` まで組み立てます。

```sh
❯ cd handson/miscdrv/module/

❯ make modules

❯ modinfo miscdrv.ko
filename:       <drivers>/handson/miscdrv/module/miscdrv.ko
author:         ymgyt
description:    Rust misc device lab
license:        GPL
name:           miscdrv
depends:
vermagic:       7.2.0-rc1+ SMP preempt mod_unload modversions
retpoline:      Y
```

出力の vermagic に注目してください。kernel release と主要な構成(SMP、preempt、modversions)が文字列として module に埋め込まれており、load 時に kernel 自身の値と比較され、一致しなければ拒否されます。前提の確認で見た symbol 単位の CRC 照合と、この vermagic の 2 段構えで、module が load 先の kernel と整合していることが検査されます。

## Module の実行

ビルドした `miscdrv.ko` を virtiofs の共有 directory に置き、VM 内から `insmod` します。

```sh
❯ cd ../../..

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

`insmod` 時の最初の 2 行は warning ですが、想定どおりのものです。1 行目の taint は「この kernel は tree 外の code を含んでいる」という印で、out-of-tree module を load すると必ず付きます。2 行目は module の署名検証に失敗したというもので、自分でビルドした未署名の module なのでこれも想定どおりです。
そして 3 行目の `miscdrv: loaded` が、概要に載せた `init()` の `pr_info!` の出力です。`rmmod` すると `Drop` が呼ばれ、`unloaded` が出力されました。

これでついに、kernel module をビルドして VM 内で検証する流れができました。

## まとめ

最初は、`module!` の仕組み(なんと kernel 内で `syn`、`quote` が使えます)を書こうとしていたのですが、環境構築の章が長くなったので記事を分けることにしました。
Rust から kernel の各種機能(memory 割当、lock 取得、timer、subsystem 登録、...)へのアクセスを提供する [`kernel`](https://rust.docs.kernel.org/kernel/) crate は絶賛開発中で、日々機能追加が続いています。
Rust for Linux project のおかげで、今まで C 開発者の特権だった module/driver 開発を Rust からも行えるのは非常にありがたいです。
ちなみに、kernel 内の Rust に対するスタンスは subsystem ごとに様々です。

DRM subsystem では 2025 年 12 月の段階で

> It was still perhaps surprising, though, when Airlie (the DRM maintainer) said that the subsystem is only "about a year away" from disallowing new drivers written in C and requiring the use of Rust.

(それでもやはり驚きだったのは、DRM subsystem の maintainer である Airlie 氏が、C で書かれた新しい driver を受け入れず Rust の使用を必須とするのは「あと 1 年程度」先の話だ、と述べたことです。)

という話が、[LWN](https://lwn.net/Articles/1050174/) で紹介されていました。
