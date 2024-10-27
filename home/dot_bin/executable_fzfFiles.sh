#!/usr/bin/env bash
# This script is used to open the files found by fzf.
# You may use it to open the files in your calibre or zotero library.

FZF_DIR="$HOME/.customized/fzf"
if [[ -x "$FZF_DIR/${1}.sh" ]]; then
    source "$FZF_DIR/${1}.sh"
elif [[ -n "$FOLDER" ]]; then
    :
else
    FOLDER="${1:-"$PWD"}"
fi

[[ -n "$SOURCE_EXTRA" && "$SOURCE_EXTRA" != 'n' ]] && source "$FZF_DIR/extra.sh"

if [[ -d $FOLDER ]]; then
    shift
    cd "$FOLDER"
fi
declare -a FILES
IFS=$'\n' FILES=($(fzf-tmux "$@"))
for file in "${FILES[@]}"; do
    echo "$FOLDER/$file"
done
