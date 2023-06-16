#!/usr/bin/env bash

exists() {
	command -v "$@"
} &>/dev/null

exists bat && bat cache --build
exists tldr && command tldr --update
[ -e ~/.config/catppuccin/obs/install.sh ] && ~/.config/catppuccin/obs/install.sh
[ -e ~/.config/catppuccin/steam/install.sh ] && ~/.config/catppuccin/steam/install.sh
