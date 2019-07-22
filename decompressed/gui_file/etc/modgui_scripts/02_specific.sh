. /etc/init.d/rootdevice

extract_with_check() {
	
	export RESTART_SERVICE=0
	MD5_CHECK_DIR=/tmp/md5check
	
	[ ! -d $MD5_CHECK_DIR ] && mkdir $MD5_CHECK_DIR
	
	for file in $(bzcat $1 | tar -C $MD5_CHECK_DIR -xvf -); do
	
		if [ ! -f $MD5_CHECK_DIR/$file ]; then
			if [ ! -d /$file ]; then
				mkdir /$file
			fi
			continue
		fi
		
		[ -n "$( echo $file | grep .md5sum )" ] && continue
		
		orig_file=/$file
		file=$MD5_CHECK_DIR/$file
		
		if [ -f $orig_file ]; then
			md5_file=$(md5sum $file | awk '{ print $1 }' )
			md5_orig_file=$(md5sum $orig_file | awk '{ print $1 }' )
			if [ $md5_file == $md5_orig_file ]; then
				rm $file
				continue
			fi
		fi
		
		cp $file $orig_file
		rm $file
		RESTART_SERVICE=1
		
	done
	
	[ -d $MD5_CHECK_DIR ] && rm -r $MD5_CHECK_DIR
	
	return $RESTART_SERVICE
}

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
		extract_with_check "/tmp/ledfw_support-specific$1.tar.bz2"
		[ $? -eq 1 ] && /usr/share/transformer/scripts/restart_leds.sh
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

remove_downgrade_bit() {
	if [ "$(uci get -q env.rip.board_mnemonic)" == "VBNT-S" ] && 
		[ "$(uci get -q env.var.prod_number)" == "4132" ] && 
		[ -f /proc/rip/0123 ]; then
		logger_command "Downgrade limitation bit detected... Removing..."
		rmmod keymanager
		rmmod ripdrv
		mv /lib/modules/3.4.11/ripdrv.ko /lib/modules/3.4.11/ripdrv.ko_back
		mv /tmp/ripdrv.ko /lib/modules/3.4.11/ripdrv.ko
		insmod ripdrv
		echo 0123 > /proc/rip/delete
		echo 0122 > /proc/rip/delete
		rmmod ripdrv
		logger_command "Restoring original driver"
		rm /lib/modules/3.4.11/ripdrv.ko
		mv /lib/modules/3.4.11/ripdrv.ko_back /lib/modules/3.4.11/ripdrv.ko
		insmod ripdrv
		insmod keymanager
	elif [ -f /tmp/ripdrv.ko ]; then
		rm /tmp/ripdrv.ko
	fi
}

#THIS CHECK DEVICE TYPE AND INSTALL SPECIFIC FILE
device_type="$(uci get -q env.var.prod_friendly_name)"
kernel_ver="$(cat /proc/version | awk '{print $3}')"

logger_command "Applying specific model fixes..."
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*DGA413*}" ] && apply_specific_DGA_package
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG789*}" ] && apply_specific_TG789_package
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG799*}" ] && apply_specific_TG799_package
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG800*}" ] && apply_specific_TG800_package
[ -z "${device_type##*DGA4130*}" ] && ledfw_extract "DGA"
[ -z "${device_type##*DGA4132*}" ] && ledfw_extract "DGA"
[ -z "${device_type##*DGA4131*}" ] && ledfw_extract "DGA4131"
[ -z "${device_type##*TG788*}" ] && ledfw_rework_TG788
[ -z "${device_type##*TG789*}" ] && ledfw_extract "TG789"
[ -z "${device_type##*TG799*}" ] && ledfw_rework_TG799
[ -z "${device_type##*TG800*}" ] && ledfw_rework_TG800
[ -z "${device_type##*DGA413*}" ] && wifi_fix_24g

#Use custom driver to remove this... thx @Roleo
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*DGA413*}" ] && logger_command "Checking downgrade limitation bit"
[ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*DGA413*}" ] && remove_downgrade_bit 

	#Fix led issues
	if [ -z "${device_type##*DGA4131*}" ] ; then
        if [ ! "$(uci get -q ledfw.ambient.active)" ] ; then
            uci set ledfw.ambient=led
            uci set ledfw.ambient.active='1'
            uci commit ledfw
        fi
	else
        if [ ! "$(uci get -q ledfw.status_led.enable)" ] ; then
            uci set ledfw.status_led=status_led
            uci set ledfw.status_led.enable='0'
            uci commit ledfw
        fi
        if [ ! "$(uci get -q ledfw.wifi.nsc_on)" ] ; then
            uci set ledfw.wifi=service
            uci set ledfw.wifi.nsc_on='1'
            uci commit ledfw
        fi
	fi
	
if [ -f /tmp/custom-ripdrv-specificDGA.tar.bz2 ]; then
	clean_specific_file
	logger_command "Removing fixes and resuming root process..."
fi
