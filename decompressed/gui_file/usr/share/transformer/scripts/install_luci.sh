#!/bin/sh
device_type="$(uci get -q env.var.prod_friendly_name)"

if [ "$device_type" == "DGA4132" ] || [ "$device_type" == "DGA4130" ]; then 
	device_type_model="$device_type"
	device_type="DGA"
fi

luci_install_DGA() {
	opkg update
	mv /usr/lib/lua/uci.so /usr/lib/lua/uci.so_bak
	if [ -f /etc/config/uhttpd ]; then
		rm /etc/config/uhttpd
	fi
	opkg install --force-reinstall libuci-lua luci rpcd
	mkdir /www_luci
	mv /www/cgi-bin /www_luci/
	mv /www/luci-static /www_luci/
	mv /www/index.html /www_luci/
	rm /usr/lib/lua/uci.so
	mv /usr/lib/lua/uci.so_bak /usr/lib/lua/uci.so
	sed -i 's/require "uci"/require "uci_luci"/g' /usr/lib/lua/luci/model/uci.lua #modify luci to load his original lib with different name
	
	if [ ! $(uci get uhttpd.main.listen_http | grep 9080) ]; then
		uci del_list uhttpd.main.listen_http='0.0.0.0:80'
		uci add_list uhttpd.main.listen_http='0.0.0.0:9080'
		uci del_list uhttpd.main.listen_http='[::]:80'
		uci add_list uhttpd.main.listen_http='[::]:9080'
		uci del_list uhttpd.main.listen_https='0.0.0.0:443'
		uci add_list uhttpd.main.listen_https='0.0.0.0:9443'
		uci del_list uhttpd.main.listen_https='[::]:443'
		uci add_list uhttpd.main.listen_https='[::]:9443'
		uci set uhttpd.main.home='/www_luci'
	fi
	
	uci commit uhttpd
	/etc/init.d/uhttpd restart
}

luci_install_tg799() {
	curl -k -L https://raw.githubusercontent.com/nutterpc/tg-luci/master/install.sh --output /tmp/install.sh
	chmod +x /tmp/install.sh
	/tmp/install.sh
}

[ "$device_type" == "DGA" ] && luci_install_DGA

[ "$(echo $device_type | grep TG789)" ] && luci_install_tg799

[ "$(echo $device_type | grep TG799)" ] && luci_install_tg799

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"
