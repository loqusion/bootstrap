#!/usr/bin/env bash

DEST=$(dirname "$(readlink -f "$0")")

usage() {
	echo "Usage: $0 <arch|macos>"
}

case "$1" in
arch)
	HOSTNAME=$(cat /etc/hostname)
	PROFILE_DIR="$DEST/profiles/$HOSTNAME"
	systemctl list-unit-files -q --state=enabled | rg 'disabled$' | cut -d' ' -f 1 >"$DEST/systemd.txt"
	paru -Qqe >"$DEST/pacman.txt"
	find "$PROFILE_DIR" -type f -not -path "*.orig" -not -regex ".*/xdg_.*" -print0 |
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
	brew bundle dump -f --file "$DEST/Brewfile"
	;;
*)
	usage
	exit 1
	;;
esac

echo "Done!" >&2
