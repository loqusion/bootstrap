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
				sudo cp -fvuP "$file" "$dest"
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

install_dconf() {
	local SRC_DIR="$DIR/profiles/$1"
	if [ -e "$SRC_DIR/dconf-settings.ini" ]; then
		dconf load / <"$SRC_DIR/dconf-settings.ini"
	fi
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

install_system "_common/arch"
install_system "$HOSTNAME"

install_xdg "$HOSTNAME"

SKIP_PACKAGES=${SKIP_PACKAGES:-}

# Install packages with paru
SKIP_PARU=${SKIP_PARU:-${SKIP_PACMAN:-${SKIP_PACKAGES}}}
if [ "$SKIP_PARU" != "1" ]; then
	paru -Sy --needed - <"$PROFILE_DIR/pacman.txt"
fi

# Install nix (Determinate Nix Installer)
SKIP_NIX=${SKIP_NIX:-${SKIP_PACKAGES}}
if [ "$SKIP_NIX" != "1" ] && ! nix-env --version &>/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi

# Install pipx packages
SKIP_PIPX=${SKIP_PIPX:-${SKIP_PACKAGES}}
if [ "$SKIP_PIPX" != "1" ] && [ -f "$PROFILE_DIR/pipx.txt" ]; then
	cut -d' ' -f1 "$PROFILE_DIR/pipx.txt" | xargs -I{} pipx install --force {} || true
fi

# Enable systemd services
while read -r service; do
	sudo systemctl enable --now "$service"
done <"$PROFILE_DIR/systemd.txt"
while read -r service; do
	systemctl --user enable --now "$service"
done <"$PROFILE_DIR/systemd.user.txt"

# Restore dconf settings
install_dconf "$HOSTNAME"

postinstall "_common/arch"
postinstall "$HOSTNAME"
