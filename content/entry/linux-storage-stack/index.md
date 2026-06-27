+++
title = "📕 Architecture and Design of the Linux Storage Stack を読んだ感想"
slug = "linux-storage-stack"
description = "VFS から physical storage まで storage stack を 1 layer ずつおりていく本"
date = "2026-06-28"
draft = false
[taxonomies]
tags = ["linux", "book"]
[extra]
image = "images/emoji/closed_book.png"
+++


## 読んだ本

{{ figure(caption="Architecture and Design of the Linux Storage Stack", href="https://www.packtpub.com/en-jp/product/architecture-and-design-of-the-linux-storage-stack-9781837639960", images=["images/book.jpg"], height="400") }}

著者: Muhammad Umer

system call -> VFS から先がブラックボックスで、そこから先を解説してくれている Linux の本ないかなと思っていたらまさになタイトルの本を見つけたので感想を書きます。

## Part 1: Diving into the Virtual Filesystem

### 1 Where It All Starts From - The Virtual Filesystem

User space (application) からファイルの操作 (open, read, write, ...) を行うためには、system call を利用して kernel に制御を移して処理を依頼します。
ここから、kernel の storage hierarchy の処理が始まります。最初にリクエストを処理するレイヤーが Virtual Filesystem (VFS) です。
VFS 自体は ext4 のようなファイルを管理する filesystem ではなく、実際の処理は、他のレイヤーに処理を移譲します。この点から、Virtual Filesystem Switch と呼ぶ人もいるそうです。
VFS レイヤーのおかげで、いわゆる pseudo filesystem (e.g. `/sys`) といった、メモリ上にしか実体がないコンポーネントにも file と同じ API でアクセスを提供することができます。
ここまではどの Linux 本でも言及されると思いますが、本書はもう一歩踏み込んで system call から VFS が実際の filesystem に処理を移譲しているところまでの解説があります。

`fs/read_write.c`
```c
SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count)
{
	return ksys_read(fd, buf, count);
}

ssize_t ksys_read(unsigned int fd, char __user *buf, size_t count)
{
	CLASS(fd_pos, f)(fd);
	ssize_t ret = -EBADF;

	if (!fd_empty(f)) {
		loff_t pos, *ppos = file_ppos(fd_file(f));
		/* omitted ... */
		ret = vfs_read(fd_file(f), buf, count, ppos);
		if (ret >= 0 && ppos)
			fd_file(f)->f_pos = pos;
	}
	return ret;
}

ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)
{
	ssize_t ret;

	/* omitted ... */
	if (file->f_op->read)
		ret = file->f_op->read(file, buf, count, pos);
	else if (file->f_op->read_iter)
		ret = new_sync_read(file, buf, count, pos);
	else
		ret = -EINVAL;

	/* omitted ... */
	return ret;
}
```

### 2 Explaining the Data Structures in a VFS

本章では、VFS が扱うデータ構造毎の解説があります。
具体的には、Inodes, Superblocks, Directory entries, File objects, Page cache です。
メモリ上だけの存在なのか、filesystem 側で永続化されるのかが整理されており、わかりやすかったです。

`include/linux/fs.h` の `inode`

```c
struct inode {
	umode_t			i_mode;
	unsigned short		i_opflags;
	unsigned int		i_flags;
	/* .... */
}
```

はメモリ上の実体ですが、これを VFS に返すのは filesystem の役目です。
ext4 の場合、`fs/ext4/ext4.h` に inode の disk 表現として、`ext4_inode` が定義されています。

```c
/*
 * Structure of an inode on the disk
 */
struct ext4_inode {
	__le16	i_mode;		/* File mode */
	__le16	i_uid;		/* Low 16 bits of Owner Uid */
	__le32	i_size_lo;	/* Size in bytes */
	__le32	i_atime;	/* Access time */
	__le32	i_ctime;	/* Inode Change time */
	/* ... */
}
```

今まで曖昧に、`inode` という共通データ構造が永続化されていると思っていたのですが、VFS と filesystem の役割分担がわかりすっきりしました。

### 3 Exploring the Actual Filesystems Under the VFS

