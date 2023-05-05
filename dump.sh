DEST=$(dirname "$(readlink -f "$0")")

usage() {
	echo "Usage: $0 <arch|macos>"
}

case "$1" in
arch)
	systemctl list-unit-files -q --state=enabled | rg 'disabled$' | cut -d' ' -f 1 >"$DEST/systemd.txt"
	paru -Qqe >"$DEST/pacman.txt"
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
