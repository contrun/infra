#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "$0 -u MAILMAN_URL"
}

MAILMAN_URL=
while getopts "u:" opt; do
        case $opt in
        u)
                MAILMAN_URL="$OPTARG"
                ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                exit 1
                ;;
        esac
done

if [[ -z "$MAILMAN_URL" ]]; then
  usage
  exit 1
fi

wget -O- -q "$MAILMAN_URL" | grep -E -o 'href="[^"]+\.txt(\.gz)?"' | cut -f2 -d\" | while read -r filename; do
  wget "$MAILMAN_URL/$filename"
  if [[ "$filename" == *.gz ]]; then
    gunzip "$filename"
  fi
done
