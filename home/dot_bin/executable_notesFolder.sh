#!/bin/zsh

if [[ $(uname) == 'Linux' ]]; then
    OPEN="emacsclientmod"
    FOLDER="~/Sync/docs/tex"
elif [[ $(uname) == 'Darwin' ]]; then
    OPEN="emacs"
    FOLDER="$(dirname ~/.zotero/zotero/*.default/zotero/storage)/storage"
else
    :
fi

#if [[ ! -d $FOLDER ]]; then
#    exit 1
#fi

echo OPEN=$OPEN
echo FOLDER=$FOLDER
echo FZFOPTS="(--query='tex\$ ' --multi --select-1)"
echo PREOPEN="'i3-msg workspace 0:noting; i3-msg append_layout ~/.config/i3/workspace-noting.json'"
#echo POSTOPEN="'emacsclientmod ~/Onedrive/docs/org-mode/gtd/superset.org'"
