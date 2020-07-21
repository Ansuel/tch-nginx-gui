#!/bin/sh

device_type="$(uci get -q env.var.prod_friendly_name)"

#  1st arg : directory
#  2nd arg : pkg name
#  3rd arg : raw or normal. Raw is used to download specific file from specific dir
#  4th arg : addtional command to append to setup.sh (usefull if setup.sh contains also uninstall command)
install_from_github(){
  mkdir /tmp/$2

	if [ $3 == "specificapp" ]; then
		if [ ! -f /tmp/$2.tar.bz2 ]; then
          if ! ping -q -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
            echo "No internet connection detected, download manually!"
            exit 0
          fi
		  curl -sLk https://raw.githubusercontent.com/$1/$2.tar.bz2 --output /tmp/$2.tar.bz2
		fi
		if [ ! -f /tmp/$2.tar.bz2 ]; then
			echo "Error installing App: Cannot find/download  $2.tar.bz2"
			return 1
		fi
		bzcat /tmp/$2.tar.bz2 | tar -C /tmp/$2 -xf -
		rm /tmp/$2.tar.bz2
		cd /tmp/$2
	else
		if [ ! -f /tmp/$2.tar.gz ]; then
          if ! ping -q -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
            echo "No internet connection detected, download manually!"
            exit 0
          fi
		  curl -sLk https://github.com/$1/tarball/$2 --output /tmp/$2.tar.gz
		fi
		if [ ! -f /tmp/$2.tar.gz ]; then
			echo "Error installing App: Cannot find/download  $2.tar.gz"
			return 1
		fi
		tar -xzf /tmp/$2.tar.gz -C /tmp/$2
		rm /tmp/$2.tar.gz
		cd /tmp/$2/*
	fi

  chmod +x ./setup.sh
	./setup.sh  "$4"
	rm -r /tmp/$2
}

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('"$1"','"$2"')"
	lua -e "$cmd"
}
#################################################

app_transmission() {

	install_DGA() {
		opkg update
		opkg install transmission-web transmission-daemon-openssl

		uci set transmission.@transmission[0].enabled=1
		uci set transmission.@transmission[0].rpc_whitelist='127.0.0.1,192.168.*'
		uci commit

		cp -r /usr/share/transmission /www/docroot/
		rm /www/docroot/transmission/web/index.html /www/docroot/transmission/web/LICENSE

		/etc/init.d/transmission enable
		/etc/init.d/transmission restart
	}

	install() {
		[ "$(echo $device_type | grep DGA)" ] && install_DGA
		if [ -z "${device_type##*TG789*}" ] && [ -z "${device_type##*Xtream*}" ]; then
		  install_from_github FrancYescO/sharing_tg789 transmission-xtream
		elif [ "$(echo $device_type | grep TG7)" ]; then
		  install_from_github FrancYescO/sharing_tg789 transmission
		fi
		uci set modgui.app.transmission_webui="1"
		uci commit modgui
	}

	remove() {
		opkg remove --force-removal-of-dependent-packages transmission-daemon-openssl transmission-web
		rm -r /www/docroot/transmission
		rm -r /etc/config/transmission*
		rm -r /var/transmission
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
			install $2
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
			install $2
			;;
		remove)
			remove
			;;
		*)
			echo "Unsupported action"
			return 1
	esac
}

app_luci() {
	install() {
		luci_install_DGA() {
			opkg update
			mv /usr/lib/lua/uci.so /usr/lib/lua/uci.so_bak
			if [ -f /etc/config/uhttpd ]; then
				rm /etc/config/uhttpd
			fi
			opkg install --force-reinstall libuci-lua luci rpcd
			mkdir /www_luci
			mv /www/cgi-bin /www_luci/
			mv /www/luci-static /www_luci/
			mv /www/index.html /www_luci/
			rm /usr/lib/lua/uci.so
			mv /usr/lib/lua/uci.so_bak /usr/lib/lua/uci.so
			sed -i 's/require "uci"/require "uci_luci"/g' /usr/lib/lua/luci/model/uci.lua #modify luci to load his original lib with different name

			if [ ! $(uci get uhttpd.main.listen_http | grep 9080) ]; then
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

		luci_install_tg799() {
			curl -k -L https://raw.githubusercontent.com/nutterpc/tg-luci/master/install.sh --output /tmp/install.sh
			chmod +x /tmp/install.sh
			/tmp/install.sh
		}

		[ "$(echo $device_type | grep DGA)" ] && luci_install_DGA
		[ "$(echo $device_type | grep TG7)" ] && luci_install_tg799
		uci set modgui.app.luci_webui="1"
		uci commit modgui
	}
	remove() {
		luci_remove_DGA() {
			opkg remove --force-removal-of-dependent-packages uhttpd rpcd libuci-lua luci luci-*

			cp /rom/usr/lib/lua/uci.so  /usr/lib/lua/ #restore lib as it gets removed by libuci-lua

			rm -r /www_luci
			rm /etc/config/uhttpd
		}

		luci_remove_tg799() {
			curl -k -L https://raw.githubusercontent.com/nutterpc/tg-luci/master/uninstall.sh --output /tmp/uninstall.sh
			chmod +x /tmp/uninstall.sh
			/tmp/uninstall.sh
		}

		[ "$(echo $device_type | grep DGA)" ] && luci_remove_DGA
		[ "$(echo $device_type | grep TG7)" ] && luci_remove_tg799
		uci set modgui.app.luci_webui="0"
		uci commit modgui
	}

	case $1 in
		install)
			install $2
			;;
		remove)
			remove
			;;
		*)
			echo "Unsupported action"
			return 1
	esac
}

app_amule() {
	install() {
		install_DGA() {
			#TODO
			echo TODO
		}

		[ "$(echo $device_type | grep DGA)" ] && install_DGA
		[ "$(echo $device_type | grep TG7)" ] && install_from_github FrancYescO/sharing_tg789 amule
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
			install $2
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
	esac
}

app_aria2() {
	install() {
		install_DGA() {
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

			echo 'enable-rpc=true' >> $ARIA2_DIR/aria2.conf
			echo 'rpc-allow-origin-all=true' >> $ARIA2_DIR/aria2.conf
			echo 'rpc-listen-all=true' >> $ARIA2_DIR/aria2.conf
			echo 'rpc-listen-port=6800' >> $ARIA2_DIR/aria2.conf
			echo 'input-file=/etc/aria2/aria2.session' >> $ARIA2_DIR/aria2.conf
			echo 'save-session=/etc/aria2/aria2.session' >> $ARIA2_DIR/aria2.conf
			echo 'save-session-interval=300' >> $ARIA2_DIR/aria2.conf
			echo 'dir=/mnt/usb/USB-A1' >> $ARIA2_DIR/aria2.conf

			# add aria2 in /etc/rc.local to start the daemon after a reboot
			sed -i '/exit 0/i \
			aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=/etc/aria2/aria2.conf' /etc/rc.local

			# start the daemon
			aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=$ARIA2_DIR/aria2.conf
		}

		[ "$(echo $device_type | grep DGA)" ] && install_DGA
		if [ -z "${device_type##*TG789*}" ] && [ -z "${device_type##*Xtream*}" ]; then
		  install_from_github FrancYescO/sharing_tg789 aria2-xtream
		elif [ "$(echo $device_type | grep TG7)" ]; then
		  install_from_github FrancYescO/sharing_tg789 aria2
		fi
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
			install $2
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
	esac
}

app_blacklist() {
	install() {
		install_from_github Ansuel/blacklist master normal $2
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
			install $2
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
	esac
}

install_specific_files() {

	install() {
		install_from_github Ansuel/gui-dev-build-auto/master/modular upgrade-pack-specific$1 specificapp
	  uci set modgui.app.specific_app=1
	  uci commit
	}
	remove() {
		echo "Specific files cannot be removed. Reset the router instead."
		return 1
	}

	case $1 in
		install)
			install $2
			;;
		remove)
			remove
			;;
		*)
			echo "Unsupported action"
			return 1
	esac
}

call_app_type() {
	case "$2" in
	transmission)
		app_transmission $1
		;;
	telstra)
		app_telstra $1
		;;
	luci)
		app_luci $1
		;;
	amule)
		app_amule $1
		;;
	aria2)
		app_aria2 $1
		;;
	xupnp)
		app_xupnp $1
		;;
	blacklist)
		app_blacklist $1 $3
		;;
	specificapp)
		install_specific_files $1 $3
		;;
	*)
		echo "Provide a valid APP_NAME" 1>&2
	 	return 1
	esac
}


case "$1" in
  install|remove|stop|start|refresh)
    call_app_type "$1" "$2" "$3"
    ;;
	*)
		echo "usage: install|remove APP_NAME" 1>&2
		return 1
esac
