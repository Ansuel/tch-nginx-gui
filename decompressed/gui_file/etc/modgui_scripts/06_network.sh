. /etc/init.d/rootdevice

check_isp_config() {
	#Detect ISP based on cwmp settings (Italian only)
	if [ -z "$(uci -q get modgui.var.isp_autodetect)" ]; then
		uci set modgui.var.isp_autodetect="1"
		uci commit modgui
	fi
	
	if [ -z "$(uci -q get modgui.var.isp_autodetect)" ]; then
		uci set modgui.var.isp="Other"
	fi
	
	if [ "$(uci -q get modgui.var.isp_autodetect)" == "1" ]; then
		ppp_user=$(uci -q get network.wan.username)
		cwmp_url=$(uci -q get cwmpd.cwmpd_config.acs_url)
		if  [ ! "$ppp_user" ]; then
			uci set modgui.var.isp="Other"
			purify_from_tim
		else
			if echo "$ppp_user" | grep -q "alice" || 
			echo "$ppp_user" | grep -q "agcombo" || 
			echo "$ppp_user" | grep -q "unica" || 
			echo "$ppp_user" | grep -q "aliceres" ||
			echo "$ppp_user" | grep -q "@00000." ; 
			then
				uci set modgui.var.isp="TIM"
			elif echo "$ppp_user" | grep -q "tiscali.it" || #acs tiscali is preconfigured 
				echo "$cwmp_url" | grep -q "tiscali.it" ; then #on tiscali firmware only
				uci set modgui.var.isp="Tiscali"
			elif echo "$cwmp_url" | grep -q "59.0.121.191" ; then #on fastweb firmware only
				uci set modgui.var.isp="Fastweb"
			else
				uci set modgui.var.isp="Other"
				purify_from_tim
			fi
		fi
	fi
}

add_ipoe() {
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
}

add_TIM_ppp_specific() {
	uci set modgui.var.ppp_mgmt="$(uci -q get env.var.serial)-$(uci -q get env.var.oui)@00000.aliceres.mgmt"
	uci set modgui.var.ppp_realm_ipv6="$(uci -q get env.var.serial)-$(uci -q get env.var.oui)@alice6.it"
}

puryfy_wan_interface() { #creano problemi di dns per chissa'  quale diavolo di motivo... Ma l'utilitÃ  di sta roba eh telecom ? 
	uci -q del network.wan.keepalive
	uci -q del network.wan.graceful_restart
	uci -q del network.wan_ipv6.keepalive
	uci -q del network.wan_ipv6.graceful_restart
}

fix_dns_dhcp_bug() {
	#SET odhcpd MAINDHCP to 0 to use dnsmasq for ipv4 
	if [ "$(uci get -q dhcp.odhcpd.maindhcp)" == "1" ]; then
		uci set dhcp.odhcpd.maindhcp="0"
		/etc/init.d/odhcpd restart
		restart_dnsmasq=1
	fi
	#Check to see if odhcpd is running
	if [ ! "$(pgrep "odhcpd")" ]; then
		/etc/init.d/odhcpd start
	fi
	#reenable it to make ipv6 works
	if [ ! "$(echo /etc/rc.d/*odhcpd*)" ]; then
		/etc/init.d/odhcpd enable
	fi
}

purify_from_tim() {
	uci -q del modgui.var.ppp_mgmt
	uci -q del network.wan_ipv6
	uci -q del dhcp.dnsmasq.server
	restart_dnsmasq=1
}

add_telecom_stock_dns() {
	if [ ! "$(uci get -q dhcp.dnsmasq.server)" ]; then
		uci set dhcp.dnsmasq.server='151.99.125.1'
		restart_dnsmasq=1
	fi
}

check_dnsmasq_name() {
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
	if [ "$(uci get -q network.sfp)" ]; then
		logger_command "Moving sfp to sfptag..."
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
	#This will try to clean every hardcoded setting from isp config
	logger_command "Cleaning WanSensing"
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
	firewall_change=0
	for ret in $(uci show firewall | grep CUPS-lan | sed 's|.name.*||'); do
		uci del $ret
		firewall_change=1
	done
	if [ $firewall_change -eq 1 ]; then
		uci commit firewall
		/etc/init.d/firewall restart
	fi
}

