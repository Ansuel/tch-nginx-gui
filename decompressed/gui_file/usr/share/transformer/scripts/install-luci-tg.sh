#!/bin/sh
filename="nutterpc-tg-luci-6f3cf6e"

mkdir /tmp/luciinstall
curl -k -L https://github.com/nutterpc/tg-luci/tarball/master --output /tmp/luciinstall/luci.tar.gz
gzip -d /tmp/luciinstall/luci.tar.gz
cd /tmp/luciinstall/

mkdir ./extracted
tar -xvf luci.tar -C ./extracted
cd ./extracted
cd ./$filename
chmod +x ./install.sh
chmod +x ./uninstall.sh
mkdir /www/luci-files
cp /tmp/luciinstall/extracted/$filename/install.sh /www/luci-files/
cp /tmp/luciinstall/extracted/$filename/uninstall.sh /www/luci-files/
cp -R /tmp/luciinstall/extracted/$filename/*.ipk /www/luci-files/
rm -R /tmp/luciinstall
/www/luci-files/install.sh



