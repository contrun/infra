#!/usr/bin/env bash
enable() {
        if [[ $(uname) == 'Linux' ]]; then
                dunstFile=/tmp/dunstSIGUSR1
                if [[ ! -f dunstFile ]]; then
                        pkill -SIGUSR1 dunst && touch dunstFile
                else
                        exit
                fi
        elif [[ $(uname) == 'Darwin' ]]; then
                exit
        else
                exit
        fi
}

disable() {
        if [[ $(uname) == 'Linux' ]]; then
                dunstFile=/tmp/dunstSIGUSR1
                if [[ -f dunstFile ]]; then
                        pkill -SIGUSR2 dunst && rm dunstFile
                else
                        exit
                fi
        elif [[ $(uname) == 'Darwin' ]]; then
                exit
        else
                exit
        fi
}

toggle() {
        if [[ $(uname) == 'Linux' ]]; then
                dunstFile=/tmp/dunstSIGUSR1
                if [[ ! -f dunstFile ]]; then
                        pkill -SIGUSR1 dunst && touch dunstFile
                else
                        pkill -SIGUSR2 dunst && rm dunstFile
                fi
        elif [[ $(uname) == 'Darwin' ]]; then
                exit
        else
                exit
        fi
}

case $1 in
enable)
        enable
        ;;
disable)
        disable
        ;;
*)
        toggle
        ;;
esac
