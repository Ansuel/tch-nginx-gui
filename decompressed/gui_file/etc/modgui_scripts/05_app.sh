. /etc/init.d/rootdevice

check_new_dlnad() {
	#This function will check to see which dlna server daemon is installed
	if [ -f /etc/init.d/dland ] && [ ! -k /etc/rc.d/S98dlnad ] && [ -f /etc/init.d/minidlna ]; then
		if [ "$(pgrep "minidlna")" ] ; then
			/etc/init.d/minidlna stop
		fi
		/etc/init.d/minidlna disable
		/etc/init.d/dlnad enable
		if [ ! "$(pgrep "dlnad")" ] ; then
			/etc/init.d/dlnad start
		fi
	fi
	if [ -f /rom/usr/bin/dlnad ]; then
		if [ "$(md5sum /rom/usr/bin/dlnad | awk '{print $1}')" !=  "$(md5sum /usr/bin/dlnad | awk '{print $1}')" ]; then
			if [ "$(pgrep "dlnad")" ] ; then
				/etc/init.d/dlnad stop
			fi
			rm /usr/bin/dlnad
			cp /rom/usr/bin/dlnad /usr/bin/dlnad
			cp /rom/etc/init.d/dlnad /etc/init.d/dlnad
			/etc/init.d/dlnad start
		fi
	fi
}

trafficmon_support() {
	if [ -d /root/trafficmon ]; then
		killall trafficmon 2>/dev/null
		killall trafficdata 2>/dev/null
		rm -rf /root/trafficmon
	fi
	
	if [ -n "$(cat /etc/crontabs/root | grep trafficmon)" ]; then
		killall trafficmon 2>/dev/null
		killall trafficdata 2>/dev/null
		sed -i '/trafficmon/d' /etc/crontabs/root
		sed -i '/trafficdata/d' /etc/crontabs/root
	fi
	
	if [ -f /etc/init.d/trafficmon ] && [ ! -k /etc/rc.d/S99trafficmon ]; then
		/etc/init.d/trafficmon enable
		if [ ! -f /var/run/trafficmon.pid ]; then
			/etc/init.d/trafficmon start
		fi
	fi
	if [ -f /etc/init.d/trafficdata ] && [ ! -k /etc/rc.d/S99trafficdata ]; then
		/etc/init.d/trafficdata enable
		if [ ! -f /var/run/trafficdata.pid ]; then
			/etc/init.d/trafficdata start
		fi
	fi

}

enable_new_upnp() {
	if [ -f /etc/init.d/miniupnpd ]; then
		if [ "$(uci get -q upnpd.config.enable_upnp)" ]; then
			if [ "$(uci get -q upnpd.config.enable_upnp)" == "1" ]; then
				/etc/init.d/miniupnpd-tch stop
				/etc/init.d/miniupnpd-tch disable
				/etc/init.d/miniupnpd enable
				if [ ! "$(pgrep "miniupnpd")" ]; then
					/etc/init.d/miniupnpd restart
				fi
			fi
		fi
	fi
}

check_aria_dir() {
	if [ -d /etc/config/aria2 ]; then #Fix generation of config
		mv /etc/config/aria2 /etc/aria2
	fi
	if [ "$(pgrep aria2)" ]; then
		killall aria2c
		aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=/etc/aria2/aria2.conf
	fi
}

apply_right_opkg_repo() {
	marketing_version="$(uci get -q version.@version[0].marketing_version)"
	
	opkg_file="/etc/opkg.conf"
	
	case $marketing_version in
	"18.3"*)
		if [ -z "$(  grep $opkg_file -e "Ansuel/GUI_ipk/kernel-4.1" )" ]; then
			cat << EOF >> $opkg_file
arch all 100
arch brcm63xx 200
arch brcm63xx-tch 300
arch arm_cortex-a9 400
src/gz chaos_calmer_base https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/base
src/gz chaos_calmer_packages https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/packages 
src/gz chaos_calmer_luci https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/luci              
src/gz chaos_calmer_routing https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/routing    
src/gz chaos_calmer_telephony https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/telephony
src/gz chaos_calmer_management https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/management
EOF
		fi
		;;
	"17.3"*)
		if [ -z "$(  grep $opkg_file -e "roleo/public/agtef/1.1.0/brcm63xx-tch" )" ]; then
			cat << EOF >> $opkg_file
src/gz chaos_calmer_base https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/base
src/gz chaos_calmer_packages https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/packages 
src/gz chaos_calmer_luci https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/luci              
src/gz chaos_calmer_routing https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/routing    
src/gz chaos_calmer_telephony https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/telephony
src/gz chaos_calmer_management https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/management
EOF
		fi
		;;
	"16.3"*)
		if [ -z "$(  grep $opkg_file -e "roleo/public/agtef/brcm63xx-tch" )" ]; then
			cat << EOF >> $opkg_file
src/gz chaos_calmer_base https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/base
src/gz chaos_calmer_packages https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/packages 
src/gz chaos_calmer_luci https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/luci              
src/gz chaos_calmer_routing https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/routing    
src/gz chaos_calmer_telephony https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/telephony
src/gz chaos_calmer_management https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/management
EOF
		fi
		;;
	*)
		logger_command "No opkg file supported"
		;;
	esac
}

telstra_support_check() {
	if [ ! "$(uci get -q modgui.app.telstra_webui)" ]; then
		uci set modgui.app.telstra_webui="0"
	fi
	if [ -f /tmp/telstra_gui.tar.bz2 ]; then
		if [ "$(uci get -q modgui.app.telstra_webui)" == "1" ]; then
			bzcat /tmp/telstra_gui.tar.bz2 | tar -C / -xf - 
		fi
		rm /tmp/telstra_gui.tar.bz2
	fi
}

#THIS CHECK DEVICE TYPE AND INSTALL SPECIFIC FILE
device_type="$(uci get -q env.var.prod_friendly_name)"
kernel_ver="$(cat /proc/version | awk '{print $3}')"

logger_command "Trafficmon inizialization"
trafficmon_support #support trafficmon
[ -z "${device_type##*DGA413*}" ] && logger_command "Enable DLNAd"
[ -z "${device_type##*DGA413*}" ] && check_new_dlnad #this enable a new dlna deamon introduced with 17.1, the old one is keep
[ -z "${device_type##*DGA413*}" ] && logger_command "Enable new upnp"
[ -z "${device_type##*DGA413*}" ] && enable_new_upnp #New upnp fix
logger_command "Move Aria2 dir"
check_aria_dir #Fix config function
[ -z "${device_type##*DGA413*}" ] && logger_command "Checking opkg feeds config"
[ -z "${device_type##*DGA413*}" ] && apply_right_opkg_repo #Check opkg conf based on version
logger_command "Reinstalling Telstra GUI if needed..."
telstra_support_check #telstra support check