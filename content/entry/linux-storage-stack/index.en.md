+++
title = "📕 Thoughts on Architecture and Design of the Linux Storage Stack"
slug = "linux-storage-stack"
description = "A book that descends through the storage stack one layer at a time, from VFS to physical storage"
date = "2026-06-28"
draft = false
[taxonomies]
tags = ["linux", "book"]
[extra]
image = "images/emoji/closed_book.png"
+++

## Book

{{ figure(caption="Architecture and Design of the Linux Storage Stack", href="https://www.packtpub.com/en-jp/product/architecture-and-design-of-the-linux-storage-stack-9781837639960", images=["images/book.jpg"], height="400") }}

Author: Muhammad Umer

I had long treated everything beyond system calls and the VFS as a black box.
While looking for a Linux book that explained that area, I found one with exactly the title I wanted, so here are my notes after reading it.

## Part 1: Diving into the Virtual Filesystem

### 1 Where It All Starts From - The Virtual Filesystem

When a user-space application wants to perform file operations such as open, read, or write, it uses system calls to transfer control to the kernel and ask it to do the work.
This is where the kernel's storage hierarchy begins.
The first layer that handles the request is the Virtual Filesystem (VFS).

The VFS itself is not a filesystem that manages files, like ext4 does.
Instead, it delegates the actual work to other layers.
For that reason, it is sometimes called the Virtual Filesystem Switch.
Thanks to the VFS layer, components that only exist in memory, such as pseudo filesystems like `/sys`, can be exposed through the same file APIs as ordinary files.

Most Linux books probably mention this much, but this book goes one step further and explains how execution moves from a system call to the point where the VFS delegates work to the actual filesystem.

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

This chapter explains each of the data structures handled by the VFS: inodes, superblocks, directory entries, file objects, and the page cache.
I found it easy to follow because the book separates which objects exist only in memory from which ones are persisted by the filesystem.

The `inode` in `include/linux/fs.h`:

```c
struct inode {
	umode_t			i_mode;
	unsigned short		i_opflags;
	unsigned int		i_flags;
	/* .... */
}
```

is an in-memory object, and it is the filesystem's responsibility to return it to the VFS.
In ext4, for example, `fs/ext4/ext4.h` defines `ext4_inode` as the on-disk representation of an inode.

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

Until now, I had vaguely assumed that some common data structure called an `inode` was what got persisted.
Understanding the split of responsibilities between the VFS and each filesystem made this much clearer.

### 3 Exploring the Actual Filesystems Under the VFS

Chapter 3 explains actual filesystems.
It covers features such as journaling and Copy on Write (CoW).
It then explains how the Ext4 filesystem manages files, mainly through data structures such as `ext4_super_block`, `ext4_inode`, and `ext4_group_desc`.

A filesystem manages data in units called blocks.
That becomes the unit of work for the layers below it.
The chapter also gives an overview of NFS and Filesystem in Userspace (FUSE).

My understanding of FUSE is that it works as follows:

1. Register a FUSE filesystem with the VFS.
2. A user-space process, which implements the filesystem, waits by reading from `/dev/fuse`.
3. A file operation is performed on the FUSE filesystem.
4. The kernel-side FUSE code serializes the file operation according to the FUSE protocol and returns it as the result of the read from `/dev/fuse`.
5. The user-space process performs the actual file operation and writes the result back to `/dev/fuse`.

## Part 2: Navigating Through the Block Layer

### 4 Understanding the Block Layer, Block Devices, and Data Structures

Chapters 4, 5, and 6 cover the block layer, which sits one level below the VFS.
The block layer is described as a kernel subsystem that manages I/O operations against block devices.

This chapter gives an overview of how I/O from the VFS reaches a block device.
It covers topics such as the mapping layer, the device mapper framework, the I/O scheduler, and blk-mq.
It also explains basic data structures such as `gendisk`, `block_device`, `buffer_head`, `request`, `request_queue`, `bio`, and `bio_vec`.

That said, the explanations of these data structures are mostly at the level of what each main field represents or points to.
Reading this chapter did not make me understand the block layer implementation in detail, but it did give me a better sense of the code layout.

### 5 Understanding the Block Layer, Multi-Queue, and Device Mapper

Chapter 5 covers blk-mq and the device mapper framework.

The block layer used to handle block I/O with a single queue.
In multi-core environments, that meant CPU cores contended for the queue lock, and CPU time was also spent maintaining cache coherency.
At the same time, with the spread of SSDs and NVMe devices, hardware became capable of processing I/O in parallel, but a single queue could not fully make use of that capability.

blk-mq addresses this by placing software staging queues on the CPU core side and hardware dispatch queues in front of the block device driver.
This reduces contention around a single centralized queue and makes it easier to take advantage of the storage device's parallelism.

