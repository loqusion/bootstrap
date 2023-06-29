#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DEPENDENCIES=(gum reflector)
SUPPORTED_KERNELS=(linux linux-lts linux-zen)
SUPPORTED_FILESYSTEMS=(ext4 btrfs)
declare -A FS_UTILS_PACKAGES=(
	[ext4]="e2fsprogs"
	[btrfs]="btrfs-progs"
)

# shellcheck disable=SC2034
COLOR_INFO="#89dceb"
# shellcheck disable=SC2034
COLOR_WARNING="#f9e2af"
# shellcheck disable=SC2034
COLOR_ERROR="#f38ba8"

TARGET_DISK=${TARGET_DISK:-${1:-}}
TARGET_HOSTNAME=${TARGET_HOSTNAME:-}
TARGET_USER=${TARGET_USER:-}
TARGET_KERNEL=${TARGET_KERNEL:-}
TARGET_FILESYSTEM=${TARGET_FILESYSTEM:-}
FORCE=${FORCE:-0}
DRY_RUN=${DRY_RUN:-0}
DEBUG=${DEBUG:-0}

EDITOR_PACKAGE=${EDITOR_PACKAGE:-neovim}
SHELL_PACKAGE=${SHELL_PACKAGE:-fish}
FS_UTILS_PACKAGE=
ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES:-}

feedback() {
	level=$1 && shift
	var="COLOR_${level^^}"
	color=${!var:-}
	echo "$(gum style --foreground="$color" "$level:")" "$@"
} >&2

die() {
	feedback ERROR "$@"
	if [ "$DEBUG" = true ] || [ "$DEBUG" = "1" ]; then
		echo
		echo "Debug information:"
		echo "=================="
		echo
		echo "FUNCNAME: ${FUNCNAME[*]}"
		echo "BASH_LINENO: ${BASH_LINENO[*]}"
	else
		echo
		echo "Run with DEBUG=1 for more information."
	fi
	exit 1
} >&2

contains() {
	declare word
	declare -n array="$1"
	for word in "${array[@]}"; do
		[ "$word" = "$2" ] && return 0
	done
	return 1
}

invariant_one() {
	declare result=
	while read -r line; do
		[ -n "$result" ] && die "Invariant violated: multiple results found."
		result=$line
	done
	[ -z "$result" ] && die "Invariant violated: no results found."
	echo "$result"
}

confirm() {
	gum confirm "$@"
}

input() {
	prompt=$1 && shift
	gum input --prompt="$prompt" "$@"
}

input_password() {
	gum input --prompt="$prompt" --password "$@"
}

choose() {
	header=$1 && shift
	gum choose --header="$header" "$@"
}

spin() {
	title=$1 && shift

	if command -v gum &>/dev/null; then
		gum spin --title="$title" -- "$@"
		return
	fi

	echo -n "$title"
	"$@" &>/dev/null && echo
}

if [ "$DRY_RUN" = true ] || [ "$DRY_RUN" = "1" ]; then
	feedback INFO "Dry run mode enabled."
fi
if [ "$(id -u)" -ne 0 ]; then
	feedback ERROR "This script must be run as root."
	exit 1
fi
if ! [ -d /sys/firmware/efi/efivars ]; then
	feedback ERROR "UEFI is not enabled. This script is only for UEFI systems."
	exit 1
fi
if [ -z "$TARGET_DISK" ]; then
	feedback ERROR "No target disk specified. Specify a block device as an argument to this script (or with TARGET_DISK)."
	exit 1
elif ! [ -b "$TARGET_DISK" ]; then
	feedback ERROR "'$TARGET_DISK' is not a block device. Try listing block devices with \`lsblk\`."
	exit 1
fi

spin "Installing dependencies..." pacman -Sy --noconfirm --needed "${SCRIPT_DEPENDENCIES[@]}"

if ! contains SUPPORTED_KERNELS "$TARGET_KERNEL"; then
	TARGET_KERNEL=$(choose "Choose kernel" "${SUPPORTED_KERNELS[@]}")
fi
KERNEL_HEADERS="$TARGET_KERNEL-headers"
echo "Using kernel: $TARGET_KERNEL"

if ! contains SUPPORTED_FILESYSTEMS "$TARGET_FILESYSTEM"; then
	TARGET_FILESYSTEM=$(choose "Choose filesystem" "${SUPPORTED_FILESYSTEMS[@]}")
