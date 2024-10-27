#!/usr/bin/env bash

if ! pgrep -f "tiddlywiki.*6489" >/dev/null ;then
    nohup tiddlywiki ~/Onedrive/docs/tiddlywiki/mynewwiki --server 6489 2>&1 >/dev/null &
    echo $! > /tmp/tiddlywiki.pid
fi

~/.config/i3/run_or_raise.py 'uzbl-core' 'nohup uzbl-browser http://127.0.0.1:6489 2>&1 >/dev/null &'

while true
do
  if pgrep -f "uzbl.*6489" >/dev/null ;then
      :
  else
      pkill -F /tmp/tiddlywiki.pid
      rm -f /tmp/tiddlywiki.pid
      exit
  fi
  sleep 60
done

