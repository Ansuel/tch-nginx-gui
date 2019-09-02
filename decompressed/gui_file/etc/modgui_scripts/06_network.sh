. /etc/init.d/rootdevice

check_isp_config() {
  logger_command "Detecting ISP and cleanup..."
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

add_TIM_ppp_specific() {
	uci set modgui.var.ppp_mgmt="$(uci -q get env.var.serial)-$(uci -q get env.var.oui)@00000.aliceres.mgmt"
	uci set modgui.var.ppp_realm_ipv6="$(uci -q get env.var.serial)-$(uci -q get env.var.oui)@alice6.it"
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

cwmp_specific_TIM() {

	cwmp_url="$(uci get cwmpd.cwmpd_config.acs_url)"
	detected_acs="Undetected"
	logger_command "TIM ISP detected, finding CWMP server..."
	new_platform=https://regman-mon.interbusiness.it:10800/acs/
	new_platform_bck=https://regman-bck.interbusiness.it:10501/acs/
	unified_platform=https://regman-tl.interbusiness.it:10700/acs/ 
	mgmt_platform=https://regman-tl.interbusiness.it:10500/acs/
	if [ "$(curl -s -k $new_platform --max-time 5 )" ]; then
		detected_acs=$new_platform
	elif [ "$(curl -s -k $new_platform_bck --max-time 5 )" ]; then
		detected_acs=$new_platform_bck
	elif [ "$(curl -s -k $unified_platform --max-time 5 )" ]; then
		detected_acs=$unified_platform
	elif [ "$(curl -s -k $mgmt_platform --max-time 5 )" ]; then
		detected_acs=$mgmt_platform
	fi
	logger_command "CWMP Server detected: $(uci get cwmpd.cwmpd_config.acs_url)"
	
	[ -z "$cwmp_url" ] && cwmp_url="None"
	
	if [ "$cwmp_url" != "None" ] && [ "$cwmp_url" != "$detected_acs" ]; then
		
		#Make the device tink is first power on by removing cwmpd db
		[ -f /etc/cwmpd.db ] && rm /etc/cwmpd.db
		uci set cwmpd.cwmpd_config.acs_url="$detected_acs"
		if [ "$(uci get -q cwmpd.cwmpd_config.interface)" != "wan" ]; then
			uci set cwmpd.cwmpd_config.interface='wan'
		fi
		uci commit cwmpd
		if [ "$(uci get -q cwmpd.cwmpd_config.acs_url)" == "None" ]; then
			[ "$(pgrep "cwmpd")" ] && /etc/init.d/cwmpd stop
		else
			/etc/init.d/cwmpd enable
			if [ ! "$(pgrep "cwmpd")" ]; then
				/etc/init.d/cwmpd start
			else
				/etc/init.d/cwmpd restart
			fi
		fi
	fi
}

firewall_specific_sip_rules_FASTWEB() {
	if [ -n "$(uci get -q firewall.Allow_restricted_sip_1.name)" ]; then
	  logger_command "Adding firewall rules for Fastweb VoIP..."
		uci set firewall.Allow_restricted_sip_1.name='Allow-restricted-sip-from-wan-again-1'
		uci set firewall.Allow_restricted_sip_1.src='wan'
		uci set firewall.Allow_restricted_sip_1.src_ip='30.253.253.68/24'
		uci set firewall.Allow_restricted_sip_1.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_1.family='ipv4'
		uci set firewall.Allow_restricted_sip_2=rule
		uci set firewall.Allow_restricted_sip_2.name='Allow-restricted-sip-from-wan-again-2'
		uci set firewall.Allow_restricted_sip_2.src='wan'
		uci set firewall.Allow_restricted_sip_2.src_ip='10.252.47.36/24'
		uci set firewall.Allow_restricted_sip_2.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_2.family='ipv4'
		uci set firewall.Allow_restricted_sip_3=rule
		uci set firewall.Allow_restricted_sip_3.name='Allow-restricted-sip-from-wan-again-3'
		uci set firewall.Allow_restricted_sip_3.src='wan'
		uci set firewall.Allow_restricted_sip_3.src_ip='10.247.5.196/24'
		uci set firewall.Allow_restricted_sip_3.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_3.family='ipv4'
		uci set firewall.Allow_restricted_sip_4=rule
		uci set firewall.Allow_restricted_sip_4.name='Allow-restricted-sip-from-wan-again-4'
		uci set firewall.Allow_restricted_sip_4.src='wan'
		uci set firewall.Allow_restricted_sip_4.src_ip='10.247.1.132/24'
		uci set firewall.Allow_restricted_sip_4.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_4.family='ipv4'
		uci set firewall.Allow_restricted_sip_5=rule
		uci set firewall.Allow_restricted_sip_5.name='Allow-restricted-sip-from-wan-again-5'
		uci set firewall.Allow_restricted_sip_5.src='wan'
		uci set firewall.Allow_restricted_sip_5.src_ip='10.247.0.100/24'
		uci set firewall.Allow_restricted_sip_5.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_5.family='ipv4'
		uci set firewall.Allow_restricted_sip_6=rule
		uci set firewall.Allow_restricted_sip_6.name='Allow-restricted-sip-from-wan-again-6'
		uci set firewall.Allow_restricted_sip_6.src='wan'
		uci set firewall.Allow_restricted_sip_6.src_ip='10.247.30.52/24'
		uci set firewall.Allow_restricted_sip_6.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_6.family='ipv4'
		uci set firewall.Allow_restricted_sip_7=rule
		uci set firewall.Allow_restricted_sip_7.name='Allow-restricted-sip-from-wan-again-7'
		uci set firewall.Allow_restricted_sip_7.src='wan'
		uci set firewall.Allow_restricted_sip_7.src_ip='10.247.0.0/26'
		uci set firewall.Allow_restricted_sip_7.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_7.family='ipv4'
		uci set firewall.Allow_restricted_sip_8=rule
		uci set firewall.Allow_restricted_sip_8.name='Allow-restricted-sip-from-wan-again-8'
		uci set firewall.Allow_restricted_sip_8.src='wan'
		uci set firewall.Allow_restricted_sip_8.src_ip='10.247.1.0/27'
		uci set firewall.Allow_restricted_sip_8.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_8.family='ipv4'
		uci set firewall.Allow_restricted_sip_9=rule
		uci set firewall.Allow_restricted_sip_9.name='Allow-restricted-sip-from-wan-again-9'
		uci set firewall.Allow_restricted_sip_9.src='wan'
		uci set firewall.Allow_restricted_sip_9.src_ip='10.247.48.0/26'
		uci set firewall.Allow_restricted_sip_9.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_9.family='ipv4'
		uci set firewall.Allow_restricted_sip_10=rule
		uci set firewall.Allow_restricted_sip_10.name='Allow-restricted-sip-from-wan-again-10'
		uci set firewall.Allow_restricted_sip_10.src='wan'
		uci set firewall.Allow_restricted_sip_10.src_ip='10.247.48.64/27'
		uci set firewall.Allow_restricted_sip_10.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_10.family='ipv4'
		uci set firewall.Allow_restricted_sip_11=rule
		uci set firewall.Allow_restricted_sip_11.name='Allow-restricted-sip-from-wan-again-11'
		uci set firewall.Allow_restricted_sip_11.src='wan'
		uci set firewall.Allow_restricted_sip_11.src_ip='10.247.30.96/27'
		uci set firewall.Allow_restricted_sip_11.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_11.family='ipv4'
		uci set firewall.Allow_restricted_sip_12=rule
		uci set firewall.Allow_restricted_sip_12.name='Allow-restricted-sip-from-wan-again-12'
		uci set firewall.Allow_restricted_sip_12.src='wan'
		uci set firewall.Allow_restricted_sip_12.src_ip='10.247.30.128/26'
		uci set firewall.Allow_restricted_sip_12.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_12.family='ipv4'
		uci set firewall.Allow_restricted_sip_13=rule
		uci set firewall.Allow_restricted_sip_13.name='Allow-restricted-sip-from-wan-again-13'
		uci set firewall.Allow_restricted_sip_13.src='wan'
		uci set firewall.Allow_restricted_sip_13.src_ip='10.247.49.0/26'
		uci set firewall.Allow_restricted_sip_13.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_13.family='ipv4'
		uci set firewall.Allow_restricted_sip_14=rule
		uci set firewall.Allow_restricted_sip_14.name='Allow-restricted-sip-from-wan-again-14'
		uci set firewall.Allow_restricted_sip_14.src='wan'
		uci set firewall.Allow_restricted_sip_14.src_ip='10.247.49.64/26'
		uci set firewall.Allow_restricted_sip_14.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_14.family='ipv4'
		uci set firewall.Allow_restricted_sip_15=rule
		uci set firewall.Allow_restricted_sip_15.name='Allow-restricted-sip-from-wan-again-15'
		uci set firewall.Allow_restricted_sip_15.src='wan'
		uci set firewall.Allow_restricted_sip_15.src_ip='10.247.30.96/27'
		uci set firewall.Allow_restricted_sip_15.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_15.family='ipv4'
		uci set firewall.Allow_restricted_sip_16=rule
		uci set firewall.Allow_restricted_sip_16.name='Allow-restricted-sip-from-wan-again-16'
		uci set firewall.Allow_restricted_sip_16.src='wan'
		uci set firewall.Allow_restricted_sip_16.src_ip='10.247.30.128/26'
		uci set firewall.Allow_restricted_sip_16.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_16.family='ipv4'
		uci set firewall.Allow_restricted_sip_17=rule
		uci set firewall.Allow_restricted_sip_17.name='Allow-restricted-sip-from-wan-again-17'
		uci set firewall.Allow_restricted_sip_17.src='wan'
		uci set firewall.Allow_restricted_sip_17.src_ip='10.247.49.0/26'
		uci set firewall.Allow_restricted_sip_17.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_17.family='ipv4'
		uci set firewall.Allow_restricted_sip_18=rule
		uci set firewall.Allow_restricted_sip_18.name='Allow-restricted-sip-from-wan-again-18'
		uci set firewall.Allow_restricted_sip_18.src='wan'
		uci set firewall.Allow_restricted_sip_18.src_ip='10.247.49.64/27'
		uci set firewall.Allow_restricted_sip_18.target='ACCEPT'
		uci set firewall.Allow_restricted_sip_18.family='ipv4'
		uci commit firewall
		/etc/init.d/firewall restart 2>/dev/null
	fi
}

cwmp_specific_FASTWEB() {
	logger_command "FASTWEB ISP detected, finding CWMP server..."
	if [ -n "$(uci get -q cwmpd.cwmpd_config.acs_url)" ]; then
		if [ "$(uci get -q cwmpd.cwmpd_config.acs_url)" != "http://59.0.121.191:8080/ACS-server/ACS" ]; then
			#Fastweb requires device registred in CWMP to make voip work in MAN voip registar
			#Fastweb will autoconfigure acs username and password with empty acs_url
			#Make the device tink is first power on by removing cwmpd db
			[ -f /etc/cwmpd.db ] && rm /etc/cwmpd.db
			uci set cwmpd.cwmpd_config.acs_url=""
			firewall_specific_sip_rules_FASTWEB
			uci commit cwmpd
			/etc/init.d/cwmpd enable
			if [ ! "$(pgrep "cwmpd")" ]; then
				/etc/init.d/cwmpd start
			else
				/etc/init.d/cwmpd restart
			fi
		fi
	fi
}

check_isp_and_cwmp() {
  logger_command "Checking detected ISP and setting CWMP..."
	if [ "$(uci -q get modgui.var.isp)" ]; then
		if [ "$(uci -q get modgui.var.isp)" == "Other" ] && 
			[ "$(uci -q get modgui.var.isp_autodetect)" == "1" ]; then #this disable cwmpd if it's not known ISP...
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
			cwmp_specific_TIM
		elif [ "$(uci -q get modgui.var.isp)" == "Fastweb" ]; then
			cwmp_specific_FASTWEB
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
check_isp_and_cwmp
disable_tcp_Sack
check_xtm_atmwan #needed for UNO firmware

logger_command "Restarting dnsmasq if needed..."
if [ $restart_dnsmasq -eq 1 ]; then
	uci commit
	killall dnsmasq
	/etc/init.d/dnsmasq restart
fi
