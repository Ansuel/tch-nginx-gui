#!/bin/sh
enabled=$(uci get network.lte_backup.auto)
if [ ${enabled} == "1" ]
then
	ubus send network.lte_backup '{"state":"enabled"}'
else
	ubus send network.lte_backup '{"state":"disabled"}'
fi

