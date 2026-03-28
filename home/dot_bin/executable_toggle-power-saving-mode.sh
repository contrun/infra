#!/usr/bin/env bash

set -uo pipefail

declare -a system_units=("pipewire*" vboxnet0 tailscaled wstunnel "wg-quick-*" eternal-terminal promtail prometheus "prometheus-*.service" cadvisor docker docker.socket "docker-*.service" zerotierone "zerotierone-*" glusterd glustereventsd syncthing aria2 chronyd cups-browsed nfs-idmapd nfs-mountd nfsdcld "pcscd*" rpc-statd "rpcbind*" system-samba.slice vsftpd waydroid-container "avahi-daemon*" postfix system-cups.slice)
declare -a user_units=("pipewire*" syncthing tomat emacs auto-fix-vscode-server app-unison.slice "offlineimap*")
declare -a kernel_modules=(asus_nb_wmi asus-nb-wmi uvcvideo)

start_user_power_saving() {
  systemctl stop --user "${user_units[@]}"
}

stop_user_power_saving() {
  for i in "${user_units[@]}"; do
    systemctl --user list-unit-files --state=enabled --output json "$i" | jq -r '.[].unit_file' | xargs -r systemctl --user start
  done
}

start_root_power_saving() {
  systemctl stop "${system_units[@]}"
  rfkill block bluetooth
  rmmod -f "${kernel_modules[@]}"
  for i in /sys/module/*/parameters/power_save; do
    echo 1 > "$i"
  done
  for i in /sys/bus/pci/devices/*/power/control; do
    echo auto > "$i"
  done
  for i in eno2 docker0; do
    ip link set "$i" down
  done
  echo 1 > /sys/fs/cgroup/system.slice/docker-*.scope/cgroup.kill
}

stop_root_power_saving() {
  for i in "${system_units[@]}"; do
    systemctl list-unit-files --state=enabled --output json "$i" | jq -r '.[].unit_file' | xargs -r systemctl start
  done
  rfkill unblock bluetooth
  modprobe asus_nb_wmi
}

start() {
  if [[ $EUID -ne 0 ]]; then
    start_user_power_saving
    exec sudo env bash "$0" start "$@"
  else
    start_root_power_saving
  fi
}

stop() {
  if [[ $EUID -ne 0 ]]; then
    stop_user_power_saving
    exec sudo env bash "$0" stop "$@"
  else
    stop_user_power_saving
  fi
}

usage() {
  echo "$0 {start | stop}"
  exit
}

if [[ $# -lt 1 ]]; then
  usage
fi

action="$1"
case "$action" in
start | stop | restart | reload | switch_to)
  shift
  "$action" "$@"
  ;;
*)
  usage
  ;;
esac