check_isp_and_cwmp() {
	if [ "$(uci -q get modgui.var.isp)" ]; then
		if [ "$(uci -q get modgui.var.isp)" == "Other" ]; then #this disable cwmpd if it's not known ISP...
			uci set cwmpd.cwmpd_config.state='0'
			if [ "$(uci get -q cwmpd.cwmpd_config.state)" = "1" ]; then
				if [ -f /var/run/cwmpd.pid ]; then
					/etc/init.d/cwmpd stop
				fi
				/etc/init.d/cwmpd disable
			fi
		elif [ "$(uci -q get modgui.var.isp)" == "Tiscali" ]; then
			uci set cwmpd.cwmpd_config.acs_url="http://webdirect.tr69.tiscali.it:8080/ftacs-basic/ACS"
			uci set cwmpd.cwmpd_config.acs_user="technicolor"
			uci set cwmpd.cwmpd_config.acs_pass="techn_tr69@"
			uci commit cwmpd
		elif [ "$(uci -q get modgui.var.isp)" == "TIM" ]; then
			logger_command "TIM ISP detected, finding CWMP server..."
			new_platform=https://regman-mon.interbusiness.it:10800/acs/
			new_platform_bck=https://regman-bck.interbusiness.it:10501/acs/
			unified_platform=https://regman-tl.interbusiness.it:10700/acs/ 
			mgmt_platform=https://regman-tl.interbusiness.it:10500/acs/
			if [ "$(curl -s -k $new_platform --max-time 5 )" ]; then
				uci set cwmpd.cwmpd_config.acs_url=$new_platform
			elif [ "$(curl -s -k $new_platform_bck --max-time 5 )" ]; then
				uci set cwmpd.cwmpd_config.acs_url=$new_platform_bck
			elif [ "$(curl -s -k $unified_platform --max-time 5 )" ]; then
				uci set cwmpd.cwmpd_config.acs_url=$unified_platform
			elif [ "$(curl -s -k $mgmt_platform --max-time 5 )" ]; then
				uci set cwmpd.cwmpd_config.acs_url=$mgmt_platform
			fi
			logger_command "CWMP Server detected: $(uci get cwmpd.cwmpd_config.acs_url)"
			if [ "$(uci get -q cwmpd.cwmpd_config.interface)" != "wan" ]; then
				uci set cwmpd.cwmpd_config.interface='wan'
			fi
			uci commit cwmpd
			if [ "$(uci get -q cwmpd.cwmpd_config.acs_url)" == "None" ]; then
				if [ "$(pgrep "cwmpd")" ]; then
					/etc/init.d/cwmpd stop
				fi
			else
				/etc/init.d/cwmpd enable
				if [ ! "$(pgrep "cwmpd")" ]; then
					/etc/init.d/cwmpd start
				else
					/etc/init.d/cwmpd restart
				fi
			fi
		fi
		if [ "$(uci get -q modgui.var.isp)" == "TIM" ]; then #this add specific config for TIM
			add_TIM_ppp_specific
			add_telecom_stock_dns
		else
			purify_from_tim
		fi
	fi
}

unlock_ssh_wan_tiscali() {
	if [ "$(uci get -q firewall.wan_SSH_rule1)" ]; then
		uci del firewall.wan_SSH_rule1
	fi
	if [ "$(uci get -q firewall.wan_SSH_rule5)" ]; then
		uci del firewall.wan_SSH_rule5
	fi
}

disable_tcp_Sack() {
	echo -e "\n" >> /etc/sysctl.conf
	echo "# disable tcp_sack for CVE 2019-11477" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_sack = 0" >> /etc/sysctl.conf
	sysctl -p 2>/dev/null 1>/dev/null
}

#THIS CHECK DEVICE TYPE AND INSTALL SPECIFIC FILE
device_type="$(uci get -q env.var.prod_friendly_name)"
kernel_ver="$(cat /proc/version | awk '{print $3}')"

check_isp_config
logger_command "Check and cleanup"
add_ipoe #this need to stay to make the wizard work correctly
logger_command "Remove default DNS Servers"
remove_default_dns #tim sets his dns on to of the loopback interface
setup_network #Fix some missing network value
logger_command "Purify WAN"
puryfy_wan_interface #remove gracefull restart, could give problem
logger_command "Fix DNS bug"
fix_dns_dhcp_bug #disable odhcpd as ipv6 is currently broken 
logger_command "Check if dnsmasq daemon name is as we need it for the GUI"
check_dnsmasq_name #check dnsmasq name in uci
logger_command "Sync DHCP configuration for new GUI"
update_dhcp_config #Dhcp sync
[ "$device_type" == "DGA4132" ] && logger_command "Reworking sfp interface in network config..."
[ "$device_type" == "DGA4132" ] && sfp_rework #sfp to sfptag, to solve local ip problem
logger_command "Attempt to clean the wansensing script from hardcoded interfaces..."
wan_sensing_clean #Wansensing clean utility
logger_command "Cleaning cups firewall rule..."
clean_cups_block_rule
[ "$device_type" == "MediaAccess TG789vac v2" ] && logger_command "Unlocking SSH for Tiscali firmware"
[ "$device_type" == "MediaAccess TG789vac v2" ] && unlock_ssh_wan_tiscali
logger_command "Checking if ISP is detected..."
check_isp_and_cwmp
logger_command "Apply CVE 2019-11477 workaround"
disable_tcp_Sack