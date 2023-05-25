#!/usr/bin/env bash

set -euo pipefail

PACMAN_CMD=${PACMAN_CMD:-paru}
VM_DIR=${VM_DIR:-"$HOME/.local/share/quickemu/vms"}
VMS=("windows 11" "macos catalina" "archlinux latest")
declare -A ARGS=(
	["windows"]="--display spice"
	["macos"]=""
	["archlinux"]="--display spice"
)
DEPS=("quickemu" "aria2" "qemu-full")

$PACMAN_CMD -S --needed "${DEPS[@]}"

[ ! -d "$VM_DIR" ] && mkdir -pv "$VM_DIR"
cd "$VM_DIR"

for vm in "${VMS[@]}"; do
	OS=$(cut -d' ' -f1 <<<"$vm")
	VERSION=$(cut -d' ' -f2 <<<"$vm")
	if [ ! -f "$OS-$VERSION.conf" ]; then
		quickget "$OS" "$VERSION"
		# shellcheck disable=SC2086
		quickemu --vm "$OS-$VERSION.conf" ${ARGS["$OS"]} --shortcut
	else
		echo "VM $OS-$VERSION already exists -- skipping" >&2
	fi
done
