#!/bin/sh

install_DGA() {
    opkg update
    opkg install transmission-web transmission-daemon-openssl

    uci set transmission.@transmission[0].enabled=1
    uci set transmission.@transmission[0].rpc_whitelist='127.0.0.1,192.168.*'
    uci commit

    cp -r /usr/share/transmission /www/docroot/
    rm /www/docroot/transmission/web/index.html /www/docroot/transmission/web/LICENSE

    /etc/init.d/transmission enable
    /etc/init.d/transmission restart
}

install_from_github(){
    curl -sLk https://github.com/$1/tarball/$2 --output /tmp/$2.tar.gz
    mkdir /tmp/$2
    tar -xzf /tmp/$2.tar.gz -C /tmp/$2
    rm /tmp/$2.tar.gz
    cd /tmp/$2/*
    chmod +x ./setup.sh
	./setup.sh
	rm -r /tmp/$2
}

device_type="$(uci get -q env.var.prod_friendly_name)"

[ "$(echo $device_type | grep DGA)" ] && install_DGA

[ "$(echo $device_type | grep TG789)" ] && install_from_github FrancYescO/sharing_tg789 transmission

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"