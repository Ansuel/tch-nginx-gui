#!/bin/sh

restart_dnsmasq=0
INIT=/etc/init.d
policy_mode=apply

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

purge_telemetry() { #disable TIM telemetry services
  if [ "$(uci -q get system.acotel.enabled)" ] && [ "$(uci -q get system.acotel.enabled)" != "0" ]; then
    logecho "Disabling and killing Acotel agent..."
    uci set system.acotel.enabled='0'
    uci commit system
    kill -9 "$(cat /tmp/acotel/agent.pid 2>/dev/null)" 2>/dev/null
    pkill -9 -f "Acotel_UA/main.py" 2>/dev/null
    pkill -9 -f "run_main.sh" 2>/dev/null
    rm -f /tmp/acotel/agent.pid
    [ -f /rom/chroot/Acotel_UA/TRACER.log ] && cp /rom/chroot/Acotel_UA/TRACER.log /chroot/Acotel_UA/TRACER.log
    [ -f /rom/chroot/Acotel_UA/Acotel_run.log ] && cp /rom/chroot/Acotel_UA/Acotel_run.log /chroot/Acotel_run.log
  fi

  if [ -x /etc/init.d/bulkdata ] && uci -q get bulkdata.global >/dev/null &&
    [ "$(uci -q get bulkdata.global.enabled)" != "0" ]; then
    logecho "Disabling bulkdata telemetry..."
    uci set bulkdata.global.enabled='0'
    uci commit bulkdata
    /etc/init.d/bulkdata stop
    /etc/init.d/bulkdata disable
  fi

  # Disable the TIMVision nanoCDN cache by default; stock IPTV interfaces
  # do not imply it is in use. The UCI flag also gates LAN-triggered starts
  # and the statistics poller in rc.local, independently of the boot symlink.
  if [ -n "$(uci -q get system.mabr)" ] && [ "$(uci -q get system.mabr.enabled)" != "0" ]; then
    logecho "Disabling mABR..."
    uci set system.mabr.enabled='0'
    uci commit system
  fi
  if [ -x /etc/init.d/nanocdn ]; then
    logecho "Stopping and disabling nanocdn..."
    /etc/init.d/nanocdn stop
    /etc/init.d/nanocdn disable
  fi
}

purge_default_services() {
  # Only disable the factory iPerf server. Preserve custom configurations
  # and skip firmware without a readable factory baseline or this UCI flag.
  if [ -x /etc/init.d/iperf ] && [ "$(uci -q get iperf.iperf.enabled)" = "1" ] &&
    [ -f /rom/etc/config/iperf ] &&
    cmp -s /etc/config/iperf /rom/etc/config/iperf &&
    cmp -s /etc/init.d/iperf /rom/etc/init.d/iperf; then
    logecho "Disabling factory iperf server..."
    # Some old stop scripts only kill the server while enabled is still 1.
    /etc/init.d/iperf stop || return 1
    /etc/init.d/iperf disable || return 1
    uci set iperf.iperf.enabled='0' || return 1
    uci commit iperf || return 1
  fi

  # The stock xl2tpd init starts even with no LAC/LNS configured. Leave
  # customized servers, netifd L2TP clients and the VPN extension untouched.
  [ -x /etc/init.d/xl2tpd ] || return 0
  [ -f /rom/etc/xl2tpd/xl2tpd.conf ] || return 0
  cmp -s /etc/init.d/xl2tpd /rom/etc/init.d/xl2tpd || return 0
  cmp -s /etc/xl2tpd/xl2tpd.conf /rom/etc/xl2tpd/xl2tpd.conf || return 0
  [ ! -f /etc/.modgui-l2tp-ipsec-installed ] || return 0
  [ ! -e /etc/init.d/l2tp-ipsec-server ] || return 0
  [ ! -e /etc/init.d/modgui-ipsec ] || return 0
  if grep -Eiq '^[[:space:]]*\[(lac|lns)([[:space:]]|\])' /etc/xl2tpd/xl2tpd.conf; then
    return 0
  fi
  default_services_network="$(uci -q show network)" || return 0
  if printf '%s\n' "$default_services_network" | grep -Eq "\\.proto='?(l2tp|l2tpv2|l2tpv3)'?$"; then
    return 0
  fi
  logecho "Disabling unconfigured factory xl2tpd..."
  /etc/init.d/xl2tpd stop || return 1
  /etc/init.d/xl2tpd disable
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

  # The env backend only accepts variables exposed by the firmware.
  # Older firmware may not provide this flag; do not try to create it.
  if unlocked_status="$(uci -q get env.var.unlockedstatus)"; then
    if [ "$unlocked_status" != "0" ]; then
      logecho "Resetting unlock bit..."
      uci set env.var.unlockedstatus='0'
    fi
  else
    logecho "Unlock bit unavailable on this firmware, skipping reset..."
  fi

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
    [ "$(uci get -q mmpbxrvsipnet.sip_net.user_param_value)" ] && uci del mmpbxrvsipnet.sip_net.user_param_value
    ;;
  Fastweb)
    check_clean Fastweb
    [ "$(uci get -q mmpbxrvsipnet.sip_net.user_param_value)" ] && uci del mmpbxrvsipnet.sip_net.user_param_value
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
    # Some firmware has no Technicolor VoIP stack. Do not create its options
    # without a parent section, or overwrite an explicitly configured value.
    if uci -q get mmpbxrvsipnet.sip_net >/dev/null &&
      [ -z "$(uci -q get mmpbxrvsipnet.sip_net.user_param_value)" ]; then
      uci set mmpbxrvsipnet.sip_net.user_param_value=phone
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


