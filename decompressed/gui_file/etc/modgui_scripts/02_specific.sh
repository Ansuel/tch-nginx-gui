#!/bin/sh

. /etc/init.d/rootdevice

extract_with_check() {

  export RESTART_SERVICE=0
  MD5_CHECK_DIR=/tmp/md5check

  [ ! -d $MD5_CHECK_DIR ] && mkdir $MD5_CHECK_DIR

  for file in $(bzcat "$1" | tar -C $MD5_CHECK_DIR -xvf -); do

    if [ ! -f "$MD5_CHECK_DIR/$file" ]; then
      if [ ! -d "/$file" ]; then
        mkdir "/$file"
      fi
      continue
    fi

    [ -n "$(echo "$file" | grep .md5sum)" ] && continue

    orig_file=/$file
    file=$MD5_CHECK_DIR/$file

    if [ -f "$orig_file" ]; then
      md5_file=$(md5sum "$file" | awk '{ print $1 }')
      md5_orig_file=$(md5sum "$orig_file" | awk '{ print $1 }')
      if [ "$md5_file" == "$md5_orig_file" ]; then
        rm "$file"
        continue
      fi
    fi

    cp "$file" "$orig_file"
    rm "$file"
    RESTART_SERVICE=1

  done

  [ -d $MD5_CHECK_DIR ] && rm -r $MD5_CHECK_DIR

  rm "$1"

  return $RESTART_SERVICE
}

apply_right_opkg_repo() {
  logger_command "Checking opkg feeds..."
	marketing_version="$(uci get -q version.@version[0].marketing_version)"

	opkg_file="/etc/opkg.conf"
	if [ "$1" ] && [ "$1" == "TG78" ]; then
		if [ -z "$(  grep $opkg_file -e "FrancYescO/789vacv2_opkg/master" )" ]; then
			cat << EOF >> $opkg_file
src/gz base https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/master/base
src/gz packages https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/master/packages
src/gz luci https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/master/luci
src/gz routing https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/master/routing
src/gz telephony https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/master/telephony
src/gz management https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/master/management
EOF
    fi
  elif [ "$1" ] && [ "$1" == "Xtream" ]; then
		if [ -z "$(  grep $opkg_file -e "FrancYescO/789vacv2_opkg/xtream35b" )" ]; then
			cat << EOF >> $opkg_file
src/gz base https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/xtream35b/packages
EOF
    fi
  else
	case $marketing_version in
	"18.3"*)
		if [ -n "$(  grep $opkg_file -e "brcm63xx-tch" )" ]; then
			rm /etc/opkg.conf
			cp /rom/etc/opkg.conf /etc/
		fi
		if [ -z "$(  grep $opkg_file -e "Ansuel/GUI_ipk/kernel-4.1" )" ]; then
			cat << EOF >> $opkg_file
arch all 100
arch arm_cortex-a9 200
arch arm_cortex-a9_neon 300
src/gz chaos_calmer_base https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/base
src/gz chaos_calmer_packages https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/packages
src/gz chaos_calmer_luci https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/luci
src/gz chaos_calmer_routing https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/routing
src/gz chaos_calmer_telephony https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/telephony
src/gz chaos_calmer_core https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/target/packages
EOF
		fi
		;;
	"17.3"*)
		if [ -z "$(  grep $opkg_file -e "roleo/public/agtef/1.1.0/brcm63xx-tch" )" ]; then
			cat << EOF >> $opkg_file
src/gz chaos_calmer_base https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/base
src/gz chaos_calmer_packages https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/packages
src/gz chaos_calmer_luci https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/luci
src/gz chaos_calmer_routing https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/routing
src/gz chaos_calmer_telephony https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/telephony
src/gz chaos_calmer_management https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/management
EOF
		fi
		;;
	"16.3"*)
		if [ -z "$(  grep $opkg_file -e "roleo/public/agtef/brcm63xx-tch" )" ]; then
			cat << EOF >> $opkg_file
src/gz chaos_calmer_base https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/base
src/gz chaos_calmer_packages https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/packages
src/gz chaos_calmer_luci https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/luci
src/gz chaos_calmer_routing https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/routing
src/gz chaos_calmer_telephony https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/telephony
src/gz chaos_calmer_management https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/management
EOF
		fi
		;;
	*)
		logger_command "No opkg file supported"
		;;
	esac
	fi

  # Remove non-existent hardcoded distfeed to avoid 404 on opkg update
  [ -f /etc/opkg/distfeeds.conf ] && sed -i '/15.05.1\/brcm63xx-tch/d' /etc/opkg/distfeeds.conf
}

ledfw_extract() {
  if [ -f "/tmp/ledfw_support-specific$1.tar.bz2" ]; then
    extract_with_check "/tmp/ledfw_support-specific$1.tar.bz2"
    if [ $? -eq 1 ]; then
      /usr/share/transformer/scripts/restart_leds.sh
      ubus send fwupgrade '{"state":"upgrading"}' #avoid losing the flashing-state when service restarted
    fi
  fi
}

ledfw_rework_TG788() {
  if [ ! "$(uci get -q button.info)" ] || [ "$(uci get -q button.info)" == "BTN_3" ]; then
    logger_command "Setting up status (wifi) button..."
    uci del button.easy_reset
    uci set button.info=button
    uci set button.info.button='BTN_1'
    uci set button.info.action='released'
    uci set button.info.handler='logger INFO button pressed ; ubus send infobutton '\''{"state":"active"}'\'''
    uci set button.info.min='0'
    uci set button.info.max='2'
    uci set button.eco.min='2'
    uci set button.eco.max='5'
    uci set button.acl.min='5'
    uci set ledfw.iptv.check='0'
    uci commit ledfw
  fi

  ledfw_extract "TG788"
}

