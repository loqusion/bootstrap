#!/usr/bin/env bash

set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
DEST=${DEST:-"$HOME/.local/share/dotfiles/"}
PARENT=$(dirname "$DEST")
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [ ! -d "$PARENT" ]; then
	mkdir -p "$PARENT"
elif [ -e "$DEST" ]; then
	echo "'$DEST' already exists" >&2
	exit 1
fi

config() {
	/usr/bin/git --git-dir="$DEST" --work-tree="$HOME" "$@"
}

git clone --bare git@github.com:loqusion/dotfiles.git "$DEST"

SPARSE="$DIR/sparse-checkout/$OS.txt"
if [ -e "$SPARSE" ]; then
	config sparse-checkout set --stdin <"$SPARSE"
fi

config checkout
config config --local status.showUntrackedFiles no
config config --local branch.main.remote origin
config config --local branch.main.merge refs/heads/main
