#!/bin/zsh
if [[ $(uname) == 'Linux' ]]; then
    OPEN="xdg-open"
    if (dirname ~/.zotero/zotero/*.default/zotero/storage(N) 1>/dev/null 2>&1) ; then
        FOLDER="$(dirname ~/.zotero/zotero/*.default/zotero/storage)/storage"
    else
        FOLDER="/run/media/e/mdt/zotero/storage"
    fi
elif [[ $(uname) == 'Darwin' ]]; then
    OPEN="open"
    FOLDER="$(dirname ~/.zotero/zotero/*.default/zotero/storage)/storage"
else
    :
fi

if [[ ! -d $FOLDER ]]; then
    exit 1
fi

echo "OPEN=$OPEN"
echo "FOLDER=$FOLDER"
echo "FZFOPTS=(--multi --select-1)"
echo PREOPEN="'i3-msg workspace 0:reading; i3-msg append_layout ~/.config/i3/workspace-reading.json'"
echo POSTOPEN="'""emacsclientmod ~/Onedrive/docs/org-mode/gtd/superset.org'"
