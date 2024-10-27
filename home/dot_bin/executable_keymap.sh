#!/usr/bin/env bash
set -xeu
DISPLAY="${DISPLAY:-:0.0}"
HOME="${HOME:-/home/e}"
XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export DISPLAY XAUTHORITY HOME
host="$(hostname)"
if [[ -x "$HOME/.Xmodmap.$host" ]]; then
    "$HOME/.Xmodmap.$host"
else
    ~/.Xmodmap
fi
