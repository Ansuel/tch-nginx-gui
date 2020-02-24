. /etc/init.d/rootdevice

check_gui_tmp() {
	if [ -f /tmp/GUI_dev.tar.bz2 ]; then
		logger_command "Found GUI_dev in tmp dir... Cleaning..."
		rm /tmp/GUI_dev.tar.bz2
	fi
	if [ -f /tmp/GUI.tar.bz2 ]; then
		logger_command "Found GUI in tmp dir... Cleaning..."
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
	while [ "$(curl 127.0.0.1 --max-time 20 -I -s | head -n 1 | cut -d$' ' -f2)" != "200" ] && [ $nginx_count -lt 5 ]; do
		if [ $nginx_count -gt 3 ]; then
			if [ -f /var/run/nginx.pid ]; then
				kill -KILL "$(cat /var/run/nginx.pid)"
				rm /var/run/nginx.pid
			fi
			for pid in $(pgrep nginx); do 
				kill -KILL "$pid"
			done
		fi
		logger_command "Restarting nginx..." ConsoleOnly
		/etc/init.d/nginx restart 2>/dev/null
		sleep 5
		nginx_count=$((nginx_count+1))
	done
}

logger_command "Applying modifications"
uci commit

if [ -f /root/.sfp_change ]; then
	rm /root/.sfp_change
	/etc/init.d/network restart
	ifup wan
fi

check_gui_tmp
logger_command "Resetting cwmp and watchdog"
/etc/init.d/watchdog-tch start

#This should comunicate the gui that the upgrade has finished.
rm /root/.check_process #we remove the placeholder as the process is complete
logger_command "Process done."

logger_command "Restarting transformer" ConsoleOnly
/etc/init.d/transformer restart
#Call a random value to check start of transformer
lua -e "require('datamodel').get('uci.env.var.oui')" > /dev/null

#This file is present only in newer build that don't suffer this strange bug
#if [ ! -f /usr/lib/lua/tch/logger.lua ]; then
#	#Wait this command better way to check if transformer is fully initialized
#	transformer-cli get uci.env.var.oui > /dev/null
#	logger_command "Restarting transformer a second time cause it's just shit..."
#	/etc/init.d/transformer restart
#fi

logger_command "Stopping nginx" ConsoleOnly
start_stop_nginx