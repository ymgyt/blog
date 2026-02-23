+++
title = "🐧 Linuxデバイスドライバプログラミングを読んだ感想"
slug = "linux-device-driver-programming-book"
description = "kernelのsamples/rust/rust_driver_*.rsを読めるようになりたい"
date = "2026-02-24"
draft = false
[taxonomies]
tags = ["linux","book"]
[extra]
image = "images/emoji/penguin.png"
+++

## 読んだ本

{{ figure(images=["images/lddp.jpg"], caption="Linux デバイスドライバプログラミング", href="https://www.sbcr.jp/product/4797346428/", width="50%") }}

著者: 平田 豊

[Kernel Maintainers Summit 2025](https://lwn.net/Archives/ConferenceIndex/#Kernel_Maintainers_Summit-2025)でLinux kernelへのRust導入について、"experimental" な扱いを終えてよいのではという提案がありました。

> Ojeda returned to his initial question: can the "experimental" status be ended? Torvalds said that, after nearly five years, the time had come.

[The state of the kernel Rust experiment](https://lwn.net/Articles/1050174/)

その後、[Rust subsystemのmaintainer](https://github.com/Rust-for-Linux/linux/blob/b8d687c7eeb52d0353ac27c4f71594a2e6aa365f/MAINTAINERS#L22887)であられる Miguel Ojeda氏による[\[PATCH\] rust: conclude the Rust experiment](https://lore.kernel.org/lkml/20251213000042.23072-1-ojeda@kernel.org/)で

> But the experiment is done, i.e. Rust is here to stay.

として、`Documentation/rust/index.rst`から、 `The Rust experiment` sectionを削除する変更が提案されました。

このような[Rust for Linux](https://rust-for-linux.com/)の取り組みを機にLinux kernelについて調べてみたいと思うようになりました。
Rustのユースケースとして、[driverをrustで書く取り組み](https://github.com/Rust-for-Linux/linux/blob/b8d687c7eeb52d0353ac27c4f71594a2e6aa365f/samples/rust/rust_driver_pci.rs)があることを知り、kernel driverの解説を探している中で本書を見つけ、読んでみておもしろかったので、感想を書きます。

本書が対象としているkernel versionは2.6.23.1ですが、記事中のコードは6.18.6で動かしました。


## 第1章 Linuxデバイスドライバの概要

Linux kernelの生い立ちや、コミュニティについて。
また、デバイスドライバのkernel内における位置づけについて。


## 第2章 Linuxのライセンス

GPLライセンスやデバイスドライバのライセンスについて。
kernel moduleの`MODULE_LICENSE` macroの説明があります。
[過去のGPL違反の事例](https://web.archive.org/web/20070205223210/http://hp.vector.co.jp/authors/VA012337/misc/authdrv.html)等も紹介されていました。

## 第3章 デバイスドライバ開発の準備

実際にドライバを書くための環境構築方法について。
自分はNixOSを使っているので以下のようなNixOS moduleを準備しました。

```nix
{ pkgs, config, ... }:
let
  kernel = config.boot.kernelPackages.kernel;
in
{
  environment.systemPackages = with pkgs; [
    kernel.dev
  ];
  environment.variables.KDIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
}
```

こうすると実行中のkernel versionに対応した、module build用のfileが揃うので、kernel自体をbuildせずに済みます。

```sh
cd $env.KDIR

pwd
/nix/store/cbc470bffdhc9wg1bgk54i6a3s5a1ygq-linux-6.18.6-dev/lib/modules/6.18.6/build

uname | get kernel-release
6.18.6

ls
 # |      name      |  type   |  size  |   modified
---+----------------+---------+--------+--------------
 0 | Makefile       | file    |  350 B | 56 years ago
 1 | Module.symvers | file    | 2.3 MB | 56 years ago
 2 | arch           | dir     | 4.0 kB | 56 years ago
 3 | include        | dir     | 4.0 kB | 56 years ago
 4 | kernel         | dir     | 4.0 kB | 56 years ago
 5 | rust           | dir     | 4.0 kB | 56 years ago
 6 | scripts        | dir     | 4.0 kB | 56 years ago
 7 | source         | symlink |    9 B | 56 years ago
 8 | tools          | dir     | 4.0 kB | 56 years ago  
```


## 第4章 デバイスドライバ開発の第一歩

本章からいよいよドライバ開発がはじまります。
ログ出力だけを行うドライバ、`hello`

```c
#include <linux/module.h>
#include <linux/kernel.h>

static int __init hello_init(void)
{
  pr_info("hello: loaded\n");
  return 0;
}

static void __exit hello_exit(void)
{
  pr_info("hello: unloaded\n");
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("ymgyt");
MODULE_DESCRIPTION("hello module");
```

Makefile
```make
obj-m := hello.o
PWD := $(shell pwd)

modules:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
```

`make modules`でbuildしてみると

```sh
make modules
/nix/store/mkm3my2067305hdh7rzmi10npwr7y17f-gnumake-4.4.1/bin/make -C /nix/store/cbc470bffdhc9wg1bgk54i6a3s5a1ygq-linux-6.18.6-dev/lib/modules/6.18.6/build M=/home/ymgyt/rs/drivers/hello modules
make[1]: Entering directory '/nix/store/cbc470bffdhc9wg1bgk54i6a3s5a1ygq-linux-6.18.6-dev/lib/modules/6.18.6/build'
make[2]: Entering directory '/home/ymgyt/rs/drivers/hello'
  CC [M]  hello.o
  MODPOST Module.symvers
  CC [M]  hello.mod.o
  CC [M]  .module-common.o
  LD [M]  hello.ko
  BTF [M] hello.ko
Skipping BTF generation for hello.ko due to unavailability of vmlinux
make[2]: Leaving directory '/home/ymgyt/rs/drivers/hello'
make[1]: Leaving directory '/nix/store/cbc470bffdhc9wg1bgk54i6a3s5a1ygq-linux-6.18.6-dev/lib/modules/6.18.6/build'

ls
 # |      name      | type |   size   |    modified
---+----------------+------+----------+----------------
 0 | Makefile       | file |    262 B | 3 weeks ago
 1 | Module.symvers | file |      0 B | 19 seconds ago
 2 | hello.c        | file |    342 B | 3 weeks ago
 3 | hello.ko       | file | 179.6 kB | 18 seconds ago
 4 | hello.mod      | file |     10 B | 19 seconds ago
 5 | hello.mod.c    | file |    373 B | 19 seconds ago
 6 | hello.mod.o    | file | 106.5 kB | 18 seconds ago
 7 | hello.o        | file |  14.0 kB | 19 seconds ago
 8 | modules.order  | file |      8 B | 19 seconds ago

file hello.ko
hello.ko: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), BuildID[sha1]=e328d799fd4e7da7538d9b81b324aac66b6ca788, with debug_info, not stripped  
```

無事、`hello.ko` ELFが生成できました。

`modinfo`してみると、`MODULE_` マクロの内容が反映していることが確かめられます

```sh
modinfo hello.ko
filename:       /home/ymgyt/rs/drivers/hello/hello.ko
description:    hello module
author:         ymgyt
license:        GPL
depends:
name:           hello
retpoline:      Y
vermagic:       6.18.6 SMP preempt mod_unload  
```

ちなみにrustだと、kernel crateにdriverの種別ごとにmacroが用意してあり、以下のようにしてmoduleのmetadataを定義できます。

```rust
kernel::module_usb_driver! {
    type: SampleDriver,
    name: "rust_driver_usb",
    authors: ["Daniel Almeida"],
    description: "Rust USB driver sample",
    license: "GPL v2",
}
```

作成したドライバをロードするには、`insmod`を実行します。

```sh
sudo insmod hello.ko

sudo dmesg | tail -n 10 | rg hello
[883897.532805] hello: loaded
```

無事ログを確認できました。

ロードしたドライバをアンロードするには`rmmod`を使います。

```sh
sudo rmmod hello

sudo dmesg | tail -n 10 | rg hello
[883897.532805] hello: loaded
[883981.712000] hello: unloaded
```

ということでドライバのハローワールドができました。
次に、関数を定義しているheaderにjumpできると便利なのでcode jumpの設定を行います。
自分はclangd lang serverを利用しているので

```sh
bear --append --output -- make -C $KDIR M=$(pwd) HOSTCC=cc modules
```

を実行して、`compile_commands.json`を生成しました。
ちなみにRustの場合は、kernelのmake targetに`rust-analyzer`があります。

```sh
make help | rg rust-analyzer
  rust-analyzer   - Generate rust-project.json rust-analyzer support file
```

次にエントリーポイントについての解説があります。
`insmod`時に呼ばれる、`module_init`, `rmmod`時の`module_exit`だけでなく、systemcall(open, close, ioctl, epoll, ...)時のhandler, 割込み,timerからデバイスの処理が呼ばれます。

## 第5章 ドライバプログラミングの基礎知識

コンテキストの概念が説明されます。
プロセス起因で呼ばれるか、割込み起因で呼ばれるかによって、プロセスコンテキストと割込みコンテキストに分類されます。

プロセスコンテキストでは、global 変数、`current` から現在実行中のスレッドを表す[`task_struct`](https://github.com/Rust-for-Linux/linux/blob/b8d687c7eeb52d0353ac27c4f71594a2e6aa365f/include/linux/sched.h#L819)の参照が得られます。

ドライバ特有の話ではないですが、`int`や`long`といったデータモデル、エンディアン、アラインメントの解説もあります。

そして、本章ではreadすると1を返す、devoneドライバを作っていきます。

```sh
hexyl -n 32 -v  /dev/devone0
┌────────┬─────────────────────────┬─────────────────────────┬────────┬────────┐
│00000000│ ff ff ff ff ff ff ff ff ┊ ff ff ff ff ff ff ff ff │××××××××┊××××××××│
│00000010│ ff ff ff ff ff ff ff ff ┊ ff ff ff ff ff ff ff ff │××××××××┊××××××××│
└────────┴─────────────────────────┴─────────────────────────┴────────┴────────┘
```

さっそくinit処理からみていきます。

```c
static int devone_major = 0; /* dynamic allocation */
static int devone_minor = 0; /* static allocation */
static int devone_devs = 1;

static int __init devone_init(void)
{
  dev_t dev = MKDEV(devone_major, devone_minor);
  int ret;

  ret = alloc_chrdev_region(&dev, 0, devone_devs, DRIVER_NAME);
  if (ret)
    return ret;

  devone_major = MAJOR(dev);

  cdev_init(&devone_cdev, &devone_fops);
  devone_cdev.owner = THIS_MODULE;
  devone_cdev.ops = &devone_fops;

  devone_class = class_create(DRIVER_NAME);
  if (IS_ERR(devone_class)) {
    ret = PTR_ERR(devone_class);
    devone_class = NULL;
    goto err_unregister;
  }

  devone_device =
      device_create(devone_class, NULL, dev, NULL, "devone%d", devone_minor);
  if (IS_ERR(devone_device)) {
    ret = PTR_ERR(devone_device);
    devone_device = NULL;
    goto err_class;
  }

  ret = cdev_add(&devone_cdev, dev, devone_devs);
  if (ret)
    goto err_device;

  printk(KERN_ALERT "%s: driver(major %d) installed\n", DRIVER_NAME,
         devone_major);

  return 0;

err_device:
  device_destroy(devone_class, dev);
  devone_device = NULL;
err_class:
  class_destroy(devone_class);
  devone_class = NULL;
err_unregister:
  unregister_chrdev_region(dev, devone_devs);

  return ret;
}
```

各種関数を呼ぶとなにが起きるかが丁寧に解説されているので、本書を読むとこのコードが読めるようになります。
本書では、`class_device_create()`関数が使われていたのですが、今は削除されており、代わりに`device_create()`を利用しました。

pointerを返す関数では、エラーの情報も同じpointer型で表現するので、判定および、エラー情報への変換用のhelper関数、`IS_ERR()`, `PTR_ERR()`が用意されています。ドライバーに限らないモジュール一般の話については、[Linuxカーネルプログラミング第2版](https://www.oreilly.co.jp/books/9784814401109/)の説明がわかりやすかったです。

リソースの割当と初期化を順番に行っていくので、エラーが発生した場合はリソースの開放を行う必要があります。こういう処理はgotoのほうが書きやすいことがわかり、gotoもあながち悪いものではないんだなと思いました。(自分では絶対ミスりそうですが)

そして、以下のudev ruleを適用してから、`insmod()`すると、`/dev/devone0`fileを`open()`できるようになります。

```sh
cat <<EOF | sudo tee /run/udev/rules.d/51-devone.rules > /dev/null
KERNEL=="devone[0-9]*", GROUP="root",  MODE="0644"
EOF

sudo insmod ./devone.ko

file /dev/devone0
/dev/devone0: character special (236/0)
```

次にopen処理を実装します。

```c
#include <linux/fs.h>

static int devone_open(struct inode *inode, struct file *file)
{
  struct devone_data *p;

  p = kmalloc(sizeof(struct devone_data), GFP_KERNEL);
  if (p == NULL) {
    printk("%s: No memory\n", __func__);
    return -ENOMEM;
  }

  p->val = 0xff;
  rwlock_init(&p->lock);

  file->private_data = p;

  return 0;
}
```

引数にopenされたfileの`inode`とfile handlerが渡されます。
個人的には初めて、`inode`の定義を読んだので、これが今までinode,inodeいっていた実体かとなりました。

```c
struct file {
	void				*private_data;
  /* ... */
}
```

`file`には`void *`を保持できる`private_data` があり、ここにドライバ側で定義した処理に関するデータを渡すことができます。結構自由なんですね。

```c
struct devone_data {
  unsigned char val;
  rwlock_t lock;
};
```

1を固定で返す、read処理は以下のようになります。

```c
static ssize_t devone_read(struct file *filep, char __user *buf, size_t count,
                           loff_t *f_pos)
{
  struct devone_data *p = filep->private_data;
  int i;
  unsigned char val;
  int retval;
  
  read_lock(&p->lock);
  val = p->val;
  read_unlock(&p->lock);

  for (i = 0; i < count; i++) {
    if (copy_to_user(&buf[i], &val, 1)) {
      retval = -EFAULT;
      goto out;
    }
  }
  retval = count;
out:
  return (retval);
}
```

open時に初期化した`devone_data`から値(1)を取り出して、ユーザ領域に書き込みます。readは複数threadから呼ばれるので、共有領域にアクセスする場合はロックをとります。このあたりの考え方は通常のプログラミングと同じだと思います。(sleepの可否を除いて)

今回はreadするデータが決め打ちなので、常に処理できますが、実際のドライバではここからデバイスを制御する処理が走り、場合によってはユーザに情報を返せないです。その際にドライバ側で、CPUの処理を手放すことになり、プロセスがスリープします。

write処理は同様に保持しているデータに書き込むだけです

```c
static ssize_t devone_write(struct file *filep, const char __user *buf,
                            size_t count, loff_t *f_pos)
{
  struct devone_data *p = filep->private_data;
  unsigned char val;
  int retval = 0;

  if (count >= 1) {
    if (copy_from_user(&val, &buf[0], 1)) {
      retval = -EFAULT;
      goto out;
    }
    write_lock(&p->lock);
    p->val = val;
    write_unlock(&p->lock);
    retval = count;
  }

out:
  return (retval);
}
```

以下の処理でアクセスしてみると

```rust
use std::{
    env, fs,
    io::{Read as _, Write as _},
};
use tracing::info;

fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let dev_file = env::var("DEV_FILE").unwrap_or("/dev/devone0".to_owned());

    let mut f = fs::OpenOptions::new()
        .read(true)
        .write(true)
        .open(dev_file)?;

    let mut buf = [0; 8];

    f.write_all(b"A")?;
    f.read_exact(&mut buf)?;
    info!("Read: {}", String::from_utf8_lossy(&buf));

    f.write_all(b"B")?;
    f.read_exact(&mut buf)?;
    info!("Read: {}", String::from_utf8_lossy(&buf));

    Ok(())
}
```

```sh
2026-02-08T08:23:16.416004Z  INFO devone: Read: AAAAAAAA
2026-02-08T08:23:17.439580Z  INFO devone: Read: BBBBBBBB
```

無事任意のデータを書き込むことができました。


## 第6章 ドライバプログラミングの実際

本章では、ioctlの実装方法の解説があります。
ioctlでは、ユーザスペースのプログラムとデータ構造を共有する必要があるので、まずheader fileを定義します。

`devone_ioctl.h`

```c
#ifndef _DEVONE_IOCTL_H
#define _DEVONE_IOCTL_H

#include <linux/ioctl.h>

struct ioctl_cmd {
  unsigned int reg;
  unsigned int offset;
  unsigned int val;
};

#define IOC_MAGIC 'd'

enum {
  IOCTL_VALSET = _IOW(IOC_MAGIC, 1, struct ioctl_cmd),
  IOCTL_VALGET = _IOR(IOC_MAGIC, 2, struct ioctl_cmd),
};

#endif
```

ioctl handler

```c
#include "devone_ioctl.h"

static long int devone_ioctl(struct file *filep, unsigned int cmd,
                             unsigned long arg)
{
  struct devone_data *dev = filep->private_data;
  struct ioctl_cmd data;
  struct ioctl_cmd __user *uarg = (struct ioctl_cmd __user *)arg;

  if (_IOC_TYPE(cmd) != IOC_MAGIC)
    return -ENOTTY;
  if (_IOC_SIZE(cmd) != sizeof(struct ioctl_cmd))
    return -EINVAL;

  memset(&data, 0, sizeof(data));

  switch (cmd) {
  /* userland write */
  case IOCTL_VALSET:
    if (!capable(CAP_SYS_ADMIN)) {
      return -EPERM;
    }
    if (copy_from_user(&data, uarg, sizeof(data))) {
      return -EFAULT;
    }

    write_lock(&dev->lock);
    dev->val = data.val;
    write_unlock(&dev->lock);
    break;

  /* userland read */
  case IOCTL_VALGET:
    read_lock(&dev->lock);
    data.val = dev->val;
    read_unlock(&dev->lock);

    if (copy_to_user(uarg, &data, sizeof(data))) {
      return -EFAULT;
    }
    break;

  default:
    return -ENOTTY;
    break;
  }

  return 0;
}
```

せっかくのioctlですがやっていることは、read/writeです。
個人的には、

```c
    if (!capable(CAP_SYS_ADMIN)) {
      return -EPERM;
    }
```

のように、capabilityのチェックがドライバのifで実装できるということを知れ、うれしかったです。

このioctlをプログラムから読んでみます。
まず、`devone_ioctl.h`をRustから読めるように、`bindings`で[`devone_ioctl_bindings.rs`](https://github.com/ymgyt/drivers/blob/ae22c97d66cb1f20010d74db29f96bb53ec4346e/uapp/src/generated/devone_ioctl_bindings.rs)を[生成](https://github.com/ymgyt/drivers/blob/ae22c97d66cb1f20010d74db29f96bb53ec4346e/uapp/build.rs)します。

その上で、ユーザ側から、`libc::ioctl()`を呼び出します。

```rust
use std::{fs::OpenOptions, io, os::fd::AsRawFd as _};
use tracing::info;
use uapp::bindings::devone_ioctl::{IOCTL_VALGET, IOCTL_VALSET, ioctl_cmd};

fn ioctl_valset(fd: i32, val: u32) -> io::Result<()> {
    let mut data = ioctl_cmd {
        reg: 0,
        offset: 0,
        val,
    };

    let rc = unsafe { libc::ioctl(fd, IOCTL_VALSET as libc::c_ulong, &mut data) };
    if rc < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

fn ioctl_valget(fd: i32) -> io::Result<u32> {
    let mut data = ioctl_cmd {
        reg: 0,
        offset: 0,
        val: 0,
    };

    let rc = unsafe { libc::ioctl(fd, IOCTL_VALGET as libc::c_ulong, &mut data) };
    if rc < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(data.val)
}

fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let f = OpenOptions::new()
        .read(true)
        .write(true)
        .open("/dev/devone0")?;
    let fd = f.as_raw_fd();

    let got = ioctl_valget(fd)?;
    info!("IOCTL_VALGET: got val=0x{got:02x}");

    let set_val = 2_u32;
    info!("IOCTL_VALSET: setting val=0x{set_val:02x}");
    ioctl_valset(fd, set_val)?;

    let got = ioctl_valget(fd)?;
    info!("IOCTL_VALGET: got val=0x{got:02x}");

    Ok(())
}
```

これを実行すると

```sh
2026-02-08T09:12:35.854053Z  INFO devone_ioctl: IOCTL_VALGET: got val=0xff
2026-02-08T09:12:35.854128Z  INFO devone_ioctl: IOCTL_VALSET: setting val=0x02
2026-02-08T09:12:35.854159Z  INFO devone_ioctl: IOCTL_VALGET: got val=0x02
```

無事ioctlできました。

次に、`poll()`です。device側は常にread/write可能な実装です

```c
static unsigned int devone_poll(struct file *filp, poll_table *wait)
{
  struct devone_data *dev = filp->private_data;

  if (dev == NULL)
    return -EBADFD;

  return POLLIN | POLLRDNORM | POLLOUT | POLLWRNORM;
}
```

これを以下のようにして呼び出しました。

```rust
use std::{fs::OpenOptions, io, mem, os::fd::AsRawFd as _};
use anyhow::bail;
use tracing::info;

fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let f = OpenOptions::new()
        .read(true)
        .write(true)
        .open("/dev/devone0")?;
    let fd = f.as_raw_fd();

    let epfd = unsafe { libc::epoll_create1(0) };
    if epfd < 0 {
        bail!(io::Error::last_os_error());
    }

    let mut ev: libc::epoll_event = unsafe { mem::zeroed() };
    ev.events = libc::EPOLLIN as u32;
    ev.u64 = fd as u64;

    let rc = unsafe { libc::epoll_ctl(epfd, libc::EPOLL_CTL_ADD, fd, &mut ev as *mut _) };
    if rc < 0 {
        let err = io::Error::last_os_error();
        unsafe { libc::close(epfd) };
        bail!(err)
    }

    let mut events: [libc::epoll_event; 8] = unsafe { mem::zeroed() };
    let n = unsafe { libc::epoll_wait(epfd, events.as_mut_ptr(), events.len() as i32, 0) };
    if n < 0 {
        let err = io::Error::last_os_error();
        unsafe { libc::close(epfd) };
        bail!(err)
    }

    info!("epoll_wait returned n={n}");
    #[expect(clippy::needless_range_loop)]
    for i in 0..n as usize {
        let ev = &events[i];
        let ready = ev.events;
        let token = ev.u64;
        info!("event[{i}]: token={token} events=0x{ready:x}");
        if ready & (libc::EPOLLIN as u32) != 0 {
            info!("  => EPOLLIN (readable)");
        }
    }

    unsafe { libc::close(epfd) };
    Ok(())
}
```

epollの詳細は割愛しますが、これを実行すると無事readableであることを伝えられました

```sh
2026-02-08T09:24:22.709203Z  INFO devone_epoll: epoll_wait returned n=1
2026-02-08T09:24:22.709280Z  INFO devone_epoll: event[0]: token=123 events=0x1
2026-02-08T09:24:22.709301Z  INFO devone_epoll:   => EPOLLIN (readable)
```

この他にも、proc_fs, seq_file, sleepの解説があります。
最後にドライバから直接、`insmod`を実行したユーザのターミナルにメッセージを出力する方法が紹介されていました。

```c
static void pr_tty_console(char *msg)
{
  struct tty_struct *tty;

  tty = current -> signal -> tty;
  if (tty != NULL) {
    (tty->driver->ops->write)(tty, msg, strlen(msg));
    (tty->driver->ops->write)(tty, "\r\n", 2);
  }
}

static int __init devone_init(void) {
  /* ... */
  pr_tty_console("devone loaded(from tty console)\n");
  /* ... */
}
```
おそらく非常に危険な処理だと思いますが、実行してみると

```sh
sudo insmod ./devone.ko
devone loaded(from tty console)
```

と、表示に成功しました。
タイマーに関するAPIは現在では変更されており、具体的な変更については、[カーネルモジュール作成で学ぶLinuxカーネル開発の基礎知識：第3版](https://techbookfest.org/product/h9vV6JbABCHD6CurWp7ers?productVariantID=idaht7Yvyg0b0ujvsyS9Y2)がわかりやすかったです。


## 第7章 ハードウェア制御

本章ではドライバから実際にデバイスを制御するために、I/OマップドI/O、メモリマップドI/Oについての解説があります。
メモリマップドI/Oの場合、デバイスのレジスタに対応した物理アドレスを指定して命令を実行する必要がありますが、ドライバは仮想アドレスで動いているので、`ioremap()`が必要となります。

また、メモリアクセスに副作用や依存関係が暗黙的に生じるので、メモリバリアやvolatileの話がでてきます。

`asm()`の解説もあり、Rustの[`asm!()`](https://doc.rust-lang.org/reference/inline-assembly.html) macroはここから来たのかと知れました。

## 第8章 メモリ

カーネルのメモリ管理について。具体的には、`kmalloc()`,`kfree()`といったAPI、スラブアロケータ、バディシステム、カーネルスタックについての言及があります。

DMAについては、実際のドライバ(drivers/net/e100.c)での利用例や、キャッシュコヒーレンス問題の解説があります。

## 第9章 タイマ

2.6時点での時間管理について。
`jiffies`や`do_gettimeofday()`, `timeval`がでてきます。
2038年問題や497日問題にもふれられています。
ドライバでは、デバイスに対してDMAの開始を指示し、通常では完了時の割込みで処理をします。しかしこれは成功したケースで、デバイス側の不具合で割込みがあがってこないかもしれないので、必ずタイムアウト処理をいれる必要があります。

今回は以下のようにして、read時のレイテンシーをモックするためにタイムアウト処理をいれてみました。

```c
struct devone_data {
  /* ... */
  
  /* mock read latency */
  wait_queue_head_t read_wq;
  atomic_t read_ready;
  struct timer_list read_timer;
};
```

```c
static int devone_open(struct inode *inode, struct file *file) {
  struct devone_data *p;

  p = kmalloc(sizeof(struct devone_data), GFP_KERNEL);
  if (p == NULL) {
    printk("%s: No memory\n", __func__);
    return -ENOMEM;
  }

  p->val = 0xff;
  rwlock_init(&p->lock);

  /* prepare mock read latency */
  init_waitqueue_head(&p->read_wq);
  atomic_set(&p->read_ready, 1);
  timer_setup(&p->read_timer, devone_read_timer_cb, 0);

  file->private_data = p;
  return 0;
}
```

open時に、`timer_setup()`で`timer_list`にcallback関数、`devone_read_timer_cb`を登録します。

```c
static void devone_read_timer_cb(struct timer_list *t)
{
  struct devone_data *p = container_of(t, struct devone_data, read_timer);
  atomic_set(&p->read_ready, 1);
  pr_info("%s: Wake up!\n", __func__);
  wake_up(&p->read_wq);
}
```

`devone_read_timer_cb`はflag変数で完了を記録して、`wake_up()`を呼びます。

```c
#define DEVONE_READ_DELAY_MS 1000

static ssize_t devone_read(struct file *filep, char __user *buf, size_t count,
                           loff_t *f_pos) {
  struct devone_data *p = filep->private_data;
  int i;
  unsigned char val;
  int retval;
  long wr;

  atomic_set(&p->read_ready,0);
  mod_timer(&p->read_timer, jiffies + msecs_to_jiffies(DEVONE_READ_DELAY_MS));
  
  wr = wait_event_interruptible_timeout(
    p->read_wq,
    atomic_read(&p->read_ready) != 0,
    msecs_to_jiffies(DEVONE_READ_DELAY_MS + 1000)
  );
  if (wr == 0)
    return -ETIMEDOUT;
  if (wr < 0)
    return wr;

  /* read処理 */
}
```

read時に、`mod_timer()`でtimeout処理を有効化して、`wait_event_interruptible_timeout()`でレイテンシをモックします。

`#define DEVONE_READ_DELAY_MS 5000` で5秒を指定してみると無事、モックできました

```sh
time hexyl -n 1 /dev/devone0 out> /dev/null
0.00user 0.00system 0:05.13elapsed 0%CPU (0avgtext+0avgdata 2676maxresident)k
0inputs+0outputs (0major+130minor)pagefaults 0swaps
```

また、timerが発火する前にcloseでリソースが開放される場合があるので、`timer_delete_sync()`を呼び出しておく必要があります。

## 第10章 同期と排他

共有リソースにアクセスする場合に、ロックをとったり、アトミック操作を行うのは、一般的なアプリケーションと同じです。
ドライバで異なるのは、割込みコンテキストではsleepできないので、spin_lock系のAPIを用いる必要があるのと、割込みの有効/無効を意識する必要があるということがわかりました。
kthreadの説明もありました。動かすだけなら以下のようになりました。

```c
#include <linux/module.h>
#include <linux/delay.h>
#include <linux/kthread.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("ymgyt");
MODULE_DESCRIPTION("kthread sample");

#define DRIVER_NAME "kthread"

static struct task_struct *kmain_task = NULL;

static int sample_thread(void *num)
{
  while (!kthread_should_stop()) {
    msleep_interruptible(3000);
  }
  return 0;
}

static int __init mykthread_init(void) {
  kmain_task = kthread_create(sample_thread, NULL, "sample mykthread");
  if (IS_ERR(kmain_task)) {
    return PTR_ERR(kmain_task);
  }
  wake_up_process(kmain_task);

  return 0;
}

static void __exit mykthread_exit(void) {
  if (kmain_task) {
    kthread_stop(kmain_task);
  }
}

module_init(mykthread_init);
module_exit(mykthread_exit);
```

```sh
sudo insmod ./"kthread".ko
ps | where name =~ "sample mykthread"
 # |   pid   | ppid |       name       |  status  | cpu  | mem | virtual
---+---------+------+------------------+----------+------+-----+---------
 0 | 1216364 |    2 | sample mykthread | Sleeping | 0.00 | 0 B |     0 B
```

## 第11章 割込み

ドライバといえば割込みということで割込みの概念について説明されます。
また実際の割込み処理として、`drivers/net/8139too.c`が取り上げられていました。
以下は、[`drivers/net/ethernet/realtek/8139too.c`](https://github.com/Rust-for-Linux/linux/blob/192c0159402e6bfbe13de6f8379546943297783d/drivers/net/ethernet/realtek/8139too.c#L2155)の`rtl8139_interrupt()`処理です。本書のこれまでの知識で雰囲気ですが読めるようになっています。

```c
/* The interrupt handler does all of the Rx thread work and cleans up
   after the Tx thread. */
static irqreturn_t rtl8139_interrupt (int irq, void *dev_instance)
{
	struct net_device *dev = (struct net_device *) dev_instance;
	struct rtl8139_private *tp = netdev_priv(dev);
	void __iomem *ioaddr = tp->mmio_addr;
	u16 status, ackstat;
	int link_changed = 0; /* avoid bogus "uninit" warning */
	int handled = 0;
```

引数から処理用のprivateなstructを取り出し、メモリマップドI/O用アドレスを保持します。

```c
	spin_lock (&tp->lock);
	status = RTL_R16 (IntrStatus);
```

レジスタにアクセスするにあたって、lockを取得します。割込み処理内なので、irqsave等は不要と思われます。

```c
#define RTL_R16(reg)		ioread16 (ioaddr + (reg))

/* Symbolic offsets to registers. */
enum RTL8139_registers {
  /* ... */
	IntrStatus	= 0x3E,
```

`RTL_R16`はレジスタをreadするマクロで、`status`におそらく割込み関連の情報が入っていると思われます。
`ioaddr`は事前にstackに確保している前提のようです。

```c
	/* shared irq? */
	if (unlikely((status & rtl8139_intr_mask) == 0))
		goto out;

	handled = 1;
```

irq(割込みハンドラ)は、共有されうるので、処理が不要ならreturn

```c
	/* h/w no longer present (hotplug?) or major error, bail */
	if (unlikely(status == 0xFFFF))
		goto out;

	/* close possible race's with dev_close */
	if (unlikely(!netif_running(dev))) {
		RTL_W16 (IntrMask, 0);
		goto out;
	}
```

処理を継続できるかの確認と思われます。

```c
	ackstat = status & ~(RxAckBits | TxErr);
	if (ackstat)
		RTL_W16 (IntrStatus, ackstat);
```

割込み要因のクリア。`RxAckBits`と`TxErr`はこのあとの処理で参照するのでそれ以外のACK処理でしょうか。

```c
	/* Receive packets are processed by poll routine.
	   If not running start it now. */
	if (status & RxAckBits){
		if (napi_schedule_prep(&tp->napi)) {
			RTL_W16_F (IntrMask, rtl8139_norx_intr_mask);
			__napi_schedule(&tp->napi);
		}
	}
```

受信処理は、[`NAPI`](https://docs.kernel.org/networking/napi.html) という仕組みを利用しているらしく、処理を移譲

```c
	/* Check uncommon events with one test. */
	if (unlikely(status & (PCIErr | PCSTimeout | RxUnderrun | RxErr)))
		rtl8139_weird_interrupt (dev, tp, ioaddr,
					 status, link_changed);
```

Uncommonな割込みを処理


```c
	if (status & (TxOK | TxErr)) {
		rtl8139_tx_interrupt (dev, tp, ioaddr);
		if (status & TxErr)
			RTL_W16 (IntrStatus, TxErr);
	}
 out:
	spin_unlock (&tp->lock);

	netdev_dbg(dev, "exiting interrupt, intr_status=%#4.4x\n",
		   RTL_R16(IntrStatus));
	return IRQ_RETVAL(handled);
}
```

送信が完了していた場合の後処理とlock開放。
ということで雰囲気ですがどんなことをしているのかわかりました。

また、割込み処理では最低限の処理を行い、残りの処理を別の機構にまかせる仕組みとして、`tasklet`と`workqueue`の紹介もありました。
割込み処理については、[新Linuxカーネル解読室 - ソフト割り込み処理](https://www.valinux.co.jp/blog/entry/202406132)や、[新Linuxカーネル解読室 - Workqueue](https://www.valinux.co.jp/blog/entry/20251106)の解説も非常にありがたかったです。

## 第12章 PCI

PCIデバイスとドライバの対応関係の調べ方から始まります。
試しに、Wi-Fiのドライバを調べてみると

```sh
# -k   Show kernel drivers handling each device and also kernel modules capable of handling it.
# -nn  Show PCI vendor and device codes as both numbers and names.
lspci -knn | rg -i 'wireless network' -A 3
pcilib: Error reading /sys/bus/pci/devices/0000:00:08.3/label: Operation not permitted
01:00.0 Network controller [0280]: MEDIATEK Corp. MT7922 802.11ax PCI Express Wireless Network Adapter [14c3:0616] (rev 02)
        Subsystem: MEDIATEK Corp. Device [14c3:223c]
        Kernel driver in use: mt7921e
        Kernel modules: mt7921e
```

> Wireless Network Adapter [14c3:0616]
からVendorIDが`14c3` でdevice codeが`0616`とわかりました。
また、moduleは`mt7921e`が利用されているので
kernelの` drivers/net/wireless/mediatek/mt76/mt7921/Makefile`をみてみると

```Makefile
# ...
obj-$(CONFIG_MT7921E) += mt7921e.o
# ...
mt7921e-y := pci.o pci_mac.o pci_mcu.o
```
と`mt7921e` モジュールが定義されており、ドライバ側で対応するデバイスを宣言する`pci_device_id[]`をみると

```sh
rg 'static const struct pci_device_id mt7921_pci_device_table' -A 15 drivers/net/wireless/mediatek/mt76/mt7921/pci.c
16:static const struct pci_device_id mt7921_pci_device_table[] = {
17-     { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7961),
18-             .driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },
19-     { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7922),
20-             .driver_data = (kernel_ulong_t)MT7922_FIRMWARE_WM },
21-     { PCI_DEVICE(PCI_VENDOR_ID_ITTIM, 0x7922),
22-             .driver_data = (kernel_ulong_t)MT7922_FIRMWARE_WM },
23-     { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x0608),
24-             .driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },
25-     { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x0616),
26-             .driver_data = (kernel_ulong_t)MT7922_FIRMWARE_WM },
27-     { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7920),
28-             .driver_data = (kernel_ulong_t)MT7920_FIRMWARE_WM },
29-     { },
30-};
31-
```
と定義されており、`include/linux/pci_ids.h`に
```c
#define PCI_VENDOR_ID_MEDIATEK		0x14c3
```
が定義されています。また、`pci_device_id`は`include/linux/mod_devicetable.h`に以下のように定義されています。

```c
struct pci_device_id {
	__u32 vendor, device;		/* Vendor and device ID or PCI_ANY_ID*/
	__u32 subvendor, subdevice;	/* Subsystem ID's or PCI_ANY_ID */
	__u32 class, class_mask;	/* (class,subclass,prog-if) triplet */
	kernel_ulong_t driver_data;	/* Data private to the driver */
	__u32 override_only;
};
```

ここから
```
25-     { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x0616),
26-             .driver_data = (kernel_ulong_t)MT7922_FIRMWARE_WM },
```

のエントリーがlspciの`Wireless Network Adapter [14c3:0616]`に対応していそうなことがわかりました。
(本書のおかげでドライバのコードちょっと見てみようという気持ちになれたのがうれしいです。)

このあと、MMIO, I/Oポート、PCIコンフィグレーション空間の詳しい解説が続きます。

PCIドライバの具体例として、`8139too.c`の解説があります。
PCIドライバの基本的な処理として、デバイスのレジスタにアクセスするために、PCIコンフィグレーション空間からBAR情報を取得して、`ioremap()`(BARは物理アドレスなのでそのままでは仮想アドレスとしてアクセスできないから)するとこれまでの説明でわかりました。そこで、`8139too.c`の実装をみてみると

`drivers/net/ethernet/realtek/8139too.c`
```c
static struct net_device *rtl8139_init_board(struct pci_dev *pdev)
{
	struct device *d = &pdev->dev;
	void __iomem *ioaddr;
	struct net_device *dev;
	struct rtl8139_private *tp;
	unsigned int i, bar;

  /* omitted... */

	ioaddr = pci_iomap(pdev, bar, 0);
	if (!ioaddr) {
    /* omitted... */
		rc = -ENODEV;
		goto err_out;
	}
	tp->regs_len = io_len;
	tp->mmio_addr = ioaddr;
```

と`pci_iomap()`を利用しており、`drivers/pci/iomap.c`をみてみると

```c
void __iomem *pci_iomap(struct pci_dev *dev, int bar, unsigned long maxlen)
{
	return pci_iomap_range(dev, bar, 0, maxlen);
}
EXPORT_SYMBOL(pci_iomap);

void __iomem *pci_iomap_range(struct pci_dev *dev,
			      int bar,
			      unsigned long offset,
			      unsigned long maxlen)
{
	resource_size_t start, len;
	unsigned long flags;

	if (!pci_bar_index_is_valid(bar))
		return NULL;

	start = pci_resource_start(dev, bar);
	len = pci_resource_len(dev, bar);
	flags = pci_resource_flags(dev, bar);

	if (len <= offset || !start)
		return NULL;

	len -= offset;
	start += offset;
	if (maxlen && len > maxlen)
		len = maxlen;
	if (flags & IORESOURCE_IO)
		return __pci_ioport_map(dev, start, len);
	if (flags & IORESOURCE_MEM)
		return ioremap(start, len);
	/* What? */
	return NULL;
}
EXPORT_SYMBOL(pci_iomap_range);
```

と`pci_resource_{start,len}`でBARを取得し、MMIO,I/Oポートを判定して、`ioremap()`を実行していました。

ここまでは、PCIの話でしたが、PCI Expressも説明されておりどういった拡張があったのかの解説があります。


## 第13章 シリアルバス

I2C(SMBus)について。
プロトコルの概要や、バス制御方法の説明があります。自分は組み込みに馴染みがないので、このあたりの解説は非常に参考になりました。
また、lm_sensorsパッケージの説明もあります。
実装については、kernelのI2Cが`i2c-dev`, `i2c-core`, `i2c-algo`, i2c adapterといったモジュールスタックからなるといった解説があります。

## 第14章 ACPI

ACPI(Advanced Configuration and Power Interface)について。
ACPIは電源管理だけでなく、起動時に kernelがPCIeを利用可能にする初期化(ホスト側の認識や設定空間アクセスの準備)にも関与するらしい。
電源ボタン押下も ACPI 経由で通知され、ユーザー空間のポリシーに従ってシャットダウン等が実行される。


## 第15章 IPMI

IPMI(Intelligent Platform Management Interface)について。
こちらは普段関わりがないので割愛しました。(74p程度としっかり解説があります)

## 第16章 テストとデバッグ

Kernelビルド時のフラグや`printk`やMagic SysRqキー、Oopsメッセージについての解説があります。

## 第17章 ドライバ設計と実装の実際

`drivers/net/8139too.c`(今だと`drivers/net/ethernet/realtek/8139too.c`)を例にネットワークドライバの実装の解説があります。

## まとめ

Rustのsample driverのコード読むために読んでみましたが、ドライバに限らず参考になる点が多く非常におもしろかったです。Kernelに関する本は最近[Linuxカーネルプログラミング第2版](https://www.oreilly.co.jp/books/9784814401109/)が出版されましたが、一時期途絶えていた印象があり、2000年代に多く出版されている印象があります。(英語だとたくさんありますが)

本書を読むにあたり、[Linux Device Driver Development: Everything you need to start with device driver development for Linux kernel and embedded Linux, 2nd Edition](https://www.amazon.com/Linux-Device-Driver-Development-development/dp/1803240067), [カーネルモジュール作成で学ぶLinuxカーネル開発の基礎知識：第3版](https://techbookfest.org/product/h9vV6JbABCHD6CurWp7ers),[Linuxカーネルモジュール自作入門](https://techbookfest.org/product/5742284180029440)等を参考にさせていただきました。
