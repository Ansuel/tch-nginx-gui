#!/bin/sh

restart_dnsmasq=0

logecho() {
  if [ "$debug" -eq 1 ]; then
    logger -t "IspConfigHelper" "$1"
    echo "IspConfigHelper" "$1"
  fi
}

purify_from_tim() {
  uci -q del modgui.var.ppp_mgmt
  uci -q del network.wan_ipv6
  uci -q del dhcp.dnsmasq.server
  restart_dnsmasq=1
}

firewall_specific_sip_rules_FASTWEB() {
  if [ -n "$(uci get -q firewall.Allow_restricted_sip_1.name)" ]; then
    logecho "Adding firewall rules for Fastweb VoIP..."
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
    uci set firewall.Allow_ACS_1=rule
    uci set firewall.Allow_ACS_1.src='wan'
    uci set firewall.Allow_ACS_1.family='ipv4'
    uci set firewall.Allow_ACS_1.dest_port='51050'
    uci set firewall.Allow_ACS_1.name='Allow-ACS-1'
    uci set firewall.Allow_ACS_1.src_ip='30.253.131.0/24'
    uci set firewall.Allow_ACS_1.target='ACCEPT'
    uci set firewall.Allow_ACS_1.proto='tcp'
    uci set firewall.Allow_ACS_2=rule
    uci set firewall.Allow_ACS_2.src='wan'
    uci set firewall.Allow_ACS_2.family='ipv4'
    uci set firewall.Allow_ACS_2.dest_port='51050'
    uci set firewall.Allow_ACS_2.name='Allow-ACS-2'
    uci set firewall.Allow_ACS_2.src_ip='59.0.121.0/24'
    uci set firewall.Allow_ACS_2.target='ACCEPT'
    uci set firewall.Allow_ACS_2.proto='tcp'
    uci commit firewall
    /etc/init.d/firewall restart 2>/dev/null
  fi
}

cwmp_specific_FASTWEB() {
  logecho "FASTWEB ISP detected, finding CWMP server..."
  if uci get -q versioncusto.override.fwversion_override | grep -q FW; then
    #Make modem think this is a fastweb modem so the server permit voip registration with internal value
    uci set versioncusto.override.fwversion_override_old="$(uci get -q versioncusto.override.fwversion_override)"
    uci set versioncusto.override.fwversion_override='18.3.0237_FW_216_FGA2130'
    uci commit versioncusto
  fi
  if [ -n "$(uci get -q cwmpd.cwmpd_config.acs_url)" ]; then
    if [ "$(uci get -q cwmpd.cwmpd_config.acs_url)" != "http://59.0.121.191:8080/ACS-server/ACS" ]; then
      #Fastweb requires device registred in CWMP to make voip work in MAN voip registar
      #Fastweb will autoconfigure acs username and password with empty acs_url
      #Make the device think is first power on by removing cwmpd db
      [ -f /etc/cwmpd.db ] && rm /etc/cwmpd.db
      uci set cwmpd.cwmpd_config.acs_url=""
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

cwmp_specific_TIM() {
  cwmp_url="$(uci get cwmpd.cwmpd_config.acs_url)"
  detected_acs="Undetected"
  logecho "TIM ISP detected, finding CWMP server..."
  new_fw220=https://fwa.cdp.tim.it/cwmpdWeb/CPEMgt
  new_platform=https://regman-mon.interbusiness.it:10800/acs/
  new_platform_bck=https://regman-bck.interbusiness.it:10501/acs/
  unified_platform=https://regman-tl.interbusiness.it:10700/acs/
  mgmt_platform=https://regman-tl.interbusiness.it:10500/acs/
  if [ "$(curl -s -k $new_platform --max-time 5)" ]; then
    detected_acs=$new_platform
  elif [ "$(curl -s -k $new_fw220 --max-time 5)" ]; then
    detected_acs=$new_fw220
  elif [ "$(curl -s -k $new_platform_bck --max-time 5)" ]; then
    detected_acs=$new_platform_bck
  elif [ "$(curl -s -k $unified_platform --max-time 5)" ]; then
    detected_acs=$unified_platform
  elif [ "$(curl -s -k $mgmt_platform --max-time 5)" ]; then
    detected_acs=$mgmt_platform
  fi
  logecho "CWMP Server detected: $detected_acs"

  logecho "Resetting unlock bit..."
  uci set env.var.unlockedstatus='0'

  [ -z "$cwmp_url" ] && cwmp_url="None"

  if [ "$detected_acs" != "Undetected" ] && [ "$cwmp_url" != "$detected_acs" ]; then

    #Make the device think is first power on by removing cwmpd db
    [ -f /etc/cwmpd.db ] && rm /etc/cwmpd.db
    uci set cwmpd.cwmpd_config.acs_url="$detected_acs"
    if [ "$(uci get -q cwmpd.cwmpd_config.interface)" != "wan" ]; then
      uci set cwmpd.cwmpd_config.interface='wan'
    fi
    uci commit cwmpd
    if [ "$(uci get -q cwmpd.cwmpd_config.acs_url)" = "None" ]; then
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

check_clean() {
  if [ -n "$(uci get -q firewall.Allow_restricted_sip_1.name)" ] && [ "$1" != "Fastweb" ]; then
    if [ $(uci get -q versioncusto.override.fwversion_override_old) ]; then
      uci set versioncusto.override.fwversion_override="$(uci get -q versioncusto.override.fwversion_override_old)"
      uci del versioncusto.override.fwversion_override_old
      uci commit versioncusto
    fi
  fi
  if [ -n "$(uci get -q modgui.var.ppp_mgmt)" ] && [ "$1" != "TIM" ]; then
    purify_from_tim
  fi

}

setup_ISP() {
  logecho "Checking detected ISP and setting CWMP..."
  case $1 in
  Tiscali)
    check_clean Tiscali
    uci set cwmpd.cwmpd_config.acs_url="http://webdirect.tr69.tiscali.it:8080/ftacs-basic/ACS"
    uci set cwmpd.cwmpd_config.acs_user="technicolor"
    uci set cwmpd.cwmpd_config.acs_pass="techn_tr69@"
    uci commit cwmpd
    ;;
  Fastweb)
    check_clean Fastweb
    firewall_specific_sip_rules_FASTWEB
    cwmp_specific_FASTWEB
    ;;
  TIM)
    check_clean TIM
    cwmp_specific_TIM
    uci set modgui.var.ppp_mgmt="$(uci -q get env.var.serial)-$(uci -q get env.var.oui)@00000.aliceres.mgmt"
    uci set modgui.var.ppp_realm_ipv6="$(uci -q get env.var.serial)-$(uci -q get env.var.oui)@alice6.it"
    if [ ! "$(uci get -q dhcp.dnsmasq.server)" ]; then
      uci set dhcp.dnsmasq.server='151.99.125.1'
      restart_dnsmasq=1
    fi
    ;;
  Other)
    check_clean Other
    if [ "$(uci -q get modgui.var.isp_autodetect)" = "1" ]; then #this disable cwmpd if it's not known ISP...
      uci set cwmpd.cwmpd_config.state='0'
      uci commit cwmpd
      if [ -f /var/run/cwmpd.pid ]; then
        /etc/init.d/cwmpd stop
      fi
      /etc/init.d/cwmpd disable
    fi
    ;;
  *)
    echo "Invalid ISP"
    return 1
    ;;
  esac
  logecho "Restarting dnsmasq if needed..."
  if [ $restart_dnsmasq -eq 1 ]; then
    uci commit
    killall dnsmasq
    /etc/init.d/dnsmasq restart
  fi
}

