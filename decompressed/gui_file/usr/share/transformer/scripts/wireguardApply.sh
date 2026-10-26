#!/bin/sh

enabled="$(uci -q get wireguard.wg.enabled)"
port="$(uci -q get wireguard.wg.listen_port)"
private_key="$(uci -q get wireguard.wg.private_key)"
address="$(uci -q get wireguard.wg.address)"
allow_lan="$(uci -q get wireguard.wg.allow_lan)"
allow_wan="$(uci -q get wireguard.wg.allow_wan)"

[ "$enabled" = "1" ] || enabled=0
[ "$allow_lan" = "1" ] || allow_lan=0
[ "$allow_wan" = "1" ] || allow_wan=0
[ -n "$port" ] || port=51820

valid_key() {
  [ "${#1}" -eq 44 ] || return 1
  case "$1" in
  *[!A-Za-z0-9+/=]*) return 1 ;;
  *=) return 0 ;;
  *) return 1 ;;
  esac
}

valid_ipv4() {
  old_ifs="$IFS"
  IFS=.
  set -- $1
  IFS="$old_ifs"
  [ "$#" -eq 4 ] || return 1
  for octet in "$@"; do
    case "$octet" in '' | *[!0-9]*) return 1 ;; esac
    [ "$octet" -le 255 ] || return 1
  done
}

valid_cidr() {
  cidr_ip="${1%/*}"
  cidr_prefix="${1#*/}"
  [ "$cidr_ip" != "$1" ] || return 1
  valid_ipv4 "$cidr_ip" || return 1
  case "$cidr_prefix" in '' | *[!0-9]*) return 1 ;; esac
  [ "$cidr_prefix" -le 32 ]
}

remove_network() {
  for section in $(uci -q show network 2>/dev/null | awk -F'[.=]' '$2 ~ /^modgui_wg0/ {print $2}' | sort -u); do
    uci -q delete "network.$section"
  done
  uci -q delete firewall.modgui_wireguard_udp
  uci -q delete firewall.modgui_wireguard_zone
  uci -q delete firewall.modgui_wireguard_to_lan
  uci -q delete firewall.modgui_lan_to_wireguard
  uci -q delete firewall.modgui_wireguard_to_wan
  uci commit network
  uci commit firewall
  /etc/init.d/network reload >/dev/null 2>&1
  /etc/init.d/firewall reload >/dev/null 2>&1
}

add_peer() {
  section="$1"
  index="$2"
  public_key="$(uci -q get "wireguard.$section.public_key")"
  valid_key "$public_key" || return 0
  preshared_key="$(uci -q get "wireguard.$section.preshared_key")"
  endpoint_host="$(uci -q get "wireguard.$section.endpoint_host")"
  endpoint_port="$(uci -q get "wireguard.$section.endpoint_port")"
  allowed_ips="$(uci -q get "wireguard.$section.allowed_ips")"
  keepalive="$(uci -q get "wireguard.$section.persistent_keepalive")"
  if [ -n "$endpoint_host" ]; then
    case "$endpoint_host" in *[!A-Za-z0-9.:-]*) return 0 ;; esac
  fi
  if [ -n "$endpoint_port" ]; then
    case "$endpoint_port" in *[!0-9]*) return 0 ;; esac
    [ "$endpoint_port" -ge 1 ] && [ "$endpoint_port" -le 65535 ] || return 0
  fi
  if [ -n "$keepalive" ]; then
    case "$keepalive" in *[!0-9]*) return 0 ;; esac
    [ "$keepalive" -le 320 ] || return 0
  fi
  [ -z "$preshared_key" ] || valid_key "$preshared_key" || return 0
  peer="modgui_wg0_peer$index"
  uci set "network.$peer=wireguard_modgui_wg0"
  uci set "network.$peer.public_key=$public_key"
  [ -n "$preshared_key" ] && uci set "network.$peer.preshared_key=$preshared_key"
  [ -n "$endpoint_host" ] && uci set "network.$peer.endpoint_host=$endpoint_host"
  [ -n "$endpoint_port" ] && uci set "network.$peer.endpoint_port=$endpoint_port"
  [ -n "$keepalive" ] && uci set "network.$peer.persistent_keepalive=$keepalive"
  if [ -n "$allowed_ips" ]; then
    for ip_entry in $(echo "$allowed_ips" | tr ',' ' '); do
      valid_cidr "$ip_entry" || continue
      uci add_list "network.$peer.allowed_ips=$ip_entry"
    done
  fi
  uci add_list network.modgui_wg0.peers="$peer"
  return 0
}

