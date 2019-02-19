#!/bin/sh
wget -P /tmp http://blacklist.satellitar.it/repository/blacklist.latest.tar.gz
tar -zxvf /tmp/blacklist.latest.tar.gz -C /tmp
cd /tmp/blacklist.latest
./uninstall.sh
rm /tmp/blacklist.latest.tar.gz
rm -r /tmp/blacklist.latest

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"