#!/bin/sh

marketing_version="$(uci get -q version.@version[0].marketing_version)"
cpu_type="$(uname -m)"

# Shared TUN lifecycle for WireGuard, OpenVPN and Tailscale.  The reviewed
# DGA4130 module is for ARMv7 kernel 4.1.52; other platforms may use their matching
# kmod-tun package.  Per-extension users prevent one VPN from removing a
# module still needed by another.
modgui_tun_file="/lib/modules/4.1.52/tun.ko"
modgui_tun_sha256="374b8399951a4fa75a0b9c68b6eced9d064cc442d3150d2210d75623c275354e"
modgui_tun_commit="1587d4a113de414f4409ea80b11a8d03c115f17c"
modgui_tun_owned="/etc/.modgui-tun-installed"
modgui_tun_package_owned="/etc/.modgui-tun-package-installed"
modgui_tun_boot="/etc/modules.d/30-modgui-tun"

modgui_has_tun() {
  [ -c /dev/net/tun ] && return 0
  [ -r /proc/config.gz ] && zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_TUN=y$'
}

modgui_reviewed_tun_build() {
  [ "$cpu_type" = "armv7l" ] && [ "$(uname -r)" = "4.1.52" ]
}

modgui_tun_migrate_owners() {
  [ -f /etc/.modgui-wireguard-tun-installed ] ||
    [ -f /etc/.modgui-openvpn-tun-installed ] || return 0
  [ -f "$modgui_tun_file" ] || return 0
  [ "$(sha256sum "$modgui_tun_file" | awk '{print $1}')" = "$modgui_tun_sha256" ] || return 0
  touch "$modgui_tun_owned"
  [ ! -f /etc/.modgui-wireguard-tun-installed ] || touch /etc/.modgui-tun-user-wireguard
  [ ! -f /etc/.modgui-openvpn-tun-installed ] || touch /etc/.modgui-tun-user-openvpn
  printf 'tun\n' > "$modgui_tun_boot"
  rm -f /etc/.modgui-wireguard-tun-installed /etc/.modgui-openvpn-tun-installed \
    /etc/modules.d/30-modgui-wireguard-tun /etc/modules.d/30-modgui-openvpn-tun
}

modgui_install_tun() {
  consumer="$1"
  modgui_tun_migrate_owners
  if modgui_has_tun; then
    [ ! -f "$modgui_tun_owned" ] || touch "/etc/.modgui-tun-user-$consumer"
    return 0
  fi

  if modgui_reviewed_tun_build; then
    if [ -f "$modgui_tun_file" ]; then
      [ "$(sha256sum "$modgui_tun_file" | awk '{print $1}')" = "$modgui_tun_sha256" ] || {
        echo "An incompatible TUN module already exists; refusing to overwrite it"
        return 1
      }
    else
      tun_tmp="/tmp/modgui-tun.$$.ko"
      curl -kfL "https://raw.githubusercontent.com/FrancYescO/GUI_ipk/$modgui_tun_commit/artifacts/tun-vbntj-damson-4.1.52.ko" \
        --output "$tun_tmp" || { rm -f "$tun_tmp"; return 1; }
      [ "$(sha256sum "$tun_tmp" | awk '{print $1}')" = "$modgui_tun_sha256" ] || {
        echo "TUN module checksum mismatch"
        rm -f "$tun_tmp"
        return 1
      }
      cp "$tun_tmp" "$modgui_tun_file" || { rm -f "$tun_tmp"; return 1; }
      rm -f "$tun_tmp"
    fi
    modprobe tun 2>/dev/null || insmod "$modgui_tun_file" 2>/dev/null || return 1
    modgui_has_tun || return 1
    printf 'tun\n' > "$modgui_tun_boot"
    touch "$modgui_tun_owned" "/etc/.modgui-tun-user-$consumer"
    return 0
  fi

  if ! opkg list-installed 2>/dev/null | grep -q '^kmod-tun '; then
    opkg install kmod-tun || return 1
    touch "$modgui_tun_package_owned"
  fi
  modprobe tun 2>/dev/null || true
  modgui_has_tun || {
    echo "No compatible TUN module is available for this firmware"
    return 1
  }
  [ ! -f "$modgui_tun_package_owned" ] || {
    touch "$modgui_tun_owned" "/etc/.modgui-tun-user-$consumer"
  }
}

modgui_release_tun() {
  consumer="$1"
  modgui_tun_migrate_owners
  rm -f "/etc/.modgui-tun-user-$consumer"
  [ -f "$modgui_tun_owned" ] || return 0
  for tun_user in /etc/.modgui-tun-user-*; do
    [ -e "$tun_user" ] && return 0
  done
  if lsmod | grep -q '^tun '; then
    rmmod tun 2>/dev/null || {
      echo "TUN is still in use; leaving the shared module installed"
      return 0
    }
  fi
  rm -f "$modgui_tun_boot"
  if [ -f "$modgui_tun_package_owned" ]; then
    opkg remove kmod-tun >/dev/null 2>&1 || return 0
    rm -f "$modgui_tun_package_owned"
  elif [ -f "$modgui_tun_file" ] &&
    [ "$(sha256sum "$modgui_tun_file" | awk '{print $1}')" = "$modgui_tun_sha256" ]; then
    rm -f "$modgui_tun_file"
  fi
  rm -f "$modgui_tun_owned"
}

