#!/bin/sh

kernel_ver="$(cat /proc/version | awk '{print $3}')"

if [ -z "${kernel_ver##3.4*}" ]; then

  move_files_and_clean(){
    for file in $(find "$1"*/ -xdev | cut -d '/' -f4-); do
      if [[ -d "$1$file" && ! -d "/$file" ]]; then
        mkdir "/$file"
        continue
      fi
      echo mv "$1$file" "/$file"
      [ ! -d "$1$file" ] && mv "$1$file" "/$file"

    done
    rm -rf "$1"
  }
  move_files_and_clean /tmp/upgrade-pack-specificDGA/

  opkg install /tmp/3.4_ipk/*
  rm -rf /tmp/3.4_ipk

  enable_new_upnp() {
    logger_command "Checking UPnP.."
    if [ -f /etc/init.d/miniupnpd ]; then
      if [ "$(uci get -q upnpd.config.enable_upnp)" ]; then
        if [ "$(uci get -q upnpd.config.enable_upnp)" == "1" ]; then
          logger_command "Disabling miniupnpd-tch and redirecting to miniupnpd"
          /etc/init.d/miniupnpd-tch stop
          /etc/init.d/miniupnpd-tch disable
          rm /etc/init.d/miniupnpd-tch
          ln -s /etc/init.d/miniupnpd /etc/init.d/miniupnpd-tch
          /etc/init.d/miniupnpd enable
          if [ ! "$(pgrep "miniupnpd")" ]; then
            /etc/init.d/miniupnpd restart
          fi
        fi
      fi
    fi
  }
  enable_new_upnp

  if [ ! -f /etc/config/dland ]; then
    touch /etc/config/dland
    uci set dlnad.config=dlnad
    uci set dlnad.config.manufacturer_url='http://www.technicolor.com'
    uci set dlnad.config.model_url='http://www.technicolor.com'
    uci set dlnad.config.radioStations_enabled='0'
    uci set dlnad.config.interface='lan'
    uci set dlnad.config.friendly_name='DLNA Modem Share'
    uci commit dlnad
  fi

  #Use custom driver to remove downgrade limitation... thx @Roleo
  logger_command "Checking downgrade limitation bit..."
  if [ "$(uci get -q env.rip.board_mnemonic)" == "VBNT-S" ] &&
    [ "$(uci get -q env.var.prod_number)" == "4132" ] &&
    [ -f /proc/rip/0123 ]; then
    logger_command "Downgrade limitation bit detected... Removing..."
    rmmod keymanager
    rmmod ripdrv
    mv /lib/modules/3.4.11/ripdrv.ko /lib/modules/3.4.11/ripdrv.ko_back
    mv /tmp/ripdrv.ko /lib/modules/3.4.11/ripdrv.ko
    insmod ripdrv
    echo 0123 >/proc/rip/delete # RIP_ID_RESTRICTED_DOWNGR_TS (0x122)
    echo 0122 >/proc/rip/delete # RIP_ID_RESTRICTED_DOWNGR_OPT (0x123)
    rmmod ripdrv
    logger_command "Restoring original driver"
    rm /lib/modules/3.4.11/ripdrv.ko
    mv /lib/modules/3.4.11/ripdrv.ko_back /lib/modules/3.4.11/ripdrv.ko
    insmod ripdrv
    insmod keymanager
  fi
  if [ -f /tmp/ripdrv.ko ]; then
    rm /tmp/ripdrv.ko
  fi

elif [ -z "${kernel_ver##4.1*}" ]; then

  #Install telnet, openssl-util and update openssl (for security reason)
  opkg install /tmp/upgrade-pack-specificDGA/tmp/4.1_ipk/*

fi

if [ ! -f /etc/config/telnet ]; then
  touch /etc/config/telnet
  uci set telnet.general=telnet
  uci set telnet.general.enable='0'
  uci commit telnet
fi

if [ -f /bin/busybox_telnet ] && [ ! -f /usr/sbin/telnetd ]; then
  ln -s /bin/busybox_telnet /usr/sbin/telnetd
fi

if [ ! -f /etc/init.d/telnet ]; then
  ln -s /etc/init.d/telnetd /etc/init.d/telnet
fi
