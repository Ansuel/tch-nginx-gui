#!/bin/sh

opkg update
opkg install unzip aria2 libstdcpp
wget https://github.com/mayswind/AriaNg-DailyBuild/archive/master.zip -P /tmp
unzip /tmp/master.zip -d /www/docroot/
rm /tmp/master.zip
mv /www/docroot/AriaNg-DailyBuild-master /www/docroot/aria

ARIA2_DIR="/etc/aria2"

mkdir $ARIA2_DIR
touch $ARIA2_DIR/aria2.conf
touch $ARIA2_DIR/aria2.session

echo 'enable-rpc=true' >> $ARIA2_DIR/aria2.conf
echo 'rpc-allow-origin-all=true' >> $ARIA2_DIR/aria2.conf
echo 'rpc-listen-all=true' >> $ARIA2_DIR/aria2.conf
echo 'rpc-listen-port=6800' >> $ARIA2_DIR/aria2.conf
echo 'input-file=/etc/aria2/aria2.session' >> $ARIA2_DIR/aria2.conf
echo 'save-session=/etc/aria2/aria2.session' >> $ARIA2_DIR/aria2.conf
echo 'save-session-interval=300' >> $ARIA2_DIR/aria2.conf
echo 'dir=/mnt/usb/USB-A1' >> $ARIA2_DIR/aria2.conf

# add aria2 in /etc/rc.local to start the daemon after a reboot
sed -i '/exit 0/i \
aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=/etc/aria2/aria2.conf' /etc/rc.local

# start the daemon
aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=$ARIA2_DIR/aria2.conf
