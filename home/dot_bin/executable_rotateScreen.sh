#!/usr/bin/env bash -
while getopts "qnilrpsa" opt; do
    case $opt in
        q)
            xrandr | grep -E '\sconnected' | awk '{print $1}' | xargs -I _ xrandr --output _ --rotate normal
            exit
            ;;
        n)
            direction="normal"
            ;;
        i)
            direction="inverted"
            ;;
        l)
            direction="left"
            ;;
        r)
            direction="right"
            ;;
        p)
            output="$(xrandr | grep -E '\sconnected' | grep primary | awk '{print $1}')"
            ;;
        s)
            output="$(xrandr | grep -E '\sconnected' | grep -v primary | awk '{print $1}')"
            ;;
        a)
            output="$(xrandr | grep -E '\sconnected' | awk '{print $1}')"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit
            ;;
    esac
done

if [[ -n "$direction" ]]; then
    if [[ -z "$output" ]]; then
        output="$(xrandr | grep -E '\sconnected' | awk '{print $1}' | shuf -n1)"
    fi
    xrandr --output "$output" --rotate "${direction:right}"
    exit
fi

shift $(($OPTIND - 1))
interval="${1:-200}"

while true; do
    if [[ -z "$output" ]]; then
        output="$(xrandr | grep -E '\sconnected' | awk '{print $1}' | shuf -n1)"
    fi
    from="$(xrandr | grep primary | awk '{print $5}')"
    [[ "$from" == "left" ]] && to="right" || to="left"
    xrandr --output "$output" --rotate "$to"
    sleep $interval
done
