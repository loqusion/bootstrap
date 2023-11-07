#!/usr/bin/env bash

exists() {
	command -v "$@"
} &>/dev/null

exists bat && bat cache --build
exists tldr && command tldr --update
[ -e ~/.config/catppuccin/obs/install.sh ] && ~/.config/catppuccin/obs/install.sh
# doesn't work anymore; see https://github.com/catppuccin/steam/issues/26
# [ -e ~/.config/catppuccin/steam/install.sh ] && ~/.config/catppuccin/steam/install.sh
