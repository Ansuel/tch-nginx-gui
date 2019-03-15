#!/bin/sh
device_type="$(uci get -q env.var.prod_friendly_name)"

if [ "$device_type" == "DGA4132" ] || [ "$device_type" == "DGA4130" ]; then 
	device_type_model="$device_type"
	device_type="DGA"
fi

luci_remove_DGA() {
	opkg remove --force-removal-of-dependent-packages uhttpd rpcd libuci-lua luci luci-*
	
	cp /rom/usr/lib/lua/uci.so  /usr/lib/lua/ #restore lib as it gets removed by libuci-lua
	
	rm -r /www_luci
	rm /etc/config/uhttpd
}

luci_remove_tg799() {
	curl -k -L https://raw.githubusercontent.com/nutterpc/tg-luci/master/uninstall.sh --output /tmp/uninstall.sh
	chmod +x /tmp/uninstall.sh
	/tmp/uninstall.sh
}

[ "$device_type" == "DGA" ] && luci_remove_DGA

[ "$(echo $device_type | grep TG789)" ] && luci_remove_tg799

[ "$(echo $device_type | grep TG799)" ] && luci_remove_tg799

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

set_transformer "rpc.system.modgui.scriptRequest.state" "Complete"