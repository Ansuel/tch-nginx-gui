#!/bin/sh
enable=$(uci get mproxy.globals.enable)
profileValue=$(uci get mproxy.globals.profile)

if [ $enable == "1" ]
then
	if [ $profileValue == "dsl_lte" ]
	then
		uci set network.mpt_lte.auto="1"
		uci set network.mpt_amod.auto="0"
	else
		uci set network.mpt_lte.auto="0"
		uci set network.mpt_amod.auto="1"
	fi

else
		uci set network.mpt_lte.auto="0"
		uci set network.mpt_amod.auto="0"
fi

uci commit network
/etc/init.d/network reload
