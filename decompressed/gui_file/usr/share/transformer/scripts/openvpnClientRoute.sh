#!/bin/sh

# Only explicitly selected, isolated Wi-Fi networks may be routed through
# this client. The main LAN and the router's default route are never changed.
state=/var/run/modgui-openvpn-client-routes
filter_chain=MODGUI_OVPN_FWD
nat_chain=MODGUI_OVPN_NAT
device=tun1
route_action="$1"
mkdir -p /var/lock
exec 9>/var/lock/modgui-openvpn-client.lock
if command -v flock >/dev/null 2>&1; then flock -x 9 || exit 1; fi

delete_rules() {
    if [ -f "$state" ]; then
        while read -r priority subnet table; do
            [ -n "$priority" ] || continue
            ip rule del pref "$priority" from "$subnet" table "$table" 2>/dev/null || true
            ip route flush table "$table" 2>/dev/null || true
        done < "$state"
    fi
    rm -f "$state"
    while iptables -C FORWARD -j "$filter_chain" 2>/dev/null; do
        iptables -D FORWARD -j "$filter_chain" || break
    done
    while iptables -t nat -C POSTROUTING -j "$nat_chain" 2>/dev/null; do
        iptables -t nat -D POSTROUTING -j "$nat_chain" || break
    done
    iptables -F "$filter_chain" 2>/dev/null || true
    iptables -X "$filter_chain" 2>/dev/null || true
    iptables -t nat -F "$nat_chain" 2>/dev/null || true
    iptables -t nat -X "$nat_chain" 2>/dev/null || true
}

guest_subnet() {
    local iface="$1" network address mask result network_ip prefix zone networks isolated
    network="$(uci -q get wireless."$iface".network)"
    case "$network" in *[!a-zA-Z0-9_]* | '') return 1 ;; esac
    [ "$network" != lan ] || return 1
    [ "$(uci -q get network."$network".proto)" = static ] || return 1
    isolated=0
    for zone in $(uci -q show firewall | sed -n 's/^firewall\.\([a-zA-Z0-9_]*\)=zone$/\1/p'); do
        networks="$(uci -q get firewall."$zone".network)"
        case " $networks " in
            *" $network "*)
                [ "$(uci -q get firewall."$zone".input)" != ACCEPT ] &&
                    [ "$(uci -q get firewall."$zone".forward)" != ACCEPT ] && isolated=1
                ;;
        esac
    done
    [ "$isolated" = 1 ] || return 1
    address="$(uci -q get network."$network".ipaddr)"
    mask="$(uci -q get network."$network".netmask)"
    [ -n "$address" ] && [ -n "$mask" ] || return 1
    result="$(ipcalc.sh "$address" "$mask")" || return 1
    network_ip="$(printf '%s\n' "$result" | sed -n 's/^NETWORK=//p')"
    prefix="$(printf '%s\n' "$result" | sed -n 's/^PREFIX=//p')"
    case "$network_ip/$prefix" in *[!0-9./]* | / | */) return 1 ;; esac
    echo "$network_ip/$prefix"
}

add_guest() {
    local iface="$1" priority="$2" table="$3" subnet
    case "$iface" in *[!a-zA-Z0-9_]* | '') echo "Guest interface unavailable" >&2; return 1 ;; esac
    [ "$(uci -q get wireless."$iface")" = wifi-iface ] || return 1
    [ "$(uci -q get wireless."$iface".mode)" = ap ] || return 1
    subnet="$(guest_subnet "$iface")" || { echo "Guest subnet unavailable" >&2; return 1; }
    ip rule show | grep -q "^$priority:" && { echo "Routing priority $priority is in use" >&2; return 1; }
    ip route show table "$table" | grep -q . && { echo "Routing table $table is in use" >&2; return 1; }
    echo "$priority $subnet $table" >> "$state"
    ip route add unreachable default table "$table" || return 1
    ip rule add pref "$priority" from "$subnet" table "$table" || return 1
    if [ "$route_action" != down ] && ip link show "$device" >/dev/null 2>&1; then
        ip route replace default dev "$device" table "$table" || return 1
    fi
    iptables -I "$filter_chain" 1 -i "$iface" -o "$device" -j ACCEPT || return 1
    iptables -t nat -A "$nat_chain" -s "$subnet" -o "$device" -j MASQUERADE || return 1
}

case "$1" in up | down | refresh) ;; *) exit 1 ;; esac
delete_rules
[ "$(uci -q get openvpn.client.enabled)" = "1" ] || exit 0
iptables -N "$filter_chain" 2>/dev/null || exit 1
iptables -t nat -N "$nat_chain" 2>/dev/null || { delete_rules; exit 1; }
iptables -I FORWARD 1 -j "$filter_chain" || { delete_rules; exit 1; }
iptables -t nat -I POSTROUTING 1 -j "$nat_chain" || { delete_rules; exit 1; }
selected="$(uci -q show openvpn.client | sed -n "s/^openvpn\.client\.ssid_\([a-zA-Z0-9_]*\)='1'$/\1/p")"
for iface in $selected; do
    [ "$(uci -q get wireless."$iface")" = wifi-iface ] || continue
    iptables -A "$filter_chain" -i "$iface" -j REJECT || exit 1
done
index=0
for iface in $selected; do
    [ "$index" -lt 32 ] || exit 1
    add_guest "$iface" "$((21010 + index))" "$((10010 + index))" || exit 1
    index=$((index + 1))
done
exit 0
