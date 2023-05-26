#!/usr/bin/env bash

DIR=$(dirname "$(readlink -f "$0")")
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

dump_arch() {
	HOSTNAME=$(cat /etc/hostname)
	PROFILE_DIR="$DIR/profiles/$HOSTNAME"
	systemctl list-unit-files -q --state=enabled | rg 'disabled$' | rg -v '^[^\s]+\.socket' | cut -d' ' -f 1 >"$PROFILE_DIR/systemd.txt"
	systemctl --user list-unit-files -q --state=enabled | rg -v '^[^\s]+\.socket' | cut -d' ' -f 1 >"$PROFILE_DIR/systemd.user.txt"
	PKGS=$(paru -Qqe)
	if [ -e "$PROFILE_DIR/pacman-optional.txt" ]; then
		PKGS=$(grep -Fvx -f "$PROFILE_DIR/pacman-optional.txt" <<<"$PKGS")
	fi
	echo "$PKGS" >"$PROFILE_DIR/pacman.txt"
	find "$PROFILE_DIR" -type f \( -path "$PROFILE_DIR/etc/*" -o -path "$PROFILE_DIR/boot/*" \) -not -path "*.orig" -print0 |
		while IFS= read -r -d '' file; do
			rel=$(realpath --relative-to="$PROFILE_DIR" "$file")
			src="/$rel"
			if [[ "$file" =~ \.patch$ ]]; then
				src="${src%.patch}"
				orig="${file%.patch}.orig"
				diff -ut "$orig" "$src" | sed -E "/^[+-]{3}/d" >"$file"
			else
				cp -fvu "$src" "$file"
			fi
		done
}

dump_macos() {
	HOSTNAME=$(hostname -s)
	PROFILE_DIR="$DIR/profiles/$HOSTNAME"
	brew bundle dump -f --file "$PROFILE_DIR/Brewfile"
}

if [ "$OS" = "linux" ]; then
	DISTRO=$("$DIR/scripts/distro.sh")
	if [ "$DISTRO" = "arch" ]; then
		dump_arch
	else
		echo "Unsupported distro: $DISTRO" >&2
		exit 1
	fi
elif [ "$OS" = "darwin" ]; then
	dump_macos
else
	echo "Unsupported OS: $OS" >&2
	exit 1
fi

echo "Done!" >&2
