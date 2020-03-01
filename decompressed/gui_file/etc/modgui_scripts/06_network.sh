#!/bin/sh

. /etc/init.d/rootdevice

add_ipoe() {
  logger_command "Adding ipoe in network config..."
	uci set network.ipoe=interface
	uci set network.ipoe.proto='dhcp'
	uci set network.ipoe.metric='1'
	uci set network.ipoe.reqopts='1 3 6 43 51 58 59'
	uci set network.ipoe.release='1'
	uci set network.ipoe.neighreachabletime='1200000'
	uci set network.ipoe.neighgcstaletime='2400'
	uci set network.ipoe.ipv6='1'
}

remove_default_dns() {
  logger_command "Removing default loopback DNS Servers..."
	uci -q del network.loopback.dns
	uci -q del network.loopback.dns_metric
}

setup_network() {
	#Set a pppoerelay empty interface if list is not present (UNO)
	if [ ! "$(uci -q get network.lan.pppoerelay)" ]; then
		uci -q add_list network.lan.pppoerelay=''
	fi
	sed -i -e 's/option pppoerelay/list pppoerelay/g' /etc/config/network

	#Set a waneth4 interface if not found (fix wizard on UNO)
	if [ ! "$(uci -q get network.waneth4)" ]; then
		uci -q add network device > /dev/null
		uci -q rename network.@device[-1]=waneth4
		uci -q set network.waneth4.enabled=1
		uci -q set network.waneth4.type=8021q
		uci -q set network.waneth4.name=waneth4
		uci -q set network.waneth4.vid=835
	fi
	if [ ! "$(uci -q get network.waneth4.vid)" ]; then
		uci -q set network.waneth4.vid=835
	fi

	#Set a wanptm0 interface if not found (fix wizard on UNO)
	if [ ! "$(uci -q get network.wanptm0)" ]; then
		uci -q add network device > /dev/null
		uci -q rename network.@device[-1]=wanptm0
		uci -q set network.wanptm0.enabled=1
		uci -q set network.wanptm0.type=8021q
		uci -q set network.wanptm0.name=wanptm0
		uci -q set network.wanptm0.vid=835
	fi
	if [ ! "$(uci -q get network.wanptm0.vid)" ]; then
		uci -q set network.wanptm0.vid=835
	fi

	#Set a SSH_wan firewall rule if not found (fix SSH Wan not working)
	if [ ! "$(uci -q get firewall.SSH_wan)" ]; then
		uci -q add firewall rule > /dev/null
		uci -q rename firewall.@rule[-1]=SSH_wan
		uci -q set firewall.SSH_wan.src=wan
		uci -q set firewall.SSH_wan.name=SSH_wan
		uci -q set firewall.SSH_wan.target=DROP
		uci -q set firewall.SSH_wan.proto=tcp
		uci -q set firewall.SSH_wan.dest_port=22
		uci -q set firewall.SSH_wan.family=ipv4
	fi

	#Rename ppp interface to wan to fix problem with TG800 strange Telstra configuration
	if [ ! "$(uci -q get network.wan.proto)" ] && [ "$(uci -q get network.ppp)" ]; then
		uci del network.wan
		uci rename network.ppp=wan
	fi

	#Set missing wan path (Xtream 35B Fastweb)
	if [ ! "$(uci -q get network.wan.password)" ]; then
		uci set network.wan.password='password'
	fi
}

puryfy_wan_interface() { #creano problemi di dns per chissa'  quale diavolo di motivo... Ma l'utilitÃ  di sta roba eh telecom ?
  logger_command "Purify WAN network config..."
	uci -q del network.wan.keepalive
	uci -q del network.wan.graceful_restart
	uci -q del network.wan_ipv6.keepalive
	uci -q del network.wan_ipv6.graceful_restart
}

