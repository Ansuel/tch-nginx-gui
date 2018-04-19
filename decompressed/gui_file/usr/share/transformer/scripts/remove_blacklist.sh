
wget -P /tmp http://blacklist.satellitar.it/repository/blacklist.latest.tar.gz
tar -zxvf /tmp/blacklist.latest.tar.gz -C /tmp
cd /tmp/blacklist.latest
./uninstall.sh
rm /tmp/blacklist.latest.tar.gz
rm -r /tmp/blacklist.latest