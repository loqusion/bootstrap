#!/usr/bin/env bash

DEST=${DEST:-"$HOME/.local/share/dotfiles/"}

config() {
	/usr/bin/git --git-dir="$DEST" --work-tree="$HOME" "$@"
}

xdg-open https://www.dashlane.com/download
gh auth login --git-protocol ssh --web

config remote set-url origin git@github.com:loqusion/dotfiles.git
