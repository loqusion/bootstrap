#!/usr/bin/env bash

DIR=$(dirname "$(readlink -f "$0")")
DOTFILES=${DOTFILES:-"$HOME/.local/share/dotfiles/"}

config() {
	/usr/bin/git --git-dir="$DOTFILES" --work-tree="$HOME" "$@"
}

xdg-open https://www.dashlane.com/download
gh auth login --git-protocol ssh --web

config remote set-url origin git@github.com:loqusion/dotfiles.git
git -C "$DIR" remote set-url origin git@github.com:loqusion/bootstrap.git
