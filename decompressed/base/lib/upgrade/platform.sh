#!/bin/sh

. /rom/lib/upgrade/platform.sh

overlay_dir=/modoverlay/bank_mod
booted_bank=$(cat /proc/banktable/booted)

base_file_dir=/tmp/rootfile/emergency
root_tmp_dir=/tmp/rootfile

homeware_conversion_tmp=/tmp/homeware_conversion_tmp
homeware_conversion_dir=/overlay/homeware_conversion

logging_file=/tmp/upgrade_logging

echo_log() {
        echo "$@"
        echo "$@" >> $logging_file
}

save_log_and_exit() {
        [ ! -d /overlay/modgui_log ] && mkdir /overlay/modgui_log
        cp $logging_file /overlay/modgui_log/firmware_upgrade_log_$(date +"%H-%M_%m-%d-%y")
        reboot
        exit 1
}

copy_base_files() { # <source> <dest>
        preserve_list="/etc/init.d/rootdevice /etc/rc.d/S94rootdevice /usr/sbin/random_seed /sbin/insmod /usr/sbin/mount_modoverlay \
                                  /sbin/mount_root-mod /lib/mount_modroot/05_transfer_basefiles /etc/init.d/do_migrate_overlay \
                                  /lib/upgrade/platform.sh /sbin/sysupgrade /usr/bin/sysupgrade-safe /usr/bin/rtfd"

        for f in $preserve_list; do
                if [ ! -f $f ]; then
                        echo_log "Can't preserve $f. Terminating upgrade!"
                        return 1
                fi
                mkdir -p $2$(dirname "$f")
                cp -a "$1$f" "$2$f"
        done
}

# Preserve file from /
preserve_root() {
        echo_log "Copying GUI package and emergency dir to RAM..."

        mkdir -p $root_tmp_dir $base_file_dir
        if [ -f /root/GUI.tar.bz2 ]; then
                cp /root/GUI.tar.bz2 $root_tmp_dir/
        else
                echo_log "Error in preserving GUI files."
        fi

        copy_base_files "" $base_file_dir

        return $?
}

preserve_config_file() {
        echo_log "Saving root password to modgui file..."
        uci set modgui.var.encrypted_pass="$(awk -F: '/root/ {print $2 }' /etc/shadow)"
        uci commit modgui

        echo_log "Copying config files to homeware_conversion_tmp dir in RAM..."
        mkdir -p $homeware_conversion_tmp
        cp -a $overlay_dir/etc $homeware_conversion_tmp/
        if [ -d $homeware_conversion_tmp/etc ]; then
                echo_log "Config files preserved!"
        else
                echo_log "Config file not copied to RAM!"
        fi
}

postpone_gui_install() {
        echo_log "GUI File found! Good Job!"

        if [ -f $root_tmp_dir/GUI.tar.bz2 ]; then
                echo_log "Restoring GUI.tar.bz2 to allow extraction on next boot"
                mkdir -p $overlay_dir/root
                cp $root_tmp_dir/GUI.tar.bz2 $overlay_dir/root/
                touch $overlay_dir/root/.install_gui            #will be useless if the extraction is not successfull (package missing)
        fi

        echo_log "Setting reapply_due_to_upgrade flag"
        touch $overlay_dir/root/.reapply_due_to_upgrade #needed for shadow password migration and extraction
}