fix_dns_dhcp_bug() {
  logger_command "Fix DNS bug, make sure odhcp is enabled"
	#SET odhcpd MAINDHCP to 0 to use dnsmasq for ipv4 
	if [ "$(uci get -q dhcp.odhcpd.maindhcp)" == "1" ]; then
    logger_command "Setting odhcpd not maindhcp"
		uci set dhcp.odhcpd.maindhcp="0"
		/etc/init.d/odhcpd restart
		restart_dnsmasq=1
	fi
	#Check to see if odhcpd is running
	if [ ! "$(pgrep odhcpd)" ]; then
    logger_command "Starting odhcpd"
		/etc/init.d/odhcpd start
	fi
	#reenable it to make ipv6 works
	if [ -n "$(find /etc/rc.d/ -iname *odhcpd*)" ]; then
    logger_command "Enabling odhcpd on boot"
		/etc/init.d/odhcpd enable
	fi
}

check_dnsmasq_name() {
  logger_command "Checking and fixing dnsmasq daemon naming..."
	#Checks what the dnsmasq daemon is referred to in the config file
	if [ "$(uci get -q dhcp.dnsmasq)" ]; then
		if [ "$(uci get -q dhcp.dnsmasq)" != "dnsmasq" ]; then
			uci set dhcp.dnsmasq=dnsmasq
			restart_dnsmasq=1
		fi
	else
		uci set dhcp.dnsmasq=dnsmasq
		restart_dnsmasq=1
	fi
	if uci show dhcp | grep -q "dhcp.@dnsmasq" ; then
		uci rename dhcp.@dnsmasq[0]=dnsmasq
		restart_dnsmasq=1
	fi
}

update_dhcp_config() {
  logger_command "Sync DHCP configuration for new GUI"
	if [ "$(uci get -q dhcp.lan.dhcpv4)" ]; then
		#REMOVE DHCPV4 this is for odhcpd daemon to tell him to run also for ipv4 dhcp...
		#by removing the entities we solve the problem
		uci del dhcp.lan.dhcpv4
	fi
	if [ ! "$(uci get -q dhcp.lan.ignore)" ]; then
		uci set dhcp.lan.ignore='0'
	fi
}

sfp_rework() {
  logger_command "Reworking sfp interface in network config..."
	if [ "$(uci get -q network.sfp)" ]; then
		logger_command "Renaming sfp to sfptag..."
		uci rename network.sfp=sfptag
		class_target=10
		if [ "$(uci get network.lan.ipaddr)" == "192.168.$class_target.1" ]; then
			class_target=$class_target+10
		fi
		uci set network.sfptag.ipaddr=192.168.$class_target.1
		touch /root/.sfp_change
	fi
}

wan_sensing_clean() {
  logger_command "Attempt to clean the wansensing script from hardcoded interfaces..."
	#This will try to clean every hardcoded setting from isp config
	if [ -f /etc/wansensing/L2EntryExit.lua ]; then
		sed -i '/[cC][wW][mM][pP][dD]/d' /etc/wansensing/L2EntryExit.lua
		sed -i '/mtu= "1500"/{N;d}' /etc/wansensing/L2EntryExit.lua
		sed -i '/[mM][tT][uU]/d' /etc/wansensing/L2EntryExit.lua
		sed -i '/vlan = default_vlan/{N;d}' /etc/wansensing/L2EntryExit.lua
		sed -i '/vci/d' /etc/wansensing/L2EntryExit.lua
		sed -i '/vpi/d' /etc/wansensing/L2EntryExit.lua
		sed -i '/enc/d' /etc/wansensing/L2EntryExit.lua
		sed -i '/ulp/d' /etc/wansensing/L2EntryExit.lua
		sed -i '/"proto", "pppoa"/d' /etc/wansensing/L2EntryExit.lua
		sed -i '/"proto", "pppoe"/d' /etc/wansensing/L2EntryExit.lua
	fi
	if [ -f /etc/wansensing/L3EntryExit.lua ]; then
		sed -i '/delete_interface("wan")/d' /etc/wansensing/L3EntryExit.lua
		sed -i '/copy_interface/d' /etc/wansensing/L3EntryExit.lua
		sed -i '/delete("network", "ipoe"/d' /etc/wansensing/L3EntryExit.lua
	fi
	if [ -f /etc/wansensing/L3PPPEntryExit.lua ]; then
		sed -i '/delete_interface("wan")/d' /etc/wansensing/L3PPPEntryExit.lua
		sed -i '/copy_interface/d' /etc/wansensing/L3PPPEntryExit.lua
		sed -i '/"ppp"/d' /etc/wansensing/L3PPPEntryExit.lua
	fi
	if [ -f /etc/wansensing/L3DHCPSenseEntryExit.lua ]; then
		sed -i '/delete_interface("wan")/d' /etc/wansensing/L3DHCPSenseEntryExit.lua
		sed -i '/"ppp"/d' /etc/wansensing/L3DHCPSenseEntryExit.lua
		sed -i '/copy_interface/d' /etc/wansensing/L3DHCPSenseEntryExit.lua
		sed -i '/"network", "ipoe"/d' /etc/wansensing/L3DHCPSenseEntryExit.lua
		sed -i '/"wan", "auto"/d' /etc/wansensing/L3DHCPSenseEntryExit.lua
		sed -i '/"wan6", "auto"/d' /etc/wansensing/L3DHCPSenseEntryExit.lua
	fi
}

