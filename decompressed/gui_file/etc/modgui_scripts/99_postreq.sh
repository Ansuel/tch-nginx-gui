#!/bin/sh

. /etc/init.d/rootdevice

check_gui_tmp() {
	if [ -f /tmp/GUI_dev.tar.bz2 ]; then
		logecho "Found GUI_dev in tmp dir... Cleaning..."
		rm /tmp/GUI_dev.tar.bz2
	fi
	if [ -f /tmp/GUI.tar.bz2 ]; then
		logecho "Found GUI in tmp dir... Cleaning..."
		rm /tmp/GUI.tar.bz2
	fi
	if [ -d /total ]; then
		rm -r /total
	fi
}

start_stop_nginx() {
	while [ "$(pgrep "nginx")" ]; do
		if [ -f /var/run/nginx.pid ]; then
			kill -KILL "$(cat /var/run/nginx.pid)"
			rm /var/run/nginx.pid
		fi
		for pid in $(pgrep nginx); do
			kill -KILL "$pid"
		done
		/etc/init.d/nginx stop 2>/dev/null
	done

	nginx_count=0
	while [ "$(curl 127.0.0.1 --max-time 20 -I -s | head -n 1 | cut -d' ' -f2)" != "200" ] && [ $nginx_count -lt 5 ]; do
		if [ $nginx_count -gt 3 ]; then
			if [ -f /var/run/nginx.pid ]; then
				kill -KILL "$(cat /var/run/nginx.pid)"
				rm /var/run/nginx.pid
			fi
			for pid in $(pgrep nginx); do
				kill -KILL "$pid"
			done
		fi
		logecho "Restarting nginx..."
		/etc/init.d/nginx restart 2>/dev/null
		sleep 5
		nginx_count=$((nginx_count+1))
	done
}

if [ "$(cat /proc/banktable/booted)" = "bank_1" ] && [ ! "$(uci get -q modgui.var.check_obp)" ]; then
	#this set check_obp bit if not present ONLY IN BANK_1, bank_2 value is set based on bank_1 value
	uci set modgui.var.check_obp="1"
fi

logecho "Applying modifications"
uci commit

check_gui_tmp
logecho "Resetting cwmp and watchdog"
/etc/init.d/watchdog-tch start > /dev/null

#This should comunicate the gui that the upgrade has finished.
if [ -f /root/.install_gui ]; then
  logecho "Removing .install_gui flag"
	rm /root/.install_gui
fi
logecho "Process complete, restarting services."

logecho "Restarting transformer..."
/etc/init.d/transformer restart
#Call a random value to check start of transformer
lua -e "require('datamodel').get('uci.env.var.oui')" > /dev/null

#This file is present only in newer build that don't suffer this strange bug
#if [ ! -f /usr/lib/lua/tch/logger.lua ]; then
#	#Wait this command better way to check if transformer is fully initialized
#	transformer-cli get uci.env.var.oui > /dev/null
#	logecho "Restarting transformer a second time cause it's just shit..."
#	/etc/init.d/transformer restart
#fi

logecho "Stopping nginx"
start_stop_nginx