3章では実際の filesystem について解説されます。
Journaling や Copy on Write (CoW) といった機能の解説があります。
その後、Ext4 filesystem がどのようにファイルを管理しているのか、`ext4_super_block`, `ext4_inode`, `ext4_group_desc` といったデータ構造を中心に説明してくれます。
filesystem は block という単位でデータを管理します。これが後続レイヤーとの処理の単位になります。
また、NFS や Filesystem in Userspace (FUSE) の概要説明もあります。
FUSE は私の理解では、以下のようにして動作します。

1. FUSE filesystem を VFS に登録
2. User space process (ユーザ側で実装したい filesystem) が `/dev/fuse` file を read して待機
3. FUSE filesystem 上のファイルオペレーションが実行される
4. kernel 側の FUSE がファイルオペレーションを FUSE のプロトコルにしたがってシリアライズし、`/dev/fuse` の read の結果として返す
5. User space process が実際のファイルオペレーションを実行し、結果を `/dev/fuse` へ書き込む

## Part 2: Navigating Through the Block Layer

### 4 Understanding the Block Layer, Block Devices, and Data Structures

4,5,6章は VFS から一段降りた、block layer についてです。
Block layer は block device に対する I/O operation を管理する kernel subsystem と説明されます。
本章では、VFS からの I/O 処理がどのように block device に到達するかの概要が説明されます。
具体的には、mapping layer (device mapper framework), I/O scheduler, blk-mq 等についてです。
また、 `gendisk`, `block_device`, `buffer_head`, `request`, `request_queue`, `bio`, `bio_vec` といった各種基本的なデータ構造の解説があります。
ただこれらのデータ構造については、主要なフィールドがどんな情報(参照)をもっているかの概要のみの説明で、この章を読めば、block layer の実装がわかるというよりコードの土地勘がちょっとつくという感じでした。

### 5 Understanding the Block Layer, Multi-Queue, and Device Mapper

5章では、blk-mq と device mapper framework を扱います。

かつて block layer では、block I/O を single queue で扱っていました。そのため、multi-core 環境では CPU core 間で queue lock の取り合いが発生し、cache coherency の維持にも CPU 時間を消費してしまう問題がありました。また、SSD/NVMe の普及によって hardware 側は並列に I/O を処理できるようになりましたが、single queue のままではその能力を十分に活かせませんでした。

そこで blk-mq では、CPU core 側に software staging queue を用意し、block device driver の前段には hardware dispatch queue を設ける構成が取られます。これにより、single queue に集中していた競合を減らし、storage device の並列性を活かしやすくしています。

Device mapper framework は、filesystem と実際の block device の間に、仮想的な block device を挟む仕組みです。Logical Volume Manager、つまり LVM はこの仕組みを利用して実現されており、user space からは dmsetup や libdevmapper を通じて制御できます。

device mapper framework は、HTTP server でいう middleware 的な機能を block layer で提供しているように思えました。たとえば、書き込むと暗号化される仮想 block device を用意することで、各 filesystem や各 storage driver が暗号化処理を個別に実装しなくても、透過的な暗号化を実現できます。

### 6 Understanding I/O Handling and Scheduling in the Block Layer

6章は scheduler について。
前章までで、filesystem から bio が submit され、それが block layer 側で request として扱われるところまで見ました。6章では、その request を block device driver に渡す前に、どう並べ替えたり、まとめたりするかという話が中心でした。

Sort や Merge は、request をそのまま下に流すのではなく、近い sector への I/O をまとめたり、順番を変えたりする処理です。特に HDD では random access が遅いので、このような処理で seek を減らす意味がありました。

そのうえで、MQ-deadline、Budget Fair Queuing、Kyber、none といった scheduler が説明されます。MQ-deadline は deadline によって request が放置されないようにするもの、BFQ は process ごとの公平性を意識するもの、Kyber は queue に request を流しすぎないようにして latency を守るもの、none は基本的に request の並べ替えを行わないもの、という理解です。

読んでいて、scheduler は単純に速くするためのものというより、request_queue にある request を、device の性質に合わせてどう driver に渡すかを決める policy なのだと思いました。HDD では並べ替えや merge が重要で、NVMe のように hardware 側が強い場合は、逆に scheduler の overhead を減らすことも重要になる、という点が面白かったです。


## Part 3: Descending into the Physical Layer

### 7 The SCSI Subsystem