restore_config_File() {
        if [ -d $homeware_conversion_tmp ]; then
                echo_log "Found config dir in RAM!"
                mkdir -p $homeware_conversion_dir

                cp -a $homeware_conversion_tmp/* $homeware_conversion_dir/

                mkdir -p $overlay_dir/etc
                cp -a $homeware_conversion_tmp/etc/config/modgui $overlay_dir/etc/modgui_old

                echo_log "Config files restored to homeware conversion dir! File will be updated on next boot."
        fi
}

restore_base_root() {
        echo_log "Rooting file not found! Using emergency method."
        mkdir -p $overlay_dir
        cp -a $base_file_dir/* $overlay_dir/
        echo_log "Device Rooted"
}



#we trick this function to simulate a singlebank device and upgrade to the same bank
platform_streaming_bank() {
        echo ""
}

platform_do_upgrade() {

        touch $logging_file

        # If /modoverlay is not mounted, use bank_2 overlay
        if ! mount | grep -q /modoverlay; then
                overlay_dir=/overlay/$booted_bank
        else
                # Update files in modroot
                /etc/init.d/do_migrate_overlay preserve_files
        fi

        preserve_root

        if [ $? -ne 0 ] || [ ! -f $base_file_dir/etc/init.d/rootdevice ]; then
                echo_log "Error in preserving root files."
                save_log_and_exit
        fi

        echo_log "Base Files preserved!"
        [ "$SAVE_CONFIG" != "0" ] && preserve_config_file

        # Reset overlay dir
        [ -d $overlay_dir ] && rm -r $overlay_dir/*

        # Make sure modoverlay is empty
        if [ "$(ls -A $overlay_dir)" ]; then
                restore_base_root
                echo_log "Running on dirty config... This could cause bootloop... Restoring file and restarting!"
                save_log_and_exit
        fi

        if [ "$ROOT_ONLY" != "1" ]; then
                check_dir=$overlay_dir/root/GUI.tar.bz2
                postpone_gui_install
        else
                check_dir=$overlay_dir/etc/init.d/rootdevice
                restore_base_root
        fi

        [ "$SAVE_CONFIG" != "0" ] && restore_config_File

        if platform_is_dualbank; then
                if [ -f $check_dir ]; then

                        if mount | grep -q /modoverlay; then
                                # As last step update base in original bank_2 overlay
                                echo_log "Update base file in original /overlay"
                                copy_base_files $base_file_dir /overlay/$booted_bank
                                      [ -f /proc/prozone/bootcounter ] && {
                                        # Simulate the bank_1 failed 3 times
                                        echo 1 > /proc/prozone/bootfail
                                        echo 2 > /proc/prozone/bootcounter
                                        echo 0 > /proc/prozone/bootbank
                                      }
                        fi

                        platform_do_upgrade_bank $1 $booted_bank || exit 1
                else
                        echo_log "Rooting file not present in new config! Aborting... "
                        restore_base_root
                        save_log_and_exit
                fi
        else
                # Not supported keep old code, no modem found with single bank with firmware based on openwrt
                platform_do_upgrade_bank $1 bank_1 || exit 1
                mkdir -p /overlay/homeware_conversion
        fi
}

#this function in firmwares >=19.x is moved to stage2 file, so redefine if not declared
if ! type 'kill_remaining' >/dev/null 2>/dev/null; then
  kill_remaining() { # [ <signal> [ <loop> ] ]
    local loop_limit=10

    local sig="${1:-TERM}"
    local loop="${2:-0}"
    local run=true
    local stat
    local proc_ppid=$(cut -d' ' -f4  /proc/$$/stat)

    echo -n "Sending $sig to remaining processes ... "

    while $run; do
      run=false
      for stat in /proc/[0-9]*/stat; do
        [ -f "$stat" ] || continue

        local pid name state ppid rest
        read pid name state ppid rest < $stat
        name="${name#(}"; name="${name%)}"

        # Skip PID1, our parent, ourself and our children
        [ $pid -ne 1 -a $pid -ne $proc_ppid -a $pid -ne $$ -a $ppid -ne $$ ] || continue

        local cmdline
        read cmdline < /proc/$pid/cmdline

        # Skip kernel threads
        [ -n "$cmdline" ] || continue

        # Skip wpa_supplicant
        [ $name != "wpa_supplicant" ] || continue
        [ $name != "wpa_supplicant_" ] || continue

        echo -n "$name "
        kill -$sig $pid 2>/dev/null

        [ $loop -eq 1 ] && run=true
      done

      let loop_limit--
      [ $loop_limit -eq 0 ] && {
        echo
        echo "Failed to kill all processes."
        exit 1
      }
    done
    echo
  }
fi

# New implementation (>19.x) use ubus that are not compatible with our script that use custom args
if ! type 'do_upgrade' >/dev/null 2>/dev/null; then
  do_upgrade() {
    v "Performing system upgrade..."
    if type 'platform_do_upgrade' >/dev/null 2>/dev/null; then
      platform_do_upgrade "$ARGV"
    else
      default_do_upgrade "$ARGV"
    fi

    if [ "$SAVE_CONFIG" -eq 1 ] && type 'platform_copy_config' >/dev/null 2>/dev/null; then
      platform_copy_config
    fi

    v "Upgrade completed"
    [ -n "$DELAY" ] && sleep "$DELAY"

    if ask_bool $REBOOT "Reboot"; then
      v "Rebooting system..."
      reboot -f
      sleep 5
      echo b 2>/dev/null >/proc/sysrq-trigger
    else
      v "No need reboot..."
    fi
  }
fi

