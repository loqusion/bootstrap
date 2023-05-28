#!/usr/bin/env bash

set -euo pipefail

TARGET_DISK=${TARGET_DISK:-${1:-}}
TARGET_HOSTNAME=${TARGET_HOSTNAME:-}
TARGET_USER=${TARGET_USER:-loqusion}
TARGET_KERNEL=${TARGET_KERNEL:-linux}
TARGET_FILESYSTEM=${TARGET_FILESYSTEM:-btrfs}
FORCE=${FORCE:-false}

EDITOR_PACKAGE=${EDITOR_PACKAGE:-neovim}
SHELL_PACKAGE=${SHELL_PACKAGE:-fish}
FS_UTILS_PACKAGE=
ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES:-}

if ! [ -d /sys/firmware/efi/efivars ]; then
	echo "ERROR: UEFI is not enabled. This script is only for UEFI systems."
	exit 1
fi

case "$TARGET_KERNEL" in
linux | linux-lts | linux-zen) KERNEL_HEADERS="$TARGET_KERNEL-headers" ;;
*)
	echo "ERROR: Unsupported kernel: $TARGET_KERNEL"
	exit 1
	;;
esac
case "$TARGET_FILESYSTEM" in
ext4) FS_UTILS_PACKAGE="e2fsprogs" ;;
btrfs) FS_UTILS_PACKAGE="btrfs-progs" ;;
*)
	echo "ERROR: Unsupported filesystem: $TARGET_FILESYSTEM"
	exit 1
	;;
esac
if [ -z "$TARGET_DISK" ]; then
	echo -e "ERROR: No target disk specified.\nSpecify a block device with TARGET_DISK or as an argument to this script."
	exit 1
elif ! [ -b "$TARGET_DISK" ]; then
	echo "ERROR: $TARGET_DISK is not a block device."
	exit 1
fi

if [ -z "$TARGET_HOSTNAME" ]; then
	read -p "Enter a hostname: " -r TARGET_HOSTNAME
	[ -z "$TARGET_HOSTNAME" ] && echo "ERROR: Hostname cannot be empty." && exit 1
fi

echo "TARGET_DISK:         $TARGET_DISK"
echo "TARGET_HOSTNAME:     $TARGET_HOSTNAME"
echo "TARGET_USER:         $TARGET_USER"
echo "TARGET_KERNEL:       $TARGET_KERNEL"
echo "TARGET_FILESYSTEM:   $TARGET_FILESYSTEM"
echo "---"
echo "EDITOR_PACKAGE:      $EDITOR_PACKAGE"
echo "SHELL_PACKAGE:       $SHELL_PACKAGE"
echo "FS_UTILS_PACKAGE:    $FS_UTILS_PACKAGE"
echo "ADDITIONAL_PACKAGES: $ADDITIONAL_PACKAGES"
read -p "Continue? [Y/n] " -r REPLY || exit 1
if [ -n "$REPLY" ] && ! [[ $REPLY =~ ^[Yy]$ ]]; then
	exit 1
fi

if [ "$FORCE" != true ] && [ "$FORCE" != "1" ]; then
	echo "WARNING: This script will destroy all data on $TARGET_DISK."
	read -p "Continue? [y/N] " -r REPLY || exit 1
	if ! [[ $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi
sgdisk "$TARGET_DISK" -og
sgdisk "$TARGET_DISK" -n=1:0:+512M -t=1:ef00 -c=1:"EFI system partition"
sgdisk "$TARGET_DISK" -n=2:0:+4096M -t=2:8200 -c=2:"Linux swap"
sgdisk "$TARGET_DISK" -n=3:0:0 -t=3:830 -c=3:"Linux filesystem"
sgdisk "$TARGET_DISK" -p

# FIXME: proper partition name detection
BOOT_PARTITION="${TARGET_DISK}p1"
SWAP_PARTITION="${TARGET_DISK}p2"
ROOT_PARTITION="${TARGET_DISK}p3"
mkfs.fat -F 32 -n EFI "$BOOT_PARTITION"
mkswap -L swap "$SWAP_PARTITION"
case "$TARGET_FILESYSTEM" in
btrfs)
	mkfs.btrfs -f -L arch_os "$ROOT_PARTITION"
	mount "$ROOT_PARTITION" /mnt
	btrfs subvolume create /mnt/@
	btrfs subvolume set-default /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@snapshots
	btrfs subvolume create /mnt/@var_log
	umount /mnt

	mount -o subvol=@ "$ROOT_PARTITION" /mnt
	mount -o subvol=@home "$ROOT_PARTITION" /mnt/home
	mount -o subvol=@snapshots "$ROOT_PARTITION" /mnt/.snapshots
	mount -o subvol=@var_log "$ROOT_PARTITION" /mnt/var/log
	mount --mkdir "BOOT_PARTITION" /mnt/boot
	swapon "$SWAP_PARTITION"
	;;
ext4)
	mkfs.ext4 -L arch_os "$ROOT_PARTITION"

	mount "$ROOT_PARTITION" /mnt
	mount --mkdir "BOOT_PARTITION" /mnt/boot
	swapon "$SWAP_PARTITION"
	;;
*)
	echo "ERROR: Unsupported filesystem: $TARGET_FILESYSTEM"
	exit 1
	;;
esac

echo "Exiting..."
exit

# shellcheck disable=SC2086
pacstrap -K /mnt base base-devel alsa-utils "$TARGET_KERNEL" "$KERNEL_HEADERS" linux-firmware intel-ucode iwd dhcpcd man-db man-pages texinfo "$SHELL_PACKAGE" "$EDITOR_PACKAGE" "$FS_UTILS_PACKAGE" $ADDITIONAL_PACKAGES

genfstab -U /mnt >>/mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
arch-chroot /mnt hwclock --systohc

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf

echo "$TARGET_HOSTNAME" >/mnt/etc/hostname

arch-chroot /mnt mkinitcpio -P

arch-chroot /mnt bootctl install
cat >/mnt/boot/loader/loader.conf <<EOF
default   arch.conf
timeout   0
console-mode max
editor    yes
EOF
cat >/mnt/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-$TARGET_KERNEL
initrd  /intel-ucode.img
initrd  /initramfs-$TARGET_KERNEL.img
options root=LABEL=arch_os rw
EOF
cat >/mnt/boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-$TARGET_KERNEL
initrd  /intel-ucode.img
initrd  /initramfs-$TARGET_KERNEL-fallback.img
options root=LABEL=arch_os rw
EOF

arch-chroot /mnt useradd -m -G wheel -s "$(which "$SHELL_PACKAGE")" "$TARGET_USER"
arch-chroot /mnt passwd "$TARGET_USER"
