#!/bin/sh
# Run by Transformer as root; the web worker never needs USB or shell access.
CMD=${1:-get_stats}
error() {
    printf 'ERROR|%s\n' "$1"
    [ -z "${2:-}" ] || printf 'ERROR_CODE|%s\n' "$2"
    [ -z "$usb_info" ] || printf '%s\n' "$usb_info"
    [ -z "$host_info" ] || printf '%s\n' "$host_info"
    exit 1
}
# USB discovery is independent of ADB authorization. Recognize ADB and USB
# network functions, not unrelated disks, printers or USB controller hubs.
usb_diagnostics() {
    for usb in /sys/bus/usb/devices/*; do
        [ -f "$usb/idVendor" ] || continue
        candidate=0
        usb_adb=0
        usb_network=0
        for interface in "$usb":*; do
            [ -r "$interface/bInterfaceClass" ] || continue
            read -r class < "$interface/bInterfaceClass"
            read -r subclass < "$interface/bInterfaceSubClass"
            read -r protocol < "$interface/bInterfaceProtocol"
            case "$class:$subclass:$protocol" in
                ff:42:01) candidate=1; usb_adb=1 ;;
                e0:01:03|ef:04:01|ef:01:01|02:02:ff|02:06:00|02:0d:00) candidate=1; usb_network=1 ;;
            esac
        done
        [ "$candidate" = 1 ] || continue
        product=$(tr '\r\n|' '   ' < "$usb/product" 2>/dev/null | cut -c1-120 | sed 's/[[:space:]]*$//')
        [ -n "$product" ] || product="USB device"
        printf 'USB_DEV|%s\nUSB_ADB|%s\nUSB_NETWORK|%s\n' "$product" "$usb_adb" "$usb_network"
        speed=$(cat "$usb/speed" 2>/dev/null)
        case "$speed" in ''|*[!0-9.]*) ;; *) printf 'USB_SPEED|%s\n' "$speed" ;; esac
        # Only report interfaces belonging to this USB device, never eth0/WAN.
        for net in "$usb":*/net/*; do
            [ -d "$net" ] || continue
            iface=${net##*/}
            case "$iface" in ''|*[!a-zA-Z0-9_.-]*) continue ;; esac
            printf 'HOST_IF|%s\n' "$iface"
            flags=$(cat "$net/flags" 2>/dev/null)
            case "$flags" in
                0x[0-9a-fA-F]*) if [ "$((flags & 1))" -eq 1 ]; then echo 'HOST_ADMIN|up'; else echo 'HOST_ADMIN|down'; fi ;;
            esac
            carrier=$(cat "$net/carrier" 2>/dev/null)
            case "$carrier" in 0|1) printf 'HOST_CARRIER|%s\n' "$carrier" ;; esac
            ip -o -4 addr show dev "$iface" 2>/dev/null | awk '$3 == "inet" {print "HOST_IPV4|" $4; exit}'
            ip -4 route show dev "$iface" 2>/dev/null | awk '$1 == "default" && $2 == "via" {print "HOST_GATEWAY|" $3; exit}'
            break
        done
        return
    done
}
usb_info=$(usb_diagnostics)
host_diagnostics() {
    modules=""
    for module in usbnet cdc_ether rndis_host cdc_ncm; do
        [ ! -d "/sys/module/$module" ] || modules="${modules:+$modules, }$module"
    done
    [ -z "$modules" ] || printf 'HOST_MODULES|%s\n' "$modules"
    if [ -f /etc/modgui-smartphone-drivers.status ]; then
        printf 'HOST_DRIVER_STATUS|'
        tr '\r\n|' '   ' < /etc/modgui-smartphone-drivers.status
        printf '\n'
    fi
}
host_info=$(host_diagnostics)
ADB_BIN=$(command -v adb) || error "ADB is not installed on this router." adb_missing
command -v timeout >/dev/null 2>&1 || error "The timeout utility is required."
# Old Technicolor BusyBox uses timeout -t SECS; newer versions use SECS.
case "$(timeout --help 2>&1)" in
    *"-t SECS"*) timed() { timeout -t "$@"; } ;;
    *) timed() { timeout "$@"; } ;;