The device mapper framework inserts a virtual block device between the filesystem and the actual block device.
Logical Volume Manager, or LVM, is implemented using this mechanism, and it can be controlled from user space through tools such as dmsetup and libdevmapper.

The device mapper framework felt to me like middleware for the block layer, similar in spirit to middleware in an HTTP server.
For example, by preparing a virtual block device that encrypts data on write, transparent encryption can be implemented without requiring every filesystem or storage driver to implement encryption itself.

### 6 Understanding I/O Handling and Scheduling in the Block Layer

Chapter 6 is about schedulers.
Up to this point, we had seen how a filesystem submits a bio and how the block layer treats it as a request.
This chapter focuses on how those requests are reordered or merged before being passed to the block device driver.

Sorting and merging mean that requests are not simply passed downward as-is.
Instead, I/O to nearby sectors can be grouped together or reordered.
This was especially meaningful for HDDs, where random access is slow, because it can reduce seeks.

The chapter then explains schedulers such as MQ-deadline, Budget Fair Queuing, Kyber, and none.
My understanding is that MQ-deadline prevents requests from being left unattended by using deadlines, BFQ focuses on fairness between processes, Kyber protects latency by avoiding pushing too many requests into queues, and none basically performs no request reordering.

While reading this, I felt that schedulers are not simply there to make things faster.
They are policies that decide how to pass requests in a `request_queue` to the driver according to the characteristics of the device.
For HDDs, reordering and merging are important.
For devices like NVMe, where the hardware already handles parallelism well, reducing scheduler overhead can instead become important.
That was an interesting point.

## Part 3: Descending into the Physical Layer

### 7 The SCSI Subsystem

