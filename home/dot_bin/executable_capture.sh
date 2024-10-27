#!/usr/bin/env bash
export PATH=/usr/local/git/bin:/usr/local/bin:$PATH
if [[ $(uname) == 'Linux' ]]; then
    systemctl --user is-active emacs.service | grep -q 'active' || systemctl --user start emacs.service
elif [[ $(uname) == 'Darwin' ]]; then
    pgrep -q emacs || brew services start emacs
else
    exit
fi
socketfile="$(lsof -c Emacs | grep server | tr -s " " | cut -d' ' -f 8 | uniq)"
cd "$(dirname "$socketfile")"
emacsclient -cne "(make-capture-frame)" -s "$(basename "$socketfile")"
