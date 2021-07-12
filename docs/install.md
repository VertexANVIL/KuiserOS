## Installation

KuiserOS does not currently have a setup for automatic partitioning. Currently this needs to be done manually.

### Partitioning

Select and zap the disk

```
DISK=/dev/disk/by-id/...
sgdisk -z $DISK
```

Create partition layouts

```
sgdisk -a1 -n1:34:2047 -t1:EF02 -c1:grub $DISK
sgdisk -n2:1M:+512M -t2:EA00 -c1:boot $DISK
sgdisk -n3:513M:+32G -t3:8200 -c1:swap $DISK
sgdisk -n4:0:0 -t4:BF00 -c1:zfs $DISK
mkfs.vfat $DISK-part2
mkswap -L swap $DISK-part3
```

Create the ZFS pool

```
zpool create -o ashift=12 -O mountpoint=none -O atime=off -O xattr=sa -O acltype=posixacl -O encryption=aes-256-gcm -O keylocation=prompt -O keyformat=passphrase rpool $DISK-part4
zfs create -o mountpoint=legacy rpool/local
zfs create rpool/local/root
zfs create rpool/local/nix
zfs create rpool/local/docker
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true rpool/safe
zfs create -o compression=lz4 rpool/safe/home
zfs create rpool/safe/persist
zfs snapshot rpool/local/root@blank
```

Mount the partitions

```
mount -t zfs rpool/local/root /mnt

cd /mnt
mkdir nix home persist boot
mount -t zfs rpool/local/nix /mnt/nix
mount -t zfs rpool/safe/home /mnt/home
mount -t zfs rpool/safe/persist /mnt/persist
mount $DISK-part2 /mnt/boot

mkdir -p /mnt/etc/nixos
nixos-generate-config --root /mnt
```
