#!/usr/bin/env bash

NAME=wireguard

wg_client="${2:-wg0-client}"
check_running(){
    wg="$(ls -1 /sys/class/net | grep -E '^wg')"
}

do_start(){
    check_running
    if [[ -n "$wg" ]]; then
        sudo wg-quick up "$wg_client"
    else
        echo "$NAME (/etc/wireguard/$wg) is already running"
    fi
}

do_stop(){
    check_running
    if [[ -n "$wg" ]]; then
        sudo wg-quick down "$wg"
    else
        echo "$NAME is not running"
    fi
}

do_status(){
    check_running
    if [[ -n "$wg" ]]; then
        echo "$NAME (/etc/wireguard/$wg) is already running"
    else
        echo "$NAME is not running"
        RETVAL=1
    fi
}

do_restart(){
    do_stop
    do_start
}

do_toggle(){
    check_running
    if [[ -n "$wg" ]]; then
        sudo wg-quick down "$wg"
    else
        sudo wg-quick up "$wg_client"
    fi
}

case "$1" in
    start|stop|restart|status|toggle)
    do_$1
    ;;
    *)
    echo "Usage: $0 { start | stop | restart | status | toggle }"
    RETVAL=1
    ;;
esac

exit $RETVAL
