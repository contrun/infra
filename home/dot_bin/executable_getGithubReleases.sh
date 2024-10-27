#!/usr/bin/env bash
set -o nounset # Treat unset variables as an error
set -o errexit # To proceed, some commands must succeed
set -o xtrace  # make script easy to debug

OWNER="${OWNER:-contrun}"
REPO=
while getopts ":u:r:f" opt; do
    case $opt in
    u)
        OWNER="$OPTARG"
        ;;
    r)
        REPO="$OPTARG"
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done
shift $(($OPTIND - 1))
[[ -n "$OWNER" ]] || exit 1
[[ -n "$REPO" ]] || exit 1
CONTENT="$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases")"
for f in "$@"; do
    URL="$(jq -r ".[] | .assets | .[] | select(.name==\"$f\") | .browser_download_url" <<<"$CONTENT")" || echo "Failed to get download information for $f"
    wget "$URL" || echo "Downloading $f from $URL failed"
done
