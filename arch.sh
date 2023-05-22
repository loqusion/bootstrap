#!/usr/bin/env bash

set -euo pipefail

DEST=$(dirname "$(readlink -f "$0")")
HOSTNAME=$(cat /etc/hostname)
ETC_DIR="$DEST/profiles/$HOSTNAME/etc"

# Request credentials so that sudo doesn't prompt later
sudo -v

# Install paru
if ! command -v paru &>/dev/null; then
	sudo pacman -S --needed base-devel rustup
	rustup default stable
	git clone https://aur.archlinux.org/paru.git "$DEST/paru"
	cd "$DEST/paru" && makepkg -si && cd "$DEST" && rm -rf "$DEST/paru"
fi

find "$ETC_DIR" -type f -not -path "*.orig" -print0 |
	while IFS= read -r -d '' file; do
		rel=$(realpath --relative-to="$ETC_DIR" "$file")
		dest="/etc/$rel"
		if [[ "$file" =~ \.patch$ ]]; then
			dest="${dest%.patch}"
			orig="${file%.patch}.orig"
			if [ ! -e "$dest" ]; then
				sudo mkdir -pv "$(dirname "$dest")"
				sudo cp -fv "$orig" "$dest"
			fi
			# Check if the patch has already been applied, and if not, apply it.
			if ! sudo patch -R -p0 -f --dry-run "$dest" "$file" &>/dev/null; then
				sudo patch "$dest" "$file"
			fi
		else
			echo sudo cp -fvu "$file" "$dest"
		fi
	done

# Install packages with paru
paru -S --needed - <"$DEST/pacman.txt"

# Enable systemd services
while read -r service; do
	sudo systemctl enable --now "$service"
done <"$DEST/systemd.txt"