service_action() {
  [ -x "$INIT/$1" ] || return 0
  "$INIT/$1" "$2"
}

stop_services() {
  stop_status=0
  for stop_name in "$@"; do
    service_action "$stop_name" stop || stop_status=1
    service_action "$stop_name" disable || stop_status=1
  done
  return "$stop_status"
}

# rc.common reload on older firmware need not start a stopped process.
# Restore boot links when the UI enables a function. Installation synchronizes
# the links without restarting features which are already enabled.
activate() {
  service_action "$1" enable || return 1
  [ "$policy_mode" = sync ] || service_action "$1" restart
}

parental_policy() {
  case "$(uci -q get parental.general.enable)" in
    0) stop_services weburl dnsfilter ;;
    1)
      mode=$(uci -q get parental.general.mode)
      case "$mode" in
        dns) stop_services weburl && activate dnsfilter ;;
        web|'') stop_services dnsfilter && activate weburl ;;
        *) [ "$policy_mode" = sync ] || service_action weburl restart ;;
      esac ;;
    *) [ "$policy_mode" = sync ] || service_action weburl restart ;;
  esac
}

dlna_policy() {
  case "$(uci -q get dlnad.config.enabled)" in
    0)
      stop_services dlnad mud mvfs ;;
    1)
      activate mvfs && activate mud && activate dlnad ;;
    *) [ "$policy_mode" = sync ] || service_action dlnad reload ;;
  esac
}

# Do not overwrite custom init implementations or act on unknown firmware.
factory_service() {
  [ -x "$INIT/$1" ] && [ -r "/rom/etc/init.d/$1" ] &&
    cmp -s "$INIT/$1" "/rom/etc/init.d/$1"
}

# Missing config is unconfigured; an existing but unreadable config is unknown.
read_config() {
  if [ ! -e "/etc/config/$1" ] && [ ! -L "/etc/config/$1" ]; then return 0; fi
  uci -q show "$1"
}

gre_unused() {
  gre_config=$(read_config gre_hotspotd) || return 1
  tunnel_config=$(read_config gre_intf) || return 1
  [ -z "$gre_config$tunnel_config" ]
}

pnp_unused() {
  read_config generic_app >/dev/null || return 1
  # Preserve customized provisioning, including unknown config layouts.
  if [ -e /etc/config/generic_app ] || [ -L /etc/config/generic_app ]; then
    cmp -s /etc/config/generic_app /rom/etc/config/generic_app || return 1
  fi
  [ -z "$(uci -q get generic_app.pnpserver.url)" ] || return 1
  case "$(uci -q get generic_app.pnpserver.registered)" in ''|0) ;; *) return 1 ;; esac
  if [ -e /etc/ssl/paired ] || [ -L /etc/ssl/paired ]; then
    [ -d /etc/ssl/paired ] && [ -r /etc/ssl/paired ] && [ -x /etc/ssl/paired ] || return 1
    paired_files=$(find /etc/ssl/paired ! -type d) || return 1
    [ -z "$paired_files" ] || return 1
  fi
}

isp_policy() {
  [ "$(uci -q get modgui.var.keep_isp_services)" != 1 ] || return 0
  isp_status=0
  if factory_service gre-hotspotd && gre_unused; then
    service_action gre-hotspotd stop && service_action gre-hotspotd disable || isp_status=1
  fi
  if factory_service generic_pnpd && pnp_unused; then
    service_action generic_pnpd stop && service_action generic_pnpd disable || isp_status=1
  fi
  return "$isp_status"
}

# These apply hooks also restore the boot service when provisioning is configured.
isp_apply() {
  case "$1" in
    gre) name=gre-hotspotd; unused=gre_unused ;;
    pnp) name=generic_pnpd; unused=pnp_unused ;;
  esac
  if [ "$(uci -q get modgui.var.keep_isp_services)" != 1 ] &&
    factory_service "$name" && "$unused"; then
    service_action "$name" stop && service_action "$name" disable
  else
    service_action "$name" enable && service_action "$name" restart
  fi
}

