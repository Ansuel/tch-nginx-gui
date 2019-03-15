#!/bin/sh

opkg remove xupnpd

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"