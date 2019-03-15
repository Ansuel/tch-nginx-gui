#!/bin/sh
opkg remove --force-removal-of-dependent-packages transmission-daemon-openssl transmission-web
rm -r /www/docroot/transmission
rm -r /etc/config/transmission*
rm -r /var/transmission

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"