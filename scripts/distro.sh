#!/usr/bin/env bash

load_lsb() {
	INFO_ROOT="/etc"
	INFO_FILES=("lsb-release" "os-release")
	loaded=1
	for file in "${INFO_FILES[@]}"; do
		if [ -f "$INFO_ROOT/$file" ]; then
			# shellcheck disable=SC1090
			. "$INFO_ROOT/$file"
			loaded=0
		fi
	done
	return $loaded
} >/dev/null

if ! load_lsb; then
	read -r -p "Failed to load Linux info -- assume Arch? [y/N] " reply
	if [[ ! "$reply" =~ ^[Yy]$ ]]; then
		return 1
	fi
	ID="arch"
fi

echo "${DISTRIB_ID:-${ID:-}}" | tr '[:upper:]' '[:lower:]'
