
device_type="$(uci get -q env.var.prod_friendly_name)"

if [ "$device_type" == "DGA4132" ] || [ "$device_type" == "DGA4130" ]; then 
	device_type_model="$device_type"
	device_type="DGA"
fi

luci_remove_DGA() {
	opkg remove --force-removal-of-dependent-packages uhttpd rpcd libuci-lua luci luci-*
	
	if [ -f /usr/lib/lua/uci.so_bak ]; then
		if [ -f /usr/lib/lua/uci.so ]; then
			rm /usr/lib/lua/uci.so
			mv /usr/lib/lua/uci.so_bak /usr/lib/lua/uci.so
		else
			mv /usr/lib/lua/uci.so_bak /usr/lib/lua/uci.so
		fi
	else
		if [ -f /usr/lib/lua/uci.so ]; then
			rm /usr/lib/lua/uci.so
		fi
		cp /rom/usr/lib/lua/uci.so  /usr/lib/lua/
	fi
	
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
