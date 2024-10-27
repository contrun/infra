#!/bin/sh
 
# backlight_get
#       Print current keyboard brightness from UPower to stdout.
backlight_get()
{
    dbus-send --type=method_call --print-reply=literal --system         \
        --dest='org.freedesktop.UPower'                                 \
        '/org/freedesktop/UPower/KbdBacklight'                          \
        'org.freedesktop.UPower.KbdBacklight.GetBrightness'             \
        | awk '{print $2}'
}
 
# backlight_get_max
#       Print the maximum keyboard brightness from UPower to stdout.
backlight_get_max()
{
    dbus-send --type=method_call --print-reply=literal --system       \
        --dest='org.freedesktop.UPower'                               \
        '/org/freedesktop/UPower/KbdBacklight'                        \
        'org.freedesktop.UPower.KbdBacklight.GetMaxBrightness'        \
        | awk '{print $2}'
}
 
# backlight_set NUMBER
#       Set the current backlight brighness to NUMBER, through UPower
backlight_set()
{
    value="$1"
    if test -z "${value}" ; then
        echo "Invalid backlight value ${value}"
    fi
 
    dbus-send --type=method_call --print-reply=literal --system       \
        --dest='org.freedesktop.UPower'                               \
        '/org/freedesktop/UPower/KbdBacklight'                        \
        'org.freedesktop.UPower.KbdBacklight.SetBrightness'           \
        "int32:${value}}"
}
 
# backlight_change [ UP | DOWN | NUMBER ]
#       Change the current backlight value upwards or downwards, or
#       set it to a specific numeric value.
backlight_change()
{
    change="$1"
    if test -z "${change}" ; then
        echo "Invalid backlight change ${change}."                    \
            "Should be 'up' or 'down'." >&2
        return 1
    fi
 
    case ${change} in
    [1234567890]|[[1234567890][[1234567890])
        current=$( backlight_get )
        max=$( backlight_get_max )
        value=$( expr ${change} + 0 )
        if test ${value} -lt 0 || test ${value} -gt ${max} ; then
            echo "Invalid backlight value ${value}."                  \
                "Should be a number between 0 .. ${max}" >&2
            return 1
        else
            backlight_set "${value}"
            notify-send -t 800 "Keyboard brightness set to ${value}"
        fi
        ;;
 
    [uU][pP])
        current=$( backlight_get )
        max=$( backlight_get_max )
        if test "${current}" -lt "${max}" ; then
            value=$(( ${current} + 1 ))
            backlight_set "${value}"
            notify-send -t 800 "Keyboard brightness set to ${value}"
        fi
        ;;
 
    [dD][oO][wW][nN])
        current=$( backlight_get )
        if test "${current}" -gt 0 ; then
            value=$(( ${current}  - 1 ))
            backlight_set "${value}"
            notify-send -t 800 "Keyboard brightness set to ${value}"
        fi
        ;;
 
    *)
        echo "Invalid backlight change ${change}." >&2
        echo "Should be 'up' or 'down' or a number between"           \
            "1 .. $( backlight_get_max )" >&2
        return 1
        ;;
    esac
}
 
if test $# -eq 0 ; then
    current_brightness=$( backlight_get )
    notify-send -t 800 "Keyboard brightness is ${current_brightness}"
else
    # Handle multiple backlight changes, e.g.:
    #   backlight.sh up up down down up
    for change in "$@" ; do
        backlight_change "${change}"
    done
fi
