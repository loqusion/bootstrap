#!/usr/bin/env bash

DIR=$(dirname "$(readlink -f "$0")")
DOTFILES=${DOTFILES:-"$HOME/.local/share/dotfiles/"}

config() {
	/usr/bin/git --git-dir="$DOTFILES" --work-tree="$HOME" "$@"
}

echo "GitHub authentication requires a browser, make sure you're running in a graphical environment."

xdg-open https://www.dashlane.com/download
gh auth login --git-protocol ssh --web

config remote set-url origin git@github.com:loqusion/dotfiles.git
git -C "$DIR" remote set-url origin git@github.com:loqusion/bootstrap.git
