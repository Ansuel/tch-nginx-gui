#
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
453dc537d3cbd6f45657c9eb8ba2eb40  A2pvbH042j2.d26r
9086cc14d865b8ec090345545425ba40  A2pvbH042n.d26r
7bcf3f18e4b25e1fdf16412e5832930c  A2pvbH042o.d26r
db76ca2f5015dd17504f1c658373e0aa  A2pvbH042r.d26r
bcfaed886a6dfd6cd2a0be2ac4e3823c  A2pvbH042u.d26r
a981a610dc01a932216a3508cf3e325f  A2pvfbH043b.d26r
f7fe190a7966a96e7340a928f96fbe77  A2pvfbH043e.d26r_BROKEN
fbaade8f05cad074403b693fedc9a2b8  A2pvfbH043f.d26r
fbaade8f05cad074403b693fedc9a2b8  A2pvfbH043g.d26r
5988d3c56b0fee3ce0c3843cda4358b1  A2pvfbH043k.d26r
6e8de6c77db38a5b5394f7f7c4221196  A2pvfbH043o.d26r
"

installed_driver=$(transformer-cli get rpc.xdsl.dslversion | awk '{print $4}')
driver_set=$(uci get env.var.driver_version)

apply_driver() {
	mv /tmp/$driver_set /etc/adsl/adsl_phy.bin
	logger "Restarting xdslctl"
	xdslctl stop
	/etc/init.d/xdsl start
}

download_Driver() {
	logger "Downloading driver "$driver_set
	wget -O /tmp/$driver_set https://repository.ilpuntotecnico.com/files/Ansuel/AGTEF/adsl_driver/$driver_set
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
				try=try+1
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