#!/usr/bin/env bash

set -euo pipefail

DEST=${DEST:-"$HOME/.local/share/bootstrap"}
if [ ! -d "$DEST/.git" ]; then
	[ -e "$DEST" ] && rm -rfiv "$DEST"
	mkdir -p "$DEST"
	git clone "https://github.com/loqusion/bootstrap.git" "$DEST"
else
	git -C "$DEST" fetch && git -C "$DEST" reset FETCH_HEAD
fi
cd "$DEST"

./scripts/dotfiles.sh

PLATFORM=$(./scripts/detect-platform.sh)
if [ "$PLATFORM" = "arch" ]; then
	./scripts/platforms/arch.sh
elif [ "$PLATFORM" = "macos" ]; then
	./scripts/platforms/macos.sh
fi

./scripts/misc.sh

if [ -x "$DEST/postinstall.sh" ]; then
	"$DEST/postinstall.sh"
fi
