. /etc/init.d/rootdevice

apply_specific_DGA_package() {
	logger_command "DGA device detected!"
	logger_command "Extracting custom-ripdrv-specificDGA.tar.bz2 ..."
	if [ -f /tmp/custom-ripdrv-specificDGA.tar.bz2 ]; then
		bzcat /tmp/custom-ripdrv-specificDGA.tar.bz2 | tar -C / -xf -
	fi
	logger_command "Extracting telnet_support-specificDGA/TG800.tar.bz2 ..."
	if [ -f /tmp/telnet_support-specificDGA.tar.bz2 ]; then
		bzcat /tmp/telnet_support-specificDGA.tar.bz2 | tar -C / -xf -
		if [ -f /bin/busybox_telnet ] && [ ! -h /usr/sbin/telnetd ]; then
			ln -s /bin/busybox_telnet /usr/sbin/telnetd
		fi
	fi
	logger_command "Extracting upgrade-pack-specificDGA.tar.bz2 ..."
	if [ -f /tmp/upgrade-pack-specificDGA.tar.bz2 ]; then
		bzcat /tmp/upgrade-pack-specificDGA.tar.bz2 | tar -C / -xf -
	fi
	logger_command "Extracting upnpfix-specificDGA.tar.bz2 ..."
	if [ -f /tmp/upnpfix-specificDGA.tar.bz2 ]; then
		bzcat /tmp/upnpfix-specificDGA.tar.bz2 | tar -C / -xf -
	fi
	logger_command "Extracting dlnad_supprto-specificDGA.tar.bz2 ..."
	if [ -f /tmp/dlnad_supprto-specificDGA.tar.bz2 ]; then
		if [ ! -f /usr/bin/dlnad ]; then
			bzcat /tmp/dlnad_supprto-specificDGA.tar.bz2 | tar -C / -xf -
		fi
	fi
	logger_command "Extracting wgetfix-specificDGA.tar.bz2 ..."
	if [ -f /tmp/wgetfix-specificDGA.tar.bz2 ]; then
		if [ ! "$(opkg info wget | grep Version | grep 1.17.1)" ]; then
			bzcat /tmp/wgetfix-specificDGA.tar.bz2 | tar -C /tmp -xf -
			opkg install /tmp/wget_1.17.1-1_brcm63xx-tch.ipk
			rm /tmp/wget_1.17.1-1_brcm63xx-tch.ipk
		fi
	fi
}

apply_specific_TG800_package() {
	logger_command "Extracting telnet_support-specificDGA/TG800.tar.bz2 ..."
	if [ -f /tmp/telnet_support-specificDGA.tar.bz2 ]; then
		bzcat /tmp/telnet_support-specificDGA.tar.bz2 | tar -C / -xf -
	fi
}

apply_specific_TG789_package() {
	logger_command "Extracting telnet_support-specificTG789/tg799.tar.bz2 ..."
	if [ -f /tmp/telnet_support-specificTG789.tar.bz2 ]; then
		bzcat /tmp/telnet_support-specificTG789.tar.bz2 | tar -C / -xf -
	fi
}

apply_specific_TG799_package() {
	logger_command "Extracting telnet_support-specificTG789/tg799.tar.bz2 ..."
	if [ -f /tmp/telnet_support-specificTG789.tar.bz2 ]; then
		bzcat /tmp/telnet_support-specificTG789.tar.bz2 | tar -C / -xf -
	fi
}

ledfw_extract() {
	if [ -f "/tmp/ledfw_support-specific$1.tar.bz2" ]; then
		stateMachine_tar_md5=$(bzcat /tmp/ledfw_support-specific$1.tar.bz2 | tar xf - stateMachines.md5sum -O | awk '{ print $1 }')
		stateMachine_md5=$(md5sum /etc/ledfw/stateMachines.lua | awk '{ print $1 }' )
		logger_command "StateMachine tar md5sum: $stateMachine_tar_md5"
		logger_command "StateMachine md5sum: $stateMachine_md5"
		if [ "$stateMachine_tar_md5" ] && [ "$stateMachine_tar_md5" != "$stateMachine_md5" ]; then
			logger_command "Extracting ledfw_support-specific$1.bz2 ..."
			/usr/share/transformer/scripts/restart_leds.sh
			bzcat "/tmp/ledfw_support-specific$1.tar.bz2" | tar -C / -xf - etc/ledfw/stateMachines.lua
		fi
	fi
}

