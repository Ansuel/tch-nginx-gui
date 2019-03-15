#!/bin/sh
opkg remove aria2
rm -r /www/docroot/aria
rm -r /etc/aria2
sed -i '/aria2c/d' /etc/rc.local
killall aria2c

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"