sync_services() {
  policy_mode=sync
  sync_status=0
  parental_policy || sync_status=1
  dlna_policy || sync_status=1
  isp_policy || sync_status=1
  return "$sync_status"
}

isp_helper() {
  purge_telemetry
  purge_default_services
  if [ "$1" = "refresh" ]; then
    autodetect_isp
    setup_ISP "$(uci get -q modgui.var.isp)" || return 1
  elif [ "$1" = "force" ]; then
    setup_ISP "$(uci get -q modgui.var.isp)" || return 1
  elif [ "$1" = "setup" ]; then
    if [ -z "$2" ]; then
      echo "Specify ISP_NAME (Supported Tiscali, TIM, Fastweb, Other)"
      return 1
    fi
    setup_ISP "$2" || return 1
  fi
  sync_services
}

apply_cwmp_service() {
  # Apply the GUI state to the service as well as the protocol configuration.
  case "$(uci -q get cwmpd.cwmpd_config.state)" in
    0)
      /etc/init.d/cwmpd disable || exit 1
      /etc/init.d/cwmpd stop
      ;;
    1)
      /etc/init.d/cwmpd enable || exit 1
      # Older rc.common scripts may not implement the procd 'running' command.
      if pidof cwmpd >/dev/null 2>&1 || /etc/init.d/cwmpd running >/dev/null 2>&1; then
        /etc/init.d/cwmpd reload
      else
        /etc/init.d/cwmpd start
      fi
      ;;
    *)
      echo "Invalid CWMP state" >&2
      exit 1
      ;;
  esac
}

apply_samba_service() {
  action="${1:-reload}"
  case "$action" in reload | restart) ;; *) exit 1 ;; esac

  # Only NQE uses this lifecycle policy. Older firmware has native Samba
  # scripts whose reload/restart behavior must be preserved.
  nqe=0
  if [ -x /etc/init.d/nqe ]; then
    case "$(readlink /etc/init.d/samba 2>/dev/null)" in
      /etc/init.d/nqe | ../init.d/nqe | nqe) nqe=1 ;;
    esac
  fi

  if [ "$nqe" = 1 ]; then
    filesharing="$(uci -q get samba.samba.filesharing)"
    printersharing="$(uci -q get printersharing.config.enabled)"
    printershare="$(uci -q get samba.printers.enabled)"
    enabled="$(uci -q get samba.samba.enabled)"
    needed=""
    case "$filesharing:$printersharing:$printershare" in
      1:* | 0:1:1 | 0:1:) needed=1 ;;
      0:0:* | 0:*:0) needed=0 ;;
    esac

    # Fall back to the firmware implementation for unknown configuration
    # layouts. Do not invent missing UCI options on older firmware.
    case "$enabled:$needed" in
      0:0 | 0:1 | 1:0 | 1:1)
        if [ "$enabled" != "$needed" ]; then
          uci set samba.samba.enabled="$needed" || exit 1
          uci commit samba || exit 1
        fi

        # Boot starts 'nqe', whereas older GUI applies may have started the
        # same binaries as 'samba'. Clear the alias instance and boot links.
        /etc/init.d/samba disable || exit 1
        /etc/init.d/samba stop || exit 1
        if [ "$needed" = 0 ]; then
          /etc/init.d/nqe disable || exit 1
          /etc/init.d/nqe stop
        else
          /etc/init.d/nqe enable || exit 1
          # NQE's reload signals the hardcoded 'samba' procd instance;
          # restart the canonical service to apply all settings reliably.
          /etc/init.d/nqe restart
        fi
        exit $?
        ;;
    esac
  fi

  if [ -x /etc/init.d/samba ]; then
    /etc/init.d/samba "$action" || exit 1
  fi
  if [ "$action" = reload ] && [ -x /etc/init.d/samba-nmbd ]; then
    /etc/init.d/samba-nmbd reload
  fi
  exit 0
}

case "$1" in
parental) parental_policy ;;
dlna) dlna_policy ;;
isp) isp_policy ;;
gre|pnp) isp_apply "$1" ;;
sync) sync_services ;;
cwmp)
  apply_cwmp_service
  ;;
samba)
  apply_samba_service "$2"
  ;;
refresh | setup | force)
  isp_helper "$1" "$2"
  ;;
*)
  echo "usage: refresh, force, setup ISP_NAME, cwmp, samba [reload|restart], parental, dlna, isp, gre, pnp or sync" 1>&2
  return 1
  ;;
esac
