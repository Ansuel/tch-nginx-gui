#!/bin/sh
# Run by Transformer as root; the web worker never needs USB or shell access.
CMD=${1:-get_stats}
error() { printf 'ERROR|%s\n' "$1"; exit 1; }
ADB_BIN=$(command -v adb) || error "ADB is not installed on this router."
command -v timeout >/dev/null 2>&1 || error "The timeout utility is required."
adb() { timeout 2 "$ADB_BIN" "$@"; }
adb get-state >/dev/null 2>&1 || error "Connect one Android device and authorize USB debugging."
android_root() { adb shell "su -c '$1'"; }

case "$CMD" in
    screen) adb shell input keyevent 26 >/dev/null 2>&1 || error "Screen command failed."; exit 0 ;;
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
        [ "$(android_root "id -u" 2>/dev/null | tr -d '\r')" = 0 ] || error "VPN sharing requires Android root authorization."
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
        timeout 12 "$ADB_BIN" shell "su -c '$remote'" >/dev/null 2>&1 || error "VPN operation failed; check Android root, firewall and routing support."
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
TEL=$(adb shell dumpsys telephony.registry)
SIGNAL=$(echo "$TEL" | grep "mSignalStrength=" | grep -o "rsrp=-[0-9]\+" | tail -n 1 | cut -d'=' -f2)
[ -z "$SIGNAL" ] && SIGNAL=$(echo "$TEL" | grep "mSignalStrength=" | grep -o "dbm=-[0-9]\+" | tail -n 1 | cut -d'=' -f2)
[ -z "$SIGNAL" ] && SIGNAL=$(echo "$TEL" | grep -o "rsrp=-[0-9]\+" | tail -n 1 | cut -d'=' -f2)

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
        13|14|19) NET="4G (LTE+)" ;;
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

# Extended Radio Metrics
RSRQ=$(echo "$TEL" | grep -o "rsrq=-[0-9]\+" | tail -n 1 | cut -d'=' -f2)
SNR=$(echo "$TEL" | grep -o "rssnr=[0-9]\+" | tail -n 1 | cut -d'=' -f2)
[ "$SNR" = "2147483647" ] || [ -z "$SNR" ] && SNR="N/A"
PCI=$(echo "$TEL" | grep -o "mPhysicalCellId=[0-9]\+" | tail -n 1 | cut -d'=' -f2)
BAND=$(echo "$TEL" | grep -o "mBand=[0-9]\+" | tail -n 1 | cut -d'=' -f2)

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
TETHER_IFACE=$(adb shell ip route 2>/dev/null | grep -iE "rndis|usb|ncm" | awk '{print $3}' | head -n 1 | tr -dc 'a-zA-Z0-9')

if [ -n "$TETHER_IFACE" ]; then
    TETHER_IP=$(adb shell ip route 2>/dev/null | grep "$TETHER_IFACE" | grep "src" | awk '{print $9}' | head -n 1 | tr -d '\r')
    if [ -n "$TETHER_IP" ]; then TETHER_STATUS="Attivo ($TETHER_IFACE - IP: $TETHER_IP)"
    else TETHER_STATUS="Connesso ($TETHER_IFACE)"; fi
else TETHER_STATUS="Inattivo"; fi

V_CHECK=$(adb shell ip link 2>/dev/null | grep -iE "tun|tailscale")
RULE_CHECK=$(adb shell su -c "ip rule" 2>/dev/null | grep "29999:")
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
echo "DEV|$MANUF $MODEL"
echo "OS|Android $OS"
echo "BATT|$LEVEL%"
echo "BATT_STAT|$BATT_STAT"
echo "BATT_HEALTH|$BATT_HEALTH"
echo "VOLT|${VOLT} mV"
echo "TEMP|$TEMP_C C"
echo "OPER|$OPER"
echo "NET|$NET"
echo "SIG|$SIGNAL dBm"
echo "SIGNAL_RAW|$SIGNAL"
echo "DATA_ST|$DATA_ST"
echo "RSRQ|$RSRQ"
echo "SNR|$SNR"
echo "PCI|$PCI"
echo "BAND|${BAND:-N/A}"
echo "LOAD|$LOADAVG"
echo "MEM|$MEM"
echo "USB_STATE|$USB_STATE"
echo "TETHER|$TETHER_STATUS"
echo "VPN_SHARE|$VPN_SHARE"
echo "LED_LOG|$LED_LOG"
echo "ACTIVE_WAN|$ACTIVE_WAN"