esac
adb() { timed 2 "$ADB_BIN" "$@"; }
# Inspect transports before get-state: its failure alone cannot distinguish
# missing devices, an unaccepted RSA key, offline transports or multiple phones.
devices=$(adb devices 2>/dev/null) || error "Unable to query ADB devices." adb_error
states=$(printf '%s\n' "$devices" | awk 'NF >= 2 && $1 != "List" && $1 !~ /^\*/ {print $2}')
count=$(printf '%s\n' "$states" | awk 'NF {n++} END {print n+0}')
if [ "$count" -eq 0 ]; then
    [ -z "$usb_info" ] || error "USB device detected, but ADB is unavailable. Enable USB debugging on the phone and reconnect it." usb_only
    error "No Android device detected by ADB. Connect the phone and enable USB debugging." no_device
fi
[ "$count" -eq 1 ] || error "Multiple ADB devices detected. Connect only one Android device." multiple_devices
case "$states" in
    unauthorized) error "ADB is not authorized. Unlock the phone and authorize USB debugging for this router." unauthorized ;;
    offline) error "The ADB device is offline. Reconnect the USB cable and check USB debugging." offline ;;
    device) ;;
    *) error "The ADB device is unavailable. Check USB permissions and USB debugging." adb_error ;;
esac
adb get-state >/dev/null 2>&1 || error "ADB connection failed. Reconnect the phone and check USB debugging." adb_error
android_shell() {
    # ADB 1.0.32 does not propagate Android shell exit codes. Read our marker
    # instead, including when su is absent or authorization is rejected.
    shell_output=$(timed "${2:-2}" "$ADB_BIN" shell "$1; printf '\nTCH_STATUS|%s\n' \"\$?\"") || return 1
    shell_output=$(printf '%s\n' "$shell_output" | tr -d '\r')
    shell_status=$(printf '%s\n' "$shell_output" | tail -n 1)
    [ "$shell_status" = 'TCH_STATUS|0' ] || return 1
    printf '%s\n' "$shell_output" | sed '$d'
}
android_root() { android_shell "su -c '$1'" "${2:-2}"; }
has_root() { [ "$(android_root "id -u" 2>/dev/null | tr -d '\r')" = 0 ]; }

capture_screen() {
    screen_dir=/var/run/modgui-smartphone-screen
    remote_image=/data/local/tmp/tch-screen-$$.png
    # Only nginx's group can read the frame, through the authenticated image page.
    (umask 027; mkdir -p "$screen_dir") || error "Unable to prepare screen capture."
    chown root:nogroup "$screen_dir" && chmod 750 "$screen_dir" || error "Unable to protect screen capture."
    screen_tmp=$(mktemp "$screen_dir/.capture.XXXXXX") || error "Unable to prepare screen capture."
    cleanup_screen() {
        adb shell rm -f "$remote_image" >/dev/null 2>&1
        rm -f "$screen_tmp"
    }
    trap cleanup_screen EXIT
    trap 'exit 1' HUP INT TERM
    android_shell "umask 077; screencap -p $remote_image" 5 >/dev/null 2>&1 || error "Unable to capture the display. Wake the phone and try again."
    timed 8 "$ADB_BIN" pull "$remote_image" "$screen_tmp" >/dev/null 2>&1 || error "Unable to transfer the screen capture."
    signature=$(head -c 8 "$screen_tmp" | base64 | tr -d '\r\n')
    size=$(wc -c < "$screen_tmp")
    [ "$signature" = iVBORw0KGgo= ] && [ "$size" -le 8388608 ] || error "Invalid or oversized screen capture."
    chown root:nogroup "$screen_tmp" && chmod 640 "$screen_tmp" || error "Unable to protect screen capture."
    mv -f "$screen_tmp" "$screen_dir/frame.png" || error "Unable to publish screen capture."
    echo "SUCCESS|Screen captured."
}

case "$CMD" in
    screen_wake) android_shell "input keyevent 224" >/dev/null 2>&1 || error "Unable to wake the display."; exit 0 ;;
    screen_sleep) android_shell "input keyevent 223" >/dev/null 2>&1 || error "Unable to turn off the display."; exit 0 ;;
    capture_screen) capture_screen; exit 0 ;;
    reboot) adb reboot >/dev/null 2>&1 || error "Reboot command failed."; exit 0 ;;
    reconnect_data|data_on|data_off)
        case "$CMD" in
            reconnect_data) action="svc data disable && sleep 1 && svc data enable" ;;
            data_on) action="svc data enable" ;;
            data_off) action="svc data disable" ;;
        esac
        android_root "$action" >/dev/null 2>&1 || error "Mobile data control requires Android root authorization."
        exit 0 ;;
    start_vpn|stop_vpn)
        has_root || error "VPN sharing requires Android root authorization."
        T=""; V=""
        if [ "$CMD" = start_vpn ]; then
            T=$(adb shell ip -4 route | awk '/dev (rndis|usb|ncm)/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}' | tr -d '\r')
            V=$(adb shell ip link | awk -F': ' '/^[0-9]+: (tun|tailscale)/ {print $2; exit}' | cut -d@ -f1 | cut -d: -f1 | tr -d '\r')
            case "$T" in ""|*[!a-zA-Z0-9_.-]*) error "USB tether interface not found." ;; esac
            case "$V" in ""|*[!a-zA-Z0-9_.-]*) error "VPN tunnel interface not found." ;; esac
        fi
        # Own chains and a dedicated policy/table make retries and teardown symmetric.
        # Never flush unrelated Android chains or VPN provider rules.
        remote="
