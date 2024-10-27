#!/usr/bin/env bash
case "$(uname)" in
    Darwin)
        cat << EOF | osascript
        display notification "$1" with title "$2"
EOF
    ;;
    Linux)
        notify-send "$2" "$1" 
    ;;
    *)
        exit
esac
