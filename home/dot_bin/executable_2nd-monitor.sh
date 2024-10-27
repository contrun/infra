#!/usr/bin/env bash
set -eu
modeName="${modeName:-2ndScreen}"
connectedPort="${connectedPort:-"$(xrandr -q | awk '$2 == "connected" {print $1}' | head -n 1)"}"
virtualPorts="$(xrandr -q | awk '/VIRTUAL1/ {print $1}' | tac)"
disconnectedPorts="$(xrandr -q | awk '$2 == "disconnected" {print $1}' | tac)"
output="${output:-"$(echo "$virtualPorts" "$disconnectedPorts" | xargs | awk '{print $1}')"}"
location="${location:-"--right-of"}"
resolution="${resolution:-1920x1200}"
remoteHScreen="$(tr "x" " " <<<"$resolution" | awk '{print $1}')"
remoteVScreen="$(tr "x" " " <<<"$resolution" | awk '{print $2}')"
method="${method:-deskreen}"

usage() {
    echo "$0 start|stop|restart"
    exit
}

addMode() {
    eval xrandr --newmode "$modeName" "$(cvt "$remoteHScreen" "$remoteVScreen" | grep Modeline | cut -d\  -f4- | xargs)"
    xrandr --addmode "$output" "$modeName"
    xrandr --output "$output" "$location" "$connectedPort" --mode "$modeName"
}

removeMode() {
    {
        xrandr --output "$output" --off
        xrandr --delmode "$output" "$modeName"
        xrandr --rmmode "$modeName"
    } || true
}

start() {
    removeMode
    addMode
    trap removeMode EXIT INT TERM
    case "$method" in
    x11vnc)
        x11vnc -clip xinerama1 -unixpw
        ;;
    deskreen)
        deskreen
        ;;
    *)
        echo "Unknown method $method"
        exit 1
        ;;
    esac
}

stop() {
    pkill "$method" || true
    removeMode
}

restart() {
    stop
    start
}

action="${1:-start}"
case "$action" in
start | stop | restart)
    "$action" "${@:1}"
    ;;
*)
    usage
    ;;
esac
