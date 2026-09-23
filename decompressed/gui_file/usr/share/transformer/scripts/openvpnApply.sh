#!/bin/sh

enabled="$(uci -q get openvpn.server.enabled)"
port="$(uci -q get openvpn.server.port)"
proto="$(uci -q get openvpn.server.proto)"
allow_lan="$(uci -q get openvpn.server.allow_lan)"
client_enabled="$(uci -q get openvpn.client.enabled)"
start_error=0
[ "$enabled" = "1" ] || enabled=0
[ "$client_enabled" = "1" ] || client_enabled=0
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

if [ "$client_enabled" = "1" ]; then
    client_host="$(uci -q get openvpn.client.remote_host)"
    client_port="$(uci -q get openvpn.client.remote_port)"
    client_proto="$(uci -q get openvpn.client.remote_proto)"
    client_cipher="$(uci -q get openvpn.client.client_cipher)"
    client_auth="$(uci -q get openvpn.client.client_auth)"
    client_username="$(uci -q get openvpn.client.username)"
    case "$client_host" in '' | [!a-zA-Z0-9]* | *[!a-zA-Z0-9.-]*) echo "Invalid client host" >&2; exit 1 ;; esac
    case "$client_port" in '' | *[!0-9]*) echo "Invalid client port" >&2; exit 1 ;; esac
    [ "$client_port" -ge 1 ] && [ "$client_port" -le 65535 ] || exit 1
    case "$client_proto" in udp | tcp) ;; *) echo "Invalid client protocol" >&2; exit 1 ;; esac
    case "$client_cipher" in AES-128-CBC | AES-256-CBC | BF-CBC | AES-128-GCM | AES-256-GCM) ;;
        *) echo "Invalid client cipher" >&2; exit 1 ;; esac
    openvpn --show-ciphers 2>/dev/null | grep -Fq "$client_cipher" || {
        echo "Client cipher is unavailable in this OpenVPN build" >&2; exit 1;
    }
    case "$client_auth" in SHA1 | SHA256 | SHA512) ;; *) echo "Invalid client auth digest" >&2; exit 1 ;; esac
    [ -s /etc/openvpn/modgui-client-ca.crt ] || { echo "Client CA is missing" >&2; exit 1; }
    if [ -s /etc/openvpn/modgui-client.crt ] || [ -s /etc/openvpn/modgui-client.key ]; then
        [ -s /etc/openvpn/modgui-client.crt ] && [ -s /etc/openvpn/modgui-client.key ] || {
            echo "Client certificate and key must be supplied together" >&2; exit 1;
        }
    fi
    if [ -n "$client_username" ]; then
        case "$client_username" in *[!a-zA-Z0-9_.@-]*) echo "Invalid client username" >&2; exit 1 ;; esac
        [ -s /etc/openvpn/modgui-client.password ] || { echo "Client password is missing" >&2; exit 1; }
        umask 077
        { printf '%s\n' "$client_username"; cat /etc/openvpn/modgui-client.password; printf '\n'; } > /etc/openvpn/modgui-client.auth || exit 1
    else
        rm -f /etc/openvpn/modgui-client.auth
    fi
    umask 077
    {
        printf 'client\ndev tun1\nproto %s\nremote %s %s\n' "$client_proto" "$client_host" "$client_port"
        printf 'nobind\npersist-key\npersist-tun\nresolv-retry infinite\nremote-cert-tls server\n'
        printf 'cipher %s\nauth %s\n' "$client_cipher" "$client_auth"
        printf 'route-nopull\nscript-security 2\n'
        printf 'ca /etc/openvpn/modgui-client-ca.crt\n'
        if [ -s /etc/openvpn/modgui-client.crt ]; then
            printf 'cert /etc/openvpn/modgui-client.crt\nkey /etc/openvpn/modgui-client.key\n'
        fi
        if [ -n "$client_username" ]; then
            printf 'auth-user-pass /etc/openvpn/modgui-client.auth\n'
        fi
        printf 'up "/usr/share/transformer/scripts/openvpnClientRoute.sh up"\n'
        printf 'down "/usr/share/transformer/scripts/openvpnClientRoute.sh down"\n'
        printf 'verb 3\n'
    } > /etc/openvpn/modgui-client.conf.tmp || exit 1
    mv /etc/openvpn/modgui-client.conf.tmp /etc/openvpn/modgui-client.conf || exit 1
fi

if [ "$enabled" = "1" ] || [ "$client_enabled" = "1" ]; then
    [ -c /dev/net/tun ] || { echo "TUN is unavailable" >&2; exit 1; }
    if [ "$enabled" = "1" ]; then
    /usr/share/transformer/scripts/openvpnGenerateKeys.sh || exit 1
    fi
    /etc/init.d/openvpn restart 1000>&- || start_error=1
    if [ "$start_error" = "0" ] && [ "$enabled" = "1" ]; then
        for attempt in 1 2 3 4 5; do
            ip link show tun0 >/dev/null 2>&1 && break
            sleep 1
        done
        ip link show tun0 >/dev/null 2>&1 || start_error=1
    fi
    if [ "$start_error" = "1" ] && [ "$enabled" = "1" ]; then
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
/usr/share/transformer/scripts/openvpnClientRoute.sh refresh || exit 1

if [ "$enabled" != "1" ] && [ "$client_enabled" != "1" ]; then
    /etc/init.d/openvpn stop 1000>&- >/dev/null 2>&1 || true
fi
[ "$start_error" = "0" ]
