#!/usr/bin/env bash
# download pdf files from sci-hub

shDownload() {
    prefix="http://sci-hub.hk"
    doi="$1"
    url="$(curl -sS --compressed "$prefix/$doi" | grep '?download=true' | awk -F"'" '{print $2}')"
    if [[ -n "$url" ]]; then
        if [[ -n "$2" ]]; then
            filename="$2"
        else
            filename="$(basename "$doi").pdf"
        fi
        wget -O "$filename" "$url"
    else
        echo "$doi" >> notFoundOnSciHub.txt
    fi
}

shDownload "$@"
