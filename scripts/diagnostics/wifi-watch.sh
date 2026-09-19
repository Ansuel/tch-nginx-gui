#!/bin/sh
# Observe only: never restart wireless or change its configuration.
DIAG_DIR=${DIAG_DIR:-/tmp/codex-wifi-diag}
INTERVAL=${INTERVAL:-30}
FAIL_LIMIT=${FAIL_LIMIT:-2}
mkdir -p "$DIAG_DIR" || exit 1
chmod 700 "$DIAG_DIR"
umask 077

probe() {
    timeout 5 ubus -t 3 call "$1" get '{}' >/dev/null 2>&1
}

capture() {
    slot=$(cat "$DIAG_DIR/slot" 2>/dev/null)
    case "$slot" in 1|2) slot=$((slot + 1));; *) slot=1;; esac
    report="$DIAG_DIR/capture-$slot.txt"
    {
        date '+%Y-%m-%d %H:%M:%S %z'
        echo "radio_status=$radio ap_status=$ap consecutive_failures=$failures"
        uptime
        free
        cat /proc/loadavg
        ps | grep -E '[h]ostapd|[t]ransformer|[n]ginx|[q]uantenna|[q]csapi'
        pid=$(cat /var/run/hostapd.pid 2>/dev/null)
        case "$pid" in
            ''|*[!0-9]*) echo 'No valid hostapd PID';;
            *)
                for name in status wchan syscall; do
                    echo "hostapd /proc/$pid/$name"
                    cat "/proc/$pid/$name" 2>/dev/null
                done
                ls -l "/proc/$pid/fd" 2>/dev/null
                ;;
        esac
        echo 'Recent wireless diagnostics (credential-related lines excluded)'
        timeout 5 logread 2>/dev/null |
            grep -Ei 'hostapd|quantenna|qcsapi|retrieving hosts|wireless.*(error|fail|timeout|unavailable)' |
            grep -Eiv 'key|password|passphrase|secret|credential|psk|pin' | tail -c 32768
        echo 'Recent kernel faults'
        dmesg | grep -Ei 'hung|blocked|oom|lockup|quantenna|qtn|watchdog' |
            grep -Eiv 'key|password|passphrase|secret|credential|psk|pin' | tail -c 8192
    } 2>&1 | head -c 65536 > "$report.new"
    mv "$report.new" "$report"
    echo "$slot" > "$DIAG_DIR/slot"
    logger -t codex-wifi-diag "Wireless probes failed twice; diagnostic saved to $report. No service restarted."
}

failures=0
captured=0
while :; do
    probe wireless.radio; radio=$?
    probe wireless.accesspoint; ap=$?
    if [ "$radio" -eq 0 ] && [ "$ap" -eq 0 ]; then
        failures=0
        captured=0
    else
        failures=$((failures + 1))
    fi
    printf '%s radio=%s ap=%s failures=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$radio" "$ap" "$failures" >> "$DIAG_DIR/health.log"
    tail -n 200 "$DIAG_DIR/health.log" > "$DIAG_DIR/health.new"
    mv "$DIAG_DIR/health.new" "$DIAG_DIR/health.log"
    if [ "$failures" -ge "$FAIL_LIMIT" ] && [ "$captured" -eq 0 ]; then
        capture
        captured=1
    fi
    [ "${1:-}" = '--once' ] && break
    sleep "$INTERVAL"
done
