#!/usr/bin/env bash

set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
DOTFILES=${DOTFILES:-"$HOME/.local/share/dotfiles/"}

config() {
	/usr/bin/git --git-dir="$DOTFILES" --work-tree="$HOME" "$@"
}

mkdir -p "$DOTFILES"
if [ ! -e "$DOTFILES/HEAD" ]; then
	rm -rfI "$DOTFILES"
	git clone --bare https://github.com/loqusion/dotfiles.git "$DOTFILES"
else
	read -r -p "Pull newest changes from loqusion/dotfiles? [y/N] " reply
	[[ "$reply" =~ ^[Yy]$ ]] && config pull
fi

"$DIR/sparse-checkout.sh"

config checkout
config submodule update --init --remote
config config --local status.showUntrackedFiles no
config config --local branch.main.remote origin
config config --local branch.main.merge refs/heads/main
