#!/usr/bin/env bash

NAME=ShadowsocksR
BIN=~/Programs/shadowsocks/shadowsocks/local.py
PREFIX=~/.customized/shadowsocksr/
PGREPEX="shadowsocks.*customized/shadowsocksr"
LOG=~/Ftemp/log/shadowsocks.log
echo  "running $0"

V4SERVERS=$(ls $PREFIX | grep -o "v4server[0-9]*conf" | uniq | wc -l)
V6SERVERS=$(ls $PREFIX | grep -o "v6server[0-9]*conf" | uniq | wc -l)

case "$2" in
    6)
        NAME="ShadowsocksR IPV6"
        if [[ $3 -ge 1 ]] && [[ $3 -le $V6SERVERS ]]; then
            HOSTNUMBER=$3
        else
            HOSTNUMBER=$(shuf -i 1-"$V6SERVERS" -n 1)
        fi
        CONFS=$(ls $PREFIX | grep v6server${HOSTNUMBER} | uniq | wc -l)
        CONFNUMBER=$(shuf -i 1-"$CONFS" -n 1)
        CONF="v6server${HOSTNUMBER}conf${CONFNUMBER}.json"
        ;;
    4)
        if [[ $3 -ge 1 ]] && [[ $3 -le $V4SERVERS ]]; then
            HOSTNUMBER=$3
        else
            HOSTNUMBER=$(shuf -i 1-"$V4SERVERS" -n 1)
        fi
        CONFS=$(ls $PREFIX | grep v4server${HOSTNUMBER} | uniq | wc -l)
        CONFNUMBER=$(shuf -i 1-"$CONFS" -n 1)
        CONF="v4server${HOSTNUMBER}conf${CONFNUMBER}.json"

        ;;
    *)
        HOSTNUMBER=$(shuf -i 1-"$V6SERVERS" -n 1)
        CONFS=$(ls $PREFIX | grep v6server${HOSTNUMBER} | uniq | wc -l)
        CONFNUMBER=$(shuf -i 1-"$CONFS" -n 1)
        CONF="v6server${HOSTNUMBER}conf${CONFNUMBER}.json"
        ;;
esac
RETVAL=0

CONF="${PREFIX}${CONF}"

check_running(){
    PID=$(pgrep -f $PGREPEX)
    if pgrep -f $PGREPEX; then
        return 0
    else
        return 1
    fi
}

do_start(){
    check_running
    if pgrep -f $PGREPEX > /dev/null; then
        echo "$NAME (pid $(pgrep -f $PGREPEX)) is already running..."
        exit 0
    else
        nohup $BIN -v -c $CONF > $LOG 2>&1 &
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
    check_running
    if [[ $? -eq 0 ]]; then
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
    check_running
    if [[ $? -eq 0 ]]; then
        echo "$NAME (pid $PID) is running..."
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
