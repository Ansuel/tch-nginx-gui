if [ "$(uci get ledfw.timeout.ms)" == "0" ]; then
	uci set ledfw.timeout.ms="5000"
	uci commit ledfw
	killall /sbin/status-led-eventing.lua
	/sbin/status-led-eventing.lua &
fi
if [ $(uci get ledfw.status_led.enable) == "1" ]; then
	ubus send statusled '{"state":"enabled"}'
	ubus send statusled '{"state":"active"}'
else
	ubus send statusled '{"state":"disabled"}'
fi	
