#!/usr/bin/env bash

set -euo pipefail

TARGET_DISK=${TARGET_DISK:-${1:-}}
HOSTNAME=${HOSTNAME:-}
USER=${USER:-loqusion}
KERNEL=${KERNEL:-linux}
FILESYSTEM=${FILESYSTEM:-btrfs}
FORCE=${FORCE:-false}

EDITOR_PACKAGE=${EDITOR_PACKAGE:-neovim}
SHELL_PACKAGE=${SHELL_PACKAGE:-fish}
ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES:-}

if ! [ -d /sys/firmware/efi/efivars ]; then
	echo "ERROR: UEFI is not enabled. This script is only for UEFI systems."
	exit 1
fi

case "$KERNEL" in
linux | linux-lts | linux-zen) KERNEL_HEADERS="$KERNEL-headers" ;;
*)
	echo "ERROR: Unsupported kernel: $KERNEL"
	exit 1
	;;
esac
case "$FILESYSTEM" in
ext4 | btrfs) ;;
*)
	echo "ERROR: Unsupported filesystem: $FILESYSTEM"
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

if [ -z "$HOSTNAME" ]; then
	read -p "Enter a hostname: " -r HOSTNAME
	[ -z "$HOSTNAME" ] && echo "ERROR: Hostname cannot be empty." && exit 1
fi

if [ "$FORCE" != true ] && [ "$FORCE" != "1" ]; then
	echo "WARNING: This script will destroy all data on $TARGET_DISK."
	read -p "Continue? [y/N] " -r REPLY
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
case "$FILESYSTEM" in
btrfs)
	mkfs.btrfs -L arch_os "$ROOT_PARTITION"
	;;
ext4)
	mkfs.ext4 -L arch_os "$ROOT_PARTITION"
	;;
*)
	echo "ERROR: Unsupported filesystem: $FILESYSTEM"
	exit 1
	;;
esac

echo "Exiting..."
exit

mount "$ROOT_PARTITION" /mnt
mount --mkdir "BOOT_PARTITION" /mnt/boot
swapon "$SWAP_PARTITION"

# shellcheck disable=SC2086
pacstrap -K /mnt base base-devel alsa-utils "$KERNEL" "$KERNEL_HEADERS" linux-firmware intel-ucode iwd dhcpcd man-db man-pages texinfo "$SHELL_PACKAGE" "$EDITOR_PACKAGE" $ADDITIONAL_PACKAGES

genfstab -U /mnt >>/mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
arch-chroot /mnt hwclock --systohc

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf

echo "$HOSTNAME" >/mnt/etc/hostname

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
linux   /vmlinuz-$KERNEL
initrd  /intel-ucode.img
initrd  /initramfs-$KERNEL.img
options root=LABEL=arch_os rw
EOF
cat >/mnt/boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-$KERNEL
initrd  /intel-ucode.img
initrd  /initramfs-$KERNEL-fallback.img
options root=LABEL=arch_os rw
EOF

arch-chroot /mnt useradd -m -G wheel -s "$(which "$SHELL_PACKAGE")" "$USER"
arch-chroot /mnt passwd "$USER"
