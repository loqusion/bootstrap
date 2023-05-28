#!/usr/bin/env bash

DIR=$(dirname "$(readlink -f "$0")")
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

dump_patch() {
	src="$1"
	orig="$file"
	patch="${file%.orig}.patch"
	diff -ut "$orig" "$src" | sed -E "/^[+-]{3}/d" >"$patch"
}

dump_arch() {
	HOSTNAME=$(cat /etc/hostname)
	PROFILE_DIR="$DIR/profiles/$HOSTNAME"

	systemctl list-unit-files -q --state=enabled | rg 'disabled$' | rg -v '^[^\s]+\.socket' | cut -d' ' -f 1 >"$PROFILE_DIR/systemd.txt"
	systemctl --user list-unit-files -q --state=enabled | rg -v '^[^\s]+\.socket' | cut -d' ' -f 1 >"$PROFILE_DIR/systemd.user.txt"

	PKGS=$(paru -Qqe)
	if [ -e "$PROFILE_DIR/pacman.optional.txt" ]; then
		PKGS=$(grep -Fvx -f "$PROFILE_DIR/pacman.optional.txt" <<<"$PKGS")
	fi
	echo "$PKGS" >"$PROFILE_DIR/pacman.txt"

	# TODO: generate -paths from array
	find "$PROFILE_DIR" -type f \( -path "$PROFILE_DIR/boot/*" -o -path "$PROFILE_DIR/etc/*" -o -path "$PROFILE_DIR/usr/*" \) -print0 |
		while IFS= read -r -d '' file; do
			rel=$(realpath --relative-to="$PROFILE_DIR" "$file")
			src="/$rel"
			if [[ "$file" =~ \.patch$ ]]; then
				if [ ! -e "${file%.patch}.orig" ]; then
					echo "Missing original file for $file, try executing the following:" >&2
					echo "  cp $src ${file%.patch}.orig"
				fi
			elif [[ "$file" =~ \.orig$ ]]; then
				dump_patch "${src%.orig}"
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

cd "$DIR" || exit 1

PLATFORM=$(./scripts/detect-platform.sh)
if [ "$PLATFORM" = "arch" ]; then
	dump_arch
elif [ "$PLATFORM" = "macos" ]; then
	dump_macos
else
	echo "Unsupported OS: $OS" >&2
	exit 1
fi

echo "Done!" >&2
