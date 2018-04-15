
wget -P /tmp http://blacklist.satellitar.it/repository/install_blacklist.sh

cd /tmp

chmod u+x ./install_blacklist.sh 

./install_blacklist.sh update

rm ./install_blacklist.sh