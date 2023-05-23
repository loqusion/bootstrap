#!/usr/bin/env bash

set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
DOTFILES=${DOTFILES:-"$HOME/.local/share/dotfiles/"}
PARENT=$(dirname "$DOTFILES")

config() {
	/usr/bin/git --git-dir="$DOTFILES" --work-tree="$HOME" "$@"
}

mkdir -p "$PARENT"
if [ ! -e "$DOTFILES/HEAD" ]; then
	rm -rfI "$DOTFILES"
	git clone --bare https://github.com/loqusion/dotfiles "$DOTFILES"
else
	read -r -p "Pull newest changes from loqusion/dotfiles? (y/N)" yes
	[[ "$yes" =~ "y" ]] && config pull
fi

"$DIR/sparse-checkout.sh"

config checkout
config submodule update --init --remote
config config --local status.showUntrackedFiles no
config config --local branch.main.remote origin
config config --local branch.main.merge refs/heads/main
