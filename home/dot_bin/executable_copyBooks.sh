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
baseDir="${3%/}"

copyFile() {
    local file="$1"
    local dir="$2"
    rsync --progress -h -av -e "ssh -p $port" "$file" "$server:$baseDir/$(basename "$dir")/"
}

declare -a fzfDirs=(zotero)
for dir in "${fzfDirs[@]}"; do
    declare -a FILES
    IFS=$'\n' FILES=($(fzfFiles.sh "$dir" -f ''))
    for file in "${FILES[@]}"; do
        copyFile "$file" "$dir"
    done
done

declare -a homeDirs=(Academia Downloads Documents)
for dir in "${homeDirs[@]}"; do
    dir="$HOME/$dir"
    declare -a FILES
    IFS=$'\n' FILES=($(fzfFiles.sh "$dir" -f '.pdf$ | .epub$ | .djvu$ | .mobi$'))
    for file in "${FILES[@]}"; do
        copyFile "$file" "$dir"
    done
done
