
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

