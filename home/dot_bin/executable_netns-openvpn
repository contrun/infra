#!/usr/bin/env bash

# Adopted from https://unix.stackexchange.com/a/196116
# sudo $0 --config config.ovpn --auth-user-pass user-pass.txt
# sudo ip netns exec openvpn sudo -u $(whoami) command

set -xeuo pipefail
export PATH=$PATH:/run/current-system/sw/bin

: "${script_type:=}"
: "${netns_name:=openvpn}"
: "${nameserver:=8.8.8.8}"

teardown() {
  if ! ip netns delete "$netns_name"; then
    :
  fi
}

runHook() {
  case "$script_type" in
  up)
    dev="$1"
    mtu="$2"
    ip="$4"
    netmask="${ifconfig_netmask:-30}"
    ip netns add "$netns_name" || true
    ip netns exec "$netns_name" ip link set dev lo up
    mkdir -p "/etc/netns/$netns_name"
    echo "nameserver $nameserver" > "/etc/netns/$netns_name/resolv.conf"
    ip link set dev "$dev" up netns "$netns_name" mtu "$mtu"
    ip netns exec "$netns_name" ip addr add dev "$dev" "$ip/$netmask" ${ifconfig_broadcast:+broadcast "$ifconfig_broadcast"}
    if [[ -n "${ifconfig_ipv6_local:-}" ]]; then
      ip netns exec "$netns_name" ip addr add dev "$1" "$ifconfig_ipv6_local"/112
    fi
    ;;
  route-up)
    ip netns exec "$netns_name" ip route add default via "$route_vpn_gateway"
    if [[ -n "${ifconfig_ipv6_remote:-}" ]]; then
      ip netns exec "$netns_name" ip route add default via "$ifconfig_ipv6_remote"
    fi
    ;;
  down)
    teardown
    ;;
  esac
  exit 0
}

runOpenvpn() {
  script="$(realpath "$0")"
  exec openvpn --script-security 2 --ifconfig-noexec --route-noexec --up "$script" --route-up "$script" --down "$script" "$@"
}

if [[ -z "$script_type" ]]; then
  runOpenvpn "$@"
else
  runHook "$@"
fi
