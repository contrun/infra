#!/usr/bin/env bash
if [[ $(uname) == 'Linux' ]]; then
    if [[ -d ~/Storage/Calibre ]]; then
        FOLDER=~/Storage/Calibre
    else
        FOLDER="/run/media/$(id -un)/mdt/zotero/storage"
    fi
elif [[ $(uname) == 'Darwin' ]]; then
    FOLDER=~/Storage/Calibre
else
    :
fi

SOURCE_EXTRA='y'
export FZF_DEFAULT_COMMAND="find -L . -mindepth 2 -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null | cut -b3- | grep -Ev '(\.DS_Store|metadata.opf|cover.jpg|metadata.pdf.lua)$|metadata.pdf.lua'"
export FZF_DEFAULT_OPTS='--multi --select-1'
