#!/usr/bin/env bash

set -euo pipefail

DIR=$(realpath "$(dirname "$(readlink -f "$0")")/../..")
HOSTNAME=$(hostname -s)
PROFILE_DIR="$DIR/profiles/$HOSTNAME"
DOTBARE_INSTALLATION_DIR="$HOME/.dotbare"

cd "$DIR" || exit 1

# Install Homebrew
if ! command -v brew &>/dev/null; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Xcode Command Line Tools
touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
softwareupdate -i -a
rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

# Install Homebrew packages
brew bundle --no-lock --file="$PROFILE_DIR/Brewfile"

# Install nix (Determinate Nix Installer)
if ! nix-env --version &>/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi

# Install pipx packages
if [ -f "$PROFILE_DIR/pipx.txt" ]; then
	cut -d' ' -f1 "$PROFILE_DIR/pipx.txt" | xargs -I{} pipx install --force {} || true
fi

# Install dotbare
if [ ! -d "$DOTBARE_INSTALLATION_DIR" ]; then
	git clone https://github.com/kazhala/dotbare.git "$DOTBARE_INSTALLATION_DIR"
fi
