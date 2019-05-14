. /etc/init.d/rootdevice

move_env_var() {
	if [ ! -f /etc/config/modgui ]; then
		subpart="gui app var"

		gui_entities="autoupgrade randomcolor autoupgrade_hour firstpage gui_skin new_ver outdated_ver gui_version autoupgradeview gui_hash update_branch"
		app_entities="xupnp_app blacklist_app telstra_webui transmission_webui aria2_webui amule_webui luci_webui"
		var_entities="isp ppp_mgmt ppp_realm_ipv6 ppp_realm_ipv4 encrypted_pass driver_version bank_check"

		touch /etc/config/modgui

		for part in $subpart; do
			uci set modgui.$part=$part
			for value in $(eval 'echo $'"$part"_entities); do
				uci_val="$(uci get -q env.var.$value)"
				if [ -n "$uci_val" ]; then
					uci set modgui.$part.$value=$uci_val
					uci delete env.var.$value
				fi
			done
		done

		uci commit env
		uci commit modgui
	fi
}

check_gui_ver() {
	if [ "$(uci -q get modgui.gui.gui_version)" != $version_gui ]; then
		uci set modgui.gui.gui_version=$version_gui
	fi
}

create_symlink() {
	#Links the pached binaries to their correct paths
	if [ -f /bin/busybox_telnet ]; then
		ln -sf ../../bin/busybox_telnet /usr/sbin/telnetd
		/etc/init.d/telnet enable
	fi
	if [ ! -f /etc/rc.d/S70wol ]; then 
		/etc/init.d/wol enable
	fi
}

check_tmp_permission() {
	#Tmp MUST be always with permission 777
	#This is ram and is used by all process to write file so everyone should be able to write here
	#Or at leat is whay ngix needs to permit a stream between gui and the sysupgrade
	#The gui has a virtual tmp dir in it and this caused the overwrite of the permission.
	#On the gui zip che tmp dir is now with 777 permission but let's make sure this is actually applied.
	#drwxrwxrwx is how ls display 777 permission
	if [ "$(ls -ld /tmp | awk '{ print $1 }')" != "drwxrwxrwx" ]; then
		chmod 777 /tmp
	fi
}

reapply_gui_after_reset() {
	if [ -f /root/GUI.tar.bz2 ] && [ -s /root/GUI.tar.bz2 ]; then
		logger_command "Resetting /www dir due to firmware upgrade..."
		rm -r /www
		bzcat /root/GUI.tar.bz2 | tar -C / -xf - www
	elif [ -f /root/GUI.tar.gz ]; then
		logger_command "Resetting /www dir due to firmware upgrade..."
		rm -r /www
		tar -C / -zxf /root/GUI.tar.gz www
	fi
}

move_env_var #This moves every garbage created before 8.11.49 in env to modgui config file
check_gui_ver
create_symlink
check_tmp_permission

if [ -f /root/.reapply_due_to_upgrade ]; then
	reapply_gui_after_reset
fi