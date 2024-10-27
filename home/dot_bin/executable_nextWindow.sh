#!/usr/bin/env bash -
#===============================================================================
#
#          FILE: nextWindow.sh
#
#         USAGE: ./nextWindow.sh
#
#   DESCRIPTION:
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (),
#  ORGANIZATION:
#       CREATED: 08/18/2018 17:54
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

xdotool search --all --onlyvisible --desktop $(xprop -notype -root _NET_CURRENT_DESKTOP | cut -c 24-) "" 2>/dev/null | grep -v "$(xdotool getactivewindow)" | head -n1
