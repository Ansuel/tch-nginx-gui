#!/bin/sh
# Copyright (C) 2018 kevdagoat (kevdawhirl@gmail.com)
# Written by kevdagoat for tch-nginx-gui.
# Last Updated: 15/5/19: Added new modgui support


######################################################################
DATE=$(date +%Y-%m-%d)
prod=$(uci get env.var.prod_name)
friend=$(uci get env.var.prod_friendly_name)
isp=$(uci get env.var._provisioning_code)
version=$(uci get env.var.friendly_sw_version_activebank)

log() {
logger -s -t "DebugHelper" "$1"
}
#####################################################################

if [ "$1" == "help" ]
then
log "debug <command>"
log "Commands Avaliable:"
log "dev -run this tool without running rootdevice"
log "help -show this"
exit 0
fi

log "DebugHelper Started! Run debug help for commands."

log "Removing directory /tmp/$DATE-DebugHelper/* to prevent duplicates"
rm -R /tmp/$DATE-DebugHelper > /dev/null 2>&1

log "Creating dir"
mkdir /tmp/$DATE-DebugHelper/ > /dev/null 2>&1
cd /tmp/$DATE-DebugHelper/

touch ./error.log
touch ./deviceinfo.txt
touch ./processes.txt
touch ./configlist.txt
touch ./gui-install.log


#################################################################################################################################################################
log "Gathering device info..."
echo "___________________________________DEVICE INFO_________________________________________" >> ./deviceinfo.txt


echo "Product Name: $prod" >> ./deviceinfo.txt
echo "Friendly Name: $friend" >> ./deviceinfo.txt
echo "ISP Name: $isp" >> ./deviceinfo.txt
echo "FW Version: $version" >> ./deviceinfo.txt

cat /etc/config/modgui >> ./deviceinfo.txt
sed -i '/encrypted/d' ./deviceinfo.txt

log "Copying firewall config..."
cp /etc/config/firewall ./firewall.txt > /dev/null 2>&1

log "Copying nginx config..."
mkdir ./nginx-files > /dev/null 2>&1
cp -R /etc/nginx/* ./nginx-files/ > /dev/null 2>&1

log "Copying samba config..."
cp /etc/config/samba ./samba.txt > /dev/null 2>&1

log "Copying dlna config..."
if [ -f "/etc/config/dlnad" ]; then
	cp /etc/config/dlnad ./dlna-dlnad.txt > /dev/null 2>&1
	sed -i '/uuid/d' ./dlna-dlnad.txt
elif [ -f "/etc/config/minidlna" ]; then
	cp /etc/config/minidlna ./dlna-minidlna.txt > /dev/null 2>&1
	sed -i '/uuid/d' ./dlna-minidlna.txt
else
	log "DLNA daemon doesn't exist!!"
	touch ./dlna-nonexistant.txt
fi

###########################################################################################################################################################

log "Scanning for log errors..."
echo "__________________________________LOG_________________________________________" >> ./error.log
logread |grep daemon.err >> ./error.log
echo " " >> ./error.log

###########################################################################################################################################################

log "Listing processes..."
echo "__________________________________PROCESSES_________________________________________" >> ./processes.txt
ps >> ./processes.txt 
echo " " >> ./processes.txt

###########################################################################################################################################################

log "Scanning /etc/config directory..."
echo "__________________________________CONFIG FILE LIST_________________________________________" >> ./configlist.txt
ls /etc/config/ >> ./configlist.txt
echo " " >> ./configlist.txt

###########################################################################################################################################################
echo "__________________________________GUI INSTALL LOG_________________________________________" >> ./gui-install.log
if [ "$1" == "dev" ] 
then
log "Dev Mode. Not running rootdevice"
else
log "Running rootdevice script in debug mode. This will take ~35sec..."
/etc/init.d/rootdevice debug > ./gui-install.log 2>&1
echo " " >> ./gui-install.log
fi
###########################################################################################################################################################
log "Tarring File..."
tar -czvf ./DebugHelper$DATE.tar.gz /tmp/$DATE-DebugHelper > /dev/null 2>&1
log "All Done! Zipped file can be found in /tmp/$DATE-DebugHelper/. The name of it is DebugHelper$DATE.tar.gz."
