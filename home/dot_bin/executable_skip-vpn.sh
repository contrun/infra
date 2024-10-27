#!/usr/bin/env bash

set -euo pipefail

# Make programs in certain cgroup route through the default link instead of the VPN interface.
# Note that even if the outgoing traffic of these programs will not go through VPN,
# their DNS resolution may be incorrect (e.g. clash resolve domains to fake IPs, which are
# only routable in the clash TUN interface).

# By default, we will skip some programs in a cgroup owned by a normal user.
# INVOKER will be that user.
if [[ -z "${INVOKER:-}" ]]; then
  INVOKER="${UID:-0}"
  # UID may be set to 0 above,
  # but it makes more sense to skip proxy for unprivileged user cgroups
  # (user.slice contains only cgroups for normal users).
  if [[ "$INVOKER" == "0" ]]; then
    INVOKER=1000
  fi
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo --preserve-env=INVOKER --preserve-env=FWMARK --preserve-env=TABLE --preserve-env=CGROUP /usr/bin/env bash "$0" "$@"
fi

INVOKER="${INVOKER:-1000}"
FWMARK="${FWMARK:-0x89}"
TABLE="${TABLE:-64}"
# systemd-run --collect --unit=noproxy --user --pty --shell
# systemd-run --collect --slice=noproxy --user --pty --shell
CGROUP="${CGROUP:-/user.slice/user-$INVOKER.slice/user@$INVOKER.service/app.slice/noproxy.service,/user.slice/user-$INVOKER.slice/user@$INVOKER.service/noproxy.slice}"

while getopts "i:f:m:t:c:g:" opt; do
  case "$opt" in
  i)
    INVOKER="$OPTARG"
    ;;
  f | m)
    FWMARK="$OPTARG"
    ;;
  t)
    TABLE="$OPTARG"
    ;;
  c | g)
    CGROUP="$OPTARG"
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done

# Make all packets with "$FWMARK" route through table "$TABLE".
if [[ -z "$(ip rule list fwmark "$FWMARK" table "$TABLE")" ]]; then
  ip rule add fwmark "$FWMARK" table "$TABLE"
fi

# Copy the default route table for the outgoing link to table "$TABLE".
default_route_table="$(ip route show default)"
ip route replace table "$TABLE" $default_route_table

# Delete some default route in this table which is created by unknown reason.
if ! ip route delete local default dev lo scope host table "$TABLE" >&/dev/null; then
  :
fi

# Set marks for sockets in certain cgroups.
sed -n 1p <<<"$CGROUP" | tr ',' '\n' | while read -r group; do
  if ! iptables -t mangle -C OUTPUT -m cgroup --path "$group" -j MARK --set-mark "$FWMARK"; then
    if ! iptables -t mangle -I OUTPUT -m cgroup --path "$group" -j MARK --set-mark "$FWMARK"; then
      :
    fi
  fi
done

# Packet may still be using the IP of the VPN interface, so masquerade them.
default_link="$(ip -j route show default | grep -E -o '"dev":\s*"([^"]*)"' | awk -F\" '{print $4}')"
iptables -t nat -A POSTROUTING -o "$default_link" -j MASQUERADE
