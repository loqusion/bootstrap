#!/usr/bin/env bash

set -euo pipefail

declare -A DEFAULTS=(
	[XDG_CONFIG_HOME]="$HOME/.config"
)
declare -A XDG_MAP=(
	[xdg_config]="XDG_CONFIG_HOME"
)

BOOTSTRAP_DIR=$(dirname "$(readlink -f "$0")")
HOSTNAME=$(cat /etc/hostname)
PROFILE_DIR="$BOOTSTRAP_DIR/profiles/$HOSTNAME"

# Request credentials so that sudo doesn't prompt later
sudo -v

PARU_DIR=$(mktemp -d)
finish() { rm -rf "$PARU_DIR"; }
trap finish EXIT

# Install paru
if ! command -v paru &>/dev/null; then
	sudo pacman -S --needed base-devel rustup
	rustup default stable
	git clone https://aur.archlinux.org/paru.git "$PARU_DIR"
	(cd "$PARU_DIR" && makepkg -si)
fi

# Install system config files
find "$PROFILE_DIR" -type f -not -path "*.orig" -not -regex ".*/xdg_.*" -print0 |
	while IFS= read -r -d '' file; do
		rel=$(realpath --relative-to="$PROFILE_DIR" "$file")
		dest="/$rel"
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
			sudo cp -fvu "$file" "$dest"
		fi
	done

# Install XDG files
find "$PROFILE_DIR" -type f -regex ".*\/xdg_.*" -print0 |
	while IFS= read -r -d '' file; do
		rel=$(realpath --relative-to="$PROFILE_DIR" "$file")
		xdg_name=$(cut -d'/' -f1 <<<"$rel")
		xdg_var="${XDG_MAP[$xdg_name]}"
		if [ -z "${!xdg_var:-}" ]; then
			declare "$xdg_var"="${DEFAULTS[$xdg_var]}"
		fi
		xdg_dir="${!xdg_var%/}"
		dest="$xdg_dir/${rel#*/}"
		ln -sfv "$file" "$dest"
	done

# Install packages with paru
paru -S --needed - <"$PROFILE_DIR/pacman.txt"

# Enable systemd services
while read -r service; do
	sudo systemctl enable --now "$service"
done <"$PROFILE_DIR/systemd.txt"
