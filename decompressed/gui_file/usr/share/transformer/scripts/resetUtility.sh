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
	running_bank=$(cat /proc/banktable/booted)
	config_tmp=/tmp/config_tmp
	
	#Copying config simulating a firmware upgrade
	echo "Copying config files to config_tmp dir in RAM..."
	mkdir /tmp/config_tmp
	mkdir /tmp/shadow_file
	cp /overlay/$running_bank/etc/config/* $config_tmp/
	cp /overlay/$running_bank/etc/shadow /tmp/shadow_file/
	
	#Saving root files
	emergencydir=/tmp/rootfile/emergency
	mkdir /tmp/rootfile
	mkdir $emergencydir
	mkdir $emergencydir/etc
	mkdir $emergencydir/etc/init.d 
	mkdir $emergencydir/etc/rc.d 
	mkdir $emergencydir/usr
	mkdir $emergencydir/usr/bin 
	mkdir $emergencydir/lib
	mkdir $emergencydir/lib/upgrade 
	mkdir $emergencydir/sbin
	cp /overlay/$running_bank/lib/upgrade/platform.sh $emergencydir/lib/upgrade/
	cp /overlay/$running_bank/sbin/sysupgrade $emergencydir/sbin/
	cp /overlay/$running_bank/etc/init.d/rootdevice $emergencydir/etc/init.d/
	cp /overlay/$running_bank/usr/bin/rtfd $emergencydir/usr/bin/
	cp /overlay/$running_bank/usr/bin/sysupgrade-safe $emergencydir/usr/bin/
	cp -d /overlay/$running_bank/etc/rc.d/S94rootdevice $emergencydir/etc/rc.d/
	
	#Delete any change from running bank
	rm -r /overlay/$running_bank
	
	#Restore config to be converted
	if [ -d $config_tmp ]; then
		mkdir -p /overlay/homeware_conversion/etc/config
		cp $config_tmp/* /overlay/homeware_conversion/etc/config/
		cp $config_tmp/modgui /overlay/homeware_conversion/etc/modgui_old
		cp /tmp/shadow_file/shadow /overlay/homeware_conversion/etc/
		cp /tmp/shadow_file/shadow /overlay/$running_bank/shadow_old
	fi
	
	#Root only
	emergencydir=/tmp/rootfile/emergency
	mkdir /overlay/$running_bank
	cp -dr $emergencydir/* /overlay/$running_bank/
	reboot
}

resetConfig() {
	rm -r "/overlay/$(cat /proc/banktable/booted)/etc/uci-defaults"
	rm -r /etc/config/*
	cp -r /rom/etc/config/* /etc/config/
	[ "$(pgrep "cwmpd")" ] && /etc/init.d/cwmpd stop
	[ -f /etc/cwmpd.db ] && rm /etc/cwmpd.db
	touch /root/.install_gui #this is needed to trigger GUI full install after reboot mainly to reapply all custom edits to stock config files needed by custom GUI
	reboot
}

resetCwmp() {
	[ "$(pgrep "cwmpd")" ] && /etc/init.d/cwmpd stop
	[ -f /etc/cwmpd.db ] && rm /etc/cwmpd.db
	/etc/init.d/cwmpd start
}

case "$1" in
		--help)
			showUsage
			;;
		--resetCWMP)
			resetCwmp
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

