# Copyright (C) 2018 kevdagoat (kevdawhirl@gmail.com)
# Written by kevdagoat for tch-nginx-gui.


#!/bin/sh
######################################################################
DATE=$(date +%Y-%m-%d)
prod=$(uci get env.var.prod_name)
friend=$(uci get env.var.prod_friendly_name)
isp=$(uci get env.var._provisioning_code)
version=$(uci get env.var.friendly_sw_version_activebank)
guiver=$(uci get env.var.gui_version)
dsl=$(uci get env.var.driver_version)
guihash=$(uci get env.var.gui_hash)
guibranch=$(uci get env.var.update_branch)
guifirst=$(uci get env.var.firstpage)
guirancol=$(uci get env.var.randomcolor)
skin=$(uci get env.var.gui_skin)
aria=$(uci get env.var.aria2_webui)
luci=$(uci get env.var.luci_webui)
trans=$(uci get env.var.transmission_webui)
xupnp=$(uci get env.var.xupnp_app)
blk=$(uci get env.var.blacklist_app)
telstra=$(uci get env.var.telstra_webui)
 

log() {
logger -s -t "DebugHelper" "$1"
}
#####################################################################

log "DebugHelper Started!"

log "Removing directory /tmp/$DATE-DebugHelper/* to prevent duplicates"
rm -R /tmp/$DATE-DebugHelper/* > /dev/null 2>&1

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
echo "DSL Version: $dsl" >> ./deviceinfo.txt

echo "GUI Skin: $skin" >> ./deviceinfo.txt
echo "GUI Version: $guiver" >> ./deviceinfo.txt
echo "GUI Hash: $guihash" >> ./deviceinfo.txt
echo "GUI Branch: $guibranch" >> ./deviceinfo.txt
echo "GUI First Page: $guifirst" >> ./deviceinfo.txt

 if [ $guirancol == 1 ]
  then
    echo "GUI Random Colour enabled" >> ./deviceinfo.txt
  else
    echo "GUI Random Colour disabled" >> ./deviceinfo.txt
  fi

echo "-----List of Installed Extensions-----" >> ./deviceinfo.txt


if [ $aria -eq 1 ] 
then
echo "Aria Installed" >> ./deviceinfo.txt
fi
if [ $luci -eq 1 ] 
then
	if [ uci get env.var.prod_number == "799vac" ] or [ uci get env.var.prod_number == "800vac" ] or [ uci get env.var.prod_number == "789vac" ]
	then
	  echo "tg-luci Installed" >> ./deviceinfo.txt
	else
          echo "LuCI Installed" >> ./deviceinfo.txt
  	fi
fi


if [ $xupnp -eq 1 ] 
then
 echo "xUPNP Installed" >> ./deviceinfo.txt
fi

if [ $blk -eq 1 ] 
then
 echo "Blacklist Installed" >> ./deviceinfo.txt
fi

if [ $telstra -eq 1 ] 
then
 echo "Telstra GUI Installed" >> ./deviceinfo.txt
fi

if [ $trans -eq 1 ] 
then
 echo "Transmission Installed" >> ./deviceinfo.txt
fi
echo "--------------------------------------" >> ./deviceinfo.txt


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
.
log "Running rootdevice script in debug mode. This will take ~35sec..."
/etc/init.d/rootdevice debug > ./gui-install.log 2>&1
echo " " >> ./gui-install.log

###########################################################################################################################################################
log "Tarring File..."
tar -czvf ./DebugHelper$DATE.tar.gz /tmp/$DATE-DebugHelper > /dev/null 2>&1
cp ./DebugHelper$DATE.tar.gz /tmp/
rm /tmp/$DATE-DebugHelper
log "All Done! Zipped file can be found in /tmp/. The name of it is DebugHelper$DATE.tar.gz."
