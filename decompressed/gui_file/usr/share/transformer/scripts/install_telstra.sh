#!/bin/sh
curl -k https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/modular/telstra_gui.tar.bz2 --output /tmp/telstra_gui.tar.bz2
bzcat /tmp/telstra_gui.tar.bz2 | tar -C / -xf - 
rm /tmp/telstra_gui.tar.bz2
/etc/init.d/nginx restart

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"