fi
FS_UTILS_PACKAGE="${FS_UTILS_PACKAGES[$TARGET_FILESYSTEM]}"
echo "Using filesystem: $TARGET_FILESYSTEM"

if [ -z "$TARGET_HOSTNAME" ]; then
	TARGET_HOSTNAME=$(input "Hostname: ")
	[ -z "$TARGET_HOSTNAME" ] && {
		feedback ERROR "Hostname cannot be empty."
		exit 1
	}
fi
echo "Using hostname: $TARGET_HOSTNAME"

if [ -z "$TARGET_USER" ]; then
	TARGET_USER=$(input "Username: " --value=loqusion)
	[ -z "$TARGET_USER" ] && {
		feedback ERROR "Username cannot be empty."
		exit 1
	}
fi
echo "Using username: $TARGET_USER"

if [ "$DRY_RUN" = true ] || [ "$DRY_RUN" = "1" ]; then
	echo
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
	echo
	echo "Dry run mode enabled. Exiting."
	exit 0
fi

if [ "$FORCE" != true ] && [ "$FORCE" != "1" ]; then
	confirm "WARNING: This script will destroy all data on $TARGET_DISK. Continue?" || exit 1
fi

echo

sgdisk "$TARGET_DISK" -og
sgdisk "$TARGET_DISK" -n=1:0:+512M -t=1:ef00 -c=1:"EFI system partition"
sgdisk "$TARGET_DISK" -n=2:0:+4096M -t=2:8200 -c=2:"Linux swap"
sgdisk "$TARGET_DISK" -n=3:0:0 -t=3:830 -c=3:"Linux filesystem"
sgdisk "$TARGET_DISK" -p

BOOT_PARTITION=$(blkid -t PARTLABEL="EFI system partition" -o device | grep -F "$TARGET_DISK" | invariant_one)
SWAP_PARTITION=$(blkid -t PARTLABEL="Linux swap" -o device | grep -F "$TARGET_DISK" | invariant_one)
ROOT_PARTITION=$(blkid -t PARTLABEL="Linux filesystem" -o device | grep -F "$TARGET_DISK" | invariant_one)
mkfs.fat -F 32 -n EFI "$BOOT_PARTITION"
mkswap -L swap "$SWAP_PARTITION"
case "$TARGET_FILESYSTEM" in
btrfs)
	mkfs.btrfs -f -L arch_os "$ROOT_PARTITION"
	mount "$ROOT_PARTITION" /mnt
	btrfs subvolume create /mnt/@
	btrfs subvolume set-default /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@var_log
	umount /mnt

	mount -o subvol=@ "$ROOT_PARTITION" /mnt
	mount -m -o subvol=@home "$ROOT_PARTITION" /mnt/home
	mount -m -o subvol=@var_log "$ROOT_PARTITION" /mnt/var/log
	mount -m "$BOOT_PARTITION" /mnt/boot
	swapon "$SWAP_PARTITION"
	;;
ext4)
	mkfs.ext4 -L arch_os "$ROOT_PARTITION"

	mount "$ROOT_PARTITION" /mnt
	mount -m "BOOT_PARTITION" /mnt/boot
	swapon "$SWAP_PARTITION"
	;;
*)
	echo "ERROR: Unsupported filesystem: $TARGET_FILESYSTEM"
	exit 1
	;;
esac

systemctl restart reflector.service

# shellcheck disable=SC2086
pacstrap -K /mnt \
	base base-devel alsa-utils \
	"$TARGET_KERNEL" "$KERNEL_HEADERS" linux-firmware intel-ucode \
	iwd dhcpcd openssh \
	man-db man-pages texinfo \
	git github-cli \
	"$SHELL_PACKAGE" \
	"$EDITOR_PACKAGE" \
	"$FS_UTILS_PACKAGE" \
	$ADDITIONAL_PACKAGES

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

arch-chroot /mnt useradd -m -G wheel -s "/usr/bin/$SHELL_PACKAGE" "$TARGET_USER"
arch-chroot /mnt passwd "$TARGET_USER"
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

umount -R /mnt
swapoff "$SWAP_PARTITION"

echo "Done! You can now reboot into your new Arch Linux installation."
