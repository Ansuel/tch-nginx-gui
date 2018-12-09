#!/bin/sh
opkg remove aria2
rm -r /www/docroot/aria
rm -r /etc/aria2
sed -i '/aria2c/d' /etc/rc.local
killall aria2c