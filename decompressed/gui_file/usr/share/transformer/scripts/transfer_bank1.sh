if [ -d /overlay/bank_1 ] 
	then
	rm -r /overlay/bank_1
fi
mkdir /overlay/bank_1
cp -r /overlay/bank_2/* /overlay/bank_1
if [ -f /overlay/bank_1/etc/init.d/rootdevice ]
	then
	mtd erase /dev/mtd3
	mtd write /dev/mtd4 /dev/mtd3
fi
activeversion=$( cat /proc/banktable/activeversion )
passiveversion=$( cat /proc/banktable/passiveversion )

if [ "$activeversion" == "$passiveversion" ]
	then
	echo bank_1 > /proc/banktable/active
	reboot
fi


