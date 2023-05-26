#!/usr/bin/env bash

# Set up Samba
sudo smbpasswd -a "$USER"

# Detect hardware monitoring chips
exists sensors-detect && sudo sensors-detect --auto
