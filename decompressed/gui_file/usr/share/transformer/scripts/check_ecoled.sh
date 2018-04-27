if [ $(uci get ledfw.status_led.enable) == "1" ]; then
	if [ $(uci get ledfw.timeout.ms) == "0" ]; then
		uci set ledfw.timeout.ms="5000"
	else
		continue
	fi
else
	if [ $(uci get ledfw.timeout.ms) != "0" ]; then
		uci set ledfw.timeout.ms="0"
	else
		continue
	fi
fi	

/etc/init.d/xtm restart
transformer-cli set uci.wireless.wifi-device.@radio_2G.state 0
transformer-cli set uci.wireless.wifi-device.@radio_5G.state 0
transformer-cli apply
transformer-cli set uci.wireless.wifi-device.@radio_2G.state 1
transformer-cli set uci.wireless.wifi-device.@radio_5G.state 1
transformer-cli apply