autodetect_isp() { #Detect ISP based on cwmp or wan settings (Italian only)
  if [ "$(uci -q get modgui.var.isp_autodetect)" = "1" ]; then
    logecho "Detecting ISP and cleanup..."
    ppp_user=$(uci -q get network.wan.username)
    cwmp_url=$(uci -q get cwmpd.cwmpd_config.acs_url)
    if echo "$ppp_user" | grep -q "alice" ||
      echo "$ppp_user" | grep -q "agcombo" ||
      echo "$ppp_user" | grep -q "unica" ||
      echo "$ppp_user" | grep -q "aliceres" ||
      echo "$ppp_user" | grep -q "@00000."; then
      uci set modgui.var.isp="TIM"
    elif echo "$ppp_user" | grep -q "tiscali.it" || #acs tiscali is preconfigured
      echo "$cwmp_url" | grep -q "tiscali.it"; then #on tiscali firmware only
      uci set modgui.var.isp="Tiscali"
    elif echo "$cwmp_url" | grep -q "59.0.121.191"; then #on fastweb firmware only
      uci set modgui.var.isp="Fastweb"
    else
      uci set modgui.var.isp="Other"
    fi
    uci commit modgui
  fi
}

isp_helper() {
  if [ "$1" = "refresh" ]; then
    autodetect_isp
    setup_ISP "$(uci get -q modgui.var.isp)"
  elif [ "$1" = "force" ]; then
    setup_ISP "$(uci get -q modgui.var.isp)"
  elif [ "$1" = "setup" ]; then
    if [ -z "$2" ]; then
      echo "Specify ISP_NAME (Supported Tiscali, TIM, Fastweb, Other)"
      return 1
    fi
    setup_ISP "$2"
  fi
}

case "$1" in
refresh | setup | force)
  isp_helper "$1" "$2"
  ;;
*)
  echo "usage: refresh, force or setup ISP_NAME" 1>&2
  return 1
  ;;
esac
