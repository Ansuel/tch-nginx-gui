#!/bin/sh

. /rom/lib/upgrade/platform.sh

overlay_dir=/modoverlay
booted_bank=$(cat /proc/banktable/booted)

base_file_dir=/tmp/rootfile/emergency
root_tmp_dir=/tmp/rootfile

homeware_conversion_tmp=/tmp/homeware_conversion_tmp
homeware_conversion_dir=/overlay/homeware_conversion

platform_streaming_bank(){
	return
}

copy_base_files(){ # <source> <dest>
  preserve_list="/etc/init.d/rootdevice /etc/rc.d/S94rootdevice /usr/sbin/random_seed /usr/sbin/mount_modoverlay \
  				/sbin/mount_root-mod /lib/mount_modroot/05_transfer_basefiles \
  				/lib/upgrade/platform.sh /sbin/sysupgrade /usr/bin/sysupgrade-safe /usr/bin/rtfd"

  for f in $preserve_list; do
    mkdir -p $2$(dirname "$f")
    cp -a "$1$f" "$2$f"
  done
}

# Preserve file from /
preserve_root() {
	echo "Copying GUI package and emergency dir to RAM..."
	mkdir $root_tmp_dir $base_file_dir
	if [ -f /root/GUI.tar.bz2 ]; then
		cp /root/GUI.tar.bz2 $root_tmp_dir/
	fi

	copy_base_files "" $base_file_dir

	if [ -f $base_file_dir/etc/init.d/rootdevice ]; then
		echo "root files preserved!"
	else
		echo "root files NOT copied to RAM!"
	fi
}

preserve_config_file() {
  echo "Saving root password to modgui file..."
  uci set modgui.var.encrypted_pass="$(awk -F: '/root/ {print $2 }' /etc/shadow)"
  uci commit modgui

	echo "Copying config files to homeware_conversion_tmp dir in RAM..."
	mkdir -p $homeware_conversion_tmp
	cp -a $overlay_dir/etc $homeware_conversion_tmp/
	if [ -d $homeware_conversion_tmp/etc ]; then
		echo "Config files preserved!"
	else
		echo "Config file not copied to RAM!"
	fi
}

postpone_gui_install() {
	echo "GUI File found! Good Job!"
	local gui_file=/tmp/rootfile/GUI.tar.bz2

  if [ -f $root_tmp_dir/GUI.tar.bz2 ]; then
    echo "Restoring GUI.tar.bz2 to allow extraction on next boot"
    mkdir -p $overlay_dir/root
    if [ -f $gui_file ]; then
      cp $gui_file $overlay_dir/root/
    fi
  fi

  echo "Setting reapply_due_to_upgrade flag"
  touch $overlay_dir/root/.reapply_due_to_upgrade #needed for shadow password migration and extraction
  touch $overlay_dir/root/.install_gui #will be useless if the extraction is not successfull (package missing)
}

restore_config_File() {
	if [ -d $homeware_conversion_tmp ]; then
		echo "Found config dir in RAM!"
		mkdir -p $homeware_conversion_dir

		cp -a $homeware_conversion_tmp/* $homeware_conversion_dir/

		mkdir -p $overlay_dir/etc
		cp -a $homeware_conversion_tmp/etc/config/modgui $overlay_dir/etc/modgui_old

		echo "Config files restored to homeware conversion dir! File will be updated on next boot."
	fi
}

restore_base_root() {
	echo "Rooting file not found! Using emergency method."
	mkdir -p $overlay_dir
	cp -a $base_file_dir/* $overlay_dir/
	echo "Device Rooted"
}

platform_do_upgrade() {

	# If /modoverlay is not mounted, use bank_2 overlay
	if ! mount | grep -q /modoverlay; then
		overlay_dir=/overlay/$booted_bank
	fi

	if [ -f $root_tmp_dir/GUI.tar.bz2 ] || [ -f /etc/init.d/rootdevice ]; then

		preserve_root

		if [ "$SAVE_CONFIG" != "0" ]; then
			preserve_config_file
		fi

		# Reset overlay dir
		if [ -d $overlay_dir ]; then
			rm -r $overlay_dir/*
		fi

		# Make sure modoverlay is empty
		if [ ! "$(ls -A $overlay_dir)" ]; then
			if [ "$ROOT_ONLY" != "1" ]; then
				check_dir=$overlay_dir/root/GUI.tar.bz2
				postpone_gui_install
			else
				check_dir=$overlay_dir/etc/init.d/rootdevice
				restore_base_root
			fi

			if [ "$SAVE_CONFIG" != "0" ]; then
				restore_config_File
			fi

			if platform_is_dualbank; then
				if [ -f $check_dir ]; then

					if mount | grep -q /modoverlay; then
						# As last step update base in original bank_2 overlay
						echo "Update base file in original /overlay"
						copy_base_files $base_file_dir /overlay/$booted_bank
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
