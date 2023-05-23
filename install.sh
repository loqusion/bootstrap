#!/usr/bin/env bash

set -euo pipefail

load_lsb() {
	INFO_ROOT="/etc"
	INFO_FILES=("lsb-release" "os-release")
	loaded=1
	for file in "${INFO_FILES[@]}"; do
		if [ -f "$INFO_ROOT/$file" ]; then
			# shellcheck disable=SC1090
			. "$INFO_ROOT/$file"
			loaded=0
		fi
	done
	return $loaded
} >/dev/null

distro() {
	if ! load_lsb; then
		read -r -p "Failed to load Linux info -- assume Arch? [y/N] " reply
		if [[ ! "$reply" =~ ^[Yy]$ ]]; then
			return 1
		fi
		ID="arch"
	fi
	echo "${DISTRIB_ID:-${ID:-}}" | tr '[:upper:]' '[:lower:]'
}

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

DEST=${DEST:-"$HOME/.local/share/bootstrap"}
if [ ! -d "$DEST/.git" ]; then
	[ -e "$DEST" ] && rm -rfiv "$DEST"
	mkdir -p "$DEST"
	git clone "https://github.com/loqusion/bootstrap.git" "$DEST"
else
	git -C "$DEST" fetch && git -C "$DEST" reset --hard FETCH_HEAD
fi
cd "$DEST"

./dotfiles.sh

if [ "$OS" = "linux" ]; then
	DISTRO=$(distro)
	if [ "$DISTRO" = "arch" ]; then
		./arch.sh
	else
		echo "Unsupported distro: $DISTRO" >&2
		exit 1
	fi
elif [ "$OS" = "darwin" ]; then
	./macos.sh
fi
