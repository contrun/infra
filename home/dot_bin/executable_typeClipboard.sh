#!/usr/bin/env bash
#sleep 0.2
#xdotool getwindowfocus windowfocus
sleep 0.15
xdotool getwindowfocus windowactivate --sync type --clearmodifiers "$(xclip -selection c -o)"
#xdotool type --clearmodifiers "$(xclip -o)"
