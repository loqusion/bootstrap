#!/usr/bin/env bash

set -euo pipefail

DIR=$(realpath "$(dirname "$(readlink -f "$0")")/..")
HOSTNAME=$(cat /etc/hostname)
DOTFILES=${DOTFILES:-"$HOME/.local/share/dotfiles/"}
FORCE=${FORCE:-false}
confirmed=false

config() {
	/usr/bin/git --git-dir="$DOTFILES" --work-tree="$HOME" "$@"
}

sparse_checkout() {
	local DOTIGNORE="$1"

	if [ -e "$DOTIGNORE" ]; then
		files=$(cat "$DOTIGNORE")
		for file in $files; do
			[ ! -e "$HOME/$file" ] && continue
			if [ "$FORCE" != true ] && [ "$confirmed" != true ]; then
				read -p "WARNING: This is a potentially destructive operation. Continue? [y/N]" -r REPLY
				[[ $REPLY =~ ^[Yy]$ ]] || exit 1
				confirmed=true
			fi
			rm -rfv "$HOME/.config/${file:?}"
		done
		echo "$files" | sed -e 's/^/!.config\//' -e $'1i\\\n/*' -e $'1i\\\n!README.md' | config sparse-checkout set --stdin --no-cone
	fi
}

PLATFORM=$("$DIR"/scripts/detect-platform.sh)
sparse_checkout "$DIR/profiles/__common__/$PLATFORM/dotignore.txt"
sparse_checkout "$DIR/profiles/$HOSTNAME/dotignore.txt"
