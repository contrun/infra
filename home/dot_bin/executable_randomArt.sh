#!/usr/bin/env bash
# DISPLAY has to be set if you are calling this script using netctl.
cd ~/Storage/wallpapers
[[ -n "$DISPLAY" ]] && export DISPLAY=":0"

set_wallpaper() {
    if [[ -n "$1" ]]; then
        file="$1"
    else
        file="$(ls -tc | shuf -n 1)"
    fi
    feh --bg-fill "$file"
    notify-send "wallpaper set" "$file"
}

artpip() {
    curl -s https://artpip.com/api/featured | jq -r '.artworks | map(.url) | join("\n")' | parallel curl -sOJL
}

artfulmac() {
    local url="$(curl -s 'http://artfulmac.com/random-art' | jq -r .file_location)"
    curl -sOJL "$url"
}

get_wallpaper() {
    artfulmac "$@"
}

new_wallpaper() {
    set_wallpaper "$(ls | shuf -n 1)"
    get_wallpaper
    set_wallpaper "$(ls -tc | shuf -n 1)"
}

case "$1" in
get | set | new)
    $1_wallpaper
    ;;
*)
    set_wallpaper
    ;;
esac
