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

    grep -q '.md5sum' "$file" && continue

    orig_file=/$file
    file=$MD5_CHECK_DIR/$file

    if [ -f "$orig_file" ]; then
      md5_file=$(md5sum "$file" | awk '{ print $1 }')
      md5_orig_file=$(md5sum "$orig_file" | awk '{ print $1 }')
      if [ "$md5_file" = "$md5_orig_file" ]; then
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

#Some globals var to check the right things to install
device_type="$(uci get -q env.var.prod_friendly_name)"
marketing_version="$(uci get -q version.@version[0].marketing_version)"
cpu_type="$(uname -m)"

apply_right_opkg_repo() {
  logecho "Checking opkg feeds..."

  opkg_file="/etc/opkg.conf"

  if [ "$cpu_type" = "armv7l" ]; then
    case $marketing_version in
    "19."*)
      sed -i '/homeware\/18\/brcm63xx-tch/d' /etc/opkg.conf #remove old setted feeds
      sed -i '/Ansuel\/GUI_ipk\/kernel-4.1/d' /etc/opkg.conf #remove old setted feeds
      sed -i '/repository\.macoers\.com\/homeware\/19\/brcm6xxx-tch/d' /etc/opkg.conf #remove broken 19 macoers feeds
      if ! grep -q "Ansuel/GUI_ipk/kernel-4.1" $opkg_file; then
        cat <<EOF >>$opkg_file
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
      sed -i '/repository\/homeware\/18\/brcm63xx-tch/d' /etc/opkg.conf #remove old setted feeds
      if ! grep -q "homeware/18/brcm63xx-tch" $opkg_file; then
        cat <<EOF >>$opkg_file
src/gz chaos_calmer_base_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/base
src/gz chaos_calmer_packages_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/packages
src/gz chaos_calmer_luci_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/luci
src/gz chaos_calmer_routing_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/routing
src/gz chaos_calmer_telephony_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/telephony
EOF
      fi
      ;;
    "18."*)
      if ! grep -q "Ansuel/GUI_ipk/kernel-4.1" $opkg_file; then
        cat <<EOF >>$opkg_file
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
      sed -i '/repository\/homeware\/18\/brcm63xx-tch/d' /etc/opkg.conf #remove old setted feeds
      if ! grep -q "homeware/18/brcm63xx-tch" $opkg_file; then
        cat <<EOF >>$opkg_file
src/gz chaos_calmer_base_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/base
src/gz chaos_calmer_packages_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/packages
src/gz chaos_calmer_luci_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/luci
src/gz chaos_calmer_routing_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/routing
src/gz chaos_calmer_telephony_macoers https://repository.macoers.com/homeware/18/brcm63xx-tch/VANTW/telephony
EOF
      fi
      ;;
    "17.3"*)
      sed -i '/roleo\/public\/agtef\/brcm63xx-tch/d' /etc/opkg.conf #remove old setted feeds
      if ! grep -q "roleo/public/agtef/1.1.0/brcm63xx-tch" $opkg_file; then
        cat <<EOF >>$opkg_file
src/gz chaos_calmer_base https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/base
src/gz chaos_calmer_packages https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/packages
src/gz chaos_calmer_luci https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/luci
src/gz chaos_calmer_routing https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/routing
src/gz chaos_calmer_telephony https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/telephony
src/gz chaos_calmer_management https://repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch/packages/management
EOF
      fi
      ;;
    "16.3"* | "17.1"* | "17.2"*)
      sed -i '/roleo\/public\/agtef\/1.1.0\/brcm63xx-tch/d' /etc/opkg.conf #remove old setted feeds
      if ! grep -q "roleo/public/agtef/brcm63xx-tch" $opkg_file; then
        cat <<EOF >>$opkg_file
src/gz chaos_calmer_base https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/base
src/gz chaos_calmer_packages https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/packages
src/gz chaos_calmer_luci https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/luci
src/gz chaos_calmer_routing https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/routing
src/gz chaos_calmer_telephony https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/telephony
src/gz chaos_calmer_management https://repository.ilpuntotecnico.com/files/roleo/public/agtef/brcm63xx-tch/packages/management
EOF
      fi
      ;;
    "16.2"* | "16.1"*)
      if ! grep -q "FrancYescO/789vacv2_opkg/xtream35b" $opkg_file; then
        cat <<EOF >>$opkg_file
src/gz base https://raw.githubusercontent.com/FrancYescO/789vacv2_opkg/xtream35b/packages
EOF
      fi
      ;;
    *)
      logecho "No known ARM feeds for this version $marketing_version"
      ;;
    esac
  elif [ "$cpu_type" = "mips" ]; then
    case $marketing_version in
    "16."* | "17."*)
      if ! grep -q "chaos_calmer/15.05.1/brcm63xx" $opkg_file; then
        sed -i '/FrancYescO\/789vacv2/d' /etc/opkg.conf #remove old setted feeds
        cat <<EOF >>$opkg_file
