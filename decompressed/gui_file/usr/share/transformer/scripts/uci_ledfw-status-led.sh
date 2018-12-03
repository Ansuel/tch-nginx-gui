#!/bin/sh
enabled=$(uci get ledfw.status_led.enable)
if [ ${enabled} == "1" ]
then
	ubus send statusled '{"state":"enabled"}'
else
	ubus send statusled '{"state":"disabled"}'
fi

