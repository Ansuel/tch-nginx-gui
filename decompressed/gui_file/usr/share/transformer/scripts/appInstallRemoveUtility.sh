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
      curl -sLk "https://raw.githubusercontent.com/$1/$2.tar.bz2" --output "/tmp/$2.tar.bz2"
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
    curl -k https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/modular/telstra_gui.tar.bz2 --output /tmp/telstra_gui.tar.bz2
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

install_specific_files() {

  install() {
    install_from_github Ansuel/gui-dev-build-auto/master/modular "upgrade-pack-specific$1" specificapp
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
