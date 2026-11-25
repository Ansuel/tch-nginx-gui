#!/bin/sh
# Applies a change of the ledfw configuration (called by uci_ledfw.ca).
#
# restart_leds.sh switches every LED off before restarting the LED framework,
# which is wrong for a plain change of the Power LED color. On the DGA4331 such a
# change is applied live instead. Any other change keeps the usual behaviour.
#
# Usage: apply_ledfw.sh [seed]   (seed only records the current state, at boot)

SYS="${LEDFW_SYS:-/sys/class/leds}"
STATE="${LEDFW_STATE:-/tmp/ledfw_applied}"
SCRIPTS="${LEDFW_SCRIPTS:-/usr/share/transformer/scripts}"

log() {
  logger -t apply_ledfw "$*" 2>/dev/null
  return 0
}

# configuration without the options that can be applied live
snapshot() {
  uci -q show ledfw | grep -v -e power_color -e power_blue_node | md5sum | cut -d' ' -f1
}

save_state() {
  snapshot > "$STATE.md5"
  color="$(uci -q get ledfw.status_led.power_color)"
  echo "${color:-green}" > "$STATE.color"
}

# red green blue sub-LEDs lit by a color (1 = on)
parts_of() {
  case "$1" in
    red) echo "1 0 0" ;;
    blue) echo "0 0 1" ;;
    orange) echo "1 1 0" ;;
    cyan) echo "0 1 1" ;;
    magenta) echo "1 0 1" ;;
    white) echo "1 1 1" ;;
    *) echo "0 1 0" ;;
  esac
}

lit() {
  local value
  value="$(cat "$SYS/power:$1/brightness" 2>/dev/null)"
  case "$value" in
    ''|*[!0-9]*|0) echo 0 ;;
    *) echo 1 ;;
  esac
}

# The framework needs to know whether the blue sub-LED exists
sync_blue_flag() {
  local want=0
  [ -e "$SYS/power:blue/brightness" ] && want=1
  [ "$(uci -q get ledfw.status_led.power_blue_node)" = "$want" ] && return 1
  uci set ledfw.status_led.power_blue_node="$want"
  uci commit ledfw
  return 0
}

apply_color_live() {
  # With Eco LED on the power LED is off: the new color shows when it is lit again
  if [ "$(uci -q get ledfw.status_led.enable)" = "1" ]; then
    log "Eco LED on: power LED color applies when the LED is lit again"
    return 0
  fi
  local prev new node want
  prev="$(cat "$STATE.color" 2>/dev/null)"
  new="$(uci -q get ledfw.status_led.power_color)"
  set -- $(parts_of "$prev")
  # Only change a steady LED showing the previous color: never an alarm, a
  # blinking pattern or an LED that is off
  if ! { [ "$(lit red)" = "$1" ] && [ "$(lit green)" = "$2" ] && [ "$(lit blue)" = "$3" ]; }; then
    log "power LED is not steady in $prev: color not written"
    return 0
  fi
  log "power LED color $prev -> $new applied live"
  set -- $(parts_of "$new")
  for node in red green blue; do
    want="$1"; shift
    [ -e "$SYS/power:$node/brightness" ] || continue
    if [ "$want" = 1 ]; then echo 255 > "$SYS/power:$node/brightness"; else echo 0 > "$SYS/power:$node/brightness"; fi
  done
}

if [ "$1" = seed ]; then
  save_state
  exit 0
fi

live=0
case "$(uci -q get env.var.prod_friendly_name)" in
  *4331*)
    flag_changed=0
    sync_blue_flag && flag_changed=1
    if [ "$flag_changed" = 0 ] && [ -f "$STATE.md5" ] && [ "$(snapshot)" = "$(cat "$STATE.md5")" ]; then
      live=1
    fi
    ;;
esac

if [ "$live" = 1 ]; then
  apply_color_live
else
  log "restarting the LEDs (ledfw settings changed)"
  # run through sh: a file copied without its execute bit must still work
  sh "$SCRIPTS/check_ecoled.sh"
  sh "$SCRIPTS/restart_leds.sh"
fi
save_state
