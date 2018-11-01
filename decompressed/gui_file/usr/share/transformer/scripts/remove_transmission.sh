opkg remove --force-removal-of-dependent-packages transmission-daemon-openssl transmission-web
rm -r /www/docroot/transmission
rm -r /etc/config/transmission*
rm -r /var/transmission
