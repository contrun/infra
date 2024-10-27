#!/usr/bin/env bash
# toggle touchpad or tap to click
toggle_touchpad() {
    declare -i ID
    ID="$(xinput list | grep -iEo '(Trackpad.*|TouchPad\s*)id\=[0-9]{1,2}' | grep -Eo '[0-9]{1,2}')"
    declare -i STATE
    STATE="$(xinput list-props $ID|grep 'Device Enabled'|awk '{print $4}')"
    if [ $STATE -eq 1 ]; then
        xinput disable $ID
        echo "Touchpad disabled."
    else
        xinput enable $ID
        echo "Touchpad enabled."
    fi
}

toggle_tap_to_click() {
    declare -i STATE
    STATE="$(synclient -l | grep TapButton1 | awk '{print $3}')"
    if [[ $STATE -eq 1 ]]; then
	synclient TapButton1=
    else
	synclient TapButton1=1
    fi
}

[[ "$1" == "tap" ]] && toggle_tap_to_click || toggle_touchpad
