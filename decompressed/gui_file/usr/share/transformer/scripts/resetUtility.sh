#!/bin/sh
#
#	 Custom Gui for Technicolor Modem: utility script and modified gui for the Technicolor Modem
#	 								   interface based on OpenWrt
#
#    Copyright (C) 2018  Christian Marangi <ansuelsmth@gmail.com>
#
#    This file is part of Custom Gui for Technicolor Modem.
#    
#    Custom Gui for Technicolor Modem is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    
#    Custom Gui for Technicolor Modem is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    
#    You should have received a copy of the GNU General Public License
#    along with Custom Gui for Technicolor Modem.  If not, see <http://www.gnu.org/licenses/>.
#
#

showUsage() {
	echo "Reset Utility: run custom command to perform advanced reset."
	echo "Usage:"
	echo "	--help 		Show help message"
	echo "	--resetGui 	Restore original gui"
	echo "	--removeRoot 	Remove root and wipe overlay bank (factory reset)"
	echo "	--removeConfig 	Reset config. Modded gui is reinstalled"
}

restoreOriginalGui() {
	rm -r /www/*
	rm /etc/nginx/nginx.conf
	rm -r /usr/share/transformer/*
	rm -r /usr/lib/lua/transformer/*
	rm -r /usr/lib/lua/web/*
	
	cp -r /rom/www/* 			/www/
	cp /rom/etc/nginx/nginx.conf 	   	/etc/nginx/nginx.conf
	cp -r /rom/usr/share/transformer/* 	/usr/share/transformer/
	cp -r /rom/usr/lib/lua/transformer/* 	/usr/lib/lua/transformer/
	cp -r /rom/usr/lib/lua/web/* 		/usr/lib/lua/web/
	
	/etc/init.d/rootdevice force
}

resetConfig() {
	rm -r /overlay/$(cat /proc/banktable/booted)/etc/uci-defaults/*
	rm -r /etc/config/*
	cp -r /rom/etc/config/* /etc/config/
	reboot
}

case "$1" in
		--help)
			showUsage
			;;
		--resetGui)
			restoreOriginalGui
			;;
		--removeRoot)
			/usr/share/transformer/scripts/hardreset.sh
			;;
		--removeConfig)
			resetConfig
			;;
		"")
			echo "resetUtility: provide an option. Use --help to show them." 1>&2
			;;
		*)
			echo "resetUtility: unknown option '$1'" 1>&2
			return 1
esac

