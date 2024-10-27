#!/usr/bin/env bash
set -ue

machine="${machine:-}"
serverName="${serverName:-1}"
port=
conf="${conf:-1}"
user="${USER:-}"
machine=
dryrun=
while getopts "s:c:p:u:m:dn-" opt; do
        case $opt in
        s)
                serverName="$OPTARG"
                ;;
        c)
                conf="$OPTARG"
                ;;
        p)
                port="$OPTARG"
                ;;
        u)
                user="$OPTARG"
                ;;
        m)
                machine="$OPTARG"
                ;;
        d | n)
                dryrun=y
                ;;
        -)
                break
                ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
done

if [[ -z "$machine" ]]; then
        echo "machine hostname is not provided"
        exit 1
fi

shift $(("$OPTIND" - 1))
serverName="autossh$serverName"
[[ -z "$port" ]] && port="$(($(printf '%i' "0x$(echo -n "$serverName->$machine->$conf" | sha512sum | head -c 3)") + 32768 + 4096 * $conf))"
if [[ -n "$dryrun" ]]; then
        echo ssh -p "$port" "$@" "$user@$serverName"
else
        ssh -p "$port" "$@" "$user@$serverName"
fi
