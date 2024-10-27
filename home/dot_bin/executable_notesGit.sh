#!/usr/bin/env bash
title=$1
if zenity --question --title "git push"  --text   "push $title to remote git repo?"; then
    error="$(echo 'git add . && git commit -m "auto push: notes of $title on $(date +%F)" && git push' | bash 2>&1 > /dev/null)"
    if [[ $? -ne 0 ]]; then
        zenity --error --text="$error" --title="pushing $1 error"
    else
        notify-send -t 3000 "pushing $1 to remote finished without error"
    fi
fi
