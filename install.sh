#!/usr/bin/env bash

set -euo pipefail

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
	DISTRO=$("$DEST/scripts/distro.sh")
	if [ "$DISTRO" = "arch" ]; then
		./arch.sh
	else
		echo "Unsupported distro: $DISTRO" >&2
		exit 1
	fi
elif [ "$OS" = "darwin" ]; then
	./macos.sh
fi

if [ -x "$DEST/postinstall.sh" ]; then
	"$DEST/postinstall.sh"
fi