#this is the same function of firmwares <19.x, in more recent versions they broken the single bank upgrade logic (changed ! -z to -n)
platform_check_image_imp() {
	rm -f /var/state/sysupgrade
	[ "$ARGC" -gt 1 ] && return 1

	rm -f $(get_cache_filename $1)

	BANK=$(platform_streaming_bank)
	if [ ! -z $BANK ]; then
		mtd erase $BANK
	else
		#single bank, no streaming
		stop_apps ${UPGRADE_MODE:-NO_GUI}
		if [ ${UPGRADE_SAFELY:-0} -eq 1 ]; then
			get_image "$1" >/dev/null
		fi
	fi

	MEMFREE=$(awk '/(MemFree|Buffers)/ {free+=$2} END {print free}' /proc/meminfo)
	if [ $MEMFREE -lt 4096 ]; then
	    # Having the kernel reclaim pagecache, dentries and inodes and check again
	    echo 3 >/proc/sys/vm/drop_caches
	    MEMFREE=$(awk '/(MemFree|Buffers)/ {free+=$2} END {print free}' /proc/meminfo)
	    if [ $MEMFREE -lt 4096 ]; then
		show_error 1 "Not enough memory available to proceed"
		return 1
	    fi
	fi

	# Prepare separate stream for signature check
	SIGCHECK_PIPE=$(mktemp)
	rm $SIGCHECK_PIPE
	mkfifo $SIGCHECK_PIPE
	add_temp_file $SIGCHECK_PIPE

	#create file for bli header info
	HDRINFO=$(mktemp)
	add_temp_file $HDRINFO

	#create pipe for writing to flash directly (or drop in case of single bank)
	MTDPIPE=$(mktemp)
	rm $MTDPIPE
	mkfifo -m 600 $MTDPIPE
	add_temp_file $MTDPIPE

	# Run signature check in background on second stream
	(signature_checker -b <$SIGCHECK_PIPE 2>/dev/null) &
	SIGCHECK_PID=$!

	#run mtd write
	if [ ! -z $BANK ]; then
		(mtd -n write - $BANK <$MTDPIPE) &
		MTD_PID=$!
	else
		(cat <$MTDPIPE >/dev/null) &
		MTD_PID=$!
	fi

	# start check/stream writing
	local CORRUPT=0
	UNSEAL_ERR=$(mktemp)
	rm -rf /tmp/getimageerr
	set -o pipefail
	RBIINFO=$( (get_image "$1" || (echo $? > /tmp/getimageerr && false))| tee $SIGCHECK_PIPE | (bli_parser > $HDRINFO && bli_unseal 2>$UNSEAL_ERR)|  tee $MTDPIPE | lua /lib/upgrade/rbi_vrss.lua)
	if [ $? -ne 0 ]; then
		E=$(head -1 $UNSEAL_ERR)
		if [ -n "$E" ]; then
			if [ $(echo $E | grep -c "platform") -ne 0 ]; then
				show_error 15 "Unseal error: $E"
			else
				show_error 9 "Unseal error: $E"
			fi
			return 1
		else
			# postpone reporting this error, it may be cause by a flash failure
			CORRUPT=1
		fi
	fi
	set +o pipefail
	rm -f $UNSEAL_ERR

	#obtain the results

	# Obtain signature result
	wait $SIGCHECK_PID
	SIGCHECK_RESULT=$?
	rm $SIGCHECK_PIPE

	#writing to flash
	wait $MTD_PID
	MTD_RESULT=$?
	rm $MTDPIPE

	if [ $MTD_RESULT -ne 0 ]; then
		show_error 16 "flash write failure"
		return 1
	fi

	if [ $CORRUPT -ne 0 ]; then
		# now report it, it was not a flash failure
		show_error 9 "File is corrupted"
		return 1
	fi

	platform_check_bliheader $HDRINFO
	E=$?
	rm $HDRINFO
	[ $E -ne 0 ] && return 1

	UNPACKEDSIZE=$(echo $RBIINFO | cut -d' ' -f1)
	VRSS=$(echo $RBIINFO | cut -d' ' -f2)
	if [ "$VRSS" = "-" ]; then
		show_error 14 "File is not a Homeware RBI"
		return 1
	fi

	if [ $SIGCHECK_RESULT -ne 0 ]; then
		if ! grep -q skip_signature_check /proc/efu/allowed; then
			show_error 10 "Signature check failed"
			return 1
		else
			v "Ignoring invalid signature"
		fi
	fi

	BANKSIZE=$((0x`cat /proc/mtd  | grep bank_1 | cut -d ' ' -f 2 `))
	if [ $UNPACKEDSIZE -ne $BANKSIZE ]; then
		show_error 11 "File does not match banksize"
		return 1
	fi

	return 0;
}

#this is the same function of firmwares <19.x, in more recent versions they broken the single bank upgrade logic (changed ! -z to -n)
platform_check_image() {
	platform_check_image_imp "$@"
	if [ $? -ne 0 ]; then
		local BANK=$(platform_streaming_bank)
		if [ ! -z $BANK ]; then
			mtd erase $BANK
		fi
		return 1
	fi
}
