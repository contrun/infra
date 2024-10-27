#!/usr/bin/env bash

on_die() {
    echo "Exiting..."
    exit 0
}

trap 'on_die' SIGINT SIGTERM

if [[ "${#@}" -ne "3" ]]; then
    echo "usage: $0 server port baseDir"
    exit 1
fi

server="$1"
port="$2"
baseDir="${3%/}/"

syncFolder() {
    local dir="${1%/}"
    rsync --exclude-from ~/.stglobalignore --progress -h -avu --delete -e "ssh -p $port" "$(basename "$dir")" "$server:$baseDir"
}

declare -a homeDirs=(Academia Bench Downloads Documents Sync Workspace Zotero)
for dir in "${homeDirs[@]}"; do
    syncFolder "$HOME/$dir"
done
