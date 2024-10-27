#!/usr/bin/env bash
# Get server name of the url to download.
function getUriFilename() {
    header="$(curl -sI "$1" | tr -d '\r')"

    filename="$(echo "$header" | grep -o -E 'filename=.*$')"
    if [[ -n "$filename" ]]; then
        echo "${filename#filename=}"
        return
    fi

    filename="$(echo "$header" | grep -o -E 'Location:.*$')"
    if [[ -n "$filename" ]]; then
        filename="$(basename "${filename#Location\:}")"
        echo "${filename%%\?*}"
        return
    fi

    return 1
}
getUriFilename "$@"
exit $?
