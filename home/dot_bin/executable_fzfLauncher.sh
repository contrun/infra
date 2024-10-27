#!/usr/bin/env bash
# This script is used to open the files found by fzf.
# You may use it to open the files in your calibre or zotero library.
set -euo pipefail

FZF_DIR="$HOME/.customized/fzf"
if [[ -x "$FZF_DIR/${1}.sh" ]]; then
        source "$FZF_DIR/${1}.sh"
elif [[ -n "${FOLDER:-}" ]]; then
        :
else
        FOLDER="${1:-"$PWD"}"
fi

[[ -n "${SOURCE_EXTRA:-}" && "$SOURCE_EXTRA" != 'n' ]] && source "$FZF_DIR/extra.sh"

cd "$FOLDER" || {
        echo "$FOLDER is not a folder."
        exit 1
}

IFS=$'\n' files=($(fzf-tmux))

# if [[ `uname` == 'Linux' ]]; then
#     OPEN="xdg-open"
# elif [[ `uname` == 'Darwin' ]]; then
#     OPEN="open"
# else
#     :
# fi

O="${OPEN:-open}"
if [[ -n "$files" ]]; then
        [[ -n "${PREOPEN:-}" ]] && eval "$PREOPEN"
        # $O "${files[@]}" >/dev/null 2>&1
        nohup "$O" "${files[@]}" >/dev/null 2>&1 &
        [[ -n "${POSTOPEN:-}" ]] && eval "$POSTOPEN"
        wait
else
        echo "No files selected."
fi
