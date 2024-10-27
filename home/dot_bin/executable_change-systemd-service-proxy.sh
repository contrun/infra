#!/usr/bin/env bash

set -euo pipefail

add_config() {
  local proxy="$1"
  mkdir -p "$dir"
  cat <<- EOF >"${conf}"
  [Service]
  Environment="http_proxy=${proxy}"
  Environment="https_proxy=${proxy}"
  Environment="all_proxy=${proxy}"
  Environment="HTTP_PROXY=${proxy}"
  Environment="HTTPS_PROXY=${proxy}"
  Environment="ALL_PROXY=${proxy}"
  Environment="no_proxy=127.0.0.1,localhost"
  Environment="NO_PROXY=127.0.0.1,localhost"
EOF
}

restart_service() {
  systemctl daemon-reload
  systemctl restart "$service"
}

start () {
  add_config "$@"
  restart_service
}

remove_config() {
  rm -f "$conf"
}

stop() {
  remove_config
  restart_service
}

restart() {
  add_config "$@"
  remove_config
  restart_service
}

switch_to() {
  restart "$@"
}

reload() {
  restart "$@"
}

usage() {
  echo "$0 {start | stop | restart | switch_to} service proxy"
  exit
}

if [[ $# -lt 2 ]]; then
  usage
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo --preserve-env=DONT_TOUCH_IPTABLES /usr/bin/env bash "$0" "$@"
fi

action="$1"
case "$action" in
start | stop | restart | reload | switch_to)
  shift
  service="$1"
  dir="/run/systemd/system/${service}.service.d"
  conf="${dir}/override.conf"
  shift
  "$action" "$@"
  ;;
*)
  usage
  ;;
esac