#  1st arg : directory
#  2nd arg : pkg name
#  3rd arg : raw or normal. Raw is used to download specific file from specific dir
#  4th arg : addtional command to append to setup.sh (usefull if setup.sh contains also uninstall command)
install_from_github() (
  # Run in a subshell so removing the staging directory cannot leave the
  # caller in a deleted working directory. Clean every failure path.
  stage="/tmp/$2"
  [ ! -e "$stage" ] || { echo "App staging directory already exists: $stage"; return 1; }
  mkdir "$stage" || return 1
  trap 'rm -rf "$stage"' EXIT
  trap 'exit 1' HUP INT TERM

  if [ "$3" = "specificapp" ]; then
    if [ ! -f "/tmp/$2.tar.bz2" ]; then
      /usr/share/transformer/scripts/checkver DownloadInstalled "$2.tar.bz2" "/tmp/$2.tar.bz2" || return 1
    fi
    if [ ! -f "/tmp/$2.tar.bz2" ]; then
      echo "Error installing App: Cannot find/download  $2.tar.bz2"
      return 1
    fi
    extract_bzip_archive "/tmp/$2.tar.bz2" "/tmp/$2" || return 1
    rm "/tmp/$2.tar.bz2"
    cd "/tmp/$2" || return 1
  else
    if [ ! -f "/tmp/$2.tar.gz" ]; then
      curl -fsSLk --connect-timeout 15 --max-time 120 "https://github.com/$1/tarball/$2" --output "/tmp/$2.tar.gz" || {
        rm -rf "/tmp/$2" "/tmp/$2.tar.gz"
        return 1
      }
    fi
    if [ ! -f "/tmp/$2.tar.gz" ]; then
      echo "Error installing App: Cannot find/download  $2.tar.gz"
      return 1
    fi
    tar -xzf "/tmp/$2.tar.gz" -C "/tmp/$2" || {
      rm -rf "/tmp/$2" "/tmp/$2.tar.gz"
      return 1
    }
    rm "/tmp/$2.tar.gz"
    cd /tmp/"$2"/* || return 1
  fi

  [ -s ./setup.sh ] || return 1
  chmod +x ./setup.sh || return 1
  ./setup.sh "$4"
  setup_status=$?
  rm -rf "/tmp/$2"
  return "$setup_status"
)

############TRANSFORMER UTILITY##################
set_transformer() {
  cmd="require('datamodel').set('"$1"','"$2"')"
  lua -e "$cmd"
}
#################################################

app_transmission() {
  if [ "$cpu_type" = mips ]; then
    legacy_mips_app "$1" transmission
    return $?
  fi

  install_arm() {
    opkg update || return 1
    opkg install transmission-web transmission-daemon-openssl || return 1
    if [ ! -f /rom/usr/lib/libmbedcrypto.so.1 ]; then
      opkg install libmbedtls || return 1 #workaround for 19.x firmware
    fi

    uci set transmission.@transmission[0].enabled=1
    uci set transmission.@transmission[0].rpc_whitelist='127.0.0.1,192.168.*.*'
    uci commit

    # Create script to trigger transmission restart when an usb is plugged in/out
    {
        echo '#!/bin/sh'
        echo 'last_usb=$(ls -t /dev/sd* | tail -n 1)'
        echo 'last_usb=${last_usb#"/dev/"}'
        echo 'usb_count=$(find /tmp/run/mountd/ -mindepth 1 -maxdepth 1 -type d | wc -l)'
        echo '[ "$usb_count" == "0" ] && /etc/init.d/transmission stop || [ -d "/tmp/run/mountd/$last_usb/sharing/config/transmission" ] && /etc/init.d/transmission restart'
    } >/etc/hotplug.d/usb/60-transmission

    cp -r /usr/share/transmission /www/docroot/
    rm /www/docroot/transmission/web/index.html /www/docroot/transmission/web/LICENSE

    /etc/init.d/transmission enable
    /etc/init.d/transmission restart
  }

  install() {
    case $marketing_version in
    "16.1"* | "16.2"*)
      case "$cpu_type" in
        armv7l) install_from_github FrancYescO/sharing_tg789 transmission-xtream || return 1 ;;
        *) return 1 ;;
      esac
      ;;
    "16."* | "17."* | "18."* | "19."*)
      case "$cpu_type" in
        armv7l) install_arm || return 1 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      echo "Unknown app install script for $marketing_version $cpu_type"
      return 1
      ;;
    esac
    uci set modgui.app.transmission_webui="1"
    uci commit modgui
  }

  remove() {
    opkg remove transmission-daemon-openssl transmission-web || return 1
    rm -rf /www/docroot/transmission
    rm -f /etc/config/transmission*
    rm -rf /var/transmission
    rm -f /etc/hotplug.d/usb/60-transmission
    uci set modgui.app.transmission_webui="0"
    uci commit modgui
  }
  start() {
    /etc/init.d/transmission start
  }
  stop() {
    /etc/init.d/transmission stop
  }

  case $1 in
  install)
    install "$2"
    ;;
  remove)
    remove
    ;;
  start)
    start
    ;;
  stop)
    stop
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_telstra() {
  install() {
    require_free_space 4096 /www || return 1
    /usr/share/transformer/scripts/checkver DownloadInstalled telstra_gui.tar.bz2 /tmp/telstra_gui.tar.bz2 || return 1
    extract_bzip_archive /tmp/telstra_gui.tar.bz2 / || return 1
    rm /tmp/telstra_gui.tar.bz2
    /etc/init.d/nginx restart
    uci set modgui.app.telstra_webui="1"
    uci commit modgui
  }

  remove() {
    if [ -d /www/telstra-snippets ]; then
      rm -r /www/telstra-snippets
      rm /www/gateway-snippets/telstra-gui.lp
      rm /www/docroot/telstra-gui.lp
      rm -r /www/docroot/telstra-modals
      rm -r /www/docroot/telstra-helpfiles
      rm -r /www/docroot/img/telstra
      rm /www/docroot/js/main-telstra-min.js
      rm -f /www/docroot/css/gw-telstra.css
      /etc/init.d/nginx restart
      uci set modgui.app.telstra_webui="0"
      uci commit modgui
    fi
  }

  case $1 in
  install)
    install "$2"
    ;;
  remove)
    remove
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_luci() {
  install() {
    luci_install_arm() {
      opkg update || return 1
      if [ ! -f /rom/usr/lib/libjson-c.so.2 ] && [ ! -e /usr/lib/libjson-c.so.2 ]; then
        ln -s /usr/lib/libjson-c.so.4 /usr/lib/libjson-c.so.2 || return 1
      fi
      rm -f /usr/lib/lua/uci.so #remove to avoid lua-uci conflict during install
      opkg install --force-reinstall libuci-lua luci rpcd uhttpd
      luci_opkg_status=$?
      # Restore the firmware binding even when opkg fails.
      cp /rom/usr/lib/lua/uci.so /usr/lib/lua/ || return 1
      [ "$luci_opkg_status" -eq 0 ] || return "$luci_opkg_status"
      [ -f /usr/lib/lua/luci/model/uci.lua ] && [ -x /etc/init.d/uhttpd ] || return 1
      mkdir -p /www_luci || return 1
      for luci_asset in cgi-bin luci-static index.html; do
        if [ -d "/www/$luci_asset" ]; then
          mkdir -p "/www_luci/$luci_asset" || return 1
          cp -R "/www/$luci_asset/." "/www_luci/$luci_asset/" || return 1
          rm -rf "/www/$luci_asset"
        elif [ -f "/www/$luci_asset" ]; then
          mv "/www/$luci_asset" /www_luci/ || return 1
        fi
      done
      [ -f /www_luci/cgi-bin/luci ] || return 1
      sed -i 's/require "uci"/require "uci_luci"/g' /usr/lib/lua/luci/model/uci.lua || return 1

      if [ ! "$(uci get uhttpd.main.listen_http | grep 9080)" ]; then
        uci del_list uhttpd.main.listen_http='0.0.0.0:80'
        uci add_list uhttpd.main.listen_http='0.0.0.0:9080'
        uci del_list uhttpd.main.listen_http='[::]:80'
        uci add_list uhttpd.main.listen_http='[::]:9080'
        uci del_list uhttpd.main.listen_https='0.0.0.0:443'
        uci add_list uhttpd.main.listen_https='0.0.0.0:9443'
        uci del_list uhttpd.main.listen_https='[::]:443'
        uci add_list uhttpd.main.listen_https='[::]:9443'
      fi
      uci set uhttpd.main.home='/www_luci' || return 1

      uci commit uhttpd || return 1
      # Legacy rc.common returns 1 after creating the boot link when STOP is
      # unset. Check the enabled state before treating that as a failure.
      /etc/init.d/uhttpd enable || /etc/init.d/uhttpd enabled || return 1
      /etc/init.d/uhttpd restart || return 1
    }

    case $marketing_version in
    "16.1"* | "16.2"*)
      [ "$cpu_type" = "mips" ] && luci_mips_install || return 1
      ;;
    "16."* | "17."*)
      if [ "$cpu_type" = "armv7l" ]; then
        luci_install_arm || return 1
        opkg install --force-reinstall --force-overwrite libuci-lua || return 1
        sed -i 's/require "uci_luci"/require "uci"/g' /usr/lib/lua/luci/model/uci.lua || return 1
      elif [ "$cpu_type" = "mips" ]; then
        luci_mips_install || return 1
      else
        return 1
      fi
      ;;
    "18."* | "19."*)
      if [ "$cpu_type" = "armv7l" ]; then
        luci_install_arm || return 1
      elif [ "$cpu_type" = "mips" ]; then
        luci_mips_install || return 1
      else
        return 1
      fi
      ;;
    *)
      echo "Unknown app install script for $marketing_version $cpu_type"
      return 1
      ;;
    esac
    if [ "$cpu_type" = "armv7l" ]; then
      install_from_github "" luci_wireless specificapp install || return 1
    fi
    uci set modgui.app.luci_webui="1"
    uci commit modgui
  }
  remove() {
    if [ -f /usr/share/modgui-luci-wireless/setup.sh ]; then
      sh /usr/share/modgui-luci-wireless/setup.sh remove || return 1
    fi
    luci_remove_arm() {
      opkg remove --force-removal-of-dependent-packages uhttpd rpcd libuci-lua luci luci-*
      [ ! -f /rom/usr/lib/libjson-c.so.2 ] && rm -rf /usr/lib/libjson-c.so.2 #workaround for 18.x feeds used on 19.x firmware
      cp /rom/usr/lib/lua/uci.so /usr/lib/lua/ #restore lib as it gets removed by libuci-lua

      rm -rf /www_luci
      rm -rf /etc/config/uhttpd
      rm -rf /etc/config/luci

      #needed cause of a bug (?) macoers repos will keep trying to install wrong (newer) versions of luci and libubox
      sed -i '/^Package: luci/,/^$/d' /usr/lib/opkg/status
      sed -i '/^Package: uhttpd/,/^$/d' /usr/lib/opkg/status
    }

    [ "$cpu_type" = "armv7l" ] && luci_remove_arm
    if [ "$cpu_type" = "mips" ]; then luci_mips_remove || return 1; fi
    uci set modgui.app.luci_webui="0"
    uci commit modgui
  }

  case $1 in
  install)
    install "$2"
    ;;
  remove)
    remove
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_amule() {
  install() {
    [ "$cpu_type" = "mips" ] || return 1
    require_usb_storage || return 1
    require_free_space 16384 /usr || return 1
    install_from_github FrancYescO/sharing_tg789 amule || return 1
    [ -x /usr/bin/amuled ] || return 1
    uci set modgui.app.amule_webui="1"
    uci commit modgui
  }
  remove() {
    if [ -f /usr/share/transformer/scripts/remove_amule.sh ]; then
      sh /usr/share/transformer/scripts/remove_amule.sh || return 1
      rm -f /usr/share/transformer/scripts/remove_amule.sh
    elif opkg list-installed | grep -q '^amule '; then
      echo "Missing aMule removal manifest; refusing an incomplete removal"
      return 1
    fi
    uci set modgui.app.amule_webui="0"
    uci commit modgui
  }
  start() {
    /etc/init.d/amule start
  }
  stop() {
    /etc/init.d/amule stop
  }

  case $1 in
  install)
    install "$2"
    ;;
  start)
    start
    ;;
  stop)
    stop
    ;;
  remove)
    remove
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_aria2() {
  if [ "$cpu_type" = mips ]; then
    legacy_mips_app "$1" aria2
    return $?
  fi
  install() {
    install_arm() {
      opkg update || return 1
      # libstdcpp6 in the stock firmware already provides libstdcpp.
      # Let opkg resolve providers instead of forcing a conflicting package.
      opkg install aria2 || return 1
      curl -fLsSk https://github.com/mayswind/AriaNg-DailyBuild/tarball/master --output /tmp/ariang.tar.gz || return 1
      tar -xzf /tmp/ariang.tar.gz -C /www/docroot/ || return 1
      rm /tmp/ariang.tar.gz
      mv /www/docroot/*AriaNg* /www/docroot/aria || return 1

      ARIA2_DIR="/etc/aria2"

      mkdir $ARIA2_DIR
      touch $ARIA2_DIR/aria2.conf
      touch $ARIA2_DIR/aria2.session
      {
        echo 'enable-rpc=true'
        echo 'rpc-allow-origin-all=true'
        echo 'rpc-listen-all=true'
        echo 'rpc-listen-port=6800'
        echo 'input-file=/etc/aria2/aria2.session'
        echo 'save-session=/etc/aria2/aria2.session'
        echo 'save-session-interval=300'
        echo 'dir=/mnt/usb/USB-A1'
      } >>$ARIA2_DIR/aria2.conf

      # add aria2 in /etc/rc.local to start the daemon after a reboot
      sed -i '/exit 0/i \
			aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=/etc/aria2/aria2.conf' /etc/rc.local

      # start the daemon
      aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=$ARIA2_DIR/aria2.conf || return 1
    }

    case $marketing_version in
    "16.1"* | "16.2"*)
      case "$cpu_type" in
        armv7l) install_from_github FrancYescO/sharing_tg789 aria2-xtream || return 1 ;;
        *) return 1 ;;
      esac
      ;;
    "16."* | "17."* | "18."* | "19."*)
      case "$cpu_type" in
        armv7l) install_arm || return 1 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      echo "Unknown app install script for $marketing_version $cpu_type"
      return 1
      ;;
    esac
    uci set modgui.app.aria2_webui="1"
    uci commit modgui
  }
  remove() {
    killall aria2c
    opkg remove aria2 || return 1
    rm -rf /www/docroot/aria
    rm -rf /etc/aria2
    sed -i '/aria2c/d' /etc/rc.local
    uci set modgui.app.aria2_webui="0"
    uci commit modgui
  }
  start() {
    /etc/init.d/aria2 start
  }
  stop() {
    /etc/init.d/aria2 stop
  }

  case $1 in
  install)
    install "$2"
    ;;
  remove)
    remove
    ;;
  start)
    start
    ;;
  stop)
    stop
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

# Never execute an HTTP error page or treat an empty failed download as success.
run_voipblock() (
  script="/tmp/modgui-voipblock.$$.sh"
  trap 'rm -f "$script"' EXIT HUP INT TERM
  curl -fkLsS --connect-timeout 15 --max-time 60 \
    https://repository.macoers.com/voipblock/voipblock.sh --output "$script" || return 1
  [ -s "$script" ] && head -n 1 "$script" | grep -q '^#!.*sh' || return 1
  sh -n "$script" || return 1
  ash "$script" "$1"
)

app_voipblock_for_mmpbx() {
  install() {
    {
      run_voipblock tch_install_for_mmpbx
    } && {
      uci set modgui.app.voipblock_for_mmpbx="1"
      uci commit modgui
    }
  }
  remove() {
    {
      run_voipblock tch_uninstall_for_mmpbx
    } && {
      uci set modgui.app.voipblock_for_mmpbx="0"
      uci commit modgui
    }
  }

  case $1 in
  install)
    install
    ;;
  remove)
    remove
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_voipblock_for_asterisk() {
  install() {
    {
      run_voipblock tch_install_for_asterisk
    } && {
      uci set modgui.app.blacklist_app="0"
      uci set modgui.app.voipblock_for_asterisk="1"
      uci commit modgui
    }
  }
  remove() {
    {
      run_voipblock tch_uninstall_for_asterisk
     } && {
      uci set modgui.app.voipblock_for_asterisk="0"
      uci commit modgui
    }
  }

  case $1 in
  install)
    install "$2"
    ;;
  remove)
    remove
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_blacklist() {
  install() {
    require_free_space 12288 /usr || return 1
    install_from_github Ansuel/blacklist master normal "$2" || return 1
    uci set modgui.app.blacklist_app="1"
    uci commit modgui
  }
  remove() {
    # A failed/preflight-only install must not run the legacy uninstaller,
    # which removes Asterisk configuration and edits sudoers unconditionally.
    if [ "$(uci -q get modgui.app.blacklist_app)" != 1 ] &&
      [ ! -f /usr/share/transformer/mappings/rpc/mmpbx.blacklist.map ]; then
      return 0
    fi
    install_from_github Ansuel/blacklist master normal remove || return 1
    uci set modgui.app.blacklist_app="0"
    uci commit modgui
  }
  refresh() {
    /usr/share/transformer/scripts/refresh-blacklist.lp
  }

  case $1 in
  install)
    install "$2"
    ;;
  remove)
    remove
    ;;
  refresh)
    refresh
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_xupnp() {
  install() {
    opkg update || return 1
    opkg install xupnpd || return 1
    uci set modgui.app.xupnp_app="1"
    uci commit modgui
  }
  remove() {
    opkg remove xupnpd || return 1
    uci set modgui.app.xupnp_app="0"
    uci commit modgui
  }

  case $1 in
  install)
    install
    ;;
  remove)
    remove
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

set_extension_state() {
  uci set "modgui.app.$1=$2"
  uci commit modgui
}

# Native MIPS lifecycle: keep Technicolor's UCI binding and core libraries.
luci_mips_state=/etc/.modgui-luci-mips
luci_mips_feed=/etc/opkg/modgui-luci.conf

luci_mips_record_packages() {
  opkg list-installed | awk '{print $1}' > "$luci_mips_state/after"
  : > "$luci_mips_state/packages"
  while read -r package; do
    grep -Fxq "$package" "$luci_mips_state/before" || echo "$package" >> "$luci_mips_state/packages"
  done < "$luci_mips_state/after"
}

luci_mips_remove() {
  if [ ! -d "$luci_mips_state" ]; then
    if opkg list-installed | grep -q '^luci '; then
      echo "Unmanaged LuCI installation: refusing to remove existing packages"
      return 1
    fi
    return 0
  fi
  [ ! -x /etc/init.d/uhttpd ] || {
    /etc/init.d/uhttpd stop
    /etc/init.d/uhttpd disable
  }
  [ ! -x /etc/init.d/rpcd ] || {
    /etc/init.d/rpcd stop
    /etc/init.d/rpcd disable
  }
  # Only packages introduced by this installation may be removed. Repeat
  # dependency-order passes; never force removal of firmware dependencies.
  for pass in 1 2 3 4 5 6; do
    opkg list-installed | awk '{print $1}' > "$luci_mips_state/remaining"
    pending=0
    while read -r package; do
      if grep -Fxq "$package" "$luci_mips_state/remaining"; then
        pending=1
        opkg remove "$package" >/dev/null 2>&1 || true
      fi
    done < "$luci_mips_state/packages"
    [ "$pending" = 1 ] || break
  done
  cp -p "$luci_mips_state/uci.so" /usr/lib/lua/uci.so || return 1
  [ ! -f "$luci_mips_state/lua-uci.list" ] ||
    cp -p "$luci_mips_state/lua-uci.list" /usr/lib/opkg/info/lua-uci.list || return 1
  while read -r package; do
    if opkg status "$package" | grep -q '^Status:.* installed'; then
      echo "LuCI package still required: $package"
      return 1
    fi
  done < "$luci_mips_state/packages"
  rm -rf /www_luci
  rm -f /etc/config/luci /etc/config/uhttpd /etc/config/rpcd "$luci_mips_feed"
  rm -rf "$luci_mips_state"
}

luci_mips_install() (
  require_free_space 4096 /usr || return 1
  if [ -d "$luci_mips_state" ] || opkg list-installed | grep -Eq '^(luci|uhttpd|rpcd|libuci-lua) '; then
    echo "A LuCI installation already exists; refusing to overwrite it"
    return 1
  fi
  for config in /etc/config/luci /etc/config/uhttpd /etc/config/rpcd "$luci_mips_feed"; do
    [ ! -e "$config" ] || { echo "Existing LuCI configuration: $config"; return 1; }
  done
  tmp="/tmp/modgui-luci-mips.$$"
  mkdir -p "$tmp" "$luci_mips_state" /etc/opkg || return 1
  chmod 700 "$tmp" "$luci_mips_state"
  cp -p /usr/lib/lua/uci.so "$luci_mips_state/uci.so" || return 1
  [ ! -f /usr/lib/opkg/info/lua-uci.list ] ||
    cp -p /usr/lib/opkg/info/lua-uci.list "$luci_mips_state/lua-uci.list" || return 1
  opkg list-installed | awk '{print $1}' > "$luci_mips_state/before"
  success=0
  cleanup() {
    cp -p "$luci_mips_state/uci.so" /usr/lib/lua/uci.so
    if [ "$success" != 1 ]; then
      luci_mips_record_packages
      luci_mips_remove
    fi
    rm -rf "$tmp"
  }
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM
  curl -fkLsS --connect-timeout 15 --max-time 120 \
    https://api.github.com/repos/nutterpc/tg-luci/tarball/9bd097140ee3d2e655724d9456e111fb6bac8925 \
    --output "$tmp/source.tgz" || return 1
  [ "$(sha256sum "$tmp/source.tgz" | awk '{print $1}')" = 3f7c0195b60782b7922e4e249e8b73bcb132c97397f9aeb5851d025f245fd0be ] || {
    echo "MIPS LuCI archive checksum mismatch"; return 1;
  }
  tar -xzf "$tmp/source.tgz" -C "$tmp" || return 1
  # Generic brcm63xx's LuCI feed is empty; the official SMP LuCI feed
  # contains the architecture-independent Lua code. Keep all other feeds.
  echo 'src/gz modgui_luci_mips http://archive.openwrt.org/chaos_calmer/15.05.1/brcm63xx/smp/packages/luci' > "$luci_mips_feed"
  opkg update || return 1
  set -- "$tmp"/nutterpc-*/libiwinfo*.ipk "$tmp"/nutterpc-*/rpcd*.ipk "$tmp"/nutterpc-*/uhttpd*.ipk
  opkg install "$@" || return 1
  # The custom package adds uci_luci.so; restore the vendor uci.so even on
  # failure. Do not upgrade libuci, libubox or any other core package.
  opkg install --force-overwrite "$tmp"/nutterpc-*/libuci-lua_*.ipk
  status=$?
  cp -p "$luci_mips_state/uci.so" /usr/lib/lua/uci.so || return 1
  [ "$status" = 0 ] || return 1
  opkg install luci luci-lib-json luci-lib-jsonc luci-lib-nixio luci-mod-rpc || return 1
  lua -e 'assert(require("uci_luci").cursor())' || return 1
  sed -i 's/require "uci"/require "uci_luci"/g' /usr/lib/lua/luci/model/uci.lua || return 1
  mkdir -p /www_luci || return 1
  for asset in cgi-bin luci-static index.html; do
    [ ! -e "/www/$asset" ] || mv "/www/$asset" /www_luci/ || return 1
  done
  [ -f /www_luci/cgi-bin/luci ] || return 1
  uci -q delete uhttpd.main.listen_http
  uci add_list uhttpd.main.listen_http=0.0.0.0:9080
  uci add_list uhttpd.main.listen_http='[::]:9080'
  uci -q delete uhttpd.main.listen_https
  uci set uhttpd.main.home=/www_luci
  uci commit uhttpd || return 1
  /etc/init.d/uhttpd enable || /etc/init.d/uhttpd enabled || return 1
  /etc/init.d/uhttpd restart || return 1
  luci_mips_record_packages
  success=1
)

