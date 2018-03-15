opkg update
opkg install transmission-web

uci set transmission.@transmission[0].enabled=1
uci set transmission.@transmission[0].rpc_whitelist='127.0.0.1,192.168.*'
uci commit
/etc/init.d/transmission enable
/etc/init.d/transmission restart