#!/usr/bin/env bash
SOURCE_EXTRA="y"
FOLDER="$(find -L . -maxdepth 3 -path '*/\.*' -prune -o -type d -print | cut -b3- | grep -Ev '^(Dropbox|Music|Zotero\.old|Ftemp|PlayOnLinux|VirtualBox|Zotero/storage/|$)' | fzf-tmux)"
FZF_DEFAULT_COMMAND="find -L . -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null | cut -b3- | grep -v 'DS_Store'"
FZF_DEFAULT_OPTS='--multi --select-1'
# echo PREOPEN="'i3-msg workspace 0:reading; i3-msg append_layout ~/.config/i3/workspace-reading.json; emacsclientmod -e "'"'"(progn (org-agenda-list) (delete-other-windows))"'"'"'"
#echo POSTOPEN="'""emacsclientmod -e "'"'"(progn (org-agenda-list) (delete-other-windows))"'"'
