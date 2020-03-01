#!/bin/sh

. /etc/init.d/rootdevice

MD5_CHECK_DIR=/tmp/md5check
	
[ ! -d $MD5_CHECK_DIR ] && mkdir $MD5_CHECK_DIR

for file in /tmp/upgrade-pack-specificTG789Xtream35B; do
	
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

  #needed to fix opkg update from https feed
	opkg install /tmp/wget_1.17.1-1_brcm63xx-tch.ipk
	rm /tmp/wget_1.17.1-1_brcm63xx-tch.ipk
done

[ -d $MD5_CHECK_DIR ] && rm -r $MD5_CHECK_DIR

if [ ! -f /etc/config/telnet ]; then
  touch /etc/config/telnet
  uci set telnet.general=telnet
  uci set telnet.general.enable='0'
  uci commit telnet
fi

if [ -f /bin/busybox_telnet ] && [ ! -f /usr/sbin/telnetd ]; then
  ln -s /bin/busybox_telnet /usr/sbin/telnetd
fi

if [ ! -f /etc/init.d/telnet ]; then
  ln -s /etc/init.d/telnetd /etc/init.d/telnet
fi