require_usb_storage() {
  modgui_usb_root=$(awk '$1 ~ /^\/dev\/sd[a-z][0-9]*$/ &&
    $2 ~ /^\/tmp\/run\/mountd\/sd[a-z][0-9]*$/ && $4 ~ /(^|,)rw(,|$)/ {
      print $2; exit
    }' /proc/mounts)
  if [ -z "$modgui_usb_root" ]; then
    echo "This legacy MIPS app requires a mounted writable USB disk"
    return 1
  fi
  probe=$(mktemp "$modgui_usb_root/.modgui-write.XXXXXX") || return 1
  rm -f "$probe"
}

# The old upstream setup scripts assume sda1, upgrade libstdcpp globally and
# remove dependencies they did not install. Keep those operations local here.
legacy_mips_record_packages() {
  opkg list-installed | awk '{print $1}' > "$legacy_state/after"
  : > "$legacy_state/packages"
  while read -r package; do
    grep -Fxq "$package" "$legacy_state/before" || echo "$package" >> "$legacy_state/packages"
  done < "$legacy_state/after"
}

legacy_mips_record_account() {
  for database in passwd group shadow; do
    [ -f "$legacy_state/$database-absent" ] || continue
    grep "^$legacy_app:" "/etc/$database" > "$legacy_state/$database-created" 2>/dev/null || true
  done
}

legacy_mips_remove() {
  [ -d "$legacy_state" ] || {
    if opkg status "$main_package" | grep -q '^Status:.* installed'; then
      echo "Unmanaged $legacy_app installation; refusing to remove existing packages"
      return 1
    fi
    return 0
  }
  ca_restore="$legacy_state/ca-original"
  if [ -f "$legacy_state/installed" ] && [ -f "$ca_restore" ] &&
    [ -f /etc/ssl/certs/ca-certificates.crt ]; then
    # The GUI/user may have refreshed CA roots while this app was installed.
    cp -p /etc/ssl/certs/ca-certificates.crt "$legacy_state/ca-current" || return 1
    ca_restore="$legacy_state/ca-current"
  fi
  [ ! -x "/etc/init.d/$legacy_app" ] || {
    "/etc/init.d/$legacy_app" stop 2>/dev/null
    "/etc/init.d/$legacy_app" disable 2>/dev/null
  }
  for pass in 1 2 3 4 5 6; do
    opkg list-installed | awk '{print $1}' > "$legacy_state/remaining"
    pending=0
    while read -r package; do
      if grep -Fxq "$package" "$legacy_state/remaining"; then
        pending=1
        opkg remove "$package" >/dev/null 2>&1 || true
      fi
    done < "$legacy_state/packages"
    [ "$pending" = 1 ] || break
  done
  # ca-bundle must not replace a customized firmware trust store, including
  # when opkg removes the bundle again during rollback or normal removal.
  [ ! -f "$ca_restore" ] ||
    cp -p "$ca_restore" /etc/ssl/certs/ca-certificates.crt || return 1
  while read -r package; do
    if opkg status "$package" | grep -q '^Status:.* installed'; then
      echo "Package still required by another application: $package"
      return 1
    fi
  done < "$legacy_state/packages"
  # BusyBox on older Homeware has no deluser/delgroup. Only remove exact
  # account entries created by this install; preserve later user edits.
  account_edited=0
  for database in passwd group shadow; do
    if [ -s "$legacy_state/$database-created" ] &&
      grep -q "^$legacy_app:" "/etc/$database" &&
      ! grep -Fxq "$(cat "$legacy_state/$database-created")" "/etc/$database"; then
      account_edited=1
    fi
  done
  if [ "$account_edited" = 0 ]; then
    for database in passwd group shadow; do
      [ ! -s "$legacy_state/$database-created" ] ||
        sed -i "/^$legacy_app:/d" "/etc/$database" || return 1
    done
  else
    echo "Modified $legacy_app account was preserved"
  fi
  if [ "$legacy_app" = aria2 ]; then
    rm -f /www/docroot/aria /usr/libexec/modgui-aria2c /etc/init.d/aria2
  else
    rm -f /usr/share/transmission
  fi
  rm -f "/etc/config/$legacy_app"
  private=$(cat "$legacy_state/private")
  case "$private" in
    /tmp/run/mountd/sd*/.modgui-apps/aria2|/tmp/run/mountd/sd*/.modgui-apps/transmission)
      # Never follow a replacement directory while the original USB is absent.
      if awk -v usb="$(cat "$legacy_state/usb")" '$2 == usb {found=1} END {exit !found}' /proc/mounts; then
        rm -rf "$private"
        rmdir "$(dirname "$private")" 2>/dev/null || true
      fi
      ;;
  esac
  rm -rf "$legacy_state"
  set_extension_state "${legacy_app}_webui" 0
}

legacy_mips_install() (
  require_usb_storage || return 1
  require_free_space 6144 /usr || return 1
  require_free_space 16384 "$modgui_usb_root" || return 1
  if [ -e "$legacy_state" ] || opkg status "$main_package" | grep -q '^Status:.* installed'; then
    echo "A $legacy_app installation already exists; refusing to overwrite it"
    return 1
  fi
  private="$modgui_usb_root/.modgui-apps/$legacy_app"
  config="$modgui_usb_root/sharing/config/$legacy_app"
  download="$modgui_usb_root/sharing/download/$legacy_app"
  if [ -e "$private" ] || [ -e "/etc/config/$legacy_app" ]; then
    echo "Existing $legacy_app runtime/configuration; refusing to overwrite it"
    return 1
  fi
  if [ "$legacy_app" = aria2 ]; then
    [ ! -e /www/docroot/aria ] && [ ! -e /usr/libexec/modgui-aria2c ] || return 1
    commit=499a17ed634e1b7ee764f58d5c20bb5bc0155c7d
    digest=3d7558fb9d80ce25269cfe746c78dd6d58820f066c7292240959018ceb8a37f2
  else
    [ ! -e /usr/share/transmission ] || return 1
    commit=49a5d4e392e66c7ff98a00c534ee21de110d71d5
    digest=6b88ca12ba21f3aaee3b0a4c7f5b6faf5a3473741f38ca58235e8c69d66b7f6f
  fi
  mkdir -p "$legacy_state" || return 1
  chmod 700 "$legacy_state"
  printf '%s\n' "$modgui_usb_root" > "$legacy_state/usb"
  printf '%s\n' "$private" > "$legacy_state/private"
  for database in passwd group shadow; do
    grep -q "^$legacy_app:" "/etc/$database" 2>/dev/null || touch "$legacy_state/$database-absent"
  done
  opkg list-installed | awk '{print $1}' > "$legacy_state/before"
  : > "$legacy_state/packages"
  stage="$private/.install"
  success=0
  cleanup() {
    if [ "$success" != 1 ]; then
      legacy_mips_record_packages
      legacy_mips_record_account
      legacy_mips_remove
    fi
    rm -rf "$stage"
  }
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM
  mkdir -p "$stage" || return 1
  curl -fkLsS --connect-timeout 15 --max-time 120 \
    "https://api.github.com/repos/FrancYescO/sharing_tg789/tarball/$commit" \
    --output "$stage/source.tgz" || return 1
  [ "$(sha256sum "$stage/source.tgz" | awk '{print $1}')" = "$digest" ] || {
    echo "MIPS $legacy_app archive checksum mismatch"; return 1;
  }
  tar -xzf "$stage/source.tgz" -C "$stage" || return 1
  set -- "$stage"/FrancYescO-sharing_tg789-*
  [ "$#" = 1 ] && [ -d "$1" ] || return 1
  source=$1
  if [ "$legacy_app" = aria2 ]; then
    # Put the newer C++ runtime on USB without installing its essential IPK.
    data_member=$(tar -tzf "$source"/libstdcpp_*.ipk | grep -E '^(\./)?data.tar.gz$')
    tar -xOzf "$source"/libstdcpp_*.ipk "$data_member" > "$stage/cpp.tgz" || return 1
    cpp_member=$(tar -tzf "$stage/cpp.tgz" | grep -E '(^|/)libstdc\+\+\.so\.6\.[0-9.]+$')
    mkdir "$private/lib" || return 1
    # FAT has no symlinks: materialize the soname as a regular library file.
    tar -xOzf "$stage/cpp.tgz" "$cpp_member" > "$private/lib/libstdc++.so.6" || return 1
    opkg install "$source"/aria2_*.ipk
    status=$?
  else
    [ ! -f /etc/ssl/certs/ca-certificates.crt ] ||
      cp -p /etc/ssl/certs/ca-certificates.crt "$legacy_state/ca-original" || return 1
    set --
    for package in ca-bundle libevent2 libminiupnpc libnatpmp transmission-daemon-openssl transmission-remote-openssl; do
      if ! opkg status "$package" | grep -q '^Status:.* installed'; then
        set -- "$@" "$source"/"$package"_*.ipk
      fi
    done
    opkg install "$@"
    status=$?
    [ ! -f "$legacy_state/ca-original" ] ||
      cp -p "$legacy_state/ca-original" /etc/ssl/certs/ca-certificates.crt || return 1
  fi
  legacy_mips_record_packages
  legacy_mips_record_account
  [ "$status" = 0 ] || return 1
  mkdir -p "$config" "$download" || return 1
  if [ "$legacy_app" = aria2 ]; then
    mkdir -p /usr/libexec || return 1
    mv /usr/bin/aria2c /usr/libexec/modgui-aria2c || return 1
    cat > /usr/bin/aria2c <<EOF
#!/bin/sh
[ -r '$private/lib/libstdc++.so.6' ] || { echo 'Aria2 USB runtime is unavailable'; exit 1; }
export LD_LIBRARY_PATH='$private/lib'
exec /usr/libexec/modgui-aria2c "\$@"
EOF
    chmod 755 /usr/bin/aria2c
    /usr/bin/aria2c --version >/dev/null || return 1
    cp -R "$source/config/webui" "$private/webui" || return 1
    if [ ! -f "$config/aria2.conf" ]; then
      sed "s#/tmp/run/mountd/sda1#$modgui_usb_root#g" "$source/config/aria2.conf" > "$config/aria2.conf" || return 1
      printf '\ndht-file-path=%s/dht.dat\ndht-file-path6=%s/dht6.dat\n' "$config" "$config" >> "$config/aria2.conf" || return 1
      touch "$config/session.dat"
    fi
    ln -s "$private/webui" /www/docroot/aria || return 1
    cat > /etc/init.d/aria2 <<EOF
#!/bin/sh /etc/rc.common
START=95
STOP=10
USE_PROCD=1
start_service() {
  [ -r '$config/aria2.conf' ] && [ -r '$private/lib/libstdc++.so.6' ] || return 1
  procd_open_instance
  procd_set_param command /usr/bin/aria2c --daemon=false --conf-path='$config/aria2.conf'
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_close_instance
}
EOF
    chmod 755 /etc/init.d/aria2
  else
    /usr/bin/transmission-daemon --version >/dev/null || return 1
    cp -R "$source/config/web" "$private/web" || return 1
    ln -s "$private" /usr/share/transmission || return 1
    sed "s#/tmp/run/mountd/sda1#$modgui_usb_root#g" "$source/transmission.conf" > /etc/config/transmission || return 1
    mkdir -p "$config/config" || return 1
    uci set transmission.@transmission[0].enabled=0
    uci set transmission.@transmission[0].port_forwarding_enabled=false
    # Include only connected LAN prefixes; bridge-mode WAN is the same LAN.
    whitelist=127.0.0.1
    for address in "$(uci -q get network.lan.ipaddr)" "$(
      if [ "$(uci -q get network.config.wan_mode)" = bridge ]; then
        ubus call network.interface.wan status | jsonfilter -e '@["ipv4-address"][0].address'
      fi
    )"; do
      case "$address" in
        *[!0-9.]*|'') ;;
        *.*.*.*) whitelist="$whitelist,${address%.*}.*" ;;
      esac
    done
    uci set "transmission.@transmission[0].rpc_whitelist=$whitelist"
    uci commit transmission || return 1
  fi
  "/etc/init.d/$legacy_app" disable 2>/dev/null || true
  set_extension_state "${legacy_app}_webui" 1 || return 1
  touch "$legacy_state/installed" || return 1
  success=1
)

