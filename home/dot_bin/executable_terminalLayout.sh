#!/bin/sh
# xrdb ~/.Xresources
# i3-msg "workspace $1; append_layout ~/.config/i3/workspace-terminal.json"
myTerminal 'sleep 8; weather.sh'
myTerminal 'kanban.py; sleep 6; task sync'
myTerminal
# sleep 30 && nohup termite -t 'scratchpad terminal' -e tmux.sh 2>&1 &