Part 3 moves into the physical layer.
As a prerequisite, Chapter 7 explains the [Linux Device Model](https://docs.kernel.org/driver-api/driver-model/overview.html) and the Small Computer System Interface (SCSI) subsystem.

The device model is an abstraction that lets the kernel handle many kinds of devices in a common way.
At its foundation is `kobject`, and devices are organized through structures such as buses, devices, drivers, and classes.
Devices appear uniformly under `/sys` because, inside the kernel, they are managed according to this common device model.

For the SCSI subsystem, the chapter explains its three-layer structure: upper, mid, and lower.
A disk that appears as something like `/dev/sda` is treated as a block device by the `sd` driver in the SCSI upper layer.

The mid layer provides common functionality such as SCSI command queueing, timeouts, and error handling.
The lower layer consists of drivers closer to HBAs or controllers, and its role is to send SCSI commands to the target device through the actual transport.

What I understood from this chapter is that SCSI is not a layer that decides data placement, unlike filesystems or the block layer.
It is a subsystem for carrying read/write requests from the block layer as SCSI commands that a storage device can understand.

### 8 Illustrating the Layout of Physical Media

Chapter 8 explains physical storage media such as HDDs, SSDs, and NVMe.

Up to this point, the book had mainly covered the software side of the stack: the VFS, filesystems, the block layer, and the SCSI subsystem.
This chapter goes below that into the structure of actual storage devices.

For HDDs, it introduces mechanical parts such as platters, spindles, read/write heads, and actuator arms.
I understood that HDDs are weak at random I/O because there is seek time to move the head to the target location and rotational latency while waiting for the target sector to pass under the head.
This connected back to the previous chapter: scheduler sorting and merging are optimizations that account for the physical constraints of HDDs.

SSDs have no mechanical parts and store data in NAND flash.
That makes them strong at random access, but they have different constraints: reads and writes happen in page units, while erases happen in block units.
I found it interesting that overwrites are not simple and require mechanisms such as the FTL, garbage collection, wear leveling, and write amplification management.
Unlike HDDs, SSDs are fast, but they perform a lot of complex management internally.

I understood NVMe less as an SSD itself and more as an interface and protocol for unlocking SSD performance.
It has less software overhead than SATA or SCSI-based stacks, and because it can use PCIe and many queues, I could see why it is closely tied to blk-mq from Chapter 5.
Concretely, SATA can place up to 32 commands in one queue, while NVMe can have up to 64K queues, each with up to 64K commands.
That made it clear that they are fundamentally different.

After reading this chapter, I understood that even though Linux exposes all of these as block devices, the characteristics of the underlying media are very different.
For HDDs, reducing seeks matters.
For SSDs, erases and garbage collection matter.
For NVMe, making use of queue parallelism matters.
I think the block layer and scheduler are designed to abstract over these physical media characteristics while still extracting as much performance as possible.

## Part 4: Analyzing and Troubleshooting Storage Performance

### 9 Analyzing Physical Storage Performance

Chapter 9 explains physical storage performance analysis.

Chapter 8 covered the characteristics of physical media such as HDDs, SSDs, and NVMe.
Chapter 9 then moves into how to decide what to look at when those storage devices are actually slow.

The book introduces tools such as top, iotop, iostat, vmstat, and `/proc/pressure/io`, and discusses metrics such as IOPS, throughput, latency, queue depth, utilization, saturation, and iowait.
Honestly, though, I still cannot connect those outputs cleanly to the internal kernel structures covered so far.

Inside the kernel, a bio becomes a request, and it should pass through multiple queues: the `request_queue`, software staging queues, scheduler-internal queues, hardware dispatch queues, and so on.
But the values shown by tools such as iostat look like fairly aggregated numbers at the device level.
So even when I look at values such as `await` or queue size, I still do not clearly understand which specific wait time or queue state inside the kernel they reflect.

Even so, I did understand that I should not vaguely think "the disk is slow."
It is necessary to distinguish IOPS, throughput, latency, queue depth, utilization, and saturation.

After reading Chapter 9, I felt that storage performance analysis is not just about looking at tool output.
It is also necessary to think about which layer's behavior in the storage stack each number is summarizing.
I do not yet feel able to make practical judgments, but this chapter at least made the problem visible: I need to connect observed values with the internal structure of the stack.

### 10 Analyzing Filesystems and the Block Layer

Chapter 10 explains performance analysis for filesystems and the block layer.

What I found especially important is that logical I/O and physical I/O do not necessarily match.
Even if an application issues reads and writes, those operations do not necessarily become reads and writes to the disk as-is.
A read may hit the page cache and never reach the disk.
With normal buffered I/O, writes enter the page cache and are written back later.
Readahead can read data before the application has asked for it.
Conversely, journaling and metadata updates can cause a single write from the application's perspective to turn into multiple physical I/Os below.

The factors that make a filesystem slow are also not simply that the disk is slow.
There can be cache misses, metadata updates, journaling, fsync, locking or contention, writeback congestion, block size problems, alignment problems, and so on.
In other words, filesystem latency is affected not only by the performance of the physical device, but also by how the filesystem manages data and metadata.

After reading this chapter, I felt that I should not directly map an application's read/write count to the disk's I/O count when looking at I/O performance.
Between logical I/O and physical I/O, there are the cache, filesystem, metadata handling, journaling, and the block layer.
I/O can disappear, increase, be merged, or be delayed there.
The reason we need tools at each layer is to observe that gap.

### 11 Tuning the I/O Stack

Chapter 11 explains I/O stack tuning.

By this point, the book had covered filesystems, the block layer, the device mapper, schedulers, SCSI, physical media, and performance analysis.
The final chapter discusses what tuning points exist at each layer of the stack.

Around memory, the main topics are the page cache and writeback.
Direct I/O is a way to bypass the page cache, which can make sense for applications such as databases that maintain their own caches.
The sysctl parameters `vm.dirty_background_bytes`, `vm.dirty_background_ratio`, `vm.dirty_bytes`, and `vm.dirty_ratio` are related to how many dirty pages can accumulate in memory, when background writeback starts, and when the writing process itself is stopped and made to perform writeback.

Recently I happened to read the LWN article [Initiating writeback earlier](https://lwn.net/Articles/1078767/), which discussed this exact area.
The article notes that dirty limits are outdated because "modern memory sizes are huge," and that they may not have been updated for more than two decades.
This was exactly the sort of parameter discussed at the [Linux Storage, Filesystem, Memory Management, and BPF Summit](https://events.linuxfoundation.org/lsfmmbpf/).

For filesystems, the book lists tuning points such as block size, alignment, journaling, barriers, timestamps, readahead, and discard.

I also learned that although filesystems record timestamps such as ctime, mtime, and atime, there are ways to suppress atime updates.

For the block layer, scheduler selection is a tuning point.
Chapter 6 covered MQ-deadline, BFQ, Kyber, and none, and Chapter 11 revisits them as scheduler choices depending on the device and workload.
For devices like NVMe, where the lower device layer has high queue parallelism, choosing not to perform complex scheduling on the host side can also make sense.

When I checked my own environment, `none` was selected as the scheduler for my NVMe device.

```text
cat /sys/block/nvme0n1/queue/scheduler
[none] mq-deadline kyber
```

If I had not read this book, I would not have thought that `none` could be a reasonable choice for an I/O scheduler.

## Summary

I had been looking for a Linux book that explained the part beyond system calls and the VFS, which had remained a black box for me.
This book turned out to be exactly that: it explains the path from the VFS down to block devices.

Reading it does not mean I now understand everything about storage I/O.
But I do think it gives a good overview of the major components and how they relate to each other.
I would also recommend it to anyone who found Chapters 8 and 9, Filesystems and Disks, of Brendan Gregg's [Systems Performance, 2nd Edition](https://www.oreilly.co.jp/books/9784814400072/) difficult.
