#!/usr/bin/env bash

set -euo pipefail

# Also check the environment variable with prefix CLASH_API_
port="${CLASH_API_PORT:-9097}"
host="${CLASH_API_HOST:-127.0.0.1}"
scheme="${CLASH_API_SCHEME:-http}"
url="${CLASH_API_URL:-}"
while getopts "p:h:s:u:" opt; do
  case $opt in
  p) port=$OPTARG ;;
  h) host=$OPTARG ;;
  s) scheme=$OPTARG ;;
  u) url=$OPTARG ;;
  \?) echo "Invalid option: -$OPTARG" ;;
  esac
done

if [ -z "$url" ]; then
  url="$scheme://$host:$port/configs"
fi

current_status="$(curl -sS "$url" | jq -r .tun.enable)"

# status must either be true or false, if not, exit
if [ "$current_status" != "true" ] && [ "$current_status" != "false" ]; then
  echo "Invalid status: $current_status"
  exit 1
fi

# If current status is true, set new status to false, otherwise set new status to true
new_status="false"
if [ "$current_status" == "false" ]; then
  new_status="true"
fi

# We use heredoc to pass the json payload to curl to ease the burden of escaping quotes
cat <<EOF | curl -sS "$url" -X PATCH --json @-
{
  "tun": {
    "enable": $new_status
  }
}
EOF

state=disabled
if [ "$new_status" == "true" ]; then
  state=enabled
fi

if ! noti -t "Clash Tun" -m "Tun mode is now $state"; then
  :
fi
