#!/bin/sh
eth4_mode=$(uci get ethernet.eth4.wan)
sfp_presence=$(uci get env.rip.sfp)
sfp_wanlan_mode=$(uci get -q ethernet.globals.eth4lanwanmode)

check_wan() {
	if [ $eth4_mode == "1" ]; then
		#uci delete ethernet.eth4.wan
		#uci delete network.waneth4
		uci delete -q qos.eth4
		uci set network.lan.ifname='eth0 eth1 eth2 eth3 eth4 eth5'
		uci commit
		reboot
	else
		#uci delete ethernet.eth4.wan
		#uci delete network.waneth4
		uci set qos.eth4=device
		uci set qos.eth4.classgroup='TO_WAN'
		uci set network.lan.ifname='eth0 eth1 eth2 eth3 eth5'
		uci commit
		reboot
	fi
}

set_sfp() {

    #this is to forcely use network.sfp otherwise /usr/sbin/sfp_get.sh will use network.sfptag that is managed by nothing
    [ "$(uci get -q network.sfptag)" ] && uci delete network.sfptag

	if [ "$sfp_wanlan_mode" = "0" ]; then
		if [ ! "$(uci get -q network.lan.ifname | grep eth4)" ]; then
			uci set network.lan.ifname='eth0 eth1 eth2 eth3 eth4 eth5'
			uci commit
			/etc/init.d/network restart
			/etc/init.d/ethernet reload
		fi
	else
		if [ ! "$(uci get -q network.sfp.ifname | grep eth4)" ]; then
			uci set network.lan.ifname='eth0 eth1 eth2 eth3 eth5'
			uci set network.sfp.ifname='eth4'
			uci commit
			/etc/init.d/network restart
			/etc/init.d/ethernet reload
		fi
	fi
}

if [ "$(uci get -q env.rip.sfp)" ]; then
	if [ "$sfp_presence" = "0" ]; then
		if [ "$(uci get -q ethernet.eth4.wan)" ] ; then
			check_wan
		fi
	else
		set_sfp
	fi
else
	check_wan
fi
