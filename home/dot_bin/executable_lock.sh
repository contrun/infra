#!/usr/bin/env bash - 
#===============================================================================
#
#          FILE: lock.sh
# 
#         USAGE: ./lock.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 07/24/2018 13:30
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error
# scrot /tmp/ss.png && convert /tmp/ss.png -sample 10% -scale 1000% /tmp/ss-p.png && rm /tmp/ss.png && i3lock -i /tmp/ss-p.png && rm /tmp/ss-p.png
file="$(find ~/Storage/wallpapers/ -type f | shuf -n 1)"
output=/tmp/lock.png
convert "$file" "$output"
i3lock -utfi "$output"
