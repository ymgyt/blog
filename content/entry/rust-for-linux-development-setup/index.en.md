+++
title = "🦀 Setting Up an Environment to Build and Run Rust Kernel Modules"
slug = "rust-for-linux-development-setup"
description = "A ground-up guide to setting up a Rust for Linux development environment"
date = "2026-08-18"
draft = false
[taxonomies]
tags = ["rust", "linux"]
[extra]
image = "images/emoji/crab.png"
+++

## Overview

In this post, we will set up an environment for building and running Linux kernel modules written in Rust.
The goal is to build the following Rust module as `miscdrv.ko` and load it with `insmod` in a VM.

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

By the end, we will be able to load and unload the module in the VM as follows:

```sh
root@localhost:~# insmod /mnt/drivers/miscdrv.ko
[ 5930.423638] miscdrv: loaded
root@localhost:~# rmmod miscdrv
[ 5982.685953] miscdrv: unloaded
```

We will build the module on the host and run it in a VM.
The VM runs on KVM/QEMU and is managed with libvirt.
The prerequisites section briefly covers KVM/QEMU and libvirt; for more detail, I recommend [Mastering KVM Virtualization](https://www.packtpub.com/en-us/product/mastering-kvm-virtualization-9781784396916).

This post is intended for readers who are new to writing kernel modules.

All the code used in this post is available in the [ymgyt/drivers](https://github.com/ymgyt/drivers/tree/blog-r4l-setup) repository.
Dependencies such as QEMU and `rustc` are declared with Nix and will be set up in the development environment section.

## Prerequisites

### What Is a Kernel Module?

A kernel module is a mechanism for dynamically adding executable code to a running kernel.
The kernel build system provides Makefile recipes, or targets, for building modules.
In this post, we will build `miscdrv.ko` from `miscdrv.rs`.
A `.ko` file is an ELF relocatable file (`ET_REL`).

```sh
❯ readelf --file-header miscdrv.ko | rg Type:
  Type:                              REL (Relocatable file)
```

Linux provides the `init_module()` and `finit_module()` system calls for loading modules, and [`insmod` ultimately calls `finit_module()`](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-module.c#L650).

A kernel module runs in the same address space and at the same privilege level as the kernel itself.
It can call functions that the kernel exports with `EXPORT_SYMBOL[_GPL]`.

These internal APIs include memory allocation functions such as `kmalloc()` and functions for registering with subsystems, such as `misc_register()`.
Unlike the user-space system-call ABI, however, compatibility of these APIs is [not guaranteed at all](https://www.kernel.org/doc/html/latest/process/stable-api-nonsense.html).
There is therefore no guarantee that a function `foo()` available at build time will exist with the same signature in the target kernel when the module is loaded.

With `CONFIG_MODVERSIONS=y`, the `.ko` file records a CRC for each symbol that it referenced at build time.
The kernel compares these CRCs when loading the module to detect mismatches.
To embed this metadata, we must build the target kernel and its in-tree modules, generating a complete `Module.symvers`, before building the external module.

For example, the CRC embedded for Rust's `kernel::print::call_printk` symbol, `0xca2eebaa`, matches the value in the target kernel's `Module.symvers`.

```sh
❯ modprobe --show-modversions handson/miscdrv/module/miscdrv.ko
0xca2eebaa      _RNvNtCse297zByDW5v_6kernel5print11call_printk
0xd272d446      __x86_return_thunk
0x7406cc83      module_layout

❯ rg _RNvNtCse297zByDW5v_6kernel5print11call_printk .build/rust-next/Module.symvers
4821:0xca2eebaa _RNvNtCse297zByDW5v_6kernel5print11call_printk  vmlinux EXPORT_SYMBOL_GPL
```

The [`modprobe` source](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-elf.c#L542) shows that it reads this information from the ELF [`__versions` section](https://github.com/kmod-project/kmod/blob/65ac890492c96b88d10d8c92342a1b00ff603dba/libkmod/libkmod-elf.c#L44).

In short, with the configuration used here, we must build the target kernel and its in-tree modules to generate a complete `Module.symvers` before building `miscdrv`.

### What Is a Kernel Configuration?

Next, let us look at how a kernel build is configured.
The kernel source contains conditional compilation controlled by `CONFIG_XXX` options, as in the following example:

```c
struct task_struct {
/* ... */
#ifdef CONFIG_MEM_ALLOC_PROFILING
	struct alloc_tag		*alloc_tag;
#endif
/* ... */
```

Rust code uses `#[cfg()]` for the same purpose.
The following is part of the expansion of the `module!` macro from the overview, generated by [`rust/macros/module.rs`](https://github.com/Rust-for-Linux/linux/blob/dc59e4fea9d83f03bad6bddf3fa2e52491777482/rust/macros/module.rs).
The `MODULE` cfg indicates whether the code is being built as a module.

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

The same source takes different paths depending on how it is built.
As a module, it refers to `__this_module`, which the kernel provides when loading it; when built into the kernel, it uses a null pointer instead.

Before building the kernel, we prepare a `.config` in which every setting has been resolved.
The settings in `.config` are not simply on or off: many features are tristates with the values `y`, `m`, or `n`.

- `y`: build the feature into the kernel image
- `m`: build the feature as a module (`.ko`) and load it at runtime
- `n`: do not build the feature

For example, Debian's configuration builds the virtio block driver as a module, while the configuration we will ultimately use builds it into the kernel.

```sh
❯ rg '^CONFIG_VIRTIO_BLK=' dev/kernel/config/debian-13-amd64 .build/rust-next/.config

.build/rust-next/.config
1968:CONFIG_VIRTIO_BLK=y

dev/kernel/config/debian-13-amd64
2691:CONFIG_VIRTIO_BLK=m
```

A general-purpose distribution such as Debian chooses `m` whenever possible so that it can support a wide range of hardware without keeping unused features resident in memory.
In fact, 4,049 of the 6,896 enabled options in this Debian configuration were set to `m`.
Deciding which features to change to `y` and which to leave as `m` will be the central task in the kernel configuration section.

There are far too many `.config` options to configure everything from scratch easily and still produce the intended kernel.
We will therefore create a Debian 13 VM and use its `.config` as our starting point.

According to [How many ways are there to configure the Linux kernel?](https://lwn.net/Articles/1034811/), Linux 6.16 had 32,468 configuration options on x86_64.

### KVM, QEMU, and libvirt

One way to think about creating a VM is that we run another operating system—its kernel—as a single process on the host.
The kernel, however, is written on the assumption that it controls the hardware directly.
It maps device registers to memory addresses and reads or writes them through memory-mapped I/O (MMIO), and it changes virtual-to-physical address mappings as it switches between processes.
A user-space process cannot be allowed to perform such operations directly.
We therefore need an API that executes the guest and returns control when the guest encounters an operation that it cannot handle itself.

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

KVM abstracts the CPU's hardware virtualization features—Intel VT-x or AMD-V—and provides roughly the API shown above.
It exposes a device file named `/dev/kvm` to user space, through which a guest can be executed using the `KVM_RUN` ioctl.
Do not worry if this does not quite click yet; it makes much more sense after writing a driver once.

The guest instructions are not interpreted or translated by software: the physical CPU executes them directly.
KVM uses the `VMLAUNCH` and `VMRESUME` instructions on Intel processors to switch the CPU into a guest execution mode.
When the guest encounters an operation it cannot handle, the CPU returns control to the host in a VM exit.

After a VM exit, control first returns to KVM inside the host kernel, not directly to the user-space process that called `KVM_RUN`.
If KVM can handle the exit itself, it resumes the guest.
If user-space handling is required, `KVM_RUN` returns with an exit reason such as `KVM_EXIT_MMIO`.
The function that performs this switch is `__vmx_vcpu_run` in [`arch/x86/kvm/vmx/vmenter.S`](https://github.com/Rust-for-Linux/linux/blob/dc59e4fea9d83f03bad6bddf3fa2e52491777482/arch/x86/kvm/vmx/vmenter.S), where the `vmlaunch` and `vmresume` instructions can be seen in the assembly.

The thought experiment also identified changes to memory mappings as a problem, but they do not appear in the pseudocode loop.
With two-stage address translation—EPT on Intel and NPT on AMD—ordinary `CR3` changes and guest page-table updates do not need to cause VM exits.
The CPU first translates a guest virtual address (GVA) into a guest physical address (GPA) using the guest's page tables, then translates the GPA into a host physical address (HPA) using second-stage tables controlled by KVM.
The guest kernel can therefore switch mappings between processes without having KVM or QEMU emulate each change to its page tables.
If the second-stage mapping for a GPA is missing or its permissions are violated, however, a VM exit occurs, so mappings to HPAs remain under host control.

KVM itself consists of kernel modules: `kvm` together with either `kvm_intel` or `kvm_amd`.
The virtualization foundation used here is therefore built on the same kernel-module mechanism that this post explores.

KVM alone does not make a complete VM.
Something must implement `emulate_hw()` and handle the device operations that KVM returns to user space.
For example, when a block device driver in the guest issues a write, the host must persist that write somewhere.

QEMU provides this part.
QEMU runs the loop above, and from the host's point of view, each VM is one QEMU process.
In this post, a qcow2 file is where the guest's writes are persisted.
The pseudocode loop can in fact be found in almost the same form in QEMU's [`kvm_cpu_exec()`](https://github.com/qemu/qemu/blob/20553466cc47af6a8c95f665b601fce3c852e503/accel/kvm/kvm-all.c#L3435): it [calls the `KVM_RUN` ioctl](https://github.com/qemu/qemu/blob/20553466cc47af6a8c95f665b601fce3c852e503/accel/kvm/kvm-all.c#L3472), then [branches on the returned `exit_reason`](https://github.com/qemu/qemu/blob/20553466cc47af6a8c95f665b601fce3c852e503/accel/kvm/kvm-all.c#L3517), such as `KVM_EXIT_IO` or `KVM_EXIT_MMIO`.

[libvirt](https://libvirt.org/) adds a common API for managing QEMU, VirtualBox, Xen, and other virtualization systems.
The host runs the `libvirtd` daemon, and `virsh` is its client.
VM definitions are represented by domain XML, while storage is organized into pools containing volumes.
The `--connect qemu:///system` option shown in later command output specifies the connection to this system-wide libvirt instance.
The `flake.nix` used here installs client-side tools such as `virsh`, so `libvirtd` itself must already be running on the host (`virtualisation.libvirtd.enable` on NixOS).

{{ figure(images=["images/kvm-execution-flow.svg"], caption="VM management and vCPU execution with KVM") }}

For an introduction to virtualization itself, I highly recommend [作って理解する仮想化技術](https://gihyo.jp/book/2025/978-4-297-15012-9) (in Japanese).
It also explains virtio and includes an implementation of virtio-blk, both of which appear in this post.

### File Sharing with virtiofs

This post uses virtiofs to share files between the host and the VM.

First, there is FUSE, or Filesystem in Userspace.
FUSE delegates filesystem operations to a process outside the kernel and defines a request-and-response protocol for operations such as open, read, and write.
virtiofs reuses this FUSE protocol.
It serializes operations on a virtiofs mount inside the guest as FUSE requests, but sends them to the host rather than to a user-space process on the same machine.

On the host, a daemon named `virtiofsd`, which libvirt starts together with the VM, receives the requests.
It performs the actual file operations in the shared directory and returns responses.
This is why reading a file from the guest returns the contents of the host file.

The guest's virtiofs driver communicates with the host backend using virtio.
Rather than reproducing a particular physical device, virtio defines a common interface through which a guest driver and host backend exchange device requests.
The driver places the locations of requests and buffers into an in-memory queue called a virtqueue, then only notifies the host that the queue has been updated.
Because multiple requests can be passed together in memory, there is no need to cause a VM exit and emulate the entire operation for every device request.

In other words, these device drivers are designed to run in a VM: they keep as much of the request-and-response exchange as possible in memory and reduce the frequency of MMIO operations that return control to the host.
Besides file sharing with virtiofs, the disk in this post uses the same mechanism through virtio-blk.
When we later enable `FUSE_FS`, `VIRTIO_FS`, and `VIRTIO_BLK` in the kernel configuration, we are building these guest-side drivers into the kernel.

Because `virtiofsd` is a separate process from QEMU, the VM's memory—including its virtqueues—must be allocated in a way that allows `virtiofsd` to access it.
The `memoryBacking` element in the domain XML configures this with memfd-backed shared memory.

## Overall Flow

As described above, we must build the target kernel before building a module that will be loaded into it.
For that kernel, we will use [rust-next](https://github.com/Rust-for-Linux/linux), the development branch of [Rust for Linux](https://rust-for-linux.com/).
Rust-related changes land there before they reach mainline, so it lets us try the latest changes.

Mainline works as well.
rust-next changes are merged into mainline during each merge window, and rust-next itself is based on a mainline release candidate, so the two do not diverge significantly.

We will use a Debian kernel configuration as the starting point for the `.config` required to build the kernel.
To obtain it, we first create a Debian VM named `deb13` and collect its configuration and `lsmod` output.
The `lsmod` output lists the modules that were actually loaded, allowing us to reduce the number of modules and drivers built with the kernel.

Instead of installing the newly built kernel in the VM, we will boot it using QEMU's direct kernel boot feature.
QEMU can load and boot a kernel image from the host without going through the bootloader on the guest disk.
This avoids reinstalling the kernel inside the VM after every rebuild.
In this setup, we do not provide an initramfs, so the drivers required for boot, such as virtio and ext4, must be built into the kernel with `y` rather than built as modules.

Finally, we will build the `miscdrv` module against this kernel, place it in the VM through the shared virtiofs directory, and load it with `insmod`.

{{ figure(images=["images/kernel-development-flow.svg"], caption="Overview of the development environment") }}

## Development Environment

First, clone rust-next and the repository for this post.
The tasks in the `drivers` repository refer to `../linux`, so the two repositories are expected to be adjacent in the same directory.
The default branch of [Rust-for-Linux/linux](https://github.com/Rust-for-Linux/linux) is rust-next, so there is no need to specify a branch.

```sh
git clone https://github.com/Rust-for-Linux/linux.git
git clone https://github.com/ymgyt/drivers.git
cd drivers
git checkout blog-r4l-setup
nix develop
```

All development dependencies are declared in `flake.nix` and become available through `nix develop`.
They fall into three main groups:

- VM management tools: libvirt (`virsh`), QEMU, `curl` for downloading images, and related tools
- Host tools required to build the kernel: Make, flex, Bison, bc, Perl, Python 3, and others
- The Rust for Linux toolchain: Clang/LLVM, lld, `rustc`, and bindgen—Clang 21.1.8, `rustc` 1.96.1, and bindgen 0.72.1 at the time of writing

The kernel specifies minimum versions of its required build tools in [`changes.rst`](https://docs.kernel.org/process/changes.html).
At the time of writing, it requires Rust 1.85.0 or later and bindgen 0.71.1 or later.

The `shellHook` in `flake.nix` also sets the environment variables used for the build.

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

`KERNEL_MAKE_ARGS` is passed directly to the `make` commands run by Just in later sections.
It is the source of the long arguments such as `LLVM=1 CC=/nix/store/... RUSTC=/nix/store/...` shown in the command output.

`LLVM=1` tells the kernel build to use Clang/LLVM instead of GCC.
Because bindgen on the Rust side uses libclang, the C side uses the same LLVM toolchain.

Using unwrapped Clang only for `CC` is specific to Nix.
The Nix Clang wrapper implicitly injects compilation flags for the Nix environment, which makes it unsuitable for the kernel build, where flags are managed precisely.
For tools that are built to run on the host during the build, however, the wrapper used by `HOSTCC` is convenient because it resolves the standard libraries for them.

The kernel's `rustavailable` target checks whether the Rust toolchain meets the kernel's build requirements.

```sh
❯ just kernel rustavailable
make -C "<linux>" "O=<drivers>/.build/rust-next" LLVM=1 CC=/nix/store/<hash>-clang-21.1.8/bin/clang HOSTCC=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang HOSTCXX=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang++ RUSTC=/nix/store/<hash>-rustc-wrapper-1.96.1/bin/rustc BINDGEN=/nix/store/<hash>-rust-bindgen-unwrapped-0.72.1/bin/bindgen rustavailable
make: Entering directory '<linux>'
make[1]: Entering directory '<drivers>/.build/rust-next'
Rust is available!
make[1]: Leaving directory '<drivers>/.build/rust-next'
make: Leaving directory '<linux>'
```

The final `exec nu` in the `shellHook` makes [Nushell](https://www.nushell.sh/) the interactive shell after `nix develop`.
This is because the tasks in this repository, defined with Just, expect Nushell.

## Creating the Debian VM (`deb13`)

First, we create a Debian VM.
Its configuration and `lsmod` output will serve as the baseline when we build a kernel on the host.

libvirt manages storage such as VM disks in units called pools.
A [`dir`-type pool](https://libvirt.org/storage.html#directory-pool) is simply a directory whose files are treated as volumes.
Here, we register the repository's `vm/storage/` directory as a pool named `drivers`.

```sh
❯ just vm pool define

command: virsh --connect qemu:///system pool-define-as drivers dir --target <drivers>/vm/storage
Pool drivers defined

❯ just vm pool start
command: virsh --connect qemu:///system pool-start drivers
Pool drivers started
```

Next, download the [Debian cloud image](https://cloud.debian.org/images/cloud/) that will serve as the base image for the VM.
Most Debian cloud image variants assume that cloud-init will perform initial setup, such as creating users and installing SSH keys, on a cloud platform such as AWS.
Because we are using local libvirt rather than a cloud platform, we choose the nocloud variant.
It does not run cloud-init and can be used immediately by logging in through the serial console after boot.

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

Rather than using the downloaded base image directly as the VM disk, we create a copy-on-write volume, or overlay, backed by the base image for each VM.
Writes are recorded only in the overlay, leaving the base image unchanged.
The `rust` VM created later will share the same base image while having its own overlay.

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

Immediately after creation, the overlay has an allocation of only 196.00 KiB despite its 3.00 GiB capacity, confirming that almost nothing has been written to it yet.

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

Connect to the VM.

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

### Collecting the Configuration and `lsmod` Output

We use virtiofs to exchange files with the host.
The domain XML exports the host's `vm/shared/` directory to the guest with the mount tag `drivers`.
The guest can access it by mounting a virtiofs filesystem with that tag.

```sh
root@localhost:~# mkdir -p /mnt/drivers
root@localhost:~# mount -t virtiofs drivers /mnt/drivers
root@localhost:~# findmnt /mnt/drivers
TARGET       SOURCE  FSTYPE   OPTIONS
/mnt/drivers drivers virtiofs rw,relatime

root@localhost:~# cp /boot/config-$(uname -r) /mnt/drivers/
```

Next, collect the list of loaded modules.
We will use it later when creating the kernel configuration.

```sh
lsmod > /mnt/drivers/lsmod-$(uname -r)
```

On the host, copy the collected configuration into the repository.

```sh
❯ file vm/shared/config-6.12.101+deb13-amd64
vm/shared/config-6.12.101+deb13-amd64: Linux make config build file, ASCII text

❯ cp vm/shared/config-6.12.101+deb13-amd64 dev/kernel/config/debian-13-amd64
```

## Creating the Kernel Configuration

Starting from the Debian configuration we collected, we now create a `.config` for rust-next.
We build the kernel out of tree with `make O=<dir>` to keep the source tree clean, placing every build artifact, including `.config`, under `.build/rust-next`.
First, copy the seed configuration into the build directory.

```sh
❯ just kernel initconfig
mkdir -p "<drivers>/.build/rust-next"
cp --force "<drivers>/dev/kernel/config/debian-13-amd64" "<drivers>/.build/rust-next/.config"
```

The seed is a configuration from Linux 6.12, so it must be updated for the Kconfig in rust-next, which is based on 7.2-rc1.
The `olddefconfig` target performs this update.

It uses the existing `.config` as its base and assigns default values to newly added options without prompting for input.

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

These warnings indicate that option types changed between Linux 6.12 and 7.2.
For example, `NETFILTER_NETLINK` changed from a tristate to a Boolean, making `m` invalid, while `BOOTPARAM_SOFTLOCKUP_PANIC` changed from a Boolean to an integer, making `n` invalid.
No action is required because `olddefconfig` resets each one to the default value for its new type.

Next, enable Rust support.
`scripts/config` is a script included with the kernel for editing `.config` from the command line.

```sh
❯ just kernel rustconfig
"<linux>/scripts/config" --file "<drivers>/.build/rust-next/.config" --enable GENDWARFKSYMS --enable RUST
```

We enable `GENDWARFKSYMS` together with `RUST` because [`init/Kconfig`](https://github.com/Rust-for-Linux/linux/blob/dc59e4fea9d83f03bad6bddf3fa2e52491777482/init/Kconfig) defines the following dependency:

```text
config RUST
	bool "Rust support"
	...
	select EXTENDED_MODVERSIONS if MODVERSIONS
	depends on !MODVERSIONS || GENDWARFKSYMS
```

For C code, a parser named genksyms calculates the symbol CRCs described in the prerequisites section, but genksyms cannot parse Rust code.
`GENDWARFKSYMS` provides an alternative that calculates CRCs from DWARF debugging information.
Because the seed configuration has `CONFIG_MODVERSIONS=y`, `RUST` cannot be enabled without `GENDWARFKSYMS`.

Next, enable the drivers required to boot the VM.
As described in the overall flow, this VM is direct-booted without an initramfs, so the drivers required during boot must be built into the kernel with `=y` rather than built as modules.

```sh
❯ just kernel vmconfig
"<linux>/scripts/config" --file "<drivers>/.build/rust-next/.config" --enable VIRTIO_MENU --enable VIRTIO_PCI --enable VIRTIO_BLK --enable EXT4_FS --enable EFI_PARTITION --enable FUSE_FS --enable VIRTIO_FS --enable SERIAL_8250 --enable SERIAL_8250_CONSOLE --enable VFAT_FS --enable NLS_CODEPAGE_437 --enable NLS_ASCII --enable EFIVAR_FS
```

The enabled options cover the virtio disk and ext4 filesystem required to mount the root filesystem (`VIRTIO_PCI`, `VIRTIO_BLK`, `EXT4_FS`, and `EFI_PARTITION`), virtiofs file sharing with the host (`FUSE_FS` and `VIRTIO_FS`), the serial console (`SERIAL_8250` and `SERIAL_8250_CONSOLE`), and EFI-related support (`VFAT_FS`, `EFIVAR_FS`, and others).

Finally, use the collected `lsmod` output to restrict the built modules to those that were actually loaded.
For every `.config` option set to `=m`, `localmodconfig` disables the module unless it appears in the list specified by `LSMOD`; it does not modify options set to `=y`.
The `yes ""` prefix answers every prompt with its default response.

```sh
❯ just kernel localmodconfig vm/shared/lsmod-6.12.101+deb13-amd64
yes "" | make -C "<linux>" "O=<drivers>/.build/rust-next" LLVM=1 CC=/nix/store/<hash>-clang-21.1.8/bin/clang HOSTCC=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang HOSTCXX=/nix/store/<hash>-clang-wrapper-21.1.8/bin/clang++ RUSTC=/nix/store/<hash>-rustc-wrapper-1.96.1/bin/rustc BINDGEN=/nix/store/<hash>-rust-bindgen-unwrapped-0.72.1/bin/bindgen "LSMOD=<drivers>/vm/shared/lsmod-6.12.101+deb13-amd64" localmodconfig
make: Entering directory '<linux>'
make[1]: Entering directory '<drivers>/.build/rust-next'
```

This reduces the number of `=m` options from 4,049 in the seed configuration to 49 in the final configuration, greatly shortening the kernel build time.

## Building the Kernel Image

With the configuration complete, build the kernel image.

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

## Initializing the Rust VM

Now create a VM that boots the kernel we just built.
The procedure is the same as for `deb13`: create an overlay for `rust` from the same base image, then define the domain.

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

The only substantial difference from `deb13` is the `<os>` element in the domain XML.

```diff
   <os firmware='efi'>
     <type arch='x86_64' machine='pc-q35-10.2'>hvm</type>
-    <boot dev='hd'/>
+    <kernel>${KERNEL_IMAGE}</kernel>
+    <cmdline>root=PARTUUID=6cf4a790-ccd9-46ad-a256-5f853165c65e ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0</cmdline>
   </os>
```

The `<boot dev='hd'/>` element in `deb13` specifies booting from the disk.
The EFI firmware starts the bootloader on the disk, which then loads the Debian kernel and initramfs installed there.

The `rust` VM replaces it with `<kernel>`.
This is QEMU's [direct kernel boot](https://qemu-project.gitlab.io/qemu/system/linuxboot.html): QEMU loads a kernel image directly from the host and starts it without going through a bootloader.
When the domain XML is rendered, `${KERNEL_IMAGE}` expands to `.build/rust-next/arch/x86/boot/bzImage`.
After rebuilding the kernel, simply restarting the VM boots the new image.

The `<cmdline>` element supplies the command line that a bootloader would normally pass to the kernel.
`root=PARTUUID=...` identifies the root filesystem.
Because there is no initramfs, the kernel must be able to find and mount this partition on its own.
This one line is why we built `VIRTIO_BLK` and `EXT4_FS` into the kernel with `=y` in the kernel configuration section.

The PARTUUID can be found by running `blkid` inside `deb13`.

```sh
root@localhost:~# blkid
/dev/vda15: SEC_TYPE="msdos" UUID="2041-A3EB" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="e65fb8b6-cb05-404f-ba6f-37e2770a43cf"
/dev/vda1: UUID="ed2d1185-cebf-4062-a788-eeab651e6ad2" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="6cf4a790-ccd9-46ad-a256-5f853165c65e"
/dev/vda14: PARTUUID="f6363e47-3332-4fac-8258-9f606b790ff1"
```

The ext4 partition containing the root filesystem, `/dev/vda1`, has the PARTUUID specified in the command line.
Because `deb13` and `rust` use overlays created from the same base image, this value is the same in both VMs.
The PARTUUID changes each time the image is built, so it must be checked again when reproducing the setup with a different image.

The vfat partition, `/dev/vda15`, is the EFI System Partition.
We enabled `VFAT_FS` in the kernel configuration so that it can be mounted after boot.
`console=ttyS0,115200` sends the kernel log to the serial console, which is the output displayed by `virsh console`.

```sh
❯ just vm boot rust

root@localhost:~# uname -a
Linux localhost 7.2.0-rc1+ #4 SMP PREEMPT_DYNAMIC Sat Aug 15 13:21:42 JST 2026 x86_64 GNU/Linux
```

## Building the Module

We are finally ready to build `miscdrv`.
First, however, build the in-tree modules.

```sh
❯ just kernel modules
```

As discussed above, this configuration has `CONFIG_MODVERSIONS=y`, so module versioning requires a complete `Module.symvers`.
Building `bzImage` produces `vmlinux.symvers`; building the in-tree modules produces the final `Module.symvers`, which includes symbols from `vmlinux` and those modules.

The Makefile for `miscdrv` is as follows:

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

Building an out-of-tree module means asking the kernel build system, kbuild, to do the work, as described in [Building External Modules](https://docs.kernel.org/kbuild/modules.html).
The command `make -C <kernel build directory> M=<module directory> modules` tells kbuild to build the module in the directory specified by `M=`.

This Makefile is read twice.
When we run `make modules` ourselves, the `else` branch is evaluated and delegates the build to kbuild.
When kbuild processes the `M=` directory, it reads the Makefile again; this time, `KERNELRELEASE` is defined, so only `obj-m := miscdrv.o` is evaluated.

`obj-m` declares the object to build as a module.
kbuild finds `miscdrv.rs` as the source for `miscdrv.o`, compiles it with `rustc`, and assembles the result into `miscdrv.ko`.

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

Notice the `vermagic` field in the output.
It embeds the kernel release and major configuration properties—SMP, preemption, and module versioning—as a string in the module.
The kernel compares it with its own value when loading the module and rejects a mismatch.
Together, these checks verify two important aspects of whether the module matches its target kernel.

## Running the Module

Place the newly built `miscdrv.ko` in the shared virtiofs directory and load it with `insmod` inside the VM.

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

The first two lines printed by `insmod` are warnings, but both are expected.
The taint on the first line marks the kernel as containing code from outside its source tree and is always set when an out-of-tree module is loaded.
The second line reports that the kernel could not verify a module signature, which is also expected because this locally built module is unsigned.

The third line, `miscdrv: loaded`, is the output from the `pr_info!` call in the `init()` function shown in the overview.
When `rmmod` removes the module, its `Drop` implementation runs and prints `unloaded`.

We now have the complete workflow for building a kernel module and testing it inside a VM.

## Conclusion

I originally intended to write about how `module!` works—it is remarkable that `syn` and `quote` can be used inside the kernel—but the environment setup grew long enough to deserve its own post.

The [`kernel`](https://rust.docs.kernel.org/kernel/) crate, which gives Rust code access to kernel facilities such as memory allocation, locks, timers, and subsystem registration, is under active development and continues to gain features every day.
Thanks to the Rust for Linux project, module and driver development is no longer exclusive to C developers: we can now do it in Rust as well, which I greatly appreciate.

Attitudes toward Rust in the kernel vary between subsystems.
In December 2025, the LWN article [The state of the kernel Rust experiment](https://lwn.net/Articles/1050174/), covering discussions at the Maintainers Summit, reported the following about the DRM subsystem:

> It was still perhaps surprising, though, when Airlie (the DRM maintainer) said that the subsystem is only "about a year away" from disallowing new drivers written in C and requiring the use of Rust.
