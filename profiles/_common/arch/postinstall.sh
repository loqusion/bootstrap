#!/usr/bin/env bash

# Create snapper configs
if lsblk -f -o FSTYPE /dev/nvme0n1p3 | sed -e '/FSTYPE/d' -e '/^$/d' | grep btrfs &>/dev/null; then
	sudo snapper -c root create-config /
fi
