#!/usr/bin/env bash

set -euo pipefail

DEST=$(dirname "$(readlink -f "$0")")

# Install paru
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru.git "$DEST/paru"
cd "$DEST/paru" && makepkg -si

# Install packages with paru
paru -S --needed - <"$DEST/pacman.txt"

# Copy etc files
for file in "$DEST/etc"/*; do
	sudo cp -riv "$file" /etc
done

# Enable systemd services
while read -r service; do
	sudo systemctl enable --now "$service"
done <"$DEST/systemd.txt"
