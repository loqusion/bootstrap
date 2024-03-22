#!/usr/bin/env bash

set -euo pipefail

DIR=$(realpath "$(dirname "$(readlink -f "$0")")/..")
DOTFILES=${DOTFILES:-"$HOME/.local/share/dotfiles/"}

cd "$DIR"

config() {
	/usr/bin/git --git-dir="$DOTFILES" --work-tree="$HOME" "$@"
}

mkdir -p "$DOTFILES"
if [ ! -e "$DOTFILES/HEAD" ]; then
	[ -e "$DOTFILES" ] && rm -rfIv "$DOTFILES"
	git clone --bare https://github.com/loqusion/dotfiles.git "$DOTFILES"
fi

config checkout --force &>/dev/null
config submodule update --init
config config --local status.showUntrackedFiles no
config config --local branch.main.remote origin
config config --local branch.main.merge refs/heads/main

./scripts/sparse-checkout.sh
