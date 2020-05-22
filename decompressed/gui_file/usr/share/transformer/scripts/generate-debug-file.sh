#!/bin/sh

# Copyright (C) 2018 kevdagoat (kevdawhirl@gmail.com)
# Written by kevdagoat for tch-nginx-gui.

######################################################################
DATE=$(date +%Y-%m-%d-%H%M)
prod=$(uci get env.var.prod_name)
friend=$(uci get env.var.prod_friendly_name)
isp=$(uci get modgui.var.isp)
version=$(uci get env.var.friendly_sw_version_activebank)
guiver=$(uci get modgui.gui.gui_version)
dsl=$(uci get modgui.var.driver_version)
guihash=$(uci get modgui.gui.gui_hash)
guibranch=$(uci get modgui.gui.update_branch)
guifirst=$(uci get modgui.gui.firstpage)
guirancol=$(uci get modgui.gui.randomcolor)
skin=$(uci get modgui.gui.gui_skin)
aria=$(uci get modgui.app.aria2_webui)
luci=$(uci get modgui.app.luci_webui)
trans=$(uci get modgui.app.transmission_webui)
xupnp=$(uci get modgui.app.xupnp_app)
blk=$(uci get modgui.app.blacklist_app)
telstra=$(uci get modgui.app.telstra_webui)


log() {
logger -s -t "DebugHelper" "$1"
}
#####################################################################

log "DebugHelper Started!"

log "Removing directory /tmp/DebugHelper-* to prevent duplicates"
rm -R /tmp/DebugHelper* > /dev/null 2>&1

log "Creating dir"
mkdir /tmp/DebugHelper-$DATE/ > /dev/null 2>&1
cd /tmp/DebugHelper-$DATE/


#################################################################################################################################################################
log "Gathering device info..."

echo "___________________________________DEVICE INFO_________________________________________" > ./deviceinfo.txt

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

echo "--------------Free Space--------------" >> ./deviceinfo.txt
df -h >> ./deviceinfo.txt

echo "--------------banktable---------------" >> ./deviceinfo.txt
find /proc/banktable -type f -print -exec cat {} ';' >> ./deviceinfo.txt

echo "-----List of Installed Extensions-----" >> ./deviceinfo.txt

if [ $aria -eq 1 ]
then
 echo "Aria Installed" >> ./deviceinfo.txt
fi

if [ $luci -eq 1 ]
then
 echo "LuCI Installed" >> ./deviceinfo.txt
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
echo "__________________________________LOG_________________________________________" > ./error.log
logread |grep daemon.err >> ./error.log
echo " " >> ./error.log

###########################################################################################################################################################

log "Listing processes..."
echo "__________________________________PROCESSES_________________________________________" > ./processes.txt
ps >> ./processes.txt
echo " " >> ./processes.txt

###########################################################################################################################################################

log "Scanning /etc/config directory..."
echo "__________________________________CONFIG FILE LIST_________________________________________" > ./configlist.txt
ls /etc/config/ >> ./configlist.txt
echo " " >> ./configlist.txt

###########################################################################################################################################################
log "Tarring File..."
tar -czvf /tmp/DebugHelper$DATE.tar.gz /tmp/DebugHelper-$DATE > /dev/null 2>&1
rm -R /tmp/DebugHelper-$DATE
log "All Done! Zipped file can be found in /tmp/DebugHelper$DATE.tar.gz"
