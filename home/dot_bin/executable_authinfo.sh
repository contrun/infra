#!/usr/bin/env bash
set -euo pipefail
# getpw.sh main/keys/authinfo -p | gpg --passphrase-fd 0 --no-verbose --quiet --decrypt ~/.authinfo.gpg
authinfo=
if [[ -f ~/.authinfo.gpg ]] && k="$(keys.sh get authinfo)"; then
        authinfo="$(gpg --passphrase-fd 0 --no-verbose --quiet --batch --yes --decrypt ~/.authinfo.gpg <<<"$k")"
elif [[ -f ~/.authinfo ]]; then
        authinfo="$(cat ~/.authinfo)"
else
        echo "authinfo file not found"
        exit 1
fi
program="$(basename "$0")"
usage() {
        cat - <<EOF
usage: $program path [-u|--username] ...
$program path [-p|--passwrod] ...
$program path [-l|--url|--host] ...
$program path [-o|-P|--port] ...
$program path [-d|--details] ...
EOF
}

if [[ "$#" -le "1" ]]; then
        usage
        exit
else
        info="$(grep -A 10 -E "$1" <<<"$authinfo" | grep -v '^\s*#' | head -n1)"
        echo "$info" >/dev/shm/myai
        eval "$(authinfo --query --path /dev/shm/myai | grep -v export)"
        rm /dev/shm/myai
        case "$2" in
        -u | --username)
                echo "$AUTHINFO_USER"
                ;;
        -p | --password)
                echo "$AUTHINFO_PASSWORD"
                ;;
        -l | --url | --host)
                echo "$AUTHINFO_HOST"
                ;;
        -o | -P | --port)
                echo "$AUTHINFO_PROTOCOL"
                ;;
        -d | --details)
                echo "$info"
                ;;
        *)
                usage
                ;;
        esac
fi