clean_cups_block_rule() {
  logger_command "Cleaning cups firewall rule..."
	firewall_change=0
	for ret in $(uci show firewall | grep CUPS-lan | sed 's|.name.*||'); do
		uci del "$ret"
		firewall_change=1
	done
	if [ $firewall_change -eq 1 ]; then
    logger_command "Restarting firewall..."
		uci commit firewall
		/etc/init.d/firewall restart 2>/dev/null
	fi
}

unlock_ssh_wan_tiscali() {
  logger_command "Unlocking SSH for Tiscali firmware"
	if [ "$(uci get -q firewall.wan_SSH_rule1)" ]; then
		uci del firewall.wan_SSH_rule1
	fi
	if [ "$(uci get -q firewall.wan_SSH_rule5)" ]; then
		uci del firewall.wan_SSH_rule5
	fi
}

disable_tcp_Sack() {
  logger_command "Apply CVE 2019-11477 workaround"
	if [ "$(cat /etc/sysctl.conf | grep 'net.ipv4.tcp_sack')" ]; then
		sed -i 's/\(net.ipv4.tcp_sack=\)1/\10/g' /etc/sysctl.conf
		sysctl -p 2>/dev/null 1>/dev/null
	elif [ -n "$(cat /etc/sysctl.conf | grep 'net.ipv4.tcp_sack=0')" ]; then
		echo -e "\n" >> /etc/sysctl.conf
		echo "# disable tcp_sack for CVE 2019-11477" >> /etc/sysctl.conf
		echo "net.ipv4.tcp_sack=0" >> /etc/sysctl.conf
		sysctl -p 2>/dev/null 1>/dev/null
	fi
}

check_xtm_atmwan() {
  logger_command "Checking atmdevice interface naming..."
	if [ -z "$(uci -q get xtm.atmwan)" ]; then
		uci set xtm.atmwan=atmdevice
		uci set xtm.atmwan.ulp='eth'
		uci set xtm.atmwan.vpi='8'
		uci set xtm.atmwan.vci='35'
		uci set xtm.atmwan.path='fast'
		uci set xtm.atmwan.enc='llc'
		uci commit
	fi
}

check_isp_config() {
	/usr/share/transformer/scripts/ispConfigHelper.sh refresh
}

#Check device type and execute specific actions
device_type="$(uci get -q env.var.prod_friendly_name)"

check_isp_config
add_ipoe #Needed to fix wizard
remove_default_dns #tim sets his dns on to of the loopback interface
setup_network #Fix some missing network value
puryfy_wan_interface #remove gracefull restart, could give problem
fix_dns_dhcp_bug #disable odhcpd as ipv6 is currently broken
check_dnsmasq_name #check dnsmasq name in uci to avoid issue in guid hardcoded references
update_dhcp_config #Dhcp sync
[ "$device_type" == "DGA4132" ] && sfp_rework #sfp to sfptag, to solve local ip problem
wan_sensing_clean #Wansensing clean utility
clean_cups_block_rule
[ "$device_type" == "MediaAccess TG789vac v2" ] && unlock_ssh_wan_tiscali
disable_tcp_Sack
check_xtm_atmwan #needed for UNO firmware

logger_command "Restarting dnsmasq if needed..."
if [ $restart_dnsmasq -eq 1 ]; then
	uci commit
	killall dnsmasq
	/etc/init.d/dnsmasq restart
fi