cleanup() {
    failed=0
    if ip rule show | grep -E \"^29999:.*lookup 29999( |$)\" >/dev/null; then
        ip rule del pref 29999 lookup 29999 || failed=1
    fi
    while iptables -t nat -C POSTROUTING -j TCH_PHONE_NAT 2>/dev/null; do
        iptables -t nat -D POSTROUTING -j TCH_PHONE_NAT || { failed=1; break; }
    done
    while iptables -C FORWARD -j TCH_PHONE_FWD 2>/dev/null; do
        iptables -D FORWARD -j TCH_PHONE_FWD || { failed=1; break; }
    done
    if iptables -t nat -S TCH_PHONE_NAT >/dev/null 2>&1; then
        iptables -t nat -F TCH_PHONE_NAT && iptables -t nat -X TCH_PHONE_NAT || failed=1
    fi
    if iptables -S TCH_PHONE_FWD >/dev/null 2>&1; then
        iptables -F TCH_PHONE_FWD && iptables -X TCH_PHONE_FWD || failed=1
    fi
    ip route flush table 29999 || failed=1
    return \$failed
}
"
        # Stop does not require the USB interface, which may already be disconnected.
        remote="$remote
rules=\$(ip rule show)
if echo \"\$rules\" | grep -q \"^29999:\" && ! echo \"\$rules\" | grep \"^29999:\" | grep -qE \"lookup 29999( |$)\"; then exit 1; fi
if [ -n \"\$(ip route show table 29999 2>/dev/null)\" ] && ! echo \"\$rules\" | grep \"^29999:\" | grep -qE \"lookup 29999( |$)\"; then exit 1; fi
cleanup || exit 1
"
        if [ "$CMD" = start_vpn ]; then
            remote="$remote
trap cleanup EXIT
iptables -t nat -N TCH_PHONE_NAT &&
iptables -N TCH_PHONE_FWD &&
iptables -t nat -A TCH_PHONE_NAT -o $V -j MASQUERADE &&
iptables -A TCH_PHONE_FWD -i $T -o $V -j ACCEPT &&
iptables -A TCH_PHONE_FWD -i $V -o $T -m state --state RELATED,ESTABLISHED -j ACCEPT &&
iptables -t nat -I POSTROUTING -j TCH_PHONE_NAT &&
iptables -I FORWARD -j TCH_PHONE_FWD &&
ip route add default dev $V table 29999 &&
ip rule add iif $T lookup 29999 pref 29999 || exit 1
trap - EXIT
"
        fi
        # Give the bounded compound transaction enough time to finish or roll back.
        android_root "$remote" 12 >/dev/null 2>&1 || error "VPN operation failed; check Android root, firewall and routing support."
        echo "SUCCESS|VPN operation completed."
        exit 0 ;;
    get_peers)
        OUT=$(android_root "/data/data/com.tailscale.ipn/files/tailscale status" 2>/dev/null) || error "Tailscale status is unavailable on this phone."
        printf '%s\n' "$OUT"
        exit 0 ;;
    get_stats) ;;
    *) error "Unsupported action." ;;
esac

BATTERY=$(adb shell dumpsys battery 2>/dev/null) || error "Android battery service is unavailable."

# Parse Battery Data
LEVEL=$(echo "$BATTERY" | grep -E "^ *level:" | awk '{print $2}' | tr -d '\r')
TEMP_RAW=$(echo "$BATTERY" | grep -E "^ *temperature:" | awk '{print $2}' | tr -d '\r')
VOLT=$(echo "$BATTERY" | grep -E "^ *voltage:" | awk '{print $2}' | tr -d '\r')
STATUS=$(echo "$BATTERY" | grep -E "^ *status:" | awk '{print $2}' | tr -d '\r')
HEALTH=$(echo "$BATTERY" | grep -E "^ *health:" | awk '{print $2}' | tr -d '\r')