ledfw_rework_TG788() {
	if [ ! "$(uci get -q button.info)" ] || [ "$(uci get -q button.info)" == "BTN_3" ]; then
		logger_command "Setting up status (wifi) button..."
		uci del button.easy_reset
		uci set button.info=button
		uci set button.info.button='BTN_1'
		uci set button.info.action='released'
		uci set button.info.handler='logger INFO button pressed ; ubus send infobutton '\''{"state":"active"}'\'''
		uci set button.info.min='0'
		uci set button.info.max='2'
		uci set button.eco.min='2'
		uci set button.eco.max='5'
		uci set button.acl.min='5'
		uci set ledfw.iptv.check='0'
		uci commit ledfw
	fi

    ledfw_extract "TG788"
}

ledfw_rework_TG799() {
	if [ ! "$(uci get -q button.info)" ]; then
		logger_command "Setting up status (power) button..."
		uci del button.easy_reset
		uci set button.info=button
		uci set button.info.button='BTN_3'
		uci set button.info.action='released'
		uci set button.info.handler='logger INFO button pressed ; ubus send infobutton '\''{"state":"active"}'\'''
		uci set button.info.min='0'
		uci set button.info.max='2'
		uci set ledfw.iptv.check='0'
		uci commit ledfw
	fi

	ledfw_extract "TG799"
}

ledfw_rework_TG800() {
	if [ ! "$(uci get -q button.info)" ]; then
		logger_command "Setting up status (wifi) button..."
		uci del button.easy_reset
		uci set button.info=button
		uci set button.info.button='BTN_1'
		uci set button.info.action='released'
		uci set button.info.handler='logger INFO button pressed ; ubus send infobutton '\''{"state":"active"}'\'''
		uci set button.info.min='0'
		uci set button.info.max='2'
		uci set button.wifi_on_off_toggle.min='2'
		uci set button.wifi_on_off_toggle.max='8'
		uci set ledfw.iptv.check='0'
		uci commit ledfw
	fi

    ledfw_extract "TG800"
}

ledfw_rework_DGA() {
	if [ "$(< /usr/lib/lua/ledframework/ubus.lua grep '\--restore default function of this')" ]; then
		cp /rom/usr/lib/lua/ledframework/ubus.lua /usr/lib/lua/ledframework/
	fi
	if [ ! "$(< /usr/lib/lua/ledframework/ubus.lua grep 'cb("fwupgrade_state_" .. msg.state)')" ]; then
		sed -i 'N;/events\['\''fwupgrade'\''\] = function(msg)/a\\t\tcb("fwupgrade_state_" .. msg.state)' /usr/lib/lua/ledframework/ubus.lua
	fi

    ledfw_extract "DGA"
}

clean_specific_file() {
	rm /tmp/*specific*.tar.bz2
}

wifi_fix_24g() {
	#Set wifi to perf mode
	wl down
	wl obss_prot set 0
	wl -i wl0 gmode Performance
	wl -i wl0 up

}

#THIS CHECK DEVICE TYPE AND INSTALL SPECIFIC FILE
device_type="$(uci get -q env.var.prod_friendly_name)"
kernel_ver="$(cat /proc/version | awk '{print $3}')"

logger_command "Applying specific model fixes..."
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*DGA413*}" ] && apply_specific_DGA_package
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG789*}" ] && apply_specific_TG789_package
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG799*}" ] && apply_specific_TG799_package
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG800*}" ] && apply_specific_TG800_package
[ -z "${device_type##*DGA4130*}" ] && ledfw_rework_DGA
[ -z "${device_type##*DGA4132*}" ] && ledfw_rework_DGA
[ -z "${device_type##*DGA4131*}" ] && ledfw_extract "DGA4131"
[ -z "${device_type##*TG788*}" ] && ledfw_rework_TG788
[ -z "${device_type##*TG789*}" ] && ledfw_extract "TG789"
[ -z "${device_type##*TG799*}" ] && ledfw_rework_TG799
[ -z "${device_type##*TG800*}" ] && ledfw_rework_TG800
[ -z "${device_type##*DGA413*}" ] && wifi_fix_24g
	
if [ -f /tmp/custom-ripdrv-specificDGA.tar.bz2 ]; then
	clean_specific_file
	logger_command "Removing fixes and resuming root process..."
fi