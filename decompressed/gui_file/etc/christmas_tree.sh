#!/bin/sh
# Minimal BusyBox-compatible christmas_tree.sh
# Esegue solo 24-26 Dicembre. Il 26 esegue cleanup: kill -> restart_leds -> exit.

today=$(date +%m%d 2>/dev/null || echo "")
case "$today" in
  1224|1225) ;;   # esegui la routine
  1226)
    # kill gentile delle altre istanze (escludi questa)
    for p in $(ps | grep '[c]hristmas_tree.sh' | awk '{print $1}'); do
      [ "$p" != "$$" ] && kill "$p" 2>/dev/null || true
    done
    sleep 2
    for p in $(ps | grep '[c]hristmas_tree.sh' | awk '{print $1}'); do
      [ "$p" != "$$" ] && kill -9 "$p" 2>/dev/null || true
    done
    # restart leds dopo che i processi sono terminati
    sh -c "sleep 1 && /usr/share/transformer/scripts/restart_leds.sh &"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac

# lockfile semplice per evitare esecuzioni parallele
LOCK="/tmp/christmas_tree.pid"
if [ -f "$LOCK" ]; then
  oldpid=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    exit 0
  else
    rm -f "$LOCK" 2>/dev/null
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"; exit' INT TERM EXIT

# se ci sono altre istanze, esci (evita sovrapposizioni)
for p in $(ps | grep '[c]hristmas_tree.sh' | awk '{print $1}'); do
  [ "$p" != "$$" ] && { kill "$p" 2>/dev/null || true; }
done
sleep 1
for p in $(ps | grep '[c]hristmas_tree.sh' | awk '{print $1}'); do
  [ "$p" != "$$" ] && { rm -f "$LOCK"; exit 0; }
done

# Corpo principale: comportamento LED (mantieni qui la logica originale, ridotta)
for led in /sys/class/leds/*; do
  [ -f "$led/brightness" ] && { echo 1 > "$led/brightness" 2>/dev/null || true; sleep 0.15; echo 0 > "$led/brightness" 2>/dev/null || true; }
done

rm -f "$LOCK"
exit 0
