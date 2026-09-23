#!/bin/sh

enabled="$(uci -q get openvpn.server.enabled)"
port="$(uci -q get openvpn.server.port)"
proto="$(uci -q get openvpn.server.proto)"
allow_lan="$(uci -q get openvpn.server.allow_lan)"
start_error=0
[ "$enabled" = "1" ] || enabled=0
[ "$allow_lan" = "1" ] || allow_lan=0
[ -n "$port" ] || port=1194
case "$port" in
    *[!0-9]* | '') echo "Invalid OpenVPN port" >&2; exit 1 ;;
esac
[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 1
case "$proto" in
    udp | tcp) ;;
    *) echo "Invalid OpenVPN protocol" >&2; exit 1 ;;
esac

if [ "$enabled" = "1" ]; then
    /usr/share/transformer/scripts/openvpnGenerateKeys.sh || exit 1
    [ -c /dev/net/tun ] || { echo "TUN is unavailable" >&2; exit 1; }
    /etc/init.d/openvpn restart 1000>&- || start_error=1
    if [ "$start_error" = "0" ]; then
        for attempt in 1 2 3 4 5; do
            ip link show tun0 >/dev/null 2>&1 && break
            sleep 1
        done
        ip link show tun0 >/dev/null 2>&1 || start_error=1
    fi
    if [ "$start_error" = "1" ]; then
        echo "OpenVPN did not create tun0" >&2
        enabled=0
        uci set openvpn.server.enabled=0
        uci commit openvpn
    fi
fi

uci -q delete firewall.modgui_openvpn
uci set firewall.modgui_openvpn=rule
uci set firewall.modgui_openvpn.name='Allow-ModGUI-OpenVPN'
uci set firewall.modgui_openvpn.src='wan'
uci set firewall.modgui_openvpn.proto="$proto"
uci set firewall.modgui_openvpn.dest_port="$port"
uci set firewall.modgui_openvpn.target='ACCEPT'
uci set firewall.modgui_openvpn.enabled="$enabled"

uci -q delete firewall.modgui_openvpn_to_lan
uci -q delete firewall.modgui_openvpn_zone
if [ "$enabled" = "1" ] && [ "$allow_lan" = "1" ]; then
    uci set firewall.modgui_openvpn_zone=zone
    uci set firewall.modgui_openvpn_zone.name='modgui_openvpn'
    uci set firewall.modgui_openvpn_zone.device='tun0'
    uci set firewall.modgui_openvpn_zone.input='ACCEPT'
    uci set firewall.modgui_openvpn_zone.output='ACCEPT'
    uci set firewall.modgui_openvpn_zone.forward='REJECT'
    uci set firewall.modgui_openvpn_to_lan=forwarding
    uci set firewall.modgui_openvpn_to_lan.src='modgui_openvpn'
    uci set firewall.modgui_openvpn_to_lan.dest='lan'
fi
uci commit firewall
/etc/init.d/firewall reload >/dev/null 2>&1 || exit 1

if [ "$enabled" != "1" ]; then
    /etc/init.d/openvpn stop 1000>&- >/dev/null 2>&1 || true
fi
[ "$start_error" = "0" ]
