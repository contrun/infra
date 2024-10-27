#!/usr/bin/env bash

screenshot() {
  file="$1"
  if [[ -z "$WAYLAND_DISPLAY" ]]; then
    if command -v maim; then
      maim -s "$file"
    else
      return 1
    fi
  else
    if command -v grim && command -v slurp; then
      grim -g "$(slurp)" "$file"
    elif command -v grimshot; then
      grimshot save area "$file"
    else
      return 1
    fi
  fi
}

file="${1:-$HOME/Pictures/screenshot-$(date +%Y-%m-%d-%H-%M-%S).png}"

if screenshot "$file"; then
  noti -t "Screenshotting succeeded" -m "saved to $file"
else
  noti -t "Screenshotting failed"
fi
