#!/bin/sh

. /rom/lib/upgrade/platform.sh

overlay_dir=/modoverlay
booted_bank=$(cat /proc/banktable/booted)

copy_base_files(){ # <source> <dest>
  preserve_list="/etc/init.d/rootdevice /etc/rc.d/S94rootdevice /usr/sbin/random_seed \
  				/sbin/mount_root-mod /lib/mount_modroot/05_transfer_basefiles \
  				/lib/upgrade/platform.sh /sbin/sysupgrade /usr/bin/sysupgrade-safe /usr/bin/rtfd"

  for f in $preserve_list; do
	mkdir -p $2$(dirname "$f")
	cp -a "$2$f" "$3$f"
  done
}

# Preserve file from /
preserve_root() {
	local root_tmp_dir=/tmp/rootfile
	local emergencydir=/tmp/rootfile/emergency
	echo "Copying GUI package and emergency dir to RAM..."
	mkdir /tmp/rootfile $emergencydir
	if [ -f /root/GUI.tar.bz2 ]; then
		cp /root/GUI.tar.bz2 $root_tmp_dir/
	fi

	preserve_files / $emergencydir

	if [ -f $emergencydir/etc/init.d/rootdevice ]; then
		echo "GUI files preserved!"
	else
		echo "GUI files not copied to RAM!"
	fi
}

preserve_config_file() {
	local config_tmp=/tmp/config_tmp
	echo "Copying config files to config_tmp dir in RAM..."
	mkdir /tmp/config_tmp /tmp/shadow_file
	cp -a $overlay_dir/etc/config/* $config_tmp/
	cp -a $overlay_dir/etc/shadow /tmp/shadow_file/
	if [ -f $config_tmp/network ]; then
		echo "Config files preserved!"
	else
		echo "Config file not copied to RAM!"
	fi
}

root_device() {
	echo "GUI File found! Good Job!"
	local gui_file=/tmp/rootfile/GUI.tar.bz2

	echo "Re-Extracting GUI files in /modoverlay"
	mkdir -p $overlay_dir/root
	if [ -f $gui_file ]; then
	  bzcat $gui_file | tar -C $overlay_dir -xf -
	  cp $gui_file $overlay_dir/root/
	fi

	echo "Setting reapply_due_to_upgrade flag"
	echo 1 > $overlay_dir/root/.reapply_due_to_upgrade
}

restore_config_File() {
	local config_tmp=/tmp/config_tmp

	if [ -d $config_tmp ]; then
		echo "Found config dir in RAM!"
		mkdir -p /overlay/homeware_conversion/etc/config

		cp $config_tmp/* /overlay/homeware_conversion/etc/config/
		cp $config_tmp/modgui /overlay/homeware_conversion/etc/modgui_old
		cp /tmp/shadow_file/shadow /overlay/homeware_conversion/etc/

		cp /tmp/shadow_file/shadow $overlay_dir/shadow_old

		echo "Config files restored to homeware conversion dir! File will be updated on next boot."
	fi
}

restore_base_root() {
	local emergencydir=/tmp/rootfile/emergency
	echo "Rooting file not found! Using emergency method."
	mkdir $overlay_dir
	cp -a $emergencydir/* $overlay_dir/
	echo "Device Rooted"
}

update_file_in_overlay() {
	local overlay_bank=/overlay/$booted_bank

	copy_base_files $overlay_dir $overlay_bank
}

platform_do_upgrade() {

	sleep 10
	mount_overlay_if_necessary

	local root_tmp_dirt=/tmp/rootfile

	local RESTORE_CONFIG=1

	if [ -n "$SAVE_CONFIG" ]; then
		if [ $SAVE_CONFIG -eq 0 ]; then
			RESTORE_CONFIG=0
		fi
	fi
	local INSTALL_GUI=1
	if [ -n "$ROOT_ONLY" ]; then
		if [ $ROOT_ONLY -eq 1 ]; then
			INSTALL_GUI=0
		fi
	fi

	# If /modoverlay is not mounted, use bank_2 overlay
	if ! mount | grep -q /modoverlay; then
		overlay_dir=/overlay/$booted_bank
	fi

	if [ -f $root_tmp_dirt/GUI.tar.bz2 ] || [ -f /etc/init.d/rootdevice ]; then

		preserve_root

		if [ $RESTORE_CONFIG -eq 1 ]; then
			preserve_config_file
		fi

		# Reset overlay dir
		if [ -d $overlay_dir ]; then
			rm -r $overlay_dir/*
		fi

		# Make sure modoverlay is empty
		if [ ! "$(ls -A $overlay_dir)" ]; then
			if [ -f $root_tmp_dirt/GUI.tar.bz2 ]; then
				root_device
			else
				restore_base_root
			fi

			if [ $RESTORE_CONFIG -eq 1 ]; then
				restore_config_File
			fi

			if platform_is_dualbank; then
				if [ -f $overlay_dir/init.d/rootdevice ]; then
					if [ $INSTALL_GUI -eq 1 ]; then
						echo 1 > $overlay_dir/root/.install_gui
					fi

					if [ -d /modoverlay ]; then
						# As last step update base in original bank_2 overlay
						update_file_in_overlay
					fi

					platform_do_upgrade_bank $1 $booted_bank || exit 1
				else
					echo "Rooting file not present in new config! Aborting... "
					restore_base_root
					reboot
				fi
			else
				# Not supported keep old code, no modem found with single bank with firmware based on openwrt
				platform_do_upgrade_bank $1 bank_1 || exit 1
				mkdir -p /overlay/homeware_conversion
			fi
		else
			restore_base_root
			echo "Running on dirty config... This could cause bootloop... Restoring file and restarting!"
			reboot
		fi
	else
		echo "Rooting file not present! Terminating upgrade process.."
		reboot
	fi
}
