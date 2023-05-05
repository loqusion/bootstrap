#!/usr/bin/env bash

set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
DEST=${DEST:-"$HOME/.local/share/dotfiles/"}
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

config() {
	/usr/bin/git --git-dir="$DEST" --work-tree="$HOME" "$@"
}

SPARSE_CHECKOUT_EXCLUDE="$DIR/sparse-checkout-exclude/$OS.txt"
if [ -e "$SPARSE_CHECKOUT_EXCLUDE" ]; then
	sed -e 's/^/!.config\//' -e $'1i\\\n/*' -e $'1i\\\n!README.md' "$SPARSE_CHECKOUT_EXCLUDE" | config sparse-checkout set --stdin --no-cone
fi
