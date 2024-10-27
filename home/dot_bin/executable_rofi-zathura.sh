#!/usr/bin/env bash

selected="$(
  grep -Po '\[\K[^\]]*' ~/.local/share/zathura/history |
    grep -Pv '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$' |
    tac |
    rofi -dmenu -i -markup-rows
)"

# exit if nothing is selected
if [[ -z "$selected" ]]; then
  exit 1
fi

zathura "$selected"
