#!/usr/bin/env bash

set -euo pipefail

DIR=$(realpath "$(dirname "$(readlink -f "$0")")/..")
HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname -s)
DOTFILES=${DOTFILES:-"$HOME/.local/share/dotfiles/"}
FORCE=${FORCE:-false}
confirmed=false

cd "$DIR"

config() {
	/usr/bin/git --git-dir="$DOTFILES" --work-tree="$HOME" "$@"
}

_cat() {
	cat "$@" 2>/dev/null || true
}

sparse_checkout() {
	local files="$1"

	for file in $files; do
		{ [ -z "$file" ] || [ ! -e "$HOME/.config/$file" ]; } && continue
		if [ "${SPARSE_CHECKOUT_CONSENT:-}" != true ] && [ "$FORCE" != true ] && [ "$confirmed" != true ]; then
			read -p "WARNING: This is a potentially destructive operation. Continue? [y/N] " -r REPLY
			[[ "$REPLY" =~ ^[Yy]$ ]] || exit 1
			confirmed=true
			echo 'export SPARSE_CHECKOUT_CONSENT=true' >>.consent
		fi
		rm -rfv "$HOME/.config/${file:?}"
	done
	echo "$files" | sed -e '/^[[:space:]]*$/d' -e 's/^/!.config\//' -e $'1i\\\n/*' -e $'1i\\\n!README.md' | config sparse-checkout set --stdin --no-cone
}

PLATFORM=$(./scripts/detect-platform.sh)
files=$(_cat "$DIR/profiles/_common/$PLATFORM/dotignore.txt" "$DIR/profiles/$HOSTNAME/dotignore.txt")
if [ -n "$files" ]; then
	sparse_checkout "$files"
fi
