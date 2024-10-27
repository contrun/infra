#!/bin/sh
export PATH=/usr/local/git/bin:/usr/local/bin:$PATH
echo "$(date -R): running $0 $@" >> ~/Ftemp/log/youtube-dl.log
youtube-dl "$@" >> ~/Ftemp/log/youtube-dl.log
