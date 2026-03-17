#!/usr/bin/env bash

set -euo pipefail

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
      read -r -a p1 < <(slurp -p -f '%x %y')
      read -r -a p2 < <(slurp -p -f '%x %y')
      x=$((p1[0] < p2[0] ? p1[0] : p2[0]))
      y=$((p1[1] < p2[1] ? p1[1] : p2[1]))
      w=$((p1[0] > p2[0] ? p1[0] - p2[0] : p2[0] - p1[0]))
      h=$((p1[1] > p2[1] ? p1[1] - p2[1] : p2[1] - p1[1]))
      grim -g "${x},${y} ${w}x${h}" "$file"
    elif command -v grimshot; then
      grimshot save area "$file"
    else
      return 1
    fi
  fi
}

file="${1:-$HOME/Pictures/screenshot-$(date +%Y-%m-%d-%H-%M-%S).png}"

if screenshot "$file"; then
  notify-send 'screenshot' "saved to $file"
else
  notify-send 'screenshot' "failed"
fi
