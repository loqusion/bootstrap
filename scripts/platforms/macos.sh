#!/usr/bin/env bash

set -euo pipefail

DIR=$(realpath "$(dirname "$(readlink -f "$0")")/../..")
HOSTNAME=$(hostname -s)
PROFILE_DIR="$DIR/profiles/$HOSTNAME"

cd "$DIR" || exit 1

# Install Homebrew
command -v brew &>/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Xcode Command Line Tools
touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
softwareupdate -i -a
rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

# Install Homebrew packages
brew bundle --no-lock --file="$PROFILE_DIR/Brewfile"

# Install pipx packages
if [ -f "$PROFILE_DIR/pipx.txt" ]; then
	cut -d' ' -f1 "$PROFILE_DIR/pipx.txt" | xargs -I{} pipx install --force {} || true
fi
