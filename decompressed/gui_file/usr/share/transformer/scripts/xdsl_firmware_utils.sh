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

log() {
	logger -t "Refresh xDSL Driver: $1"
	echo "Refresh xDSL Driver: $1"
}

curl="/usr/bin/curl -k -s"
try=0
CLEAN=0

checksums="
453dc537d3cbd6f45657c9eb8ba2eb40  A2pvbH042j2
9086cc14d865b8ec090345545425ba40  A2pvbH042n
7bcf3f18e4b25e1fdf16412e5832930c  A2pvbH042o
db76ca2f5015dd17504f1c658373e0aa  A2pvbH042r
bcfaed886a6dfd6cd2a0be2ac4e3823c  A2pvbH042u
a981a610dc01a932216a3508cf3e325f  A2pvfbH043b
fbaade8f05cad074403b693fedc9a2b8  A2pvfbH043g
5988d3c56b0fee3ce0c3843cda4358b1  A2pvfbH043k
6e8de6c77db38a5b5394f7f7c4221196  A2pvfbH043o
1fe1773b24a5eba1d92333a788a4a279  A2pvfbH043h
4455c1c2416d4f4a6336861378550dbf  A2pvfbH043i
efee94080f1ab7e29a1c7a571a6c8488  B2pvbH042l
2a44b0dd6c0b24c29f8ea1aab10d60f0  B2pvbH042s
3f85469797162bda08fabc28ed325042  B2pvfbH043e
42e93153db06857021faf1de1b320f6d  B2pvfbH043g
d76d9eebfccd572b0a0943cd3957b82a  B2pvfbH043i1
1767c3c86b5e4f5b46ce024ccd4f91b2  B2pvfbH043k
3a6e7122462e51623e8ed3c6b17e46d4  B2pvbH042j2
3bd099fc326da94376c317204bba4d01  A2pv6F039v2
b3c2341f91a39114bce643b6547ed3c6  A2pv6F039x5
f338c1d3d39c2c2b2a602784c668e726  B2pv6F039v
1c234e007b4c9b50d2ff7475848885c0  A2pv6F039u
86fc1ee93a236baa5894768c077cd746  A2pv6F038f2
a456d92a642fc6a4cc2edd2e503420f8  A2pv6F039m1
e9e17c447a5ae7cf424b69a61ae3d62b  A2pv6F039o1
dd7107058ade6405151ae708f46c07b3  A2pv6F039v4
ab254b632ed51af98088df78d235bd8f  A2pv6F039v
f8b79ad11f3089ff301fa81e5c5f7cb7  A2pv6F039f1
e770d5a89ce9fd29cc6f2a63c3ffc351  A2pv6F039e
dc8f33f59901a4a38cbb292ae6fcb390  B2pv6F039k
b75a96fef8010f0f728d77368aa776ce  A2pv6F039x1
3b1be04587a2df4aa56c179a711cec79  A2pv6F039x6
8fd81e22b9e7e5fa6b6ee6d7d3fc5353  A2pvfbH043j2
648e9ca169cd73be4bdf99bf862e9e8d  A2pvfbH043q
70e51c7948c01583963cad39174ed2c0  B2pvfbH043q
033ddd744ae3e82c84314db84f9e062b  A2pvfbH045k
49bf76755cb9bd9f8b09e4b79a0496ef  A2pvfbH043d1
462fd33eb2e02b263f36ff11427f2aa8  B2pvfbH043d1
0a5c3cbbe500de3fe6949e08d3e07331  A2pvfbH043i2
a8606f73a646bf8051be4650b3090fe3  A2pv6F039t
2e5541e674e2acfab72d2f2becdfc995  B2pvfbH045k
01f2f50f3f9e49f9d68705ea96e92429  A2pvfbH045l
338d7eef1dfffa6b4c7bc7baeca86975  B2pvfbH045l
e29df9a67a5cd38512afc5c325e859bd  A2pvfbH045o
b4ffad29ffa325d3904cb6f26800c625  B2pvfbH045o
af819f9e761207e4b21040cc5b687d81  A2pvfbH045o1
e5aaffb9b5c6c113a0c9fcbc9f754b9a  B2pvfbH045o1
a4ecffcbde7dd55e7eaa08d694a96fde  A2pvfbH045p
733a9a783838707635af7f8a6f3882b3  A2pvfbH045q
74c89e5ada33e6bbc439185d541f1529  A2pvfbH045r
7f95a5b59938204db25939bcfc0a1ae7  A2pvfbH046w
41f1d53abfaf30390ceaa354d0d84c49  B2pvfbH046w
d1ae358e154f32cb33607ae7f5072f9c  A2pvfbH046y
90cc6b3354c22965b4e6c4b716cae682  B2pvfbH046y
58bf11929814bc104f977ccfd526755a  A2pvfbH046u
35375a69ccd7a4deb1d4880c06d19117  A2pvfbH045s
"

if [ -z "$1" ]; then
	log "Provide a driver version as args to use this script or 'clean' to restore original firmware. Terminating"
	exit 0
else
	[ "$1" = "clean" ] && CLEAN=1
fi

installed_driver=$(xdslctl --version 2>&1 >/dev/null | grep 'version -' | awk '{print $6}' | sed 's/\..*//')
request_driver="$1"

if [ "$(grep </proc/cpuinfo Processor | grep ARM)" ]; then
	arch=arm
elif [ "$(grep </proc/cpuinfo 'cpu model' | grep MIPS)" ]; then
	arch=mips
fi

download_Driver() {
	log "Downloading driver $request_driver"
	curl -sk "https://raw.githubusercontent.com/Ansuel/tch-nginx-gui/master/xdsl_driver/$arch/$request_driver" --output "/tmp/$request_driver"
}

test_apply() {
	if [ -f "/tmp/$request_driver" ]; then
		rm "/tmp/$request_driver"
	fi
	connectivity="yes"
	if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
		connectivity="yes"
	else
		connectivity="no"
	fi

	if [ $connectivity == "yes" ]; then
		if [ "$installed_driver" != "$request_driver" ]; then
			download_Driver
			if [ "$(echo $checksums | grep $(md5sum /tmp/$request_driver | awk '{print $1}'))" ]; then

				log "Testing driver $request_driver... If the modem crash, reset the driver on next boot"
				rm /etc/adsl/adsl_phy.bin
				ln -s /tmp/$request_driver /etc/adsl/adsl_phy.bin
				log "Restarting xDSL..."
				xdslctl stop
				/etc/init.d/xdsl restart >/dev/null
				sleep 5
				log "Reading version with xdslctl..."
				xdslctl --version
				log "Moving driver to permantent dir"
				rm /etc/adsl/adsl_phy.bin
				mv /tmp/$request_driver /etc/adsl/adsl_phy.bin

				if [ -f "/tmp/$request_driver" ]; then
					rm "/tmp/$request_driver"
				fi
			else
				log "Download corrupted, retrying..."
				try=$((try + 1))
				download_Driver
				if [ $try -lt 2 ]; then
					test_apply
				else
					log "Too much try, aborting..."
				fi
			fi
		fi
	else
		log "No internet connection detected, Terminating."
	fi
}

if [ $CLEAN -eq 0 ]; then
	log "Trying to download and apply driver $request_driver..."
	test_apply
	log "Process done"
else
	log "Restoring original driver"
	rm /etc/adsl/adsl_phy.bin
	cp /rom/etc/adsl/adsl_phy.bin /etc/adsl/adsl_phy.bin
	log "Restarting xDSL..."
	xdslctl stop
	/etc/init.d/xdsl restart >/dev/null
	log "Process done"
fi
