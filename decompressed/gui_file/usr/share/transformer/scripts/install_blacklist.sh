#!/bin/sh
wget -P /tmp http://blacklist.satellitar.it/repository/install_blacklist.sh

cd /tmp

chmod u+x ./install_blacklist.sh 

if [ $1 == "empty" ]; then
	./install_blacklist.sh update
else
	./install_blacklist.sh
fi

rm ./install_blacklist.sh

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"