legacy_mips_app() {
  legacy_app=$2
  legacy_state="/etc/.modgui-mips-$legacy_app"
  main_package=$legacy_app
  [ "$legacy_app" != transmission ] || main_package=transmission-daemon-openssl
  case "$1" in
    install) legacy_mips_install ;;
    remove) legacy_mips_remove ;;
    start|stop)
      [ -x "/etc/init.d/$legacy_app" ] || return 1
      # Older unmanaged installations retain their original start/stop behavior.
      if [ -d "$legacy_state" ] && [ "$1" = start ]; then
        usb=$(cat "$legacy_state/usb")
        awk -v usb="$usb" '$2 == usb && $4 ~ /(^|,)rw(,|$)/ {found=1} END {exit !found}' /proc/mounts || {
          echo "$legacy_app USB storage is unavailable"; return 1;
        }
        if [ "$legacy_app" = transmission ]; then
          uci set transmission.@transmission[0].enabled=1 && uci commit transmission || return 1
        fi
      fi
      "/etc/init.d/$legacy_app" "$1" || return 1
      if [ -d "$legacy_state" ] && [ "$legacy_app" = transmission ] && [ "$1" = stop ]; then
        uci set transmission.@transmission[0].enabled=0 && uci commit transmission || return 1
      fi
      ;;
    *) echo "Unsupported action"; return 1 ;;
  esac
}

extract_bzip_archive() (
  # Legacy BusyBox tar has no -j. Avoid a pipeline whose exit status hides
  # decompression failures and could report an empty install as successful.
  archive_tmp=$(mktemp /tmp/modgui-app-archive.XXXXXX) || return 1
  trap 'rm -f "$archive_tmp"' EXIT
  trap 'exit 1' HUP INT TERM
  bzcat "$1" > "$archive_tmp" || return 1
  tar -xf "$archive_tmp" -C "$2"
)

require_free_space() {
  required_kb="$1"
  target_path="$2"
  available_kb="$(df -Pk "$target_path" 2>/dev/null | awk 'END {print $4}')"
  case "$available_kb" in
  *[!0-9]* | "")
    echo "Unable to determine free space on $target_path"
    return 1
    ;;
  esac
  if [ "$available_kb" -lt "$required_kb" ]; then
    echo "Not enough free space on $target_path: ${available_kb} KB available, ${required_kb} KB required"
    return 1
  fi
}

adblock_cleanup_dns() {
  # The legacy package leaves its servers file attached to Technicolor dnsmasq
  # instances even after uninstall. Preserve unrelated/custom servers files.
  local changed=0 section
  for section in $(uci -q show dhcp | sed -n 's/^dhcp\.\([^.=]*\)=dnsmasq$/\1/p'); do
    if [ "$(uci -q get "dhcp.$section.serversfile")" = "/tmp/adb_list.overall" ]; then
      uci -q delete "dhcp.$section.serversfile"
      changed=1
    fi
  done
  if [ "$changed" = 1 ]; then
    uci commit dhcp
    /etc/init.d/dnsmasq reload || return 1
  fi
  return 0
}

app_adblock() {
  adblock_owned="/etc/.modgui-adblock-installed"
  case "$1" in
  install)
    require_free_space 2048 /usr || return 1
    if ! opkg list-installed | grep -q '^adblock '; then
      touch "$adblock_owned"
    fi
    opkg update || return 1
    if [ "$cpu_type" = mips ] && ! opkg list adblock | grep -q '^adblock '; then
      # Chaos Calmer predates Adblock. Use the reviewed shell-only package;
      # its dependencies already exist in Technicolor Homeware 17.x.
      adblock_tmp="/tmp/modgui-adblock.$$.ipk"
      curl -fkLsS --connect-timeout 15 --max-time 60 \
        https://raw.githubusercontent.com/Ansuel/GUI_ipk/1587d4a113de414f4409ea80b11a8d03c115f17c/packages/adblock_3.5.5-3_all.ipk \
        --output "$adblock_tmp" || { rm -f "$adblock_tmp"; return 1; }
      if [ "$(sha256sum "$adblock_tmp" | awk '{print $1}')" != 5e76418e082917f3524706aa6ca1d05ae04042ec4d07080b1c3b9c320cb044b9 ]; then
        echo "Adblock package checksum mismatch"
        rm -f "$adblock_tmp"
        return 1
      fi
      opkg install "$adblock_tmp"
      adblock_status=$?
      rm -f "$adblock_tmp"
      [ "$adblock_status" = 0 ] || return 1
    else
      opkg install adblock || return 1
    fi
    # Old Homeware jshn provides json_load but not json_load_file. Keep the
    # package's status command usable without replacing the firmware library.
    if ! sh -c '. /usr/share/libubox/jshn.sh; command -v json_load_file >/dev/null'; then
      sed -i 's/json_load_file "${rtfile}"/json_load "$(cat "${rtfile}")"/' /etc/init.d/adblock || return 1
    fi
    [ -n "$(uci get -q adblock.global)" ] || uci set adblock.global=adblock
    uci set adblock.global.adb_enabled=1
    uci set adblock.global.adb_dns=dnsmasq
    uci set adblock.global.adb_fetchutil=curl
    uci commit adblock
    /etc/init.d/adblock enable
    /etc/init.d/adblock restart
    set_extension_state adblock_app 1
    ;;
  remove)
    [ -x /etc/init.d/adblock ] && /etc/init.d/adblock stop
    [ -x /etc/init.d/adblock ] && /etc/init.d/adblock disable
    if opkg list-installed | grep -q '^adblock '; then
      opkg remove adblock || return 1
    fi
    adblock_cleanup_dns || return 1
    if [ -f "$adblock_owned" ]; then
      rm -f /etc/config/adblock "$adblock_owned"
    fi
    set_extension_state adblock_app 0
    ;;
  start)
    /etc/init.d/adblock restart
    ;;
  stop)
    /etc/init.d/adblock stop
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_rsyncd() {
  rsync_owned="/etc/.modgui-rsync-installed"
  rsyncd_owned="/etc/.modgui-rsyncd-installed"
  case "$1" in
  install)
    opkg list-installed | grep -q '^rsync ' || touch "$rsync_owned"
    opkg list-installed | grep -q '^rsyncd ' || touch "$rsyncd_owned"
    opkg update || return 1
    opkg install rsync rsyncd || return 1
    /etc/init.d/rsyncd enable
    set_extension_state rsyncd_app 1
    ;;
  remove)
    [ -x /etc/init.d/rsyncd ] && /etc/init.d/rsyncd stop
    [ -x /etc/init.d/rsyncd ] && /etc/init.d/rsyncd disable
    if opkg list-installed | grep -q '^rsyncd '; then
      opkg remove rsyncd || return 1
    fi
    if [ -f "$rsync_owned" ] && opkg list-installed | grep -q '^rsync '; then
      opkg remove rsync || return 1
    fi
    if [ -f "$rsyncd_owned" ]; then
      rm -f /etc/rsyncd.conf "$rsyncd_owned"
    fi
    rm -f "$rsync_owned"
    set_extension_state rsyncd_app 0
    ;;
  start)
    /etc/init.d/rsyncd start
    ;;
  stop)
    /etc/init.d/rsyncd stop
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_speedtest() {
  speedtest_dir="/opt/ookla"
  speedtest_bin="$speedtest_dir/speedtest"
  speedtest_tmp="/tmp/speedtest-install.$$"

  speedtest_process_is_running() {
    [ -s /tmp/speedtest.pid ] || return 1
    speedtest_pid="$(cat /tmp/speedtest.pid)"
    case "$speedtest_pid" in
    *[!0-9]* | "") return 1 ;;
    esac
    [ -r "/proc/$speedtest_pid/cmdline" ] || return 1
    tr '\000' ' ' < "/proc/$speedtest_pid/cmdline" | grep -Fq "$speedtest_bin"
  }

  case "$1" in
  install)
    case "$cpu_type" in
    armv7*) speedtest_arch="armel" ;;
    aarch64 | arm64) speedtest_arch="aarch64" ;;
    *)
      echo "Speedtest is only supported on ARM devices"
      return 1
      ;;
    esac
    mkdir -p "$speedtest_dir" || return 1
    require_free_space 12288 "$speedtest_dir" || return 1
    mkdir -p "$speedtest_tmp" || return 1
    curl -kfL "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-$speedtest_arch.tgz" \
      --output "$speedtest_tmp/speedtest.tgz" || {
        rm -rf "$speedtest_tmp"
        return 1
      }
    tar -xzf "$speedtest_tmp/speedtest.tgz" -C "$speedtest_tmp" || {
      rm -rf "$speedtest_tmp"
      return 1
    }
    [ -x "$speedtest_tmp/speedtest" ] || {
      rm -rf "$speedtest_tmp"
      return 1
    }
    cp "$speedtest_tmp/speedtest" "$speedtest_bin"
    chmod 755 "$speedtest_bin"
    rm -rf "$speedtest_tmp"
    set_extension_state speedtest_app 1
    ;;
  remove)
    app_speedtest stop
    rm -rf "$speedtest_dir"
    rm -f /tmp/speedtest-result.txt /tmp/speedtest.pid
    set_extension_state speedtest_app 0
    ;;
  start)
    [ -x "$speedtest_bin" ] || return 1
    if speedtest_process_is_running; then
      echo "Speedtest is already running"
      return 1
    fi
    (
      "$speedtest_bin" --accept-license --accept-gdpr --format=human-readable > /tmp/speedtest-result.txt 2>&1
      rm -f /tmp/speedtest.pid
    ) &
    echo $! > /tmp/speedtest.pid
    ;;
  stop)
    if speedtest_process_is_running; then
      kill "$speedtest_pid" 2>/dev/null
    fi
    rm -f /tmp/speedtest.pid
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_adguardhome() {
  adguard_dir="/opt/AdGuardHome"
  adguard_bin="$adguard_dir/AdGuardHome"
  adguard_config="$adguard_dir/AdGuardHome.yaml"
  adguard_work="$adguard_dir/work"
  adguard_tmp="/tmp/adguardhome-install.$$"

  if awk '$2 == "/overlay" && $3 == "jffs2" { found=1 } END { exit !found }' /proc/mounts; then
    adguard_work="/tmp/AdGuardHomeWork"
  fi

  case "$1" in
  install)
    case "$cpu_type" in
    armv7*) adguard_arch="armv5" ;;
    aarch64 | arm64) adguard_arch="arm64" ;;
    *)
      echo "AdGuard Home is only supported on ARM devices"
      return 1
      ;;
    esac
    mkdir -p /opt || return 1
    require_free_space 49152 /opt || return 1
    if [ -e "$adguard_dir" ]; then
      echo "$adguard_dir already exists; refusing to overwrite it"
      return 1
    fi
    mkdir -p "$adguard_tmp" || return 1
    curl -kfL "https://static.adguard.com/adguardhome/release/AdGuardHome_linux_$adguard_arch.tar.gz" \
      --output "$adguard_tmp/adguardhome.tgz" || {
        rm -rf "$adguard_tmp"
        return 1
      }
    tar -xzf "$adguard_tmp/adguardhome.tgz" -C "$adguard_tmp" || {
      rm -rf "$adguard_tmp"
      return 1
    }
    [ -x "$adguard_tmp/AdGuardHome/AdGuardHome" ] || {
      rm -rf "$adguard_tmp"
      return 1
    }
    mv "$adguard_tmp/AdGuardHome" "$adguard_dir" || {
      rm -rf "$adguard_tmp"
      return 1
    }
    rm -rf "$adguard_tmp"
    mkdir -p "$adguard_work" || {
      rm -rf "$adguard_dir"
      return 1
    }
    chmod 700 "$adguard_work"
    if ! "$adguard_bin" -s install -c "$adguard_config" -w "$adguard_work"; then
      rm -rf "$adguard_dir"
      rm -rf "$adguard_work"
      return 1
    fi
    if [ "$adguard_work" = "/tmp/AdGuardHomeWork" ] && [ -f /etc/init.d/AdGuardHome ]; then
      sed -i '/start_service() {/a\    mkdir -p /tmp/AdGuardHomeWork && chmod 700 /tmp/AdGuardHomeWork' /etc/init.d/AdGuardHome
    fi
    set_extension_state adguardhome_app 1
    ;;
  remove)
    if [ -x "$adguard_bin" ]; then
      "$adguard_bin" -s stop 2>/dev/null
      "$adguard_bin" -s uninstall 2>/dev/null
    fi
    rm -rf "$adguard_dir"
    [ "$adguard_work" = "/tmp/AdGuardHomeWork" ] && rm -rf "$adguard_work"
    set_extension_state adguardhome_app 0
    ;;
  start)
    "$adguard_bin" -s start
    ;;
  stop)
    "$adguard_bin" -s stop
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_openspeedtest() {
  openspeedtest_commit="f4263546f50694a154fdd27a03000390949068df"
  openspeedtest_sha256="f8d239bc4183c214c0747ec1a1c418fd33773683f82e7ee8327cf734ea6a4987"
  openspeedtest_dir="/usr/share/nginx/OpenSpeedTest"
  openspeedtest_conf="/etc/nginx/server_openspeedtest.conf"
  openspeedtest_disabled="/etc/nginx/server_openspeedtest.disabled"
  openspeedtest_tmp="/tmp/openspeedtest-install.$$"

  case "$1" in
  install)
    if [ -e "$openspeedtest_dir" ]; then
      echo "$openspeedtest_dir already exists; refusing to overwrite it"
      return 1
    fi
    mkdir -p /usr/share/nginx || return 1
    require_free_space 40960 /usr/share/nginx || return 1
    require_free_space 40960 /tmp || return 1
    mkdir -p "$openspeedtest_tmp" || return 1
    curl -kfL "https://github.com/openspeedtest/Speed-Test/archive/$openspeedtest_commit.tar.gz" \
      --output "$openspeedtest_tmp/openspeedtest.tgz" || {
        rm -rf "$openspeedtest_tmp"
        return 1
      }
    openspeedtest_actual_sha256="$(sha256sum "$openspeedtest_tmp/openspeedtest.tgz" | awk '{print $1}')"
    if [ "$openspeedtest_actual_sha256" != "$openspeedtest_sha256" ]; then
      echo "OpenSpeedTest archive checksum mismatch"
      rm -rf "$openspeedtest_tmp"
      return 1
    fi
    tar -xzf "$openspeedtest_tmp/openspeedtest.tgz" -C "$openspeedtest_tmp" || {
      rm -rf "$openspeedtest_tmp"
      return 1
    }
    openspeedtest_extracted="$openspeedtest_tmp/Speed-Test-$openspeedtest_commit"
    [ -f "$openspeedtest_extracted/index.html" ] || {
      rm -rf "$openspeedtest_tmp"
      return 1
    }
    mv "$openspeedtest_extracted" "$openspeedtest_dir" || {
      rm -rf "$openspeedtest_tmp"
      return 1
    }
    rm -rf "$openspeedtest_tmp"
    cat > "$openspeedtest_conf" <<CONF_END
