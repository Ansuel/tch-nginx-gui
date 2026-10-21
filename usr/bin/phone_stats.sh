#!/bin/sh
# Extract telemetry data from tethered Android devices for GUI integration

# Sanitize input arguments
CMD=$(echo "$1" | tr -d '\r')

# ================= SPECIAL ACTIONS (VPN & PEERS) =================
if [ "$CMD" = "start_vpn" ]; then
    T=$(adb shell ip route 2>/dev/null | grep -iE "rndis|usb|ncm" | awk '{print $3}' | head -n 1 | tr -dc 'a-zA-Z0-9')
    V=$(adb shell ip link 2>/dev/null | grep -E "^[0-9]+:" | awk '{print $2}' | cut -d: -f1 | cut -d@ -f1 | grep -iE "^tun|^tailscale" | head -n 1 | tr -dc 'a-zA-Z0-9')

    if [ -z "$T" ]; then echo "ERRORE: Tether USB non trovato."; exit 0; fi
    if [ -z "$V" ]; then echo "ERRORE: VPN non trovata."; exit 0; fi

    # Clear previous rules
    adb shell su -c "ip rule del pref 9999" 2>/dev/null
    adb shell su -c "ip route flush table 99" 2>/dev/null

    # Setup NAT and forwarding
    adb shell su -c "iptables -t nat -I POSTROUTING -o $V -j MASQUERADE" 2>/dev/null
    adb shell su -c "iptables -I FORWARD -i $T -o $V -j ACCEPT" 2>/dev/null
    adb shell su -c "iptables -I FORWARD -i $V -o $T -m state --state RELATED,ESTABLISHED -j ACCEPT" 2>/dev/null

    # Route traffic through VPN
    adb shell su -c "ip route add default dev $V table 99" 2>/dev/null
    adb shell su -c "ip rule add iif $T lookup 99 pref 9999" 2>/dev/null

    echo "SUCCESSO: Traffico condiviso ($T -> $V) completato!"
    exit 0
fi

if [ "$CMD" = "stop_vpn" ]; then
    adb shell su -c "ip rule del pref 9999" 2>/dev/null
    adb shell su -c "ip route flush table 99" 2>/dev/null
    echo "SUCCESSO: Condivisione VPN disattivata."
    exit 0
fi

if [ "$CMD" = "get_peers" ]; then
    OUT=$(adb shell su -c "/data/data/com.tailscale.ipn/files/tailscale status" 2>&1)
    if echo "$OUT" | grep -qE "not found|inaccessible|No such file"; then
        LOCAL_IP=$(adb shell ip -4 addr show dev tun0 2>/dev/null | grep inet | awk '{print $2}')
        if [ -n "$LOCAL_IP" ]; then
            OUT="Tunnel ATTIVO con IP: $LOCAL_IP\n(Dispositivi nascosti da Android)"
        else
            OUT="Nessun tunnel Tailscale attivo."
        fi
    fi
    echo "$OUT"
    exit 0
fi

# ================= TELEMETRY DATA GATHERING =================

BATTERY=$(adb shell timeout 2 dumpsys battery 2>/dev/null)
if [ $? -ne 0 ]; then
    # Fallback: Smartphone not found, check 4G Dongle status
    LED_GREEN="broadband:green"
    LED_ORANGE="broadband:orange"

    set_led_on() {
        if [ -d "/sys/class/leds/$1" ]; then
            echo none > "/sys/class/leds/$1/trigger" 2>/dev/null
            MAX_B=$(cat "/sys/class/leds/$1/max_brightness" 2>/dev/null)
            [ -z "$MAX_B" ] && MAX_B=255
            echo "$MAX_B" > "/sys/class/leds/$1/brightness" 2>/dev/null
        fi
    }
    
    set_led_off() {
        if [ -d "/sys/class/leds/$1" ]; then
            echo none > "/sys/class/leds/$1/trigger" 2>/dev/null
            echo 0 > "/sys/class/leds/$1/brightness" 2>/dev/null
        fi
    }

    DONGLE_IP=$(ubus call network.interface.mobiled status 2>/dev/null | grep '"up": true')
    IFACE_WWAN=$(ifconfig wwan0 2>/dev/null | grep "inet ")
    IFACE_USB=$(ifconfig usb0 2>/dev/null | grep "inet ")
    REAL_WWAN_IP=$(ip -4 addr show dev wwan0 2>/dev/null | grep inet | awk '{print $2}')

    if [ -n "$DONGLE_IP" ] || [ -n "$IFACE_WWAN" ] || [ -n "$IFACE_USB" ] || [ -n "$REAL_WWAN_IP" ]; then
        set_led_off "$LED_GREEN"
        set_led_on "$LED_ORANGE"
    else
        set_led_off "$LED_GREEN"
        set_led_off "$LED_ORANGE"
    fi

    echo "BATT|Disconnesso"
    exit 0
fi

