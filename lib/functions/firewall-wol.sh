#!/bin/sh
# Copyright (c) 2015 Technicolor
# Wake on LAN over the Internet

. $IPKG_INSTROOT/lib/functions.sh
config_load wol

apply()
{
  local RULE=$1
  logger -t WakeOnWAN -- $RULE
  iptables $RULE
}

config_get_bool enabled config enabled 0

if [ "$enabled" == "1" ]; then
  ACT="-I"
else
  ACT="-D"
fi

config_get src_intf config src_intf
zone=$(fw3 -q network "$src_intf")
config_get src_dport config src_dport
config_get dest_ip config dest_ip

WAKE_PORT=9

local FWD_RULE="-t nat $ACT zone_wan_prerouting -p udp -m udp --dport $WAKE_PORT -j DNAT --to-destination $dest_ip"
local FWD_NULL="-t nat $ACT zone_wan_prerouting -p udp --dport $src_dport -j REDIRECT --to-port $WAKE_PORT"
local ACCEPT_RULE="-t filter $ACT zone_wan_input -p udp --dport $src_dport -j ACCEPT"

if [ "$WAKE_PORT" != "$src_dport" ]; then
  
  apply "$FWD_NULL"
fi
apply "$FWD_RULE"
apply "$ACCEPT_RULE"

