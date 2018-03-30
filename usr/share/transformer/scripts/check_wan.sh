eth4_mode=$(uci get ethernet.eth4.wan)
sfp_presence=$(uci get env.rip.sfp)

if [ $(uci get -q env.rip.sfp) ]; then
	if [ $sfp_presence == "0" ]; then
		if [ $(uci get -q ethernet.eth4.wan) ] ; then
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
		fi
	fi
fi
