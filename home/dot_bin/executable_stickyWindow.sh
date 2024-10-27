#!/usr/bin/env bash
SCALE="${1:-3}"
POSITION="${2:-tr}"
if [[ $(uname) == 'Linux' ]]; then
    RESOLUTION="$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')"
    DIMENSION_X="$(awk -Fx '{print $1}' <<< "$RESOLUTION")"
    DIMENSION_Y="$(awk -Fx '{print $2}' <<< "$RESOLUTION")"
    SIZE_X="$(bc <<< "$DIMENSION_X / $SCALE")"
    SIZE_Y="$(bc <<< "$DIMENSION_Y / $SCALE")"
    OFFSET_X=0
    OFFSET_Y=0
    if [[ "${POSITION:0:1}" == 'b' || "${POSITION:1:1}" == 'b' ]]; then
        OFFSET_Y="$(($DIMENSION_Y - $SIZE_Y))"
    fi
    if [[ "${POSITION:0:1}" == 'r' || "${POSITION:1:1}" == 'r' ]]; then
        OFFSET_X="$(($DIMENSION_X - $SIZE_X))"
    fi
    i3-msg "fullscreen disable; floating enable; resize set $SIZE_X $SIZE_Y; sticky enable; move position $OFFSET_X $OFFSET_Y"
elif [[ $(uname) == 'Darwin' ]]; then
    :
else
    :
fi