src/gz chaos_calmer_base http://archive.openwrt.org/chaos_calmer/15.05.1/brcm63xx/generic/packages/base
src/gz chaos_calmer_packages http://archive.openwrt.org/chaos_calmer/15.05.1/brcm63xx/generic/packages/packages
src/gz chaos_calmer_luci http://archive.openwrt.org/chaos_calmer/15.05.1/brcm63xx/generic/packages/luci
src/gz chaos_calmer_routing http://archive.openwrt.org/chaos_calmer/15.05/brcm63xx/generic/packages/routing
src/gz chaos_calmer_telephony http://archive.openwrt.org/chaos_calmer/15.05/brcm63xx/generic/packages/telephony
src/gz chaos_calmer_management http://archive.openwrt.org/chaos_calmer/15.05.1/brcm63xx/generic/packages/management

arch all 100
arch brcm63xx 200
arch brcm63xx-tch 300
EOF
      fi
      ;;
    *)
      logecho "No known MIPS feeds for this version $marketing_version"
      ;;
    esac
  else
    logecho "CPU '$cpu_type' UNKNOWN, feeds not found for this version $marketing_version"
  fi

  # Remove non-existent hardcoded distfeed to avoid 404 on opkg update
  [ -f /etc/opkg/distfeeds.conf ] && {
    sed -i '/15.05.1\/brcm63xx-tch/d' /etc/opkg/distfeeds.conf
    sed -i '/targets\/brcm6xxx-tch\/VBNTJ_502L07p1/d' /etc/opkg/distfeeds.conf
    sed -i '/targets\/brcm6xxx-tch\/VCNTD_502L07p1/d' /etc/opkg/distfeeds.conf
  }
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
  if [ ! "$(uci get -q button.info)" ] || [ "$(uci get -q button.info)" = "BTN_3" ]; then
    logecho "Setting up status (wifi) button..."
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
    logecho "Setting up status (power) button..."
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
    logecho "Setting up status (wifi) button..."
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
  logecho "Applying specific model fixes..."
  /usr/share/transformer/scripts/appInstallRemoveUtility.sh install specificapp "$1"
}

remove_wizard_5ghz() {
  if [ -n "$(find /www/wizard-cards/ -iname '*wireless_5G*')" ]; then
    logecho "Removing 5GHz config from wizard..."
    rm /www/wizard-cards/*wireless_5G*
  fi
}

apply_right_opkg_repo

if [ ! "$(uci get -q modgui.app.specific_app)" ]; then
  uci set modgui.app.specific_app="0"
fi

# TODO: make all specifc package generic (mips/arm)
# TODO: avoid replacing nginx/miniupnpd/dlnad in DGA pack if unneeded (deprecate the TG800 package)
# A case similar to this one is in the modgui-modal.lp for who installed offline
# and should be linked to the package download, make sure to reflect changes in the modal
case $marketing_version in
"16.1"* | "16.2"*)
  [ "$cpu_type" = "armv7l" ] && install_specific TG789Xtream35B
  [ "$cpu_type" = "mips" ] && install_specific TG789
  ;;
"16."* | "17."*)
  [ "$cpu_type" = "armv7l" ] && {
    [ -z "${device_type##*TG800*}" ] && install_specific TG800 || install_specific DGA
  }
  [ "$cpu_type" = "mips" ] && install_specific TG789
  ;;
"18."*)
  [ "$cpu_type" = "armv7l" ] && install_specific DGA
  [ "$cpu_type" = "mips" ] && logecho "Unknown what specific_app to install on $marketing_version $cpu_type"
  ;;
*)
  uci set modgui.app.specific_app="1" #no specific package for this device
  logecho "Unknown what specific_app to install on $marketing_version $cpu_type"
  ;;
esac

uci commit modgui

[ -z "${device_type##*DGA4130*}" ] && ledfw_extract "DGA"
[ -z "${device_type##*DGA4132*}" ] && ledfw_extract "DGA"
[ -z "${device_type##*DGA4131*}" ] && ledfw_extract "DGA4131"
[ -z "${device_type##*TG788*}" ] && ledfw_extract "TG788"
[ -z "${device_type##*TG788*}" ] && ledfw_rework_TG788
[ -z "${device_type##*TG789*}" ] && ledfw_extract "TG789"
[ -z "${device_type##*TG589*}" ] && ledfw_rework_TG799
[ -z "${device_type##*TG799*}" ] && ledfw_rework_TG799
[ -z "${device_type##*TG800*}" ] && ledfw_rework_TG800
#[ -z "${device_type##*DGA413*}" ] && wifi_fix_24g

ls /tmp/ledfw* 1>/dev/null 2>&1 && rm /tmp/ledfw* #clean ledfw bz2 from /tmp

[ -z "${device_type##*TG788*}" ] && remove_wizard_5ghz

if [ -f /proc/rip/0122 ]; then
  logecho "WARNING! RIP_ID_RESTRICTED_DOWNGR_TS detected!!"
fi
if [ -f /proc/rip/0123 ]; then
  logecho "WARNING! RIP_ID_RESTRICTED_DOWNGR_OPT detected!!"
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
