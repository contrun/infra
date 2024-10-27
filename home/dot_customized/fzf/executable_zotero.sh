#!/usr/bin/env bash
if [[ `uname` == 'Linux' ]]; then
    if (ls ~/.zotero/zotero/*.default/zotero/storage 1>/dev/null 2>&1); then
        FOLDER="$(dirname ~/.zotero/zotero/*.default/zotero/storage)/storage"
    elif [[ -d ~/Zotero/storage ]]; then
        FOLDER="$HOME/Zotero/storage"
    else
        FOLDER="/run/media/$(id -un)/mdt/zotero/storage"
    fi
elif [[ `uname` == 'Darwin' ]]; then
    FOLDER="$(dirname ~/.zotero/zotero/*.default/zotero/storage)/storage"
else
    :
fi

SOURCE_EXTRA='y'
export FZF_DEFAULT_COMMAND="find -L . -mindepth 1 -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null | cut -b3- | grep -v 'DS_Store'"
export FZF_DEFAULT_OPTS='--multi --select-1'
# echo PREOPEN="'i3-msg workspace 0:reading; i3-msg append_layout ~/.config/i3/workspace-reading.json; emacsclientmod -e "'"'"(progn (org-agenda-list) (delete-other-windows))"'"'"'"
#echo POSTOPEN="'""emacsclientmod -e "'"'"(progn (org-agenda-list) (delete-other-windows))"'"'
