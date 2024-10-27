#!/usr/bin/env bash

NAME=v2ray
BIN=~/Programs/v2ray/v2ray
PREFIX=~/.customized/v2ray/
LOG=~/Ftemp/log/v2ray.log
IP="v${2:-6}"
PROTO="${3:-tcpm}"
PROTO="$(tr '[:lower:]' '[:upper:]' <<< "$PROTO")"
CONF=~/.customized/v2ray/$4$IP$PROTO.json
PGREPEX="v2ray.*customized/v2ray"

do_start(){
    if pgrep -f $PGREPEX > /dev/null; then
        echo "$NAME (pid $(pgrep -f $PGREPEX)) is already running..."
        exit 0
    else
        nohup $BIN -config $CONF > $LOG 2>&1 &
        #$BIN -config $CONF
        RETVAL=$?
        if [[ $RETVAL -eq 0 ]]; then
            echo "Starting $NAME succeeded"
            echo "The conf file is $CONF"
            echo "The log file is $LOG"
        else
            echo "Starting $NAME failed"
        fi
    fi
}

do_stop(){
    if pgrep -f $PGREPEX > /dev/null; then
        pkill -f $PGREPEX
        RETVAL=$?
        if [[ $RETVAL -eq 0 ]]; then
            echo "Stopping $NAME succeeded"
        else
            echo "Stopping $NAME failed"
        fi
    else
        echo "$NAME is not running"
        RETVAL=1
    fi
}

do_status(){
    if pgrep -f $PGREPEX > /dev/null; then
        echo "$NAME (pid $(pgrep -f $PGREPEX)) is running..."
    else
        echo "$NAME is not running"
        RETVAL=1
    fi
}

do_restart(){
    do_stop
    do_start
}

case "$1" in
    start|stop|restart|status)
    do_$1
    ;;
    *)
    echo "Usage: $0 { start | stop | restart | status }"
    RETVAL=1
    ;;
esac

exit $RETVAL