ledfw_rework_TG799() {
  if [ ! "$(uci get -q button.info)" ]; then
    logger_command "Setting up status (power) button..."
    uci del button.easy_reset
    uci set button.info=button
    uci set button.info.button='BTN_3'
    uci set button.info.action='released'
    uci set button.info.handler='logger INFO button pressed ; ubus send infobutton '\''{"state":"active"}'\'''
    uci set button.info.min='0'
    uci set button.info.max='2'
    uci set ledfw.iptv.check='0'
    uci commit ledfw
  fi

  ledfw_extract "TG799"
}

ledfw_rework_TG800() {
  if [ ! "$(uci get -q button.info)" ]; then
    logger_command "Setting up status (wifi) button..."
    uci del button.easy_reset
    uci set button.info=button
    uci set button.info.button='BTN_1'
    uci set button.info.action='released'
    uci set button.info.handler='logger INFO button pressed ; ubus send infobutton '\''{"state":"active"}'\'''
    uci set button.info.min='0'
    uci set button.info.max='2'
    uci set button.wifi_on_off_toggle.min='2'
    uci set button.wifi_on_off_toggle.max='8'
    uci set ledfw.iptv.check='0'
    uci commit ledfw
  fi

  ledfw_extract "TG800"
}

#wifi_fix_24g() {
#	#Set wifi to perf mode
#	wl down
#	wl obss_prot set 0
#	wl -i wl0 gmode Performance
#	wl -i wl0 up
#
#}

install_specific() {
  logger_command "Applying specific model fixes..."
  /usr/share/transformer/scripts/appInstallRemoveUtility.sh install specificapp "$1"
}

remove_wizard_5ghz() {
  if [ -n "$(find /www/wizard-cards/ -iname '*wireless_5G*')" ]; then
    logger_command "Removing 5GHz config from wizard..."
    rm /www/wizard-cards/*wireless_5G*
  fi
}

#THIS CHECK DEVICE TYPE AND INSTALL SPECIFIC FILE
device_type="$(uci get -q env.var.prod_friendly_name)"
kernel_ver="$(< /proc/version awk '{print $3}')"


[ -z "${device_type##*DGA413*}" ] && apply_right_opkg_repo #Check opkg conf based on version
if [ -z "${device_type##*TG78*}" ] && [ -n "${device_type##*Xtream*}" ]; then
  apply_right_opkg_repo TG78
fi
if [ -z "${device_type##*TG789*}" ] && [ -z "${device_type##*Xtream*}" ]; then
  apply_right_opkg_repo Xtream
fi

if [ ! "$(uci get -q modgui.app.specific_app)" ]; then
  uci set modgui.app.specific_app="0"
fi

if [ -z "${device_type##*DGA413*}" ]; then
  install_specific DGA
elif [ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG789*}" ] && [ -n "${device_type##*Xtream*}" ]; then
  install_specific TG789
elif [ -z "${device_type##*TG789*}" ] && [ -z "${device_type##*Xtream*}" ]; then
  install_specific TG789Xtream35B
elif [ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG799*}" ]; then
  install_specific TG789
elif [ -z "${kernel_ver##3.4*}" ] && [ -z "${device_type##*TG800*}" ]; then
  install_specific TG800
else
  uci set modgui.app.specific_app="1" #no specific package for this device
fi

uci commit modgui

[ -z "${device_type##*DGA4130*}" ] && ledfw_extract "DGA"
[ -z "${device_type##*DGA4132*}" ] && ledfw_extract "DGA"
[ -z "${device_type##*DGA4131*}" ] && ledfw_extract "DGA4131"
[ -z "${device_type##*TG788*}" ] && ledfw_rework_TG788
[ -z "${device_type##*TG789*}" ] && ledfw_extract "TG789"
[ -z "${device_type##*TG799*}" ] && ledfw_rework_TG799
[ -z "${device_type##*TG800*}" ] && ledfw_rework_TG800
#[ -z "${device_type##*DGA413*}" ] && wifi_fix_24g

[ -z "${device_type##*TG788*}" ] && remove_wizard_5ghz

if [ -f /proc/rip/0122 ]; then
  logger_command "WARNING! RIP_ID_RESTRICTED_DOWNGR_TS detected!!"
fi
if [ -f /proc/rip/0123 ]; then
  logger_command "WARNING! RIP_ID_RESTRICTED_DOWNGR_OPT detected!!"
fi

#Fix led issues
if [ -z "${device_type##*DGA4131*}" ]; then
  if [ ! "$(uci get -q ledfw.ambient.active)" ]; then
    uci set ledfw.ambient=led
    uci set ledfw.ambient.active='1'
    uci commit ledfw
  fi
else
  if [ ! "$(uci get -q ledfw.status_led.enable)" ]; then
    uci set ledfw.status_led=status_led
    uci set ledfw.status_led.enable='0'
    uci commit ledfw
  fi
  if [ ! "$(uci get -q ledfw.wifi.nsc_on)" ]; then
    uci set ledfw.wifi=service
    uci set ledfw.wifi.nsc_on='1'
    uci commit ledfw
  fi
fi
