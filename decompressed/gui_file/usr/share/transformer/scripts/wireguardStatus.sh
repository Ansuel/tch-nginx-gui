#!/bin/sh

interface="modgui_wg0"
enabled="$(uci -q get wireguard.wg.enabled)"
port="$(uci -q get wireguard.wg.listen_port)"
[ -n "$port" ] || port=51820
running="false"
online="false"
message="Service disabled"

ip_address="$(ip -4 addr show dev "$interface" 2>/dev/null | awk '/inet / { sub("/.*", "", $2); print $2; exit }')"
[ -n "$ip_address" ] && running="true"

configured_peers=0
for section in $(uci -q show wireguard 2>/dev/null | awk -F'[.=]' '$3 == "peer" {print $2}'); do
  [ "$(uci -q get "wireguard.$section.enabled")" = "1" ] || continue
  [ -n "$(uci -q get "wireguard.$section.public_key")" ] || continue
  configured_peers=$((configured_peers + 1))
done

live_peers=0
wg_tool=""
[ -x /usr/bin/wg-go ] && wg_tool="/usr/bin/wg-go"
[ -n "$wg_tool" ] || wg_tool="$(command -v wg 2>/dev/null)"
if [ "$running" = "true" ] && [ -n "$wg_tool" ]; then
  live_peers="$("$wg_tool" show "$interface" latest-handshakes 2>/dev/null |
    awk -v now="$(date +%s)" '$2 != "" && $2 != "(never)" && now - $2 < 360 { count++ } END { print count + 0 }')"
fi
[ -n "$live_peers" ] || live_peers=0

if [ "$enabled" = "1" ]; then
  if [ "$running" != "true" ]; then
    message="Interface down"
  elif [ "$live_peers" -gt 0 ]; then
    online="true"
    message="Peers connected"
  else
    message="Waiting for peers"
  fi
fi

printf 'enabled=%s\nrunning=%s\nonline=%s\nip=%s\nport=%s\npeers=%s\nlive=%s\nmessage=%s\n' \
  "$enabled" "$running" "$online" "$ip_address" "$port" "$configured_peers" "$live_peers" "$message"
