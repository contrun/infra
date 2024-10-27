#!/usr/bin/env bash
MYSHELL=zsh
if [ -n "$@" ]; then
    tmux new "exec $MYSHELL"
else
    tmux new "$@; exec $MYSHELL"
fi
