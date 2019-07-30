. /etc/init.d/rootdevice

kernel_ver="$(cat /proc/version | awk '{print $3}')"

if [ -z "${kernel_ver##3.4*}" ]; then

MD5_CHECK_DIR=/tmp/md5check
	
[ ! -d $MD5_CHECK_DIR ] && mkdir $MD5_CHECK_DIR

for file in /tmp/upgrade-pack-specificDGA; do
	
	if [ ! -f $MD5_CHECK_DIR/$file ]; then
		if [ ! -d /$file ]; then
			mkdir /$file
		fi
		continue
	fi
	
	[ -n "$( echo $file | grep .md5sum )" ] && continue
	
	orig_file=/$file
	file=$MD5_CHECK_DIR/$file
	
	if [ -f $orig_file ]; then
		md5_file=$(md5sum $file | awk '{ print $1 }' )
		md5_orig_file=$(md5sum $orig_file | awk '{ print $1 }' )
		if [ $md5_file == $md5_orig_file ]; then
			rm $file
			continue
		fi
	fi
	
	cp $file $orig_file
	rm $file
	RESTART_SERVICE=1
	
done

[ -d $MD5_CHECK_DIR ] && rm -r $MD5_CHECK_DIR

if [ ! -f /etc/config/telnet ]; then
	cp /tmp/telnet_orig /etc/config/telnet
fi

if [ ! -f /etc/config/dland ]; then
	cp /tmp/dland_orig /etc/config/dland
fi

rm /tmp/dlnad_orig
rm /tmp/telnet_orig

if [ -f /bin/busybox_telnet ] && [ ! -h /usr/sbin/telnetd ]; then
	ln -s /bin/busybox_telnet /usr/sbin/telnetd
fi

	opkg install /tmp/3.4_ipk/wget_1.17.1-1_brcm63xx-tch.ipk
	rm -r /tmp/3.4_ipk /tmp/4.1_ipk

elif [ -z "${kernel_ver##4.1*}" ]; then

	if [ ! -f /bin/busybox_telnet ]; then
		opkg install /tmp/4.1_ipk/busybox_telnet_1.23.2-1_brcm63xx-tch.ipk
	fi
	
	if [ ! -f /etc/config/telnet ]; then
		cp /tmp/telnet_orig /etc/config/telnet
	fi
	
	if [ -f /bin/busybox_telnet ] && [ ! -h /usr/sbin/telnetd ]; then
		ln -s /bin/busybox_telnet /usr/sbin/telnetd
	fi
	
	rm -r /tmp/3.4_ipk /tmp/4.1_ipk
fi
