bank_1="/dev/mtd3"
bank_2="/dev/mtd4"

booted=$( cat /proc/banktable/booted )
notbooted=$( cat /proc/banktable/notbooted )

eval "orig=\$$booted"
eval "dest=\$$notbooted"

if [ -d /overlay/$notbooted ]; then
	rm -r /overlay/$notbooted
fi
if [ -d /overlay/$booted ]; then
	mkdir /overlay/$notbooted
	cp -r /overlay/$booted/* /overlay/$notbooted/
fi
if [ -f /overlay/$notbooted/etc/init.d/rootdevice ]; then
	mtd erase $dest
	mtd write $orig $dest
fi
