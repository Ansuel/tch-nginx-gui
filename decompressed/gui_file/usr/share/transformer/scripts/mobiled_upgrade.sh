#!/bin/sh
# Copyright (c) 2015 Technicolor

if [ -f /tmp/.mobiled.upgrade ]; then
  cat /tmp/.mobiled.upgrade | while read LINE
  do
    dev_idx=$(echo $LINE | cut -d " " -f 1)
    path=$(echo $LINE | cut -d " " -f 2)

    # 1001 (user-defined) - Non-responsive LTE module
    if [ "$(eval ubus call mobiled status | grep '\"devices\":' | cut -d ' ' -f 2 | sed 's/\"//g' | sed 's/\,//g')" == 0 ]; then
      eval ubus send mobiled.firmware_upgrade "'{\"status\":\"failed\",\"dev_idx\":${dev_idx},\"error_code\":1001}'"
      continue
    fi

    # 1002 (user-defined) - No SIM card installed
    if [ "$(eval ubus call mobiled.sim get "'{\"dev_idx\":${dev_idx}}'" | grep '\"sim_state\":' | cut -d ' ' -f 2 | sed 's/\"//g' | sed 's/\,//g')" == "not_present" ]; then
      eval ubus send mobiled.firmware_upgrade "'{\"status\":\"failed\",\"dev_idx\":${dev_idx},\"error_code\":1002}'"
      continue
    fi

    # 1005 (user-defined) - SIM card locked
    if [ "$(eval ubus call mobiled.sim get "'{\"dev_idx\":${dev_idx}}'" | grep '\"sim_state\":' | cut -d ' ' -f 2 | sed 's/\"//g' | sed 's/\,//g')" == "locked" ]; then
      eval ubus send mobiled.firmware_upgrade "'{\"status\":\"failed\",\"dev_idx\":${dev_idx},\"error_code\":1005}'"
      continue
    fi

    # 1003 (user-defined) - No service due to poor signal
    if [ "$(eval ubus call mobiled.radio signal_quality "'{\"dev_idx\":${dev_idx}}'" | grep '\"radio_interface\":' | cut -d ' ' -f 2 | sed 's/\"//g' | sed 's/\,//g')" == "no_service" ]; then
      eval ubus send mobiled.firmware_upgrade "'{\"status\":\"failed\",\"dev_idx\":${dev_idx},\"error_code\":1003}'"
      continue
    fi

    # 1004 (user-defined) - There is a voice calling over mobile, please try FOTA upgrade later
    if [ "$(eval ubus call network.interface.wwan status | grep '\"up\":' | cut -d ' ' -f 2 | sed 's/\"//g' | sed 's/\,//g')" == "true" ]; then
      if [ -n "$(eval ubus call mmpbx.call get | grep 'call')" ]; then
        eval ubus send mobiled.firmware_upgrade "'{\"status\":\"failed\",\"dev_idx\":${dev_idx},\"error_code\":1004}'"
        continue
      fi
    fi

    if [ -n "$dev_idx" -a -n "$path" ]; then
      eval ubus call mobiled.device firmware_upgrade "'{\"dev_idx\":${dev_idx},\"path\":\"${path}\"}'"
    fi
  done
fi
rm /tmp/.mobiled.upgrade
