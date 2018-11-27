#!/bin/sh
if [ $(uci get env.var.update_branch) == "dev" ]; then
	branch="dev"
else
	branch="master"
fi

curl -k https://raw.githubusercontent.com/Ansuel/tch-nginx-gui/$branch/modular/telstra_gui.tar.bz2 --output /tmp/telstra_gui.tar.bz2
bzcat /tmp/telstra_gui.tar.bz2 | tar -C / -xf - 
rm /tmp/telstra_gui.tar.bz2
/etc/init.d/nginx restart