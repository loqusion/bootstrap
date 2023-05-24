#!/usr/bin/env bash

exists() {
	command -v "$@"
} &>/dev/null

exists bat && bat cache --build
exists tldr && command tldr --update
