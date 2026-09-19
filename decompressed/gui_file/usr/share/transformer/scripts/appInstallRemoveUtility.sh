#!/bin/sh

marketing_version="$(uci get -q version.@version[0].marketing_version)"
cpu_type="$(uname -m)"

#  1st arg : directory
#  2nd arg : pkg name
#  3rd arg : raw or normal. Raw is used to download specific file from specific dir
#  4th arg : addtional command to append to setup.sh (usefull if setup.sh contains also uninstall command)
install_from_github() {
  mkdir "/tmp/$2"

  if [ "$3" = "specificapp" ]; then
    if [ ! -f "/tmp/$2.tar.bz2" ]; then
      if ! ping -q -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        echo "No internet connection detected, download manually!"
        exit 0
      fi
      /usr/share/transformer/scripts/checkver DownloadInstalled "$2.tar.bz2" "/tmp/$2.tar.bz2" || return 1
    fi
    if [ ! -f "/tmp/$2.tar.bz2" ]; then
      echo "Error installing App: Cannot find/download  $2.tar.bz2"
      return 1
    fi
    bzcat "/tmp/$2.tar.bz2" | tar -C "/tmp/$2" -xf -
    rm "/tmp/$2.tar.bz2"
    cd "/tmp/$2" || return 1
  else
    if [ ! -f "/tmp/$2.tar.gz" ]; then
      if ! ping -q -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        echo "No internet connection detected, download manually!"
        exit 0
      fi
      curl -sLk "https://github.com/$1/tarball/$2" --output "/tmp/$2.tar.gz"
    fi
    if [ ! -f "/tmp/$2.tar.gz" ]; then
      echo "Error installing App: Cannot find/download  $2.tar.gz"
      return 1
    fi
    tar -xzf "/tmp/$2.tar.gz" -C "/tmp/$2"
    rm "/tmp/$2.tar.gz"
    cd /tmp/"$2"/*
  fi

  chmod +x ./setup.sh
  ./setup.sh "$4"
  rm -rf "/tmp/$2"
}

############TRANSFORMER UTILITY##################
set_transformer() {
  cmd="require('datamodel').set('"$1"','"$2"')"
  lua -e "$cmd"
}
#################################################

app_transmission() {

  install_arm() {
    opkg update
    opkg install transmission-web transmission-daemon-openssl
    [ ! -f /rom/usr/lib/libmbedcrypto.so.1 ] && opkg install libmbedtls #workaround for 19.x firmware

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
      [ "$cpu_type" = "armv7l" ] && install_from_github FrancYescO/sharing_tg789 transmission-xtream
      [ "$cpu_type" = "mips" ] && install_from_github FrancYescO/sharing_tg789 transmission
      ;;
    "16."* | "17."* | "18."* | "19."*)
      [ "$cpu_type" = "armv7l" ] && install_arm
      [ "$cpu_type" = "mips" ] && install_from_github FrancYescO/sharing_tg789 transmission
      ;;
    *)
      echo "Unknown app install script for $marketing_version $cpu_type"
      ;;
    esac
    uci set modgui.app.transmission_webui="1"
    uci commit modgui
  }

  remove() {
    opkg remove --force-removal-of-dependent-packages transmission-daemon-openssl transmission-web
    [ ! -f /rom/usr/lib/libmbedcrypto.so.1 ] && opkg install libmbedtls #workaround for 19.x firmware
    rm -r /www/docroot/transmission
    rm -r /etc/config/transmission*
    rm -r /var/transmission
    rm /etc/hotplug.d/usb/60-transmission
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
    /usr/share/transformer/scripts/checkver DownloadInstalled telstra_gui.tar.bz2 /tmp/telstra_gui.tar.bz2 || return 1
    bzcat /tmp/telstra_gui.tar.bz2 | tar -C / -xf -
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
      rm /www/docroot/css/gw-telstra.css/gw-telstra.css
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
      opkg update
      [ ! -f /rom/usr/lib/libjson-c.so.2 ] && ln -s /usr/lib/libjson-c.so.4 /usr/lib/libjson-c.so.2 #workaround for 18.x feeds used on 19.x firmware
      rm -rf /etc/config/uhttpd
      rm /usr/lib/lua/uci.so #remove to avoid lua-uci conflict during install
      opkg install --force-reinstall libuci-lua luci rpcd
      [ ! -f /etc/init.d/uhttpd ] && opkg install uhttpd # only on 19.x is not getting installed as dependency?
      mkdir /www_luci
      mv /www/cgi-bin /www_luci/
      mv /www/luci-static /www_luci/
      mv /www/index.html /www_luci/
      cp /rom/usr/lib/lua/uci.so /usr/lib/lua/ #restore lib as it gets removed by libuci-lua
      sed -i 's/require "uci"/require "uci_luci"/g' /usr/lib/lua/luci/model/uci.lua #modify luci to load his original lib with different name

      if [ ! "$(uci get uhttpd.main.listen_http | grep 9080)" ]; then
        uci del_list uhttpd.main.listen_http='0.0.0.0:80'
        uci add_list uhttpd.main.listen_http='0.0.0.0:9080'
        uci del_list uhttpd.main.listen_http='[::]:80'
        uci add_list uhttpd.main.listen_http='[::]:9080'
        uci del_list uhttpd.main.listen_https='0.0.0.0:443'
        uci add_list uhttpd.main.listen_https='0.0.0.0:9443'
        uci del_list uhttpd.main.listen_https='[::]:443'
        uci add_list uhttpd.main.listen_https='[::]:9443'
        uci set uhttpd.main.home='/www_luci'
      fi

      uci commit uhttpd
      /etc/init.d/uhttpd restart
    }

    luci_install_mips() {
      curl -k -L https://raw.githubusercontent.com/nutterpc/tg-luci/master/install.sh --output /tmp/install.sh
      chmod +x /tmp/install.sh
      /tmp/install.sh
    }

    case $marketing_version in
    "16.1"* | "16.2"*)
      [ "$cpu_type" = "armv7l" ] && echo "Unknown app install script for $marketing_version $cpu_type"
      [ "$cpu_type" = "mips" ] && luci_install_mips
      ;;
    "16."* | "17."*)
      [ "$cpu_type" = "armv7l" ] && {
        luci_install_arm
        opkg install --force-reinstall --force-overwrite libuci-lua
        sed -i 's/require "uci_luci"/require "uci"/g' /usr/lib/lua/luci/model/uci.lua
      }
      [ "$cpu_type" = "mips" ] && luci_install_mips
      ;;
    "18."* | "19."*)
      [ "$cpu_type" = "armv7l" ] && luci_install_arm
      [ "$cpu_type" = "mips" ] && luci_install_mips
      ;;
    *)
      echo "Unknown app install script for $marketing_version $cpu_type"
      ;;
    esac
    uci set modgui.app.luci_webui="1"
    uci commit modgui
  }
  remove() {
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

    luci_remove_mips() {
      curl -k -L https://raw.githubusercontent.com/nutterpc/tg-luci/master/uninstall.sh --output /tmp/uninstall.sh
      chmod +x /tmp/uninstall.sh
      /tmp/uninstall.sh
    }

    [ "$cpu_type" = "armv7l" ] && luci_remove_arm
    [ "$cpu_type" = "mips" ] && luci_remove_mips
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
    [ "$cpu_type" = "armv7l" ] && echo "Unknown app install script for $marketing_version $cpu_type"
    [ "$cpu_type" = "mips" ] && install_from_github FrancYescO/sharing_tg789 amule
    uci set modgui.app.amule_webui="1"
    uci commit modgui
  }
  remove() {
    #TODO
    echo TODO
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
  *)
    remove
    return 1
    ;;
  esac
}

app_aria2() {
  install() {
    install_arm() {
      opkg update
      opkg install aria2 libstdcpp
      curl -sLk https://github.com/mayswind/AriaNg-DailyBuild/tarball/master --output /tmp/ariang.tar.gz
      tar -xzf /tmp/ariang.tar.gz -C /www/docroot/
      rm /tmp/ariang.tar.gz
      mv /www/docroot/*AriaNg* /www/docroot/aria

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
      aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=$ARIA2_DIR/aria2.conf
    }

    case $marketing_version in
    "16.1"* | "16.2"*)
      [ "$cpu_type" = "armv7l" ] && install_from_github FrancYescO/sharing_tg789 aria2-xtream
      [ "$cpu_type" = "mips" ] && install_from_github FrancYescO/sharing_tg789 aria2
      ;;
    "16."* | "17."* | "18."* | "19."*)
      [ "$cpu_type" = "armv7l" ] && install_arm
      [ "$cpu_type" = "mips" ] && install_from_github FrancYescO/sharing_tg789 aria2
      ;;
    *)
      echo "Unknown app install script for $marketing_version $cpu_type"
      ;;
    esac
    uci set modgui.app.aria2_webui="1"
    uci commit modgui
  }
  remove() {
    killall aria2c
    opkg remove aria2
    rm -r /www/docroot/aria
    rm -r /etc/aria2
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

app_voipblock_for_mmpbx() {
  install() {
    {
      curl -ks https://repository.macoers.com/voipblock/voipblock.sh | ash -s tch_install_for_mmpbx
    } && {
      uci set modgui.app.voipblock_for_mmpbx="1"
      uci commit modgui
    }
  }
  remove() {
    {
      curl -ks https://repository.macoers.com/voipblock/voipblock.sh | ash -s tch_uninstall_for_mmpbx
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
      curl -ks https://repository.macoers.com/voipblock/voipblock.sh | ash -s tch_install_for_asterisk
    } && {
      uci set modgui.app.blacklist_app="0"
      uci set modgui.app.voipblock_for_asterisk="1"
      uci commit modgui
    }
  }
  remove() {
    {
      curl -ks https://repository.macoers.com/voipblock/voipblock.sh | ash -s tch_uninstall_for_asterisk
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
    install_from_github Ansuel/blacklist master normal "$2"
    uci set modgui.app.blacklist_app="1"
    uci commit modgui
  }
  remove() {
    install_from_github Ansuel/blacklist master normal remove
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
    opkg update
    opkg install xupnpd
    uci set modgui.app.xupnp_app="1"
    uci commit modgui
  }
  remove() {
    opkg remove xupnpd
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

app_adblock() {
  adblock_owned="/etc/.modgui-adblock-installed"
  case "$1" in
  install)
    if ! opkg list-installed | grep -q '^adblock '; then
      touch "$adblock_owned"
    fi
    opkg update || return 1
    opkg install adblock || return 1
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

  wireguard_tun_supported() {
    [ -c /dev/net/tun ] && return 0
    [ -r /proc/config.gz ] && zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_TUN=y$'
  }

  case "$1" in
  install)
    if ! wireguard_tun_supported; then
      echo "WireGuard requires firmware built with CONFIG_TUN=y; this kernel does not support TUN"
      return 1
    fi
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
    if opkg list-installed | grep -q '^wireguard-go '; then
      set_extension_state wireguard_app 1
      return 0
    fi
    require_free_space 8192 /overlay || return 1
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
      return 1
    fi
    set_extension_state wireguard_app 1
    ;;
  remove)
    if uci show network 2>/dev/null | grep -q "\.proto='wireguard'"; then
      echo "Remove WireGuard network interfaces before uninstalling the runtime"
      return 1
    fi
    if [ -f "$wireguard_owned" ] && opkg list-installed | grep -q '^wireguard-go '; then
      opkg remove wireguard-go || return 1
    fi
    rm -f "$wireguard_owned" "$wireguard_tmp"
    if opkg list-installed | grep -q '^wireguard-go '; then
      set_extension_state wireguard_app 1
    else
      set_extension_state wireguard_app 0
    fi
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
    require_free_space 16384 /overlay || return 1
    opkg list-installed | awk '{print $1}' > "$l2tpipsec_before" || return 1
    opkg update || {
      rm -f "$l2tpipsec_before"
      return 1
    }
    opkg install xl2tpd strongswan-default || {
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