Part 3 からは Physical layer について入ります。7章では、その前提として、[Linux Device Model](https://docs.kernel.org/driver-api/driver-model/overview.html) と Small Computer System Interface (SCSI) subsystem について説明されます。

Device model は、kernel が扱う多様な device を共通的に扱うための抽象です。その土台には kobject があり、bus、device、driver、class といった構造として整理されます。/sys で device が統一的に見えるのは、kernel 内で各 device がこの共通の device model に基づいて管理されているからです。

SCSI subsystem については、Upper、Mid、Lower layer の 3 層構造であることが解説されます。`/dev/sda` のように見える disk は、SCSI upper layer の sd driver によって block device として扱われます。

Mid layer は、SCSI command の queueing、timeout、error handling などの共通機能を提供します。Lower layer は HBA や controller に近い driver で、SCSI command を実際の transport を通じて target device に送る役割を担います。

この章で理解したのは、SCSI は filesystem や block layer のように data の配置を決める層ではなく、block layer から来た read/write request を storage device が理解できる SCSI command として運ぶための subsystem だということです。

### 8 Illustrating the Layout of Physical Media

8章では、HDD、SSD、NVMe といった physical storage media について説明されます。

ここまでの章では、VFS、filesystem、block layer、SCSI subsystem など、主に software stack 側を見てきました。8章ではその下にある実際の storage device の構造に入ります。

HDD では、platter、spindle、read/write head、actuator arm といった機械部品が出てきます。HDD の性能が random I/O に弱いのは、目的の位置まで head を動かす seek time と、目的の sector が head の下に来るまで待つ rotational latency があるからだと理解しました。そのため、前章で出てきた scheduler の sorting や merging は、HDD の物理的な制約を意識した最適化なのだとつながりました。

SSD では、機械部品がなくなり、NAND flash に data を保存します。そのため random access には強くなりますが、page 単位で read/write し、erase は block 単位で行うという別の制約があります。上書きが単純にできず、FTL、garbage collection、wear leveling、write amplification といった仕組みが必要になる点が面白かったです。HDD とは違い、SSD は速い代わりに内部でかなり複雑な管理をしていると感じました。

NVMe については、SSD そのものというより、SSD の性能を引き出すための interface / protocol として理解しました。SATA や SCSI 系の stack よりも software overhead が小さく、PCIe と多くの queue を使えるため、Chapter 5 の blk-mq と強く関係していることがわかりました。
具体的には、SATA は 1 queue に 32 command まで詰めますが、NVMe では最大 64K queues を持て、各 queue に最大 64K commands を詰められるとあり、まったく別物であることがわかりました。

この章を読んで、Linux からはどれも block device として見えていても、下にある media の性質は大きく違うのだと理解しました。HDD では seek を減らすこと、SSD では erase や GC を意識すること、NVMe では queue の並列性を活かすことが重要になります。block layer や scheduler の設計は、こうした物理 media の性質を抽象しつつ、できるだけ性能を引き出すためにあるのだと思いました。

## Part 4: Analyzing and Troubleshooting Storage Performance

### 9 Analyzing Physical Storage Performance

9章では、physical storage の performance analysis について説明されます。

8章では HDD、SSD、NVMe といった physical media の性質を見ました。9章では、それらの storage device が実際に遅いときに、どの指標を見て判断するかという話に入ります。

top、iotop、iostat、vmstat、/proc/pressure/io などの tool が紹介され、IOPS、throughput、latency、queue depth、utilization、saturation、iowait といった指標を見ていきます。ただ、正直なところ、これらの出力と、ここまで見てきた kernel 内部の構造がまだうまくつながっていません。

内部では、bio が request になり、request_queue、software staging queue、scheduler の内部 queue、hardware dispatch queue など、複数の queue を経由しているはずです。しかし、iostat などの tool で見える値は、かなり集約された device 単位の数字に見えます。そのため、await や queue size のような値を見ても、それが具体的に kernel 内部のどの待ち時間やどの queue の状態を反映しているのかは、まだはっきり理解できていません。

それでも、「disk が遅い」と雑に見るのではなく、IOPS、throughput、latency、queue depth、utilization、saturation を分けて考える必要がある、ということはわかりました。

9章を読んで、storage performance analysis は、tool の数字を見るだけではなく、その数字が storage stack のどの層の現象を集約しているのかを考える必要があるのだと思いました。まだ実戦で判断できる感じはありませんが、少なくとも、観測値と内部構造をつなげて読む必要がある、という課題が見えた章でした。

### 10 Analyzing Filesystems and the Block Layer

10章では、filesystem と block layer の performance analysis について説明されます。

特に重要だと思ったのは、Logical I/O と Physical I/O が一致しないという点です。application が read/write しても、それがそのまま disk への read/write になるとは限りません。read は page cache に hit すれば disk まで行かないし、通常の buffered I/O では write は page cache に入ってあとで writeback されます。また、readahead によって application がまだ要求していない data が先に読まれることもあります。逆に journaling や metadata update によって、application から見ると 1 回の write でも、下では複数の physical I/O になることがあります。

filesystem を遅くする要因も、単純に disk が遅いだけではありません。cache miss、metadata update、journaling、fsync、locking や contention、writeback の詰まり、block size や alignment の問題などがあります。つまり filesystem latency は、physical device の性能だけではなく、filesystem が data と metadata をどう管理しているかにも大きく影響されます。

この章を読んで、I/O performance を見るときは、application の read/write 回数と disk の I/O 回数をそのまま対応づけてはいけないのだと思いました。Logical I/O と Physical I/O の間に、cache、filesystem、metadata、journaling、block layer があり、そこで I/O が消えたり、増えたり、まとめられたり、遅れたりする。そのズレを見るために layer ごとの tool が必要になる、という理解です。


### 11 Tuning the I/O Stack

11章では、I/O stack の tuning について説明されます。

ここまで、filesystem、block layer、device mapper、scheduler、SCSI、physical media、performance analysis と見てきました。最後の 11章では、それぞれの stack の layer にどんな調整ポイントがあるのかが扱われます。

memory まわりでは、page cache と writeback の話が中心でした。direct I/O は page cache を bypass する方法で、database のように application 側で cache を持っている場合には意味があります。また、sysctl の `vm.dirty_background_bytes`、`vm.dirty_background_ratio`、`vm.dirty_bytes`、`vm.dirty_ratio` などは、dirty page をどれくらい memory に溜めるか、いつ background writeback を始めるか、いつ write している process を止めて writeback させるかに関係します。
ちょうど最近、LWN の [Initiating writeback earlier](https://lwn.net/Articles/1078767/) という記事で

> Writeback is initiated for buffered I/O when the memory-management subsystem decides that the number of dirty pages is too high; it is also initiated periodically. But "modern memory sizes are huge", so the default dirty limits used are out of date; he thought they had not been updated for 20 years or more.

(ライトバック処理は、メモリ管理サブシステムがダーティページの数が許容範囲を超えたと判断した場合、あるいは定期的に自動的に開始されます。しかし「現代のメモリ容量は膨大になっている」ため、現在使用されているデフォルトのダーティページ制限値は時代遅れの状態です。これらの制限値は20年以上更新されていないとのことです。)

という話があり、まさにこのパラメータについて、[Linux Storage, Filesystem, Memory Management, and BPF Summit](https://events.linuxfoundation.org/lsfmmbpf/) で取り上げられていたようでした。

filesystem では、block size、alignment、journaling、barrier、timestamp、readahead、discard などが tuning point として出てきます。

また、filesystem は ctime、mtime、atime のような timestamp を記録しますが、atime の更新を抑える方法があることを知りました。

block layer では scheduler の選択が tuning point になります。6章で MQ-deadline、BFQ、Kyber、none を見ましたが、11章では device や workload に応じて scheduler を選ぶ話として出てきます。NVMe のように下の device 側の queue 並列性が高い場合は、host 側で複雑に scheduling しないことも選択肢になります。
自分の環境を確認してみたところ、NVMe の scheduler は none が選択中になっていました。

```
cat /sys/block/nvme0n1/queue/scheduler
[none] mq-deadline kyber
```
この本を読まなかったら、I/O scheduler の none が妥当な選択肢になるとは思わなかったでしょう。

## まとめ

system call -> VFS から先がブラックボックスで、そこだけ解説してくれている Linux の本ないかなと探してた中でまさに VFS から block device までを解説してくれている本に出会えました。
この本を読めば、storage に対する I/O がすべてわかるとまではいきませんが、全体の登場人物なり、おおまかなコンポーネント間の関係がわかると思います。
また、Brendan Gregg 先生の [詳解 システム・パフォーマンス 第2版](https://www.oreilly.co.jp/books/9784814400072/) 8章 ファイルシステム、9章 ディスク が難しかったと思った人にもおすすめです。
