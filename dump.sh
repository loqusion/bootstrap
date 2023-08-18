#!/usr/bin/env bash

DIR=$(dirname "$(readlink -f "$0")")
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

cd "$DIR" || exit 1

git_add() {
	git -C "$DIR" add "$@"
}

_dump_patch() {
	local file src orig patch
	file="$1"
	src="$2"
	orig="$file.orig"
	patch="$file.patch"
	diff -ut "$orig" "$src" | sed -E "/^[+-]{3}/d" >"$patch"
}

_dump_profiles() {
	local rel src
	local DEST_DIR="$DIR/profiles/$1"
	# TODO: generate -paths from array
	find "$DEST_DIR" -type f \( -path "$DEST_DIR/boot/*" -o -path "$DEST_DIR/etc/*" -o -path "$DEST_DIR/usr/*" \) -print0 |
		while IFS= read -r -d '' file; do
			rel=$(realpath --relative-to="$DEST_DIR" "$file")
			src="/$rel"
			if [[ "$file" =~ \.patch$ ]]; then
				if [ ! -e "${file%.patch}.orig" ]; then
					echo "Missing original file for $file, try executing the following:" >&2
					echo "  cp $src ${file%.patch}.orig"
				fi
			elif [[ "$file" =~ \.orig$ ]]; then
				_dump_patch "${file%.orig}" "${src%.orig}"
				git_add "$file" "${file%.orig}.patch"
			else
				cp -fvu "$src" "$file"
				git_add "$file"
			fi
		done
}

_dump_pacman() {
	local DEST_DIR="$1"
	local pkgs

	pkgs=$(paru -Qqe)
	if [ -e "$DEST_DIR/pacman.optional.txt" ]; then
		pkgs=$(grep -Fvx -f "$DEST_DIR/pacman.optional.txt" <<<"$pkgs")
	fi
	echo "$pkgs" >"$DEST_DIR/pacman.txt"
	git_add "$DEST_DIR/pacman.txt"
}

dump_arch() {
	local HOSTNAME
	HOSTNAME=$(cat /etc/hostname)
	local DEST_DIR="$DIR/profiles/$HOSTNAME"

	systemctl list-unit-files -q --state=enabled | rg 'disabled$' | rg -v '^[^\s]+\.socket' | cut -d' ' -f 1 >"$DEST_DIR/systemd.txt"
	git_add "$DEST_DIR/systemd.txt"
	systemctl --user list-unit-files -q --state=enabled | rg -v '^[^\s]+\.socket' | cut -d' ' -f 1 >"$DEST_DIR/systemd.user.txt"
	git_add "$DEST_DIR/systemd.user.txt"

	_dump_pacman "$DEST_DIR"

	_dump_profiles "_common/arch"
	_dump_profiles "$HOSTNAME"
}

_dump_brew() {
	local DEST_DIR="$1"
	brew bundle dump -f --file "$DEST_DIR/Brewfile"
	git_add "$DEST_DIR/Brewfile"
}

dump_macos() {
	local HOSTNAME
	HOSTNAME=$(hostname -s)
	local DEST_DIR="$DIR/profiles/$HOSTNAME"
	_dump_brew "$DEST_DIR"
}

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
