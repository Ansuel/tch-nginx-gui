#!/bin/sh

#Forcely turn off all LEDs (ledfw restart does not turn of all LEDs on some devices)
for filename in /sys/class/leds/*; do
    echo 0 > "$filename/brightness"
done

#Call default restart script (that will break LEDs)
/etc/init.d/ledfw restart

#than check services and simulate ubus actions to get all LEDs back in normal status...

#Restore Broadband LED status (only if on xDSL on ETH ledfw restart seems enough)
xdsl_status=$(transformer-cli get sys.class.xdsl.@line0.LinkStatus | cut -d= -f 2 | awk '{$1=$1};1')
xdsl_statuscode=0

if [ "$(echo $xdsl_status | grep Showtime)" ]; then
    xdsl_statuscode=5
elif [ "$(echo $xdsl_status | grep Training)" ]; then
    xdsl_statuscode=1
elif [ "$(echo $xdsl_status | grep Started)" ]; then
    xdsl_statuscode=6
fi

if [ $xdsl_statuscode -gt 0 ]; then
    if [ $xdsl_statuscode==5 ]; then #cause we cannot go directly in showtime send a fake "Started"
        ubus send xdsl "{\"status\":\"G.993 Started\",\"statuscode\":6,\"line1\":{\"status\":\"G.993 Started\",\"statuscode\":6}}"
    fi
    ubus send xdsl "{\"status\":\"$xdsl_status\",\"statuscode\":$xdsl_statuscode,\"line1\":{\"status\":\"$xdsl_status\",\"statuscode\":$xdsl_statuscode}}"
fi

#Restore Wifi LED(s) status
connected_wl0=0
connected_wl1=0
num_dev=$(seq $(transformer-cli get rpc.hosts.HostNumberOfEntries | cut -d= -f 2))
i=0
while [ ! -z "$num_dev" ] && [ $num_dev -gt 0 ]; do
    if [ ! -z "$(transformer-cli get rpc.hosts.host.$i. | grep 'ERROR')" ]; then
        i=$((i+1))
    else
        num_dev=$((num_dev-1))
        if [ ! -z "$(transformer-cli get rpc.hosts.host.$i.State | grep '= 1')" ]; then
            if [ ! -z "$(transformer-cli get rpc.hosts.host.$i.L2Interface | grep '= wl0')" ]; then
                connected_wl0=$((connected_wl0+1))
            elif [ ! -z "$(transformer-cli get rpc.hosts.host.$i.L2Interface | grep '= wl1')" ]; then
                connected_wl1=$((connected_wl1+1))
            fi
        fi
    fi
done

for i in 0 1
do
	radio_oper_state="$(transformer-cli get rpc.wireless.ssid.@wl$i.oper_state | cut -d= -f 2)"
	radio_admin_state="$(transformer-cli get rpc.wireless.ssid.@wl$i.admin_state | cut -d= -f 2)"
	if [ $i == 0 ]; then
	    connected_devices=$connected_wl0
	else
	    connected_devices=$connected_wl1
	fi
	ubus send wireless.wlan_led "{\"ifname\":\"wl$i\",\"radio_admin_state\":$radio_admin_state,\"radio_oper_state\":$radio_oper_state,\"bss_admin_state\":1,\"bss_oper_state\":1,\"acl_state\":0,\"sta_connected\":$connected_devices,\"security\":\"disabled\"}"
done

#Restore Internet LED status
for iface in "wan" "wwan"
do
	wan_status="down"
	if [ "$(transformer-cli get rpc.network.interface.@$iface.up | cut -d= -f 2 | grep 1)" ]; then
		wan_status="up"
	fi
	ubus send network.interface "{\"action\":\"if$wan_status\",\"interface\":\"$iface\"}"
done

#Restore Voice LED(s) status
fxs_dev_0_status="OK-OFF"
if [ "$(transformer-cli get rpc.mmpbx.device.@fxs_dev_0.profileUsable | cut -d= -f 2 | grep true)" ]; then
	fxs_dev_0_status="OK"
elif [ "$(transformer-cli get rpc.mmpbx.device.@fxs_dev_0.profileUsable | cut -d= -f 2 | grep false)" ]; then
	fxs_dev_0_status="NOK"
fi

fxs_dev_1_status="OK-OFF"
if [ "$(transformer-cli get rpc.mmpbx.device.@fxs_dev_1.profileUsable | cut -d= -f 2 | grep true)" ]; then
	fxs_dev_1_status="OK"
elif [ "$(transformer-cli get rpc.mmpbx.device.@fxs_dev_1.profileUsable | cut -d= -f 2 | grep false)" ]; then
	fxs_dev_1_status="NOK"
fi

ubus send mmpbx.voiceled.status "{\"fxs_dev_0\":\"$fxs_dev_0_status\",\"fxs_dev_1\":\"$fxs_dev_1_status\"}"