# Parse Battery Data
LEVEL=$(echo "$BATTERY" | grep -E "^ *level:" | awk '{print $2}')
TEMP_RAW=$(echo "$BATTERY" | grep -E "^ *temperature:" | awk '{print $2}')
VOLT=$(echo "$BATTERY" | grep -E "^ *voltage:" | awk '{print $2}')
STATUS=$(echo "$BATTERY" | grep -E "^ *status:" | awk '{print $2}')
HEALTH=$(echo "$BATTERY" | grep -E "^ *health:" | awk '{print $2}')

[ -n "$TEMP_RAW" ] && TEMP_C=$(awk "BEGIN {print $TEMP_RAW / 10}") || TEMP_C="N/A"

case "$STATUS" in 2) BATT_STAT="In Carica" ;; 3) BATT_STAT="In Uso" ;; 4) BATT_STAT="Non in carica" ;; 5) BATT_STAT="Carica (100%)" ;; *) BATT_STAT="Sconosciuto" ;; esac
case "$HEALTH" in 2) BATT_HEALTH="Buona" ;; 3) BATT_HEALTH="Surriscaldata" ;; 4) BATT_HEALTH="Morta" ;; 5) BATT_HEALTH="Sovratensione" ;; 7) BATT_HEALTH="Fredda" ;; *) BATT_HEALTH="Sconosciuta" ;; esac

# Parse Telephony Data
TEL=$(adb shell dumpsys telephony.registry)
SIGNAL=$(echo "$TEL" | grep "mSignalStrength=" | grep -o "rsrp=-[0-9]\+" | tail -n 1 | cut -d'=' -f2)
[ -z "$SIGNAL" ] && SIGNAL=$(echo "$TEL" | grep "mSignalStrength=" | grep -o "dbm=-[0-9]\+" | tail -n 1 | cut -d'=' -f2)
[ -z "$SIGNAL" ] && SIGNAL=$(echo "$TEL" | grep -o "rsrp=-[0-9]\+" | tail -n 1 | cut -d'=' -f2)

TECH=$(echo "$TEL" | grep -o "getRilDataRadioTechnology=[0-9]*" | tail -n 1 | cut -d'=' -f2)
IS_5G=$(echo "$TEL" | grep -iE "nrState=CONNECTED|CellSignalStrengthNr")
if echo "$TEL" | grep -q "mDataConnectionState=2"; then DATA_ST="1"; else DATA_ST="0"; fi

NET_OVERRIDE=$(echo "$TEL" | grep "TelephonyDisplayInfo" | tail -n 1 | grep -o "override=[A-Z_]*" | cut -d'=' -f2)
if [ "$NET_OVERRIDE" = "NR_NSA" ] || [ -n "$IS_5G" ]; then
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

# Manage LEDs based on Network Technology
LED_GREEN="broadband:green"
LED_ORANGE="broadband:orange"

set_led_on() {
    if [ -d "/sys/class/leds/$1" ]; then
        echo none > "/sys/class/leds/$1/trigger" 2>/dev/null
        MAX_B=$(cat "/sys/class/leds/$1/max_brightness" 2>/dev/null)
        [ -z "$MAX_B" ] && MAX_B=255
        echo "$MAX_B" > "/sys/class/leds/$1/brightness" 2>/dev/null
    fi
}

set_led_off() {
    if [ -d "/sys/class/leds/$1" ]; then
        echo none > "/sys/class/leds/$1/trigger" 2>/dev/null
        echo 0 > "/sys/class/leds/$1/brightness" 2>/dev/null
    fi
}

if echo "$NET" | grep -q "5G"; then
    set_led_off "$LED_ORANGE"
    set_led_on "$LED_GREEN"
    LED_LOG="Acceso Verde (5G)"
elif echo "$NET" | grep -qE "4G|3G"; then
    set_led_off "$LED_GREEN"
    set_led_on "$LED_ORANGE"
    LED_LOG="Acceso Arancione (4G/3G)"
else
    set_led_off "$LED_GREEN"
    set_led_off "$LED_ORANGE"
    LED_LOG="Spento tutto (Nessuna Rete)"
fi

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
MEM_TOTAL=$(adb shell cat /proc/meminfo | grep MemTotal | awk '{print $2}')
MEM_FREE=$(adb shell cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
[ -z "$MEM_FREE" ] && MEM_FREE=$(adb shell cat /proc/meminfo | grep MemFree | awk '{print $2}')
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
RULE_CHECK=$(adb shell su -c "ip rule" 2>/dev/null | grep "9999:")
if [ -n "$V_CHECK" ] && echo "$RULE_CHECK" | grep -q "9999:"; then VPN_SHARE="Attiva"; else VPN_SHARE="Inattiva"; fi

# Gateway Route Analysis
ACTIVE_GW=$(ip route show default 2>/dev/null | head -n 1 | grep -oE "dev [a-z0-9]+" | awk '{print $2}')
if [ "$ACTIVE_GW" = "usb0" ]; then
    ACTIVE_WAN="Smartphone (Priorita Alta)"
elif echo "$ACTIVE_GW" | grep -qE "wwan|rmnet|usb1"; then
    ACTIVE_WAN="Chiavetta 4G (Backup)"
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