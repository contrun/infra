#!/usr/bin/env bash

(($#)) || { printf 'usage: %s <video>\n' "${0##*/}" >&2; exit; }

[[ ${1,,} == *.gif ]] && exit

ffmpeg() {
    command ffmpeg -hide_banner -loglevel error -nostdin "$@"
}

video_to_gif() {
    ffmpeg -i "$1" -vf palettegen -f image2 -c:v png - |
    ffmpeg -i "$1" -i - -filter_complex paletteuse "$2"
}

set -- "$1" "${1%.*}.gif"
printf 'converting: %s ...' "$1" >&2
video_to_gif "$@" &&
printf '\r\e[Kwritten to: %s\n' "$2" >&2

# vim:et:sw=4:ts=4:

