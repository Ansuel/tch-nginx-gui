#!/bin/sh

. /etc/init.d/rootdevice

check_upgrade_shit() {
  logecho "Fixing sysupgrade if needed..."
	if [ -f /lib/upgrade/resetgui.sh ]; then
		rm /lib/upgrade/resetgui.sh
		rm /lib/upgrade/transfer_bank1.sh
		rm /lib/upgrade/upgradegui.sh
		rm /lib/upgrade/checkver.sh
		rm /lib/upgrade/hardreset.sh
	fi
}

restore_original_mapper() {
  logecho "Restoring and enabling few transformer mappers..."
	orig_dir=/rom/usr/share/transformer/mappings
	target=/usr/share/transformer/mappings

	if [ "$(md5sum $orig_dir/device2/Device.map | awk '{print $1}')" != "$(md5sum $target/device2/Device.map | awk '{print $1}')" ]; then
		mkdir /tmp/tmp_bff_file
		cp $target/bbf/VoiceService* /tmp/tmp_bff_file/
		rm -r $target/bbf/*
		rm -r $target/device2/*
		rm -r $target/clash/*
		rm -r $target/igd/*
		cp $orig_dir/bbf/* $target/bbf
		cp $orig_dir/clash/* $target/clash
		cp $orig_dir/device2/* $target/device2
		cp $orig_dir/igd/* $target/igd
		cp /tmp/tmp_bff_file/* $target/bbf
		rm -r /tmp/tmp_bff_file
		logecho "Restored device-specific transformer mapping files"
	fi
	if [ ! -f $target/bbf/VoiceService.VoiceProfile.Line.map ]; then
		cp $orig_dir/bbf/VoiceService.VoiceProfile.Line.map $orig_dir/bbf/
	elif [ "$(md5sum $orig_dir/bbf/VoiceService.VoiceProfile.Line.map | awk '{print $1}')" != "$(md5sum $target/bbf/VoiceService.VoiceProfile.Line.map | awk '{print $1}')" ]; then
		rm "$target/bbf/VoiceService.VoiceProfile.Line.map"
		cp "$orig_dir/bbf/VoiceService.VoiceProfile.Line.map" "$orig_dir/bbf/"
	fi #Solve some problems with cwmp AGTEF_1.0.3

	#Remove ignored Root device naming from transformer
	uci del_list transformer.@main[0].ignore_patterns='^Device%.'
	uci del_list transformer.@main[0].ignore_patterns='^InternetGatewayDevice%.'
}

transformer_lib_check() {
  logecho "Transformer lib check"
	orig_dir=/rom/usr
	target=/usr

	if [ "$(md5sum $orig_dir/lib/lua/transformer/commitapply.lua | awk '{print $1}')" != "$(md5sum $target/lib/lua/transformer/commitapply.lua | awk '{print $1}')" ]; then
		rm $target/share/transformer/mappings/rpc/*
		rm $target/share/transformer/mappings/uci/*
		rm -r $target/lib/lua/tch/*
		rm -r $target/lib/lua/transformer/*
		cp $orig_dir/share/transformer/mappings/rpc/* $target/share/transformer/mappings/rpc
		cp $orig_dir/share/transformer/mappings/uci/* $target/share/transformer/mappings/uci
		cp $orig_dir/bin/transformer $target/bin/
		cp -r $orig_dir/lib/lua/tch/* $target/lib/lua/tch
		cp -r $orig_dir/lib/lua/transformer/* $target/lib/lua/transformer
		gui_pos=""
		if [ -f /root/GUI.tar.bz2 ]; then
			gui_pos=/root/GUI.tar.bz2
		elif [ -f /root/GUI_dev.tar.bz2 ]; then
			gui_pos=/root/GUI_dev.tar.bz2
		elif [ -f /tmp/GUI.tar.bz2 ]; then
			gui_pos=/tmp/GUI.tar.bz2
		elif [ -f /tmp/GUI_dev.tar.bz2 ]; then
			gui_pos=/tmp/GUI_dev.tar.bz2
		fi
		logecho "Found gui here: "$gui_pos
		if [ $gui_pos != "" ] && [ -s $gui_pos ]; then
			bzcat $gui_pos | tar -C / -xf - usr #reapply the upgrade as in the gui we store some of this file that we restored
			logecho "Restoring transformer lib" #What is going on here? Doesn't even restart transformer???
		fi
		#/etc/init.d/transformer restart
	fi
}

check_wansensing() {
	#Make sure that wansensing is under the correct dir
	if [ -d /usr/lib/lua/wansensing ] && [ ! -d /usr/lib/lua/wansensingfw ] ; then
    logecho "Old build detected, moving wansensing file"
		rm /usr/lib/lua/wansensing/scripthelpers.lua
		mv /usr/lib/lua/wansensingfw/scripthelpers.lua /usr/lib/lua/wansensing/scripthelpers.lua
		rm -r /usr/lib/lua/wansensing
	fi
}

create_simbolic_utility() {
  logecho "Creating custom GUI utils symlinks..."
	if [ ! -h /usr/sbin/upgradegui ]; then
		upgrade_utility=/usr/share/transformer/scripts/upgradegui
		check_ver=/usr/share/transformer/scripts/checkver
		if [ -f $upgrade_utility ]; then
			ln -s $upgrade_utility /usr/sbin/upgradegui
			ln -s $check_ver /usr/sbin/checkver
		fi
	fi
}

update_checkver_upgrade_script() {
	if [ -f /usr/share/transformer/scripts/upgradegui.sh ]; then
	  logecho "Removing old update script"
		rm /usr/sbin/upgradegui
		rm /usr/sbin/checkver
		create_simbolic_utility
		rm /usr/share/transformer/scripts/upgradegui.sh
		rm /usr/share/transformer/scripts/checkver.sh
	fi
}

checkver_cron() {
  logecho "Add checkversion to cron..."
	if [ -f /usr/share/transformer/scripts/checkver ]; then
		if [ -f /etc/crontabs/root ]; then #remove from cron old checkver.sh script
			sed -i '/checkver.sh/d' /etc/crontabs/root
			if [ "$(ls -l /etc/crontabs/root | awk '{print $3}')" != "root" ]; then
				rm /etc/crontabs/root #THIS CHECK A VALID ROOT CRON... we remove it as it's useless if the owner is not root.
			fi
		fi
		if [ ! -f /etc/crontabs/root ] || ! grep -q "checkver" /etc/crontabs/root; then
			rand_h=$(awk -v min=1 -v max=6 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
			rand_m=$(awk -v min=1 -v max=59 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
			echo "$rand_m $rand_h * * * /usr/share/transformer/scripts/checkver >/dev/null 2>&1" >> /etc/crontabs/root
			/etc/init.d/cron restart
		fi
	fi
}

cron_christmas() {
	if [ ! -f /etc/crontabs/root ] || ! grep -q "christmas_tree" /etc/crontabs/root; then
		echo "*/30 * 24-26 12 * /etc/christmas_tree.sh &" >> /etc/crontabs/root
	fi
}

create_symlink() {
	if [ ! -f /etc/rc.d/S70wol ]; then
		/etc/init.d/wol enable
	fi
}

device_type="$(uci get -q env.var.prod_friendly_name)"

check_upgrade_shit #this if old script are present to fix sysupgrade
restore_original_mapper #this restore the original file autogenerated as they are specific to the build version.
[ -z "${device_type##*DGA413*}" ] && transformer_lib_check #another cleanup
[ -z "${device_type##*DGA413*}" ] && check_wansensing # Move wansensing file to old directory
create_simbolic_utility #This create symbolic link
update_checkver_upgrade_script #This clean old script
checkver_cron
cron_christmas #You guess...
create_symlink
