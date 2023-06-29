#!/usr/bin/env bash

set -euo pipefail

declare -A XDG_DEFAULTS=(
	[XDG_CONFIG_HOME]="$HOME/.config"
)
declare -A XDG_MAP=(
	[xdg_config]="XDG_CONFIG_HOME"
)

DIR=$(realpath "$(dirname "$(readlink -f "$0")")/../..")
HOSTNAME=$(cat /etc/hostname)
PROFILE_DIR="$DIR/profiles/$HOSTNAME"

cd "$DIR" || exit 1

install_system() {
	SRC_DIR="$DIR/profiles/$1"
	find "$SRC_DIR" -type f \( -path "$SRC_DIR/boot/*" -o -path "$SRC_DIR/etc/*" -o -path "$SRC_DIR/usr/*" \) -not -path "*.orig" -print0 |
		while IFS= read -r -d '' file; do
			rel=$(realpath --relative-to="$SRC_DIR" "$file")
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
				sudo mkdir -pv "$(dirname "$dest")"
				sudo cp -fvu "$file" "$dest"
			fi
		done
}

install_xdg() {
	SRC_DIR="$DIR/profiles/$1"
	find "$SRC_DIR" -type f -regex ".*\/xdg_.*" -print0 |
		while IFS= read -r -d '' file; do
			rel=$(realpath --relative-to="$SRC_DIR" "$file")
			xdg_name=$(cut -d'/' -f1 <<<"$rel")
			xdg_var="${XDG_MAP[$xdg_name]}"
			if [ -z "${!xdg_var:-}" ]; then
				declare "$xdg_var"="${XDG_DEFAULTS[$xdg_var]}"
			fi
			xdg_dir="${!xdg_var%/}"
			dest="$xdg_dir/${rel#*/}"
			mkdir -pv "$(dirname "$dest")"
			ln -sfv "$file" "$dest"
		done
}

postinstall() {
	SRC_DIR="$DIR/profiles/$1"
	[ -x "$SRC_DIR/postinstall.sh" ] && "$SRC_DIR/postinstall.sh"
}

# Request credentials so that sudo doesn't prompt later
sudo -v

PARU_DIR=$(mktemp -d)
finish() { rm -rf "$PARU_DIR"; }
trap finish EXIT

# Install paru
if ! command -v paru &>/dev/null; then
	sudo pacman -S --noconfirm --needed base-devel rustup
	rustup default stable
	git clone https://aur.archlinux.org/paru.git "$PARU_DIR"
	(cd "$PARU_DIR" && makepkg -si)
fi

install_system "__common__/arch"
install_system "$HOSTNAME"

install_xdg "$HOSTNAME"

# Install packages with paru
paru -Sy --needed - <"$PROFILE_DIR/pacman.txt" || true

# Enable systemd services
while read -r service; do
	sudo systemctl enable --now "$service"
done <"$PROFILE_DIR/systemd.txt"
while read -r service; do
	systemctl --user enable --now "$service"
done <"$PROFILE_DIR/systemd.user.txt"

postinstall "__common/arch"
postinstall "$HOSTNAME"
