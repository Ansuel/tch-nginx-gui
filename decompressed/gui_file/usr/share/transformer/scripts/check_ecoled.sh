if [ $(uci get ledfw.status_led.enable) == "1" ]; then
	if [ "$(uci get ledfw.timeout.ms)" == "0" ]; then
		uci set ledfw.timeout.ms="5000"
		uci commit ledfw
	fi
	ubus send statusled '{"state":"enabled"}'
	ubus send statusled '{"state":"active"}'
else
	ubus send statusled '{"state":"disabled"}'
	ubus send statusled '{"state":"inactive"}'
fi	
