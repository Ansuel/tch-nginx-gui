#!/bin/sh

# Copyright (C) 2018 kevdagoat (kevdawhirl@gmail.com)
# Written by kevdagoat for tch-nginx-gui.

######################################################################
DATE=$(date +%Y-%m-%d-%H%M)
guiver=$(grep /etc/init.d/rootdevice -e 'version_gui' | sed 's/version_gui=//')
dsl=$(xdslctl --version 2>&1 >/dev/null | grep 'version -' | awk '{print $6}' | sed 's/\..*//')


log() {
logger -s -t "DebugHelper" "$1"
}
#####################################################################

log "DebugHelper Started!"

log "Removing directory /tmp/DebugHelper-* to prevent duplicates"
rm -R /tmp/DebugHelper* > /dev/null 2>&1

log "Creating dir"
mkdir "/tmp/DebugHelper-$DATE/" > /dev/null 2>&1
cd "/tmp/DebugHelper-$DATE/"

#################################################################################################################################################################
log "Gathering device info..."
{
  echo "___________________________________DEVICE INFO_________________________________________"
  echo "Friendly Name: $(uci get env.var.prod_friendly_name)"
  echo "Product Name: $(uci get env.var.prod_name)"
  echo "Uptime: $(uptime)"
  echo "Uname: $(uname -a)"
  uci show modgui |grep -v "encrypted_pass"
  echo "--------------Free Space--------------"
  df -h
  echo "--------------Mounts--------------"
  mount
  echo "--------------NAND--------------"
  cat /proc/mtd
  echo "--------------LEDS--------------"
  ls -lah /sys/class/leds/
  echo "--------------Buttons config--------------"
  uci show button
  echo "--------------pwrctl--------------"
  pwrctl show
  echo "--------------banktable---------------"
  for f in /proc/banktable/*; do
    echo -n "$f "
    cat "$f"
    echo
  done
  echo "--------------USB---------------"
  lsusb
  dmesg |grep usb
  echo "--------------INTERFACES---------------"
  ifconfig
  echo "--------------ROUTING---------------"
  ip r
}> ./deviceinfo.txt

###########################################################################################################################################################

log "Scanning for log errors..."
{
  echo "__________________________________LOG_________________________________________"
  logread |grep daemon.err
}> ./error.log

###########################################################################################################################################################

log "XDSL stats..."
{
  echo "__________________________________LOG_________________________________________"
  logread |grep daemon.err
}> ./error.log

###########################################################################################################################################################

log "Listing processes..."
{
  echo "__________________________________PROCESSES_________________________________________"
  ps
}> ./processes.txt

###########################################################################################################################################################

log "Scanning /etc/config directory..."
{
  echo "__________________________________CONFIG FILE LIST_________________________________________"
  ls -lah /etc/config/
}> ./configlist.txt

[ -d /overlay/modgui_log.remove_due_to_upgrade ] && cp -r /overlay/modgui_log.remove_due_to_upgrade ./
[ -d /overlay/modgui_log ] && cp -r /overlay/modgui_log ./

###########################################################################################################################################################
log "Tarring File..."
tar -czvf "/tmp/DebugHelper$DATE.tar.gz" "/tmp/DebugHelper-$DATE" > /dev/null 2>&1
rm -R "/tmp/DebugHelper-$DATE"
log "All Done! Zipped file can be found in /tmp/DebugHelper$DATE.tar.gz"

}
