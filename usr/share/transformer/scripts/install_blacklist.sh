
wget -P /tmp http://blacklist.satellitar.it/repository/blacklist.2.0.tar.gz
tar -zxvf /tmp/blacklist.2.0.tar.gz -C /tmp
cd /tmp/blacklist.2.0
./install.sh

./import-blacklist.sh