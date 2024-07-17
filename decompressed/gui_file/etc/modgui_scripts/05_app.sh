#!/bin/sh

. /etc/init.d/rootdevice

check_new_dlnad() {
  logecho "Enable DLNAd"
	#This function will check to see which dlna server daemon is installed
	if [ -f /etc/init.d/dland ] && [ ! -f /etc/rc.d/S98dlnad ] && [ -f /etc/init.d/minidlna ]; then
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
  logecho "Trafficmon inizialization"
	if [ -d /root/trafficmon ]; then
		killall trafficmon 2>/dev/null
		killall trafficdata 2>/dev/null
		rm -rf /root/trafficmon
	fi

	if grep -q trafficmon /etc/crontabs/root; then
		killall trafficmon 2>/dev/null
		killall trafficdata 2>/dev/null
		sed -i '/trafficmon/d' /etc/crontabs/root
		sed -i '/trafficdata/d' /etc/crontabs/root
	fi

	if [ -f /etc/init.d/trafficmon ] && [ ! -f /etc/rc.d/S99trafficmon ]; then
		/etc/init.d/trafficmon enable
		if [ ! -f /var/run/trafficmon.pid ]; then
			/etc/init.d/trafficmon start
		fi
	fi
	if [ -f /etc/init.d/trafficdata ] && [ ! -f /etc/rc.d/S99trafficdata ]; then
		/etc/init.d/trafficdata enable
		if [ ! -f /var/run/trafficdata.pid ]; then
			/etc/init.d/trafficdata start
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

telstra_support_check() {
	if [ ! "$(uci get -q modgui.app.telstra_webui)" ]; then
		uci set modgui.app.telstra_webui="0"
	fi
	if [ -f /tmp/telstra_gui.tar.bz2 ]; then
		if [ "$(uci get -q modgui.app.telstra_webui)" = "1" ]; then
			bzcat /tmp/telstra_gui.tar.bz2 | tar -C / -xf -
		fi
		rm /tmp/telstra_gui.tar.bz2
	fi
}

#THIS CHECK DEVICE TYPE AND INSTALL SPECIFIC FILE
device_type="$(uci get -q env.var.prod_friendly_name)"

trafficmon_support #support trafficmon
[ -z "${device_type##*DGA413*}" ] && check_new_dlnad #this enable a new dlna deamon introduced with 17.1, the old one is keep
logecho "Move Aria2 dir"
check_aria_dir #Fix config function
logecho "Reinstalling Telstra GUI if needed..."
telstra_support_check #telstra support check
