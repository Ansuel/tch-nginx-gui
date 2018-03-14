opkg update
opkg install transmission-web
mkdir /www/docroot/transmission
cp -r /usr/share/transmission/web/* /www/docroot/transmission/
rm -r /usr/share/transmission
