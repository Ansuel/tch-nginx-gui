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

curl="/usr/bin/curl -k -s"

wanmode=$(uci get -q network.config.wan_mode)
connectivity="yes"
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
  connectivity="yes"
else
  connectivity="no"
fi

try=0

sleep 7

checksums="
453dc537d3cbd6f45657c9eb8ba2eb40  A2pvbH042j2
9086cc14d865b8ec090345545425ba40  A2pvbH042n
7bcf3f18e4b25e1fdf16412e5832930c  A2pvbH042o
db76ca2f5015dd17504f1c658373e0aa  A2pvbH042r
bcfaed886a6dfd6cd2a0be2ac4e3823c  A2pvbH042u
a981a610dc01a932216a3508cf3e325f  A2pvfbH043b
fbaade8f05cad074403b693fedc9a2b8  A2pvfbH043f
fbaade8f05cad074403b693fedc9a2b8  A2pvfbH043g
5988d3c56b0fee3ce0c3843cda4358b1  A2pvfbH043k
6e8de6c77db38a5b5394f7f7c4221196  A2pvfbH043o
efee94080f1ab7e29a1c7a571a6c8488  B2pvbH042l
2a44b0dd6c0b24c29f8ea1aab10d60f0  B2pvbH042s
3f85469797162bda08fabc28ed325042  B2pvfbH043e
42e93153db06857021faf1de1b320f6d  B2pvfbH043g
d76d9eebfccd572b0a0943cd3957b82a  B2pvfbH043i1
1767c3c86b5e4f5b46ce024ccd4f91b2  B2pvfbH043k
"

installed_driver=$(transformer-cli get rpc.xdsl.dslversion | awk '{print $4}'  | cut -d. -f1)
driver_set=$(uci get env.var.driver_version)

if [ "$(cat /proc/cpuinfo | grep Processor | grep ARM)" ]; then
	arch=arm
elif [ "$(cat /proc/cpuinfo | grep 'cpu model' | grep MIPS)" ]; then
	arch=mips
fi

apply_driver() {
	mv /tmp/$driver_set /etc/adsl/adsl_phy.bin
	logger "Restarting xdslctl"
	xdslctl stop
	/etc/init.d/xdsl start
}

download_Driver() {
	logger "Downloading driver "$driver_set
	remote_driver_dir=https://raw.githubusercontent.com/Ansuel/tch-nginx-gui/dev/modular/xdsl_driver/$arch/
	$curl $remote_driver_dir/$driver_set --output /tmp/$driver_set
}

test_apply() {
	if [ -f /tmp/$driver_set ]; then
		rm /tmp/$driver_set
	fi
	if [ "$wanmode" != "bridge" ] && [ $connectivity == "yes" ]; then
		if [ $installed_driver != $driver_set ]; then
			download_Driver
			if [ "$(echo $checksums | grep $( md5sum /tmp/$driver_set | awk '{print $1}' ) )" ]; then
				apply_driver
				if [ -f /tmp/$driver_set ]; then
					rm /tmp/$driver_set
				fi
			else
				logger "Download corrupted, retrying..."
				try=$((try+1))
				download_Driver
				if [ $try < 2 ]; then
					test_apply
				else
					logger "Too much try, aborting..."
				fi
			fi
		fi
	fi
}

test_apply