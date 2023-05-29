#!/usr/bin/env bash

exists() {
	command -v "$@"
} &>/dev/null

# Set up Samba
sudo smbpasswd -a "$USER"

# Detect hardware monitoring chips
exists sensors-detect && sudo sensors-detect --auto
