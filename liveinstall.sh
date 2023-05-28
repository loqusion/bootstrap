#!/usr/bin/env bash

set -euo pipefail

TARGET_DISK=${TARGET_DISK:-${1:-}}
HOSTNAME=${HOSTNAME:-arch}
KERNEL=${KERNEL:-linux}
FILESYSTEM=${FILESYSTEM:-btrfs}
ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES:-}
FORCE=${FORCE:-false}

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

if [ -z "$TARGET_DISK" ]; then
	echo -e "ERROR: No target disk specified.\nSpecify a block device with TARGET_DISK or as an argument to this script."
	exit 1
elif ! [ -b "$TARGET_DISK" ]; then
	echo "ERROR: $TARGET_DISK is not a block device."
	exit 1
fi

if [ "$FORCE" != true ]; then
	echo "WARNING: This script will destroy all data on $TARGET_DISK."
	read -p "Continue? [y/N] " -r REPLY
	if ! [[ $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi
parted -sf "$TARGET_DISK" mklabel gpt
parted -sf "$TARGET_DISK" mkpart "EFI system partition" fat32 1MiB 513MiB
parted -sf "$TARGET_DISK" set 1 esp on
parted -sf "$TARGET_DISK" mkpart "swap partition" linux-swap 513MiB 4609MiB
parted -sf "$TARGET_DISK" mkpart "root partition" "$FILESYSTEM" 4609MiB 100%

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

mount "$ROOT_PARTITION" /mnt
mount --mkdir "BOOT_PARTITION" /mnt/boot
swapon "$SWAP_PARTITION"

# shellcheck disable=SC2086
pacstrap -K /mnt base base-devel alsa-utils "$KERNEL" "$KERNEL_HEADERS" linux-firmware iwd dhcpcd neovim man-db man-pages texinfo $ADDITIONAL_PACKAGES

genfstab -U /mnt >>/mnt/etc/fstab

# FIXME: This doesn't actually execute all the commands in the chroot
arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

echo "$HOSTNAME" >/etc/hostname

mkinitcpio -P

# TODO: Create user
