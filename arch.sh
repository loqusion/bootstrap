#!/usr/bin/env bash

set -euo pipefail

DEST=$(dirname "$(readlink -f "$0")")

# Install paru
if ! command -v paru &>/dev/null; then
	sudo pacman -S --needed base-devel rustup
	rustup default stable
	git clone https://aur.archlinux.org/paru.git "$DEST/paru"
	cd "$DEST/paru" && makepkg -si && cd "$DEST" && rm -rf "$DEST/paru"
fi

# Copy etc files
for file in "$DEST/etc"/*; do
	sudo cp -riv "$file" /etc
done

# Install packages with paru
paru -S --needed - <"$DEST/pacman.txt"

# Enable systemd services
while read -r service; do
	sudo systemctl enable --now "$service"
done <"$DEST/systemd.txt"
