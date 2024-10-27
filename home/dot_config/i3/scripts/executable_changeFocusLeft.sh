#!/bin/sh
# https://faq.i3wm.org/question/1537/show-title-of-focused-window-in-status-bar.1.html

id=$(xprop -root | awk '/_NET_ACTIVE_WINDOW\(WINDOW\)/{print $NF}')
class=$(xprop -id $id | awk '/WM_CLASS/{$1=$2="";print}')
if grep 'emacs' <<< "$class"; then
    sleep 0.2; xdotool key --clearmodifiers --window $(($id)) F5 Left
else
    i3-msg 'focus left'
fi
