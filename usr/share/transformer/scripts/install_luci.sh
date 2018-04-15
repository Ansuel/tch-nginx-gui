opkg update
mv /usr/lib/lua/uci.so /usr/lib/lua/uci.so_bak
opkg install --force-reinstall libuci-lua luci rpcd
mkdir /www_luci
mv /www/cgi-bin /www_luci/
mv /www/luci-static /www_luci/
mv /www/index.html /www_luci/

if [ ! $(uci get uhttpd.main.listen_http | grep 9080) ]; then
	uci del_list uhttpd.main.listen_http='0.0.0.0:80'
	uci add_list uhttpd.main.listen_http='0.0.0.0:9080'
	uci del_list uhttpd.main.listen_http='[::]:80'
	uci add_list uhttpd.main.listen_http='[::]:9080'
	uci del_list uhttpd.main.listen_https='0.0.0.0:443'
	uci add_list uhttpd.main.listen_https='0.0.0.0:9443'
	uci del_list uhttpd.main.listen_https='[::]:443'
	uci add_list uhttpd.main.listen_https='[::]:9433'
	uci set uhttpd.main.home='/www_luci'
fi

uci commit
/etc/init.d/uhttpd restart