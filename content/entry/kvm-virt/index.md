+++
title = "TODO"
slug = "mastering-kvm-virtualization"
description = "TODO"
date = "2026-06-28"
draft = true
[taxonomies]
tags = ["linux", "book"]
[extra]
image = "todo"
+++

## MEMO


## 読んだ本


## Ch3

```sh
sudo mkdir -p /var/lib/libvirt/images

curl -L -o debian-13.5.0-amd64-netinst.iso "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.5.0-amd64-netinst.iso"

sudo mv debian-13.5.0-amd64-netinst.iso /var/lib/libvirt/images/

(
virt-install
  --connect qemu:///system
  --virt-type=kvm
  --name vm01
  --vcpus 2
  --ram 4096
  --os-variant debian13
  --cdrom /var/lib/libvirt/images/debian-13.5.0-amd64-netinst.iso
  --network network=default
  --graphics vnc
  --disk size=16
)

virsh net-dhcp-leases default

ssh <host>@<user>
```
