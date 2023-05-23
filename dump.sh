#!/usr/bin/env bash

BOOTSTRAP_DIR=$(dirname "$(readlink -f "$0")")

usage() {
	echo "Usage: $0 <arch|macos>"
}

case "$1" in
arch)
	HOSTNAME=$(cat /etc/hostname)
	PROFILE_DIR="$BOOTSTRAP_DIR/profiles/$HOSTNAME"
	systemctl list-unit-files -q --state=enabled | rg 'disabled$' | cut -d' ' -f 1 >"$PROFILE_DIR/systemd.txt"
	systemctl --user list-unit-files -q --state=enabled | rg -v '^[^\s]+\.socket' | cut -d' ' -f 1 >"$PROFILE_DIR/systemd.user.txt"
	paru -Qqe >"$PROFILE_DIR/pacman.txt"
	find "$PROFILE_DIR" -type f -path "$PROFILE_DIR/etc/*" -not -path "*.orig" -print0 |
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
	;;
macos)
	HOSTNAME=$(hostname -s)
	PROFILE_DIR="$BOOTSTRAP_DIR/profiles/$HOSTNAME"
	brew bundle dump -f --file "$PROFILE_DIR/Brewfile"
	;;
*)
	usage
	exit 1
	;;
esac

echo "Done!" >&2
