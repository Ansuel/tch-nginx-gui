eth4_mode = $(uci get ethernet.eth4.wan) 

if [ $eth4_mode == "1" ]; then
	#uci delete ethernet.eth4.wan
	#uci delete network.waneth4
	uci delete qos.eth4
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
