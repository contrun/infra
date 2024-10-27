#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-emacs}"
INIT_FILE="${INIT_FILE:-"${DIR}/init.el"}"
n=0
until [ "$n" -ge 5 ]; do
   emacs --batch --load "${INIT_FILE}" --eval '(message "hello world")' && break
   n="$((n+1))"
   sleep 15
done
