#!/usr/bin/env bash
if [[ "$1" == "up" ]]; then
    xdotool key Prior
    xdotool key Hyper_L+l
    xdotool key Prior
    xdotool key Hyper_L+h
elif [[ "$1" == "down" ]]; then
    xdotool key Next
    xdotool key Hyper_L+l
    xdotool key Next
    xdotool key Hyper_L+h
fi
