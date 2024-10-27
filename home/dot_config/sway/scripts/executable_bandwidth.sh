#!/bin/bash
parameter="$(cat << EOF
printf "<span font='FontAwesome'></span>%-1.0f<span font='FontAwesome'> </span>%-1.0f\n", rx, wx
EOF
)"
~/.config/i3blocks-contrib/bandwidth3/bandwidth3 -p "$parameter" -u KB

