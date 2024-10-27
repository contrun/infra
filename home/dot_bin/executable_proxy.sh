#!/usr/bin/env bash
PROXY_TYPE="${proxy_type:-http}"
PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${PROXY_PORT:-8118}"
while getopts "shp:H:P:" opt; do
    case $opt in
    s)
        PROXY_TYPE="socks5"
        ;;
    h)
        PROXY_TYPE="http"
        ;;
    p)
        PROXY="$OPTARG"
        ;;
    H)
        PROXY_HOST="$OPTARG"
        ;;
    P)
        PROXY_PORT="$OPTARG"
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit
        ;;
    esac
done

[[ -z "$PROXY" ]] && PROXY="$PROXY_TYPE://$PROXY_HOST:$PROXY_PORT"
unset PROXY_TYPE
unset PROXY_HOST
unset PROXY_PORT
no_proxy='localhost,127.0.0.1,localaddress,.localdomain.com'
export no_proxy="$no_proxy"
if [[ -n "$IS_USING_PROXY" ]]; then
    unset PROXY
    unset IS_USING_PROXY
    unset http_proxy
    unset https_proxy
    unset ftp_proxy
    unset rsync_proxy
    unset all_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset FTP_PROXY
    unset RSYNC_PROXY
    unset ALL_PROXY
else
    export IS_USING_PROXY='y'
    export http_proxy="$PROXY"
    export https_proxy="$PROXY"
    export ftp_proxy="$PROXY"
    export rsync_proxy="$PROXY"
    export all_proxy="$PROXY"
    export HTTP_PROXY="$PROXY"
    export HTTPS_PROXY="$PROXY"
    export FTP_PROXY="$PROXY"
    export RSYNC_PROXY="$PROXY"
    export ALL_PROXY="$PROXY"
fi