server {
  listen 5678;
  listen [::]:5678;
  server_name _;
  root $openspeedtest_dir;
  index index.html;
  client_max_body_size 10000M;
  access_log off;
  log_not_found off;
  server_tokens off;
  tcp_nodelay on;
  sendfile on;

  error_page 405 =200 \$uri;

  location / {
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Headers "Accept,Authorization,Cache-Control,Content-Type,DNT,If-Modified-Since,Keep-Alive,Origin,User-Agent,X-Mx-ReqToken,X-Requested-With" always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Cache-Control "no-store, no-cache, max-age=0, no-transform";
    if_modified_since off;
    expires off;
    etag off;
  }

  location /assets/ {
    access_log off;
    expires 365d;
    add_header Cache-Control public;
    add_header Vary Accept-Encoding;
  }
}
CONF_END
    if ! nginx -t; then
      rm -f "$openspeedtest_conf"
      rm -rf "$openspeedtest_dir"
      return 1
    fi
    if ! /etc/init.d/nginx restart; then
      rm -f "$openspeedtest_conf"
      rm -rf "$openspeedtest_dir"
      /etc/init.d/nginx restart
      return 1
    fi
    set_extension_state openspeedtest_app 1
    ;;
  remove)
    rm -f "$openspeedtest_conf" "$openspeedtest_disabled"
    rm -rf "$openspeedtest_dir"
    nginx -t || return 1
    /etc/init.d/nginx restart || return 1
    set_extension_state openspeedtest_app 0
    ;;
  start)
    if [ -f "$openspeedtest_disabled" ]; then
      mv "$openspeedtest_disabled" "$openspeedtest_conf"
    fi
    if ! nginx -t; then
      [ -f "$openspeedtest_conf" ] && mv "$openspeedtest_conf" "$openspeedtest_disabled"
      return 1
    fi
    if ! /etc/init.d/nginx restart; then
      [ -f "$openspeedtest_conf" ] && mv "$openspeedtest_conf" "$openspeedtest_disabled"
      /etc/init.d/nginx restart
      return 1
    fi
    ;;
  stop)
    if [ -f "$openspeedtest_conf" ]; then
      mv "$openspeedtest_conf" "$openspeedtest_disabled"
    fi
    if ! nginx -t; then
      [ -f "$openspeedtest_disabled" ] && mv "$openspeedtest_disabled" "$openspeedtest_conf"
      return 1
    fi
    if ! /etc/init.d/nginx restart; then
      [ -f "$openspeedtest_disabled" ] && mv "$openspeedtest_disabled" "$openspeedtest_conf"
      /etc/init.d/nginx restart
      return 1
    fi
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_wireguard() {
  wireguard_commit="7ac8fe29a7ab64eb0c9c9774bb36cf2c7648399e"
  wireguard_version="2023.09.29"
  wireguard_owned="/etc/.modgui-wireguard-go-installed"
  wireguard_tmp="/tmp/wireguard-go-install.$$.ipk"

  wireguard_gui_backup="/opt/modgui-wireguard-gui.tar.gz"

  wireguard_tun_supported() {
    modgui_has_tun
  }

  wireguard_install_tun() {
    modgui_install_tun wireguard
  }

  wireguard_remove_tun() {
    modgui_release_tun wireguard
  }

  wireguard_register_gui() {
    uci -q del_list web.ruleset_main.rules=wireguardmodal
    uci add_list web.ruleset_main.rules=wireguardmodal
    uci set web.wireguardmodal=rule
    uci set web.wireguardmodal.target=/modals/wireguard-modal.lp
    uci -q del_list web.wireguardmodal.roles=admin
    uci -q del_list web.wireguardmodal.roles=engineer
    uci -q del_list web.wireguardmodal.roles=superuser
    uci add_list web.wireguardmodal.roles=admin
    uci add_list web.wireguardmodal.roles=engineer
    uci add_list web.wireguardmodal.roles=superuser
    uci -q del_list web.ruleset_main.rules=wireguardprofile
    uci add_list web.ruleset_main.rules=wireguardprofile
    uci set web.wireguardprofile=rule
    uci set web.wireguardprofile.target=/ajax/wireguard_profile.lua
    uci -q del_list web.wireguardprofile.roles=admin
    uci -q del_list web.wireguardprofile.roles=engineer
    uci -q del_list web.wireguardprofile.roles=superuser
    uci add_list web.wireguardprofile.roles=admin
    uci add_list web.wireguardprofile.roles=engineer
    uci add_list web.wireguardprofile.roles=superuser
    uci set web.wireguard_card=card
    uci set web.wireguard_card.card=016_wireguard.lp
    uci set web.wireguard_card.modal=wireguardmodal
    uci commit web
  }

  wireguard_backup_gui() {
    mkdir -p /opt || return 1
    tar -czf "$wireguard_gui_backup" -C / \
      usr/share/modgui-wireguard/wireguard.default \
      usr/share/transformer/commitapply/uci_wireguard.ca \
      usr/share/transformer/mappings/uci/wireguard.map \
      usr/share/transformer/mappings/uci/wireguard.peer.map \
      usr/share/transformer/scripts/wireguardApply.sh \
      usr/share/transformer/scripts/wireguardStatus.sh \
      usr/share/transformer/scripts/wireguardKeygen.sh \
      www/cards/016_wireguard.lp \
      www/docroot/ajax/wireguard_profile.lua \
      www/docroot/modals/wireguard-modal.lp \
      www/lang/it-it/webui-wireguard.po
  }

  wireguard_repair_gui() {
    [ -f "$wireguard_gui_backup" ] || return 1
    tar -xzf "$wireguard_gui_backup" -C / || return 1
    chmod 755 /usr/share/transformer/scripts/wireguardApply.sh \
      /usr/share/transformer/scripts/wireguardStatus.sh \
      /usr/share/transformer/scripts/wireguardKeygen.sh
    wireguard_register_gui
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
  }

  wireguard_prepare_config() {
    if [ ! -f /etc/config/wireguard ]; then
      cp /usr/share/modgui-wireguard/wireguard.default /etc/config/wireguard || return 1
    fi
    if [ "$(uci -q get wireguard.wg)" != "interface" ]; then
      uci set wireguard.wg=interface
      uci set wireguard.wg.enabled='0'
      uci set wireguard.wg.listen_port='51820'
      uci set wireguard.wg.private_key=''
      uci set wireguard.wg.public_key=''
      uci set wireguard.wg.address='10.66.66.1/24'
      uci set wireguard.wg.allow_lan='0'
      uci set wireguard.wg.allow_wan='0'
      uci commit wireguard
    fi
    chmod 600 /etc/config/wireguard
  }

  wireguard_cleanup_network() {
    for section in $(uci -q show network 2>/dev/null | awk -F'[.=]' '$2 ~ /^modgui_wg0/ {print $2}'); do
      uci -q delete "network.$section"
    done
    uci -q delete firewall.modgui_wireguard_udp
    uci -q delete firewall.modgui_wireguard_zone
    uci -q delete firewall.modgui_wireguard_to_lan
    uci -q delete firewall.modgui_lan_to_wireguard
    uci -q delete firewall.modgui_wireguard_to_wan
    uci -q commit network
    uci -q commit firewall
    /etc/init.d/network reload >/dev/null 2>&1
    /etc/init.d/firewall reload >/dev/null 2>&1
  }

  case "$1" in
  install)
    case "$cpu_type" in
    armv7*)
      wireguard_arch="arm_cortex-a9"
      wireguard_sha256="0cd9777ae758b180a140a11e24eea1716c001fcd2ef82adb0b43225b4929610b"
      ;;
    aarch64 | arm64)
      wireguard_arch="arm_cortex-a53"
      wireguard_sha256="1025b7cf216301c1f8db5d93a3cf683d11eea6d9a3bf19b620e27a083aefc0ff"
      ;;
    *)
      echo "WireGuard userspace runtime is only supported on ARM devices"
      return 1
      ;;
    esac
    wireguard_install_tun || return 1
    if opkg list-installed | grep -q '^wireguard-go '; then
      wireguard_prepare_config || return 1
      wireguard_register_gui
      wireguard_backup_gui || return 1
      set_extension_state wireguard_app 1
      /etc/init.d/transformer restart
      /etc/init.d/nginx restart
      return 0
    fi
    require_free_space 8192 /usr || return 1
    curl -kfL "https://raw.githubusercontent.com/seud0nym/openwrt-wireguard-go/$wireguard_commit/repository/$wireguard_arch/base/wireguard-go_${wireguard_version}_${wireguard_arch}.ipk" \
      --output "$wireguard_tmp" || {
        rm -f "$wireguard_tmp"
        return 1
      }
    wireguard_actual_sha256="$(sha256sum "$wireguard_tmp" | awk '{print $1}')"
    if [ "$wireguard_actual_sha256" != "$wireguard_sha256" ]; then
      echo "WireGuard package checksum mismatch"
      rm -f "$wireguard_tmp"
      return 1
    fi
    touch "$wireguard_owned"
    if ! opkg install "$wireguard_tmp"; then
      rm -f "$wireguard_tmp" "$wireguard_owned"
      return 1
    fi
    rm -f "$wireguard_tmp"
    if [ ! -x /usr/bin/wireguard-go ] || [ ! -x /usr/bin/wg-go ] ||
      [ ! -x /lib/netifd/proto/wireguard.sh ]; then
      opkg remove wireguard-go 2>/dev/null
      rm -f "$wireguard_owned"
      wireguard_remove_tun
      return 1
    fi
    wireguard_prepare_config || return 1
    wireguard_register_gui
    wireguard_backup_gui || return 1
    set_extension_state wireguard_app 1
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  remove)
    if [ ! -f "$wireguard_owned" ] && opkg list-installed | grep -q '^wireguard-go '; then
      echo "A pre-existing WireGuard runtime is installed; refusing to remove it"
      return 1
    fi
    if uci -q show network 2>/dev/null | grep "\.proto='wireguard'" | grep -v modgui_wg0 >/dev/null 2>&1; then
      echo "Remove manually configured WireGuard network interfaces before uninstalling the runtime"
      return 1
    fi
    if [ -f "$wireguard_owned" ]; then
      uci -q set wireguard.wg.enabled=0
      for section in $(uci -q show wireguard 2>/dev/null | awk -F'[.=]' '$3 == "peer" {print $2}'); do
        uci -q delete "wireguard.$section"
      done
      uci -q commit wireguard
      wireguard_cleanup_network
      rm -f /etc/config/wireguard /tmp/modgui-wireguard-client.conf \
        /tmp/modgui-wireguard-client.name
    fi
    if [ -f "$wireguard_owned" ] && opkg list-installed | grep -q '^wireguard-go '; then
      opkg remove wireguard-go || return 1
    fi
    wireguard_remove_tun
    uci -q delete web.wireguard_card
    uci -q delete web.wireguardmodal
    uci -q delete web.wireguardprofile
    uci -q del_list web.ruleset_main.rules=wireguardmodal
    uci -q del_list web.ruleset_main.rules=wireguardprofile
    uci commit web
    rm -f "$wireguard_owned" "$wireguard_tmp" "$wireguard_gui_backup" \
      /tmp/modgui-wireguard-client.conf /tmp/modgui-wireguard-client.name
    if opkg list-installed | grep -q '^wireguard-go '; then
      set_extension_state wireguard_app 1
    else
      set_extension_state wireguard_app 0
    fi
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  start)
    [ -x /usr/bin/wireguard-go ] || return 1
    wireguard_prepare_config || return 1
    uci set wireguard.wg.enabled=1
    uci commit wireguard
    /usr/share/transformer/scripts/wireguardApply.sh
    ;;
  stop)
    uci -q set wireguard.wg.enabled=0
    uci -q commit wireguard
    /usr/share/transformer/scripts/wireguardApply.sh
    ;;
  refresh)
    wireguard_repair_gui
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_l2tpipsec() {
  l2tpipsec_commit="5c9015930961848259aa883cbe1a20c02a227de4"
  l2tpipsec_sha256="5604db2e143c339eb1db0cb980e30492c2e5f57c4e35f06b52d224fb4822de18"
  l2tpipsec_tmp="/tmp/modgui-vpn-install.$$.ipk"
  l2tpipsec_before="/tmp/modgui-vpn-packages-before.$$"
  l2tpipsec_owned="/etc/.modgui-l2tp-ipsec-installed"
  l2tpipsec_packages="/etc/.modgui-l2tp-ipsec-packages"
  l2tpipsec_gui_backup="/opt/modgui-l2tp-ipsec-gui.tar.gz"

  l2tpipsec_backup_gui() {
    mkdir -p /opt || return 1
    tar -czf "$l2tpipsec_gui_backup" -C / \
      www/cards/014_l2tp-ipsec-server.lp \
      www/docroot/modals/l2tp-ipsec-server-modal.lp \
      www/lang/it-it/webui-l2tp-ipsec-server.po \
      usr/share/transformer/commitapply/uci_ipsec.ca \
      usr/share/transformer/commitapply/uci_l2tp_ipsec_server.ca \
      usr/share/transformer/mappings/rpc/l2tp_ipsec_server.map \
      usr/share/transformer/mappings/uci/ipsec.map \
      usr/share/transformer/mappings/uci/l2tp_ipsec_server.map || return 1
  }

  l2tpipsec_repair_gui() {
    [ -f "$l2tpipsec_gui_backup" ] || return 1
    tar -xzf "$l2tpipsec_gui_backup" -C / || return 1
    uci -q del_list web.ruleset_main.rules=l2tpipsecservermodal
    uci add_list web.ruleset_main.rules=l2tpipsecservermodal
    uci set web.l2tpipsecservermodal=rule
    uci set web.l2tpipsecservermodal.target=/modals/l2tp-ipsec-server-modal.lp
    uci -q del_list web.l2tpipsecservermodal.roles=admin
    uci -q del_list web.l2tpipsecservermodal.roles=engineer
    uci -q del_list web.l2tpipsecservermodal.roles=superuser
    uci add_list web.l2tpipsecservermodal.roles=admin
    uci add_list web.l2tpipsecservermodal.roles=engineer
    uci add_list web.l2tpipsecservermodal.roles=superuser
    uci set web.l2tpipsecserver_card=card
    uci set web.l2tpipsecserver_card.card=014_l2tp-ipsec-server.lp
    uci set web.l2tpipsecserver_card.modal=l2tpipsecservermodal
    uci commit web
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
  }

  l2tpipsec_set_enabled() {
    uci set "vpn.l2tpipsecserver.enable=$1"
    uci set "ipsec.l2tp.enabled=$1"
    uci commit vpn
    uci commit ipsec
  }

  l2tpipsec_remove_owned_package() {
    package="$1"
    grep -Fxq "$package" "$l2tpipsec_packages" || return 0
    if opkg status "$package" 2>/dev/null | grep -q '^Status:.*installed'; then
      opkg remove "$package" 2>/dev/null
    fi
  }

  l2tpipsec_remove_owned_packages() {
    [ -f "$l2tpipsec_packages" ] || return 0

    # strongswan-default depends on every plugin; remove it before the modules,
    # then remove the two frontends before the shared strongSwan base package.
    l2tpipsec_remove_owned_package strongswan-default
    grep '^strongswan-mod-' "$l2tpipsec_packages" | while read -r package; do
      l2tpipsec_remove_owned_package "$package"
    done
    l2tpipsec_remove_owned_package strongswan-charon
    l2tpipsec_remove_owned_package strongswan-ipsec
    l2tpipsec_remove_owned_package strongswan

    awk '{ packages[NR]=$0 } END { for (i=NR; i>0; i--) print packages[i] }' "$l2tpipsec_packages" |
      while read -r package; do
        case "$package" in
        modgui-vpn | strongswan | strongswan-*) continue ;;
        esac
        l2tpipsec_remove_owned_package "$package"
      done
  }

  l2tpipsec_record_new_packages() {
    : > "$l2tpipsec_packages" || return 1
    opkg list-installed | awk '{print $1}' | while read -r package; do
      grep -Fxq "$package" "$l2tpipsec_before" || echo "$package" >> "$l2tpipsec_packages"
    done
  }

  l2tpipsec_rollback_install() {
    l2tpipsec_record_new_packages
    opkg list-installed | grep -q '^modgui-vpn ' && opkg remove modgui-vpn 2>/dev/null
    l2tpipsec_remove_owned_packages
    rm -f "$l2tpipsec_packages" "$l2tpipsec_tmp" "$l2tpipsec_before"
  }

  case "$1" in
  install)
    case "$cpu_type" in
    armv7* | mips*) ;;
    *)
      echo "L2TP/IPsec runtime is only supported on ARMv7 and MIPS Technicolor gateways"
      return 1
      ;;
    esac
    if opkg list-installed | grep -q '^modgui-vpn '; then
      set_extension_state l2tpipsec_app 1
      return 0
    fi
    if opkg list-installed | grep -q '^strongswan'; then
      echo "A pre-existing strongSwan installation was found; refusing to overwrite its configuration"
      return 1
    fi
    require_free_space 16384 /usr || return 1
    opkg list-installed | awk '{print $1}' > "$l2tpipsec_before" || return 1
    opkg update || {
      rm -f "$l2tpipsec_before"
      return 1
    }
    # Preserve the firmware's existing xl2tpd version and configuration.
    if ! opkg status xl2tpd 2>/dev/null | grep -q '^Status:.*installed'; then
      opkg install xl2tpd || {
        l2tpipsec_rollback_install
        return 1
      }
    fi
    opkg install strongswan-default || {
      l2tpipsec_rollback_install
      return 1
    }
    curl -kfL "https://raw.githubusercontent.com/FrancYescO/sharing_tg789/$l2tpipsec_commit/modgui-vpn_1.1-0_all.ipk" \
      --output "$l2tpipsec_tmp" || {
        l2tpipsec_rollback_install
        return 1
      }
    l2tpipsec_actual_sha256="$(sha256sum "$l2tpipsec_tmp" | awk '{print $1}')"
    if [ "$l2tpipsec_actual_sha256" != "$l2tpipsec_sha256" ]; then
      echo "L2TP/IPsec package checksum mismatch"
      l2tpipsec_rollback_install
      return 1
    fi
    if ! opkg install "$l2tpipsec_tmp"; then
      l2tpipsec_rollback_install
      return 1
    fi
    rm -f "$l2tpipsec_tmp"
    if ! xl2tpd -v 2>&1 | grep -q '^xl2tpd version:' || ! ipsec version >/dev/null 2>&1; then
      echo "Installed L2TP/IPsec binaries are incompatible with this gateway"
      l2tpipsec_rollback_install
      return 1
    fi
    l2tpipsec_record_new_packages || return 1
    rm -f "$l2tpipsec_before"
    touch "$l2tpipsec_owned"
    l2tpipsec_backup_gui || return 1
    l2tpipsec_set_enabled 0
    /etc/init.d/l2tp-ipsec-server stop 2>/dev/null
    /etc/init.d/modgui-ipsec stop 2>/dev/null
    set_extension_state l2tpipsec_app 1
    ;;
  remove)
    if [ -f "$l2tpipsec_owned" ]; then
      l2tpipsec_set_enabled 0 2>/dev/null
      [ -x /etc/init.d/l2tp-ipsec-server ] && /etc/init.d/l2tp-ipsec-server stop 2>/dev/null
      [ -x /etc/init.d/modgui-ipsec ] && /etc/init.d/modgui-ipsec stop 2>/dev/null
      opkg list-installed | grep -q '^modgui-vpn ' && opkg remove modgui-vpn
      l2tpipsec_remove_owned_packages
    fi
    uci -q delete web.l2tpipsecserver_card
    uci -q delete web.l2tpipsecservercard
    uci -q delete web.l2tpipsecservermodal
    uci -q del_list web.ruleset_main.rules=l2tpipsecservermodal
    uci commit web
    rm -f "$l2tpipsec_owned" "$l2tpipsec_packages" "$l2tpipsec_gui_backup" \
      "$l2tpipsec_tmp" "$l2tpipsec_before"
    if opkg list-installed | grep -q '^modgui-vpn '; then
      set_extension_state l2tpipsec_app 1
    else
      set_extension_state l2tpipsec_app 0
    fi
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  start)
    l2tpipsec_set_enabled 1
    /etc/init.d/modgui-ipsec restart || return 1
    /etc/init.d/l2tp-ipsec-server restart
    ;;
  stop)
    l2tpipsec_set_enabled 0
    /etc/init.d/l2tp-ipsec-server stop
    /etc/init.d/modgui-ipsec stop
    ;;
  refresh)
    l2tpipsec_repair_gui
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_openvpn() {
  openvpn_before="/tmp/modgui-openvpn-packages-before.$$"
  openvpn_owned="/etc/.modgui-openvpn-installed"
  openvpn_packages="/etc/.modgui-openvpn-packages"
  openvpn_openssl_lib="/opt/modgui-openvpn-openssl"
  openvpn_openssl_sha256="12585b06530fecd2c73f9045edb131860e87ee4946c75be18a9d96f9b6ca8c37"
  openvpn_gui_backup="/opt/modgui-openvpn-gui.tar.gz"

  openvpn_has_tun() {
    modgui_has_tun
  }

  openvpn_install_tun() {
    modgui_install_tun openvpn
  }

  openvpn_remove_tun() {
    modgui_release_tun openvpn
  }

  openvpn_prepare_openssl() {
    openssl version >/dev/null 2>&1 && return 0
    if [ -d "$openvpn_openssl_lib/usr/lib" ] &&
      LD_LIBRARY_PATH="$openvpn_openssl_lib/usr/lib" openssl version >/dev/null 2>&1; then
      return 0
    fi
    modgui_reviewed_tun_build || return 1
    curl -kfL "https://raw.githubusercontent.com/FrancYescO/GUI_ipk/$modgui_tun_commit/base/libopenssl_1.0.2t-1_arm_cortex-a9_neon.ipk" \
      --output /tmp/modgui-openvpn-libopenssl.ipk || return 1
    [ "$(sha256sum /tmp/modgui-openvpn-libopenssl.ipk | awk '{print $1}')" = "$openvpn_openssl_sha256" ] || {
      echo "OpenSSL library checksum mismatch"
      return 1
    }
    mkdir -p "$openvpn_openssl_lib" || return 1
    tar -xOzf /tmp/modgui-openvpn-libopenssl.ipk ./data.tar.gz |
      tar -xzf - -C "$openvpn_openssl_lib" || return 1
    rm -f /tmp/modgui-openvpn-libopenssl.ipk
    LD_LIBRARY_PATH="$openvpn_openssl_lib/usr/lib" openssl version >/dev/null 2>&1
  }

  openvpn_register_gui() {
    uci -q del_list web.ruleset_main.rules=openvpnservermodal
    uci add_list web.ruleset_main.rules=openvpnservermodal
    uci set web.openvpnservermodal=rule
    uci set web.openvpnservermodal.target=/modals/openvpn-server-modal.lp
    uci -q del_list web.openvpnservermodal.roles=admin
    uci -q del_list web.openvpnservermodal.roles=engineer
    uci -q del_list web.openvpnservermodal.roles=superuser
    uci add_list web.openvpnservermodal.roles=admin
    uci add_list web.openvpnservermodal.roles=engineer
    uci add_list web.openvpnservermodal.roles=superuser
    uci set web.openvpnserver_card=card
    uci set web.openvpnserver_card.card=015_openvpn-server.lp
    uci set web.openvpnserver_card.modal=openvpnservermodal
    uci commit web
  }

  openvpn_register_client() {
    if [ "$(uci -q get openvpn.client)" != "openvpn" ]; then
      uci set openvpn.client=openvpn
      uci set openvpn.client.enabled=0
    fi
    [ -n "$(uci -q get openvpn.client.remote_port)" ] || uci set openvpn.client.remote_port=1194
    [ -n "$(uci -q get openvpn.client.remote_proto)" ] || uci set openvpn.client.remote_proto=udp
    [ -n "$(uci -q get openvpn.client.client_cipher)" ] || uci set openvpn.client.client_cipher=AES-256-CBC
    [ -n "$(uci -q get openvpn.client.client_auth)" ] || uci set openvpn.client.client_auth=SHA256
    uci set openvpn.client.config=/etc/openvpn/modgui-client.conf
    uci commit openvpn
  }

  openvpn_backup_gui() {
    mkdir -p /opt || return 1
    tar -czf "$openvpn_gui_backup" -C / \
      usr/share/modgui-openvpn/openvpn.default \
      usr/share/modgui-openvpn/checkpwd.sh \
      usr/share/transformer/commitapply/uci_openvpn.ca \
      usr/share/transformer/mappings/uci/openvpn.map \
      usr/share/transformer/mappings/rpc/openvpn.map \
      usr/share/transformer/mappings/rpc/openvpn.server.map \
      usr/share/transformer/mappings/rpc/openvpn.client.map \
      usr/share/transformer/mappings/rpc/openvpn.client.ssid.map \
      usr/share/transformer/scripts/openvpnApply.sh \
      usr/share/transformer/scripts/openvpnClientRoute.sh \
      usr/share/transformer/scripts/openvpnGenerateKeys.sh \
      etc/hotplug.d/iface/95-modgui-openvpn-client \
      www/cards/015_openvpn-server.lp \
      www/docroot/modals/openvpn-server-modal.lp \
      www/lang/it-it/webui-openvpn-server.po
  }

  openvpn_repair_gui() {
    [ -f "$openvpn_gui_backup" ] || return 1
    tar -xzf "$openvpn_gui_backup" -C / || return 1
    openvpn_register_gui
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
  }

  openvpn_record_new_packages() {
    : > "$openvpn_packages" || return 1
    opkg list-installed | awk '{print $1}' | while read -r package; do
      grep -Fxq "$package" "$openvpn_before" || echo "$package" >> "$openvpn_packages"
    done
  }

  openvpn_remove_owned_packages() {
    [ -f "$openvpn_packages" ] || return 0
    awk '{ packages[NR]=$0 } END { for (i=NR; i>0; i--) print packages[i] }' "$openvpn_packages" |
      while read -r package; do
        grep -Fxq "$package" "$openvpn_packages" || continue
        opkg status "$package" 2>/dev/null | grep -q '^Status:.*installed' && opkg remove "$package" 2>/dev/null
      done
  }

  openvpn_rollback_install() {
    openvpn_record_new_packages
    openvpn_remove_owned_packages
    openvpn_remove_tun
    rm -rf "$openvpn_openssl_lib"
    rm -f "$openvpn_before" "$openvpn_packages"
  }

  case "$1" in
  install)
    case "$cpu_type" in
    armv7* | mips*) ;;
    *)
      echo "OpenVPN is only supported on ARMv7 and MIPS Technicolor gateways"
      return 1
      ;;
    esac
    if opkg list-installed | grep -Eq '^openvpn-(openssl|mbedtls|polarssl|nossl) '; then
      if [ -f "$openvpn_owned" ]; then
        openvpn_install_tun || return 1
        openvpn_prepare_openssl || return 1
        openvpn_register_client || return 1
        openvpn_backup_gui || return 1
        openvpn_register_gui
        set_extension_state openvpn_app 1
        /etc/init.d/transformer restart
        /etc/init.d/nginx restart
        return 0
      fi
      echo "A pre-existing OpenVPN installation was found; refusing to overwrite its configuration"
      return 1
    fi
    require_free_space 16384 /usr || return 1
    opkg list-installed | awk '{print $1}' > "$openvpn_before" || return 1
    opkg update || {
      rm -f "$openvpn_before"
      return 1
    }
    openvpn_install_tun || {
      openvpn_rollback_install
      return 1
    }
    if modgui_reviewed_tun_build; then
      opkg install openvpn-easy-rsa openssl-util liblzo &&
        opkg install --nodeps --force-depends openvpn-openssl
    else
      opkg install openvpn-openssl openvpn-easy-rsa
    fi || {
      openvpn_rollback_install
      return 1
    }
    openvpn --version 2>/dev/null | grep -q '^OpenVPN ' || {
      echo "Installed OpenVPN binary is incompatible with this gateway"
      openvpn_rollback_install
      return 1
    }
    openvpn_prepare_openssl || {
      echo "No compatible OpenSSL utility is available for key generation"
      openvpn_rollback_install
      return 1
    }
    openvpn_record_new_packages || return 1
    rm -f "$openvpn_before"
    touch "$openvpn_owned"
    mkdir -p /etc/openvpn
    cp /usr/share/modgui-openvpn/openvpn.default /etc/config/openvpn || return 1
    cp /usr/share/modgui-openvpn/checkpwd.sh /etc/openvpn/checkpwd.sh || return 1
    chmod 700 /etc/openvpn/checkpwd.sh
    touch /etc/openvpn/psw-file
    chmod 600 /etc/openvpn/psw-file
    uci set openvpn.server.enabled=0
    uci commit openvpn
    openvpn_register_client || return 1
    openvpn_register_gui
    openvpn_backup_gui || return 1
    /usr/share/transformer/scripts/openvpnApply.sh
    set_extension_state openvpn_app 1
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  remove)
    if [ -f "$openvpn_owned" ]; then
      uci set openvpn.server.enabled=0
      uci set openvpn.client.enabled=0
      uci commit openvpn
      /usr/share/transformer/scripts/openvpnApply.sh >/dev/null 2>&1
      openvpn_remove_owned_packages
      openvpn_remove_tun
      rm -rf "$openvpn_openssl_lib"
      rm -f /etc/openvpn/checkpwd.sh
      rm -f /etc/openvpn/modgui-client.conf /etc/openvpn/modgui-client.auth \
        /etc/openvpn/modgui-client.password /etc/openvpn/modgui-client-ca.crt \
        /etc/openvpn/modgui-client.crt /etc/openvpn/modgui-client.key
    fi
    uci -q delete firewall.modgui_openvpn
    uci -q delete firewall.modgui_openvpn_zone
    uci -q delete firewall.modgui_openvpn_to_lan
    uci commit firewall
    /etc/init.d/firewall reload >/dev/null 2>&1
    uci -q delete web.openvpnserver_card
    uci -q delete web.openvpnservermodal
    uci -q del_list web.ruleset_main.rules=openvpnservermodal
    uci commit web
    rm -f "$openvpn_owned" "$openvpn_packages" "$openvpn_before" "$openvpn_gui_backup"
    set_extension_state openvpn_app 0
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  start)
    [ -f "$openvpn_owned" ] || return 1
    /usr/share/transformer/scripts/openvpnGenerateKeys.sh || return 1
    uci set openvpn.server.enabled=1
    uci commit openvpn
    /usr/share/transformer/scripts/openvpnApply.sh
    ;;
  stop)
    uci set openvpn.server.enabled=0
    uci commit openvpn
    /usr/share/transformer/scripts/openvpnApply.sh
    ;;
  refresh)
    openvpn_repair_gui
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_tailscale() {
  tailscale_version="1.102.4"
  tailscale_owned="/etc/.modgui-tailscale-installed"
  tailscale_packages="/etc/.modgui-tailscale-packages"
  tailscale_before="/tmp/modgui-tailscale-packages-before.$$"
  tailscale_archive="/tmp/modgui-tailscale-install.$$.tgz"
  tailscale_extract="/tmp/modgui-tailscale-extract.$$"
  tailscale_runtime_dir="$(uci -q get tailscale.service.runtime_dir)"
  tailscale_storage_dir="$(uci -q get tailscale.service.storage_dir)"
  tailscale_archive_path="$(uci -q get tailscale.service.archive_path)"
  tailscale_download_url="$(uci -q get tailscale.service.download_url)"
  tailscale_state_dir="$(uci -q get tailscale.service.state_dir)"
  [ -n "$tailscale_runtime_dir" ] || tailscale_runtime_dir="/opt/tailscale"
  [ -n "$tailscale_storage_dir" ] || tailscale_storage_dir="$tailscale_runtime_dir"
  [ -n "$tailscale_state_dir" ] || tailscale_state_dir="/opt/modgui-tailscale-state"
  tailscale_gui_backup="/opt/modgui-tailscale-gui.tar.gz"

  tailscale_has_tun() {
    modgui_has_tun
  }

  tailscale_has_space() {
    tailscale_available_kb="$(df -Pk "$2" 2>/dev/null | awk 'END {print $4}')"
    case "$tailscale_available_kb" in '' | *[!0-9]*) return 1 ;; esac
    [ "$tailscale_available_kb" -ge "$1" ]
  }

  tailscale_register_gui() {
    uci -q del_list web.ruleset_main.rules=tailscalemodal
    uci add_list web.ruleset_main.rules=tailscalemodal
    uci set web.tailscalemodal=rule
    uci set web.tailscalemodal.target=/modals/tailscale-modal.lp
    uci -q del_list web.tailscalemodal.roles=admin
    uci -q del_list web.tailscalemodal.roles=engineer
    uci -q del_list web.tailscalemodal.roles=superuser
    uci add_list web.tailscalemodal.roles=admin
    uci add_list web.tailscalemodal.roles=engineer
    uci add_list web.tailscalemodal.roles=superuser
    uci set web.tailscale_card=card
    uci set web.tailscale_card.card=016_tailscale.lp
    uci set web.tailscale_card.modal=tailscalemodal
    uci commit web
  }

  tailscale_backup_gui() {
    mkdir -p /opt || return 1
    tar -czf "$tailscale_gui_backup" -C / \
      usr/share/modgui-tailscale/tailscale.default \
      usr/share/modgui-tailscale/tailscale.init \
      usr/share/modgui-tailscale/tailscale.bootstrap \
      usr/share/modgui-tailscale/tailscale.connect \
      usr/share/transformer/commitapply/uci_tailscale.ca \
      usr/share/transformer/mappings/uci/tailscale.map \
      usr/share/transformer/scripts/tailscaleApply.sh \
      usr/share/transformer/scripts/tailscaleStatus.sh \
      www/cards/016_tailscale.lp \
      www/docroot/modals/tailscale-modal.lp \
      www/lang/it-it/webui-tailscale.po || return 1
  }

  tailscale_repair_gui() {
    [ -f "$tailscale_gui_backup" ] || return 1
    tar -xzf "$tailscale_gui_backup" -C / || return 1
    chmod 755 /usr/share/transformer/scripts/tailscaleApply.sh \
      /usr/share/transformer/scripts/tailscaleStatus.sh \
      /usr/share/modgui-tailscale/tailscale.bootstrap \
      /usr/share/modgui-tailscale/tailscale.connect
    tailscale_register_gui
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
  }

  tailscale_record_new_packages() {
    : > "$tailscale_packages" || return 1
    opkg list-installed | awk '{print $1}' | while read -r package; do
      grep -Fxq "$package" "$tailscale_before" || echo "$package" >> "$tailscale_packages"
    done
  }

  tailscale_remove_owned_packages() {
    [ -f "$tailscale_packages" ] || return 0
    awk '{ packages[NR]=$0 } END { for (i=NR; i>0; i--) print packages[i] }' "$tailscale_packages" |
      while read -r package; do
        opkg status "$package" 2>/dev/null | grep -q '^Status:.*installed' && opkg remove "$package" 2>/dev/null
      done
  }

  tailscale_remove_runtime() {
    [ -x /etc/init.d/tailscale ] && /etc/init.d/tailscale disable >/dev/null 2>&1
    [ -x /etc/init.d/tailscale ] && /etc/init.d/tailscale stop >/dev/null 2>&1
    [ -L /usr/sbin/tailscale ] && rm -f /usr/sbin/tailscale
    [ -L /usr/sbin/tailscaled ] && rm -f /usr/sbin/tailscaled
    rm -rf "$tailscale_runtime_dir"
    [ "$tailscale_storage_dir" = "$tailscale_runtime_dir" ] || rm -rf "$tailscale_storage_dir"
    rm -rf "$tailscale_state_dir"
    rm -f /etc/init.d/tailscale /etc/config/tailscale /tmp/modgui-tailscale-auth
  }

  tailscale_rollback_install() {
    tailscale_record_new_packages
    tailscale_remove_runtime
    tailscale_remove_owned_packages
    rm -rf "$tailscale_extract"
    rm -f "$tailscale_archive" "$tailscale_before" "$tailscale_packages"
    modgui_release_tun tailscale
  }

  case "$1" in
  install)
    case "$cpu_type" in
    armv7*)
      tailscale_arch="arm"
      tailscale_sha256="b981a59cb85fb923ee6e1860ee6934772c83a840a6627f0dbfd7711ed690b869"
      ;;
    aarch64 | arm64)
      tailscale_arch="arm64"
      tailscale_sha256="9dd1e6a592a014bbaea0103167ffe299adeda4ba14e078ce9c2895364f6c4c3f"
      ;;
    *)
      echo "Tailscale is only supported on ARM Technicolor gateways"
      return 1
      ;;
    esac
    if [ -f "$tailscale_owned" ]; then
      modgui_install_tun tailscale || return 1
      tailscale_register_gui
      tailscale_backup_gui || return 1
      set_extension_state tailscale_app 1
      /etc/init.d/transformer restart
      /etc/init.d/nginx restart
      return 0
    fi
    if [ -x /usr/sbin/tailscale ] || [ -x /usr/sbin/tailscaled ]; then
      echo "A pre-existing Tailscale installation was found; refusing to overwrite it"
      return 1
    fi
    if [ ! -f "$tailscale_owned" ] &&
      { [ -e /etc/config/tailscale ] || [ -e /etc/init.d/tailscale ] ||
        [ -e /opt/tailscale ] || [ -e /overlay/modgui-tailscale ]; }; then
      echo "Pre-existing Tailscale configuration or state was found; refusing to overwrite it"
      return 1
    fi
    modgui_install_tun tailscale || return 1
    if tailscale_has_space 98304 /opt; then
      tailscale_runtime_dir="/opt/tailscale"
      tailscale_storage_dir="$tailscale_runtime_dir"
      tailscale_archive_path=""
      tailscale_download_url=""
    elif tailscale_has_space 131072 /tmp; then
      tailscale_runtime_dir="/tmp/modgui-tailscale-runtime"
      tailscale_storage_dir="$tailscale_runtime_dir"
      tailscale_archive_path=""
      tailscale_download_url="https://pkgs.tailscale.com/stable/tailscale_${tailscale_version}_${tailscale_arch}.tgz"
    else
      echo "Tailscale needs 96 MB in /opt or 128 MB of temporary RAM for low-storage mode"
      modgui_release_tun tailscale
      return 1
    fi
    opkg list-installed | awk '{print $1}' > "$tailscale_before" || {
      modgui_release_tun tailscale
      return 1
    }
    curl -kfL "https://pkgs.tailscale.com/stable/tailscale_${tailscale_version}_${tailscale_arch}.tgz" \
      --output "$tailscale_archive" || {
        tailscale_rollback_install
        return 1
      }
    tailscale_actual_sha256="$(sha256sum "$tailscale_archive" | awk '{print $1}')"
    if [ "$tailscale_actual_sha256" != "$tailscale_sha256" ]; then
      echo "Tailscale archive checksum mismatch"
      tailscale_rollback_install
      return 1
    fi
    mkdir -p "$tailscale_extract" "$tailscale_runtime_dir" "$tailscale_storage_dir" "$tailscale_state_dir" || {
      tailscale_rollback_install
      return 1
    }
    tar -xzf "$tailscale_archive" -C "$tailscale_extract" || {
      tailscale_rollback_install
      return 1
    }
    tailscale_source="$tailscale_extract/tailscale_${tailscale_version}_${tailscale_arch}"
    [ -x "$tailscale_source/tailscale" ] && [ -x "$tailscale_source/tailscaled" ] || {
      echo "Tailscale archive does not contain the expected binaries"
      tailscale_rollback_install
      return 1
    }
    case "$tailscale_runtime_dir" in
    /tmp/*)
      rm -rf "$tailscale_runtime_dir"
      mv "$tailscale_source" "$tailscale_runtime_dir" || {
        tailscale_rollback_install
        return 1
      }
      ;;
    *)
      cp "$tailscale_source/tailscale" "$tailscale_runtime_dir/tailscale" || {
        tailscale_rollback_install
        return 1
      }
      cp "$tailscale_source/tailscaled" "$tailscale_runtime_dir/tailscaled" || {
        tailscale_rollback_install
        return 1
      }
      ;;
    esac
    chmod 755 "$tailscale_runtime_dir/tailscale" "$tailscale_runtime_dir/tailscaled"
    if [ -n "$tailscale_archive_path" ]; then
      cp "$tailscale_archive" "$tailscale_archive_path" || {
        tailscale_rollback_install
        return 1
      }
      sync
      [ "$(sha256sum "$tailscale_archive_path" | awk '{print $1}')" = "$tailscale_sha256" ] || {
        echo "Stored Tailscale archive checksum mismatch"
        tailscale_rollback_install
        return 1
      }
    fi
    ln -s "$tailscale_runtime_dir/tailscale" /usr/sbin/tailscale || {
      tailscale_rollback_install
      return 1
    }
    ln -s "$tailscale_runtime_dir/tailscaled" /usr/sbin/tailscaled || {
      tailscale_rollback_install
      return 1
    }
    /usr/sbin/tailscale version 2>/dev/null | grep -q "^$tailscale_version" || {
      echo "Installed Tailscale binary is incompatible with this gateway"
      tailscale_rollback_install
      return 1
    }
    cp /usr/share/modgui-tailscale/tailscale.init /etc/init.d/tailscale || {
      tailscale_rollback_install
      return 1
    }
    chmod 755 /etc/init.d/tailscale
    if [ ! -f /etc/config/tailscale ]; then
      cp /usr/share/modgui-tailscale/tailscale.default /etc/config/tailscale || {
        tailscale_rollback_install
        return 1
      }
      tailscale_hostname="$(uci -q get system.@system[0].hostname | tr 'A-Z_' 'a-z-')"
      case "$tailscale_hostname" in '' | [!a-z0-9]* | *[!a-z0-9.-]*) tailscale_hostname="technicolor" ;; esac
      tailscale_subnet="$(ip -4 route show dev br-lan 2>/dev/null | awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/ { print $1; exit }')"
      uci set "tailscale.service.hostname=$tailscale_hostname"
      [ -z "$tailscale_subnet" ] || uci set "tailscale.service.advertise_routes=$tailscale_subnet"
      uci set "tailscale.service.runtime_dir=$tailscale_runtime_dir"
      uci set "tailscale.service.storage_dir=$tailscale_storage_dir"
      uci set "tailscale.service.archive_path=$tailscale_archive_path"
      uci set "tailscale.service.download_url=$tailscale_download_url"
      uci set "tailscale.service.archive_sha256=$tailscale_sha256"
      uci set "tailscale.service.state_dir=$tailscale_state_dir"
      uci set tailscale.service.enabled=0
      uci set tailscale.service.connect=0
      uci commit tailscale
    fi
    tailscale_record_new_packages || {
      tailscale_rollback_install
      return 1
    }
    rm -rf "$tailscale_extract"
    rm -f "$tailscale_archive" "$tailscale_before"
    touch "$tailscale_owned"
    tailscale_register_gui
    tailscale_backup_gui || return 1
    /usr/share/transformer/scripts/tailscaleApply.sh || return 1
    set_extension_state tailscale_app 1
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  remove)
    if [ -f "$tailscale_owned" ]; then
      uci set tailscale.service.enabled=0
      uci set tailscale.service.connect=0
      uci commit tailscale
      /usr/share/transformer/scripts/tailscaleApply.sh >/dev/null 2>&1
      tailscale_remove_runtime
      tailscale_remove_owned_packages
    fi
    modgui_release_tun tailscale
    uci -q delete web.tailscale_card
    uci -q delete web.tailscalemodal
    uci -q del_list web.ruleset_main.rules=tailscalemodal
    uci commit web
    rm -rf "$tailscale_extract"
    rm -f "$tailscale_owned" "$tailscale_packages" "$tailscale_before" \
      "$tailscale_archive" "$tailscale_gui_backup" /tmp/modgui-tailscale-auth
    if [ -x /usr/sbin/tailscale ] || [ -x /usr/sbin/tailscaled ]; then
      set_extension_state tailscale_app 1
    else
      set_extension_state tailscale_app 0
    fi
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  start)
    uci set tailscale.service.enabled=1
    uci commit tailscale
    /usr/share/transformer/scripts/tailscaleApply.sh
    ;;
  stop)
    uci set tailscale.service.enabled=0
    uci commit tailscale
    /usr/share/transformer/scripts/tailscaleApply.sh
    ;;
  refresh)
    tailscale_repair_gui
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

app_dumaos() {
  dumaos_version="2.0-46"
  dumaos_tag="dumaos-repack-v$dumaos_version"
  dumaos_package="dumaos-repack_${dumaos_version}_arm_cortex-a9.ipk"
  dumaos_sha256="4fe83ddc7a34e1ada525302863f7683f54d1b37f21233c7db0750f253e50e4ef"
  dumaos_tmp="/tmp/dumaos-repack-install.$$.ipk"
  dumaos_module="/lib/modules/4.1.52/extra/act-connmark-damson-4.1.52.ko"
  dumaos_module_sha256="9bbd94d4e1ed2d02e1c990797b6540d3af3a4a13680099cb7014c4e211bc83ff"

  dumaos_installed() {
    opkg status dumaos-repack 2>/dev/null | grep -q '^Status:.*installed'
  }

  dumaos_installed_version() {
    opkg status dumaos-repack 2>/dev/null | awk -F': ' '$1 == "Version" { print $2; exit }'
  }

  dumaos_repair_gui() {
    # DumaOS is opened from Extensions; retire the card shipped by the IPK.
    rm -f /www/cards/015_dumaos.lp
    uci -q delete web.dumaos_card
    mkdir -p /www/data || return 1
    if [ -s /dumaossystem/version ]; then
      cp /dumaossystem/version /www/data/shorthash || return 1
      chmod 644 /www/data/shorthash
    fi
    if [ -f /www/docroot/modals/dumaos-modal.lp ]; then
      uci -q del_list web.ruleset_main.rules=dumaosmodal
      uci add_list web.ruleset_main.rules=dumaosmodal
      uci set web.dumaosmodal=rule
      uci set web.dumaosmodal.target=/modals/dumaos-modal.lp
      uci -q delete web.dumaosmodal.roles
      uci add_list web.dumaosmodal.roles=admin
      uci add_list web.dumaosmodal.roles=engineer
      uci add_list web.dumaosmodal.roles=superuser
    fi
    uci commit web
  }

  dumaos_running() {
    ps w 2>/dev/null | grep 'cli.lua -p .*com.netdumasoftware.procmanager' | grep -v grep >/dev/null
  }

  dumaos_recover_if_enabled() {
    [ "$(uci -q get dumaos.tr69.dumaos_enabled)" = "1" ] || return 0
    dumaos_running && return 0
    if [ -x /usr/lib/dumaos/platform/control.sh ]; then
      /usr/lib/dumaos/platform/control.sh start
    else
      rm -f /var/run/dumaos-status
      /etc/init.d/ctwatch-shim enable 2>/dev/null
      /etc/init.d/ctwatch-shim start 2>/dev/null
      /etc/init.d/ndhttpd enable 2>/dev/null
      /etc/init.d/ndhttpd start 2>/dev/null
      /etc/init.d/dumaos enable 2>/dev/null
      /etc/init.d/dumaos start
    fi
  }

  dumaos_install_qos_module() {
    [ "$(uname -r)" = "4.1.52" ] || return 0
    if [ ! -f "$dumaos_module" ]; then
      mkdir -p /lib/modules/4.1.52/extra || return 1
      curl -kfL "https://raw.githubusercontent.com/FrancYescO/GUI_ipk/kmods-4.1.52/artifacts/act-connmark-damson-4.1.52.ko" \
        --output "$dumaos_module.tmp" || {
          rm -f "$dumaos_module.tmp"
          return 1
        }
      dumaos_module_actual_sha256="$(sha256sum "$dumaos_module.tmp" | awk '{print $1}')"
      if [ "$dumaos_module_actual_sha256" != "$dumaos_module_sha256" ]; then
        echo "DumaOS QoS module checksum mismatch"
        rm -f "$dumaos_module.tmp"
        return 1
      fi
      mv "$dumaos_module.tmp" "$dumaos_module" || return 1
      depmod -a 4.1.52 2>/dev/null || true
    fi
    echo act_connmark > /etc/modules.d/99-dumaos-qos || return 1
    modprobe act_connmark 2>/dev/null || insmod "$dumaos_module" 2>/dev/null || {
      echo "Unable to load the DumaOS act_connmark QoS module"
      return 1
    }
  }

  dumaos_remove_firewall() {
    for section in $(uci -q show firewall 2>/dev/null | awk -F'[.=]' '$3 == "rule" {print $2}'); do
      dumaos_rule_name="$(uci -q get "firewall.$section.name")"
      case "$dumaos_rule_name" in
      "DumaOS UI" | dumaos_ui) uci -q delete "firewall.$section" ;;
      esac
    done
    uci -q delete firewall.dumaos_ui
    uci -q commit firewall
    /etc/init.d/firewall reload 2>/dev/null || true
  }

  dumaos_start() {
    uci -q set dumaos.tr69.dumaos_enabled=1
    uci -q commit dumaos
    if [ -x /usr/lib/dumaos/platform/control.sh ]; then
      /usr/lib/dumaos/platform/control.sh start
      return $?
    fi
    if ! dumaos_running; then
      rm -f /var/run/dumaos-status
    fi
    /etc/init.d/ctwatch-shim enable 2>/dev/null
    /etc/init.d/ctwatch-shim start 2>/dev/null
    /etc/init.d/ndhttpd enable
    /etc/init.d/ndhttpd start || return 1
    /etc/init.d/dumaos enable
    /etc/init.d/dumaos start
  }

  dumaos_stop() {
    uci -q set dumaos.tr69.dumaos_enabled=0
    uci -q commit dumaos
    if [ -x /usr/lib/dumaos/platform/control.sh ]; then
      /usr/lib/dumaos/platform/control.sh stop
      return $?
    fi
    /etc/init.d/dumaos stop 2>/dev/null
    /etc/init.d/ctwatch-shim stop 2>/dev/null || true
    /etc/init.d/ctwatch-shim disable 2>/dev/null || true
    /etc/init.d/ndhttpd stop 2>/dev/null || true
  }

  case "$1" in
  install)
    case "$cpu_type" in
    armv7*) ;;
    *)
      echo "DumaOS is only supported on ARMv7 Technicolor gateways"
      return 1
      ;;
    esac
    if [ "$(dumaos_installed_version)" != "$dumaos_version" ]; then
      require_free_space 40960 /usr || return 1
      require_free_space 10240 /tmp || return 1
      opkg update || return 1
      curl -kfL "https://github.com/FrancYescO/sharing_tg789/releases/download/$dumaos_tag/$dumaos_package" \
        --output "$dumaos_tmp" || {
          rm -f "$dumaos_tmp"
          return 1
        }
      dumaos_actual_sha256="$(sha256sum "$dumaos_tmp" | awk '{print $1}')"
      if [ "$dumaos_actual_sha256" != "$dumaos_sha256" ]; then
        echo "DumaOS package checksum mismatch"
        rm -f "$dumaos_tmp"
        return 1
      fi
      opkg install "$dumaos_tmp" || {
        rm -f "$dumaos_tmp"
        return 1
      }
      rm -f "$dumaos_tmp"
    fi
    [ -x /etc/init.d/dumaos ] && [ -x /etc/init.d/ndhttpd ] &&
      [ -f /usr/share/transformer/mappings/rpc/dumaos.map ] || {
        echo "DumaOS package does not contain the expected services and GUI files"
        return 1
    }
    dumaos_repair_gui || return 1
    set_extension_state dumaos_app 1
    dumaos_install_qos_module || echo "WARN: DumaOS installed, but the optional QoS module could not be prepared"
    dumaos_remove_firewall
    dumaos_start || return 1
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  remove)
    dumaos_installed || {
      set_extension_state dumaos_app 0
      return 0
    }
    dumaos_stop
    opkg remove dumaos-repack || return 1
    dumaos_remove_firewall
    rm -f "$dumaos_tmp" "$dumaos_module.tmp"
    uci -q delete web.dumaos_card
    uci -q delete web.dumaosmodal
    uci -q del_list web.ruleset_main.rules=dumaosmodal
    uci commit web
    set_extension_state dumaos_app 0
    ;;
  start)
    dumaos_installed || return 1
    dumaos_start
    ;;
  stop)
    dumaos_installed || return 1
    dumaos_stop
    ;;
  refresh)
    dumaos_installed || return 1
    dumaos_repair_gui || return 1
    dumaos_recover_if_enabled || return 1
    /etc/init.d/transformer restart
    /etc/init.d/nginx restart
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

install_specific_files() {

  install() {
    install_from_github "" "upgrade-pack-specific$1" specificapp || return 1
    uci set modgui.app.specific_app=1
    uci commit
  }
  remove() {
    echo "Specific files cannot be removed. Reset the router instead."
    return 1
  }

  case $1 in
  install)
    install "$2"
    ;;
  remove)
    remove
    ;;
  *)
    echo "Unsupported action"
    return 1
    ;;
  esac
}

call_app_type() {
  case "$2" in
  transmission)
    app_transmission "$1"
    ;;
  telstra)
    app_telstra "$1"
    ;;
  luci)
    app_luci "$1"
    ;;
  amule)
    app_amule "$1"
    ;;
  aria2)
    app_aria2 "$1"
    ;;
  xupnp)
    app_xupnp "$1"
    ;;
  voipblockmmpbx)
    app_voipblock_for_mmpbx "$1"
    ;;
  voipblockasterisk)
    app_voipblock_for_asterisk "$1"
    ;;
  blacklist)
    app_blacklist "$1" "$3"
    ;;
  adblock)
    app_adblock "$1"
    ;;
  rsyncd)
    app_rsyncd "$1"
    ;;
  speedtest)
    app_speedtest "$1"
    ;;
  adguardhome)
    app_adguardhome "$1"
    ;;
  openspeedtest)
    app_openspeedtest "$1"
    ;;
  wireguard)
    app_wireguard "$1"
    ;;
  l2tpipsec)
    app_l2tpipsec "$1"
    ;;
  openvpn)
    app_openvpn "$1"
    ;;
  tailscale)
    app_tailscale "$1"
    ;;
  dumaos)
    app_dumaos "$1"
    ;;
  specificapp)
    install_specific_files "$1" "$3"
    ;;
  *)
    echo "Provide a valid APP_NAME" 1>&2
    return 1
    ;;
  esac
}

case "$1" in
install | remove | stop | start | refresh)
  call_app_type "$1" "$2" "$3"
  ;;
*)
  echo "usage: install|remove APP_NAME" 1>&2
  return 1
  ;;
esac
