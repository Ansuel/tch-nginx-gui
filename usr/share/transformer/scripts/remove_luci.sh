
opkg remove --force-removal-of-dependent-packages uhttpd luci luci-*
cp /rom/usr/lib/lua/uci.so  /usr/lib/lua/
rm -r /www_luci
rm /etc/config/uhttpd