TEMP_C=$(printf '%s\n' "$TEMP_RAW" | awk '/^-?[0-9]+$/ {print $1 / 10}')
[ -n "$TEMP_C" ] || TEMP_C="N/A"

case "$STATUS" in 2) BATT_STAT="In Carica" ;; 3) BATT_STAT="In Uso" ;; 4) BATT_STAT="Non in carica" ;; 5) BATT_STAT="Carica (100%)" ;; *) BATT_STAT="Sconosciuto" ;; esac
case "$HEALTH" in 2) BATT_HEALTH="Buona" ;; 3) BATT_HEALTH="Surriscaldata" ;; 4) BATT_HEALTH="Morta" ;; 5) BATT_HEALTH="Sovratensione" ;; 7) BATT_HEALTH="Fredda" ;; *) BATT_HEALTH="Sconosciuta" ;; esac

# Parse Telephony Data
RADIO_AWK=/usr/share/modgui-smartphone/radio.awk
TEL=$(adb shell dumpsys telephony.registry | tr -d '\r')
SDK=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
case "$SDK" in ''|*[!0-9]*) SDK=0 ;; esac
RADIO=$(printf '%s\n' "$TEL" | awk -v mode=metrics -v sdk="$SDK" -f "$RADIO_AWK")
TEL=$(printf '%s\n' "$TEL" | awk -v mode=select -f "$RADIO_AWK")
radio_value() {
    printf '%s\n' "$RADIO" | awk -F '|' -v key="$1" '$1 == key {print $2; exit}'
}
SIGNAL=$(radio_value SIGNAL_RAW)

TECH=$(echo "$TEL" | grep -o "getRilDataRadioTechnology=[0-9]*" | tail -n 1 | cut -d'=' -f2)
IS_5G=$(echo "$TEL" | grep -iE "nrState=CONNECTED")
if echo "$TEL" | grep -q "mDataConnectionState=2"; then DATA_ST="1"; else DATA_ST="0"; fi

NET_OVERRIDE=$(echo "$TEL" | grep "TelephonyDisplayInfo" | tail -n 1 | grep -o "override=[A-Z_]*" | cut -d'=' -f2)
if [ "$TECH" = "20" ]; then
    NET="5G (SA)"
elif [ "$NET_OVERRIDE" = "NR_NSA" ] || [ "$NET_OVERRIDE" = "NR_ADVANCED" ] || [ -n "$IS_5G" ]; then
    NET="5G (NSA)"
else
    case "$TECH" in
        14) NET="4G (LTE)" ;;
        19) NET="4G (LTE+)" ;;
        13) NET="3G (eHRPD)" ;;
        0|"") NET="N/A" ;;
        *) NET="4G/3G" ;;
    esac
fi

# Extract Operator Name
OPER=$(echo "$TEL" | grep -o "mOperatorAlphaLong=[^,]*" | grep -v "null" | tail -n 1 | cut -d'=' -f2)
if [ -z "$OPER" ] || [ "$OPER" = "" ]; then
    OPER=$(adb shell getprop gsm.operator.alpha | tr -d '\r[]' | awk -F',' '{if($1!="") print $1; else print $2}')
fi
OPER=$(echo "$OPER" | xargs)

if [ -z "$OPER" ] || [ "$OPER" = "" ]; then
    OPER="No SIM"
    if [ "$SIGNAL" = "N/A" ] || [ -z "$SIGNAL" ]; then NET="N/A"; fi
fi

LED_LOG="Managed by router"

# Hardware & System Info
MANUF=$(adb shell getprop ro.product.manufacturer)
MODEL=$(adb shell getprop ro.product.model)
OS=$(adb shell getprop ro.build.version.release)

LOADAVG=$(adb shell cat /proc/loadavg | awk '{print $1", "$2", "$3}')
MEM_TOTAL=$(adb shell cat /proc/meminfo | grep MemTotal | awk '{print $2}' | tr -d '\r')
MEM_FREE=$(adb shell cat /proc/meminfo | grep MemAvailable | awk '{print $2}' | tr -d '\r')
[ -z "$MEM_FREE" ] && MEM_FREE=$(adb shell cat /proc/meminfo | grep MemFree | awk '{print $2}' | tr -d '\r')
if [ -n "$MEM_TOTAL" ] && [ -n "$MEM_FREE" ]; then
    MEM_TOTAL_MB=$((MEM_TOTAL / 1024))
    MEM_FREE_MB=$((MEM_FREE / 1024))
    MEM="${MEM_FREE_MB} MB liberi su ${MEM_TOTAL_MB} MB"
else MEM="N/A"; fi

# Interface States
USB_STATE=$(adb shell getprop sys.usb.state | tr -d '\r')
TETHER_IFACE=$(adb shell ip -4 route 2>/dev/null | awk '/dev (rndis|usb|ncm)/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}' | tr -d '\r')
case "$TETHER_IFACE" in *[!a-zA-Z0-9_.-]*) TETHER_IFACE="" ;; esac

if [ -n "$TETHER_IFACE" ]; then
    TETHER_ADDR=$(adb shell ip -4 addr show dev "$TETHER_IFACE" 2>/dev/null)
    TETHER_IP=$(printf '%s\n' "$TETHER_ADDR" | awk '/inet / {print $2; exit}' | cut -d/ -f1 | tr -d '\r')
    if ! printf '%s\n' "$TETHER_ADDR" | head -n 1 | grep -qE 'LOWER_UP|state UP'; then
        TETHER_STATUS="Configurato, collegamento inattivo ($TETHER_IFACE)"
    elif [ -n "$TETHER_IP" ]; then TETHER_STATUS="Attivo ($TETHER_IFACE - IP: $TETHER_IP)"
    else TETHER_STATUS="Connesso ($TETHER_IFACE)"; fi
else TETHER_STATUS="Inattivo"; fi

V_CHECK=$(adb shell ip link 2>/dev/null | grep -iE "tun|tailscale")
ROOT_ACCESS=0
TAILSCALE_CLI=0
RULE_CHECK=""
if has_root; then
    ROOT_ACCESS=1
    RULE_CHECK=$(android_root "ip rule" 2>/dev/null | grep "29999:")
    android_root "test -x /data/data/com.tailscale.ipn/files/tailscale" >/dev/null 2>&1 && TAILSCALE_CLI=1
fi
SCREEN_CAPTURE=0
command -v base64 >/dev/null 2>&1 && android_shell "command -v screencap >/dev/null" >/dev/null 2>&1 && SCREEN_CAPTURE=1
if [ -n "$V_CHECK" ] && echo "$RULE_CHECK" | grep -q "29999:"; then VPN_SHARE="Attiva"; else VPN_SHARE="Inattiva"; fi

# Gateway Route Analysis
ACTIVE_GW=$(ip route show default 2>/dev/null | head -n 1 | grep -oE "dev [a-z0-9]+" | awk '{print $2}' | tr -d '\r')
if [ "$ACTIVE_GW" = "usb0" ]; then
    ACTIVE_WAN="Smartphone (Priorita Alta)"
elif echo "$ACTIVE_GW" | grep -qE "wwan|rmnet|usb1"; then
    ACTIVE_WAN="Chiavetta 4G (Backup)"
elif [ -n "$ACTIVE_GW" ]; then
    ACTIVE_WAN="Router ($ACTIVE_GW)"
else
    ACTIVE_WAN="Nessuna Connessione"
fi

# Print final payload
[ -z "$usb_info" ] || printf '%s\n' "$usb_info"
[ -z "$host_info" ] || printf '%s\n' "$host_info"
echo "DEV|$MANUF $MODEL"
echo "OS|Android $OS"
echo "BATT|$LEVEL%"
echo "BATT_STAT|$BATT_STAT"
echo "BATT_HEALTH|$BATT_HEALTH"
echo "VOLT|${VOLT} mV"
echo "TEMP|$TEMP_C C"
echo "OPER|$OPER"
echo "NET|$NET"
if [ -n "$SIGNAL" ] && [ "$SIGNAL" != "N/A" ]; then echo "SIG|$SIGNAL dBm"; else echo "SIG|N/A"; fi
echo "DATA_ST|$DATA_ST"
printf '%s\n' "$RADIO"
echo "LOAD|$LOADAVG"
echo "MEM|$MEM"
echo "USB_STATE|$USB_STATE"
echo "TETHER|$TETHER_STATUS"
echo "VPN_SHARE|$VPN_SHARE"
echo "LED_LOG|$LED_LOG"
echo "ACTIVE_WAN|$ACTIVE_WAN"
echo "ROOT_ACCESS|$ROOT_ACCESS"
echo "TAILSCALE_CLI|$TAILSCALE_CLI"
echo "SCREEN_CAPTURE|$SCREEN_CAPTURE"