configure_network() {
  case "$port" in '' | *[!0-9]*) echo "Invalid WireGuard port" >&2; exit 1 ;; esac
  [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 1
  valid_key "$private_key" || {
    echo "Generate or paste a valid WireGuard private key before enabling the interface" >&2
    exit 1
  }
  ip="${address%/*}"
  prefix="${address#*/}"
  valid_cidr "$address" || { echo "Invalid tunnel address" >&2; exit 1; }

  uci -q delete network.modgui_wg0
  uci set network.modgui_wg0=interface
  uci set network.modgui_wg0.proto='wireguard'
  uci set network.modgui_wg0.private_key="$private_key"
  uci set network.modgui_wg0.listen_port="$port"
  uci add_list network.modgui_wg0.addresses="$address"

  for section in $(uci -q show network 2>/dev/null | awk -F'[.=]' '$2 ~ /^modgui_wg0_peer/ {print $2}' | sort -u); do
    uci -q delete "network.$section"
  done
  peer_index=0
  for section in $(uci -q show wireguard 2>/dev/null | awk -F'[.=]' '$3 == "peer" {print $2}' | sort -u); do
    [ "$(uci -q get "wireguard.$section.enabled")" = "1" ] || continue
    peer_index=$((peer_index + 1))
    add_peer "$section" "$peer_index"
  done

  uci -q delete firewall.modgui_wireguard_zone
  uci set firewall.modgui_wireguard_zone=zone
  uci set firewall.modgui_wireguard_zone.name='wireguard'
  uci add_list firewall.modgui_wireguard_zone.network='modgui_wg0'
  uci set firewall.modgui_wireguard_zone.input='REJECT'
  uci set firewall.modgui_wireguard_zone.output='ACCEPT'
  uci set firewall.modgui_wireguard_zone.forward='REJECT'
  uci set firewall.modgui_wireguard_zone.masq='1'
  uci set firewall.modgui_wireguard_zone.mtu_fix='1'

  uci -q delete firewall.modgui_wireguard_udp
  uci set firewall.modgui_wireguard_udp=rule
  uci set firewall.modgui_wireguard_udp.name='Allow-ModGUI-WireGuard'
  uci set firewall.modgui_wireguard_udp.src='wan'
  uci set firewall.modgui_wireguard_udp.proto='udp'
  uci set firewall.modgui_wireguard_udp.dest_port="$port"
  uci set firewall.modgui_wireguard_udp.target='ACCEPT'

  uci -q delete firewall.modgui_wireguard_to_lan
  if [ "$allow_lan" = "1" ]; then
    uci set firewall.modgui_wireguard_to_lan=forwarding
    uci set firewall.modgui_wireguard_to_lan.src='wireguard'
    uci set firewall.modgui_wireguard_to_lan.dest='lan'
  fi

  uci -q delete firewall.modgui_lan_to_wireguard

  uci -q delete firewall.modgui_wireguard_to_wan
  if [ "$allow_wan" = "1" ]; then
    uci set firewall.modgui_wireguard_to_wan=forwarding
    uci set firewall.modgui_wireguard_to_wan.src='wireguard'
    uci set firewall.modgui_wireguard_to_wan.dest='wan'
  fi

  uci commit network
  uci commit firewall
  chmod 600 /etc/config/wireguard 2>/dev/null || true
  /etc/init.d/network reload >/dev/null 2>&1 || return 1
  # netifd discovers protocol handlers only at startup. Immediately after the
  # wireguard-go package is installed, a reload can leave this new interface
  # registered as proto "none" until netifd is restarted once.
  sleep 1
  if ubus call network.interface.modgui_wg0 status 2>/dev/null | grep -q '"proto": "none"'; then
    /etc/init.d/network restart >/dev/null 2>&1 || return 1
  fi
  /etc/init.d/firewall reload >/dev/null 2>&1 || return 1
}

if [ "$enabled" != "1" ]; then
  remove_network
  exit 0
fi

if [ ! -c /dev/net/tun ] && zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_TUN=y$'; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
fi
[ -c /dev/net/tun ] || { echo "TUN is unavailable" >&2; exit 1; }
if [ ! -x /usr/bin/wireguard-go ] && ! command -v wg >/dev/null 2>&1; then
  echo "WireGuard runtime is not installed" >&2
  exit 1
fi
configure_network || exit 1
exit 0
