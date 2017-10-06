#!/bin/sh
# Copyright (c) 2015 Technicolor
# Wake on LAN over the Internet

. $IPKG_INSTROOT/lib/functions.sh
config_load wol
wol_id=0x776f6c00

# Delete wol DNAT rules
iptables-save -t nat | grep $wol_id | sed 's/^\-A\ /iptables -t nat -D /g' | while read LINE
    do
        eval $LINE
    done

# Check if service is enabled, if not return immediately
config_get_bool enabled config enabled 0
[ $enabled -eq 0 ] && exit 0

config_get src_intf config src_intf
zone=$(fw3 -q network "$src_intf")
config_get src_dport config src_dport
config_get dest_ip config dest_ip

if [ -n "$zone" -a -n "$src_dport" -a -n "$dest_ip" ]; then
    # Create wol DNAT rule
    iptables -t nat -I prerouting_${zone}_rule -p udp -m id --id $wol_id -m udp --dport $src_dport -m comment --comment "Wake on LAN over the Internet" -j DNAT --to-destination $dest_ip
fi

