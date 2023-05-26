#!/usr/bin/env bash

exists() {
	command -v "$@"
} &>/dev/null

exists bat && bat cache --build
exists tldr && command tldr --update
[ -e ~/.config/catppuccin/obs/install.sh ] && bash <~/.config/catppuccin/obs/install.sh
[ -e ~/.config/catppuccin/steam/install.sh ] && bash <~/.config/catppuccin/steam/install.sh
