RAMFS_COPY_BIN=" /usr/bin/bli_parser /usr/bin/bli_unseal /usr/bin/bli_unseal_rsa /usr/bin/bli_unseal_rsa_helper /usr/bin/bli_unseal_aes128 /usr/bin/bli_unseal_aes128_helper /usr/bin/bli_unseal_sha1 /usr/bin/bli_unseal_sha1_helper /usr/bin/bli_unseal_sha256 /usr/bin/bli_unseal_aes256 /usr/bin/bli_unseal_aes256_helper /usr/bin/bli_unseal_zip /usr/bin/bli_unseal_zip_helper /usr/bin/bli_unseal_open /bin/busybox:/bin/sed:/bin/tar:/usr/bin/bzcat:/usr/bin/tail:/usr/bin/cut:/bin/mkdir:/bin/mktemp:/bin/rm:/bin/cp:/usr/bin/mkfifo:/usr/bin/sha256sum:/usr/bin/tee /usr/bin/curl `ls /etc/ssl/certs/*.0`"

TEMP_FILES_TO_CLEANUP=
cleanup_temp_files() {
	for f in $TEMP_FILES_TO_CLEANUP; do
		rm -f $f
	done
}

trap "cleanup_temp_files" EXIT

add_temp_file() {
	TEMP_FILES_TO_CLEANUP="$TEMP_FILES_TO_CLEANUP $1"
}

platform_is_dualbank() {
	grep bank_2 /proc/mtd >/dev/null
	return $?
}

platform_streaming_bank() {
	if platform_is_dualbank; then
		if [ "$SWITCHBANK" -eq 1 ]; then
			cat /proc/banktable/notbooted
		else
			cat /proc/banktable/booted
		fi
	fi
}

get_filetype() {
lua - $1 <<EOF
lfs = require "lfs"
print(lfs.attributes(arg[1], "mode") or "none")
EOF
}

get_cache_filename() {
	echo "/tmp/$(echo $1 | md5sum | cut -d' ' -f1)"
}

get_image() { # <source> [ <command> ]
	local from="$1"
	local conc="$2"
	local cmd
	local pipe
	local rv

	echo "get_image $1" >/dev/console

	local filetype="none"

	case "$from" in
		ftp://*) cmd="wget -O- -q -T 300";;
		http://*) cmd="curl --connect-timeout 300 -m 1800 -S -s --anyauth";;
		https://*) cmd="curl --connect-timeout 300 -S -s --capath /etc/ssl/certs";;
		tftp://*) cmd="curl --connect-timeout 300 -m 1800 -S -s";;
		*)
			cmd="cat"
			filetype=$(get_filetype $from)
		;;
	esac

	if [ ${UPGRADE_SAFELY:-0} -eq 1 ]; then
		# make sure the upgrade happens streaming or is done
		# from a locally downloaded file
			#no streaming possible
			if [ "$filetype" != "file" ]; then
				local CACHED_STREAM_FILE=$(get_cache_filename $1)
				if [ ! -f $CACHED_STREAM_FILE ]; then
					# retrieve first for later reuse
					eval "$cmd \$from >$CACHED_STREAM_FILE"
					add_temp_file $CACHED_STREAM_FILE
				fi
				from=$CACHED_STREAM_FILE
			fi
			cmd="cat"
	fi
	eval "$cmd \$from ${conc:+| $conc}"
	rv=$?
	ubus send fwupgrade '{ "state": "flashing" }'
	return $rv
}


bli_field() {
	INPUT="$1"
	FIELD="$2"
	grep $FIELD $INPUT | sed 's/.*: //'
}

show_error() {
	ERRC=$1
	MSG="$2"
	logger -p daemon.crit -t "sysupgrade[$$]" "Sysupgrade failed: $MSG"
	v "sysupgrade error $ERRC: $MSG"
	echo ${ERRC} >/var/state/sysupgrade
	echo ${MSG} >/var/state/sysupgrade-msg
}

platform_check_bliheader() {
	local INFO="$1"

	# Only allow a BLI format
	if [ "BLI2" != "`bli_field "$INFO" magic_value`" ]; then
		show_error 3 "Incorrect magic"
		return 1
	fi

	# FIA must match the RIP
	if [ "`cat /proc/rip/0028`" != "`bli_field "$INFO" fia`" ]; then
		show_error 4 "Incorrect FIA"
		return 1
	fi

	# FIM must be 23
	if [ "23" != "`bli_field "$INFO" fim`" ]; then
		show_error 5 "Incorrect FIM"
		return 1
	fi

	# Boardname must match the RIP
	if [ "`cat /proc/rip/0040`" != "`bli_field "$INFO" boardname`" ]; then
		show_error 6 "Incorrect Boardname"
		return 1
	fi

	# Product ID must match the RIP, unless it is the generic one (="0")
	if [ "`cat /proc/rip/8001`" != "0" ] && [ "`cat /proc/rip/8001`" != "`bli_field "$INFO" prodid`" ]; then
		show_error 7 "Incorrect Product ID"
		return 1
	fi

	# Variant ID must match exactly the RIP settings
	if [ "`cat /proc/rip/8003`" != "`bli_field "$INFO" varid`"  ]; then
		show_error 8 "Incorrect Variant ID"
		return 1
	fi
}

# Actual implementation of the image check.
# Note that on dual bank platforms the inactive bank will be written to.
# (to avoid storing it in RAM and avoid out of memory conditions)
platform_check_image_imp() {
	rm -f /var/state/sysupgrade
	[ "$ARGC" -gt 1 ] && return 1

	rm -f $(get_cache_filename $1)

	#single bank, no streaming
	stop_apps ${UPGRADE_MODE:-NO_GUI}
	if [ ${UPGRADE_SAFELY:-0} -eq 1 ]; then
		get_image "$1" >/dev/null
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
		if [ ${IGNORE_SIGNATURE:-0} -eq 0 ]; then
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

mount_overlay_if_necessary() {
	if ! ( mount | grep '/dev/mtdblock[0-9] on /overlay type jffs2' >/dev/null ) ; then
		# Running from RAM fs, the jffs2 isn't mounted...
		mkdir -p /overlay
		device=/dev/mtdblock$(grep -E "(rootfs_data|userfs)" /proc/mtd | sed 's/mtd\([0-9]\):.*\(rootfs_data\|userfs\).*/\1/')
		mount $device /overlay -t jffs2
		sleep 10
		mount -o remount,rw /overlay
		sleep 10
	fi
}

platform_check_image() {
	platform_check_image_imp "$@"
	if [ $? -ne 0 ]; then
		return 1
	fi
}

target_bank=$(cat /proc/banktable/notbooted)
running_bank=$(cat /proc/banktable/booted)

root_device() {
	echo "GUI File found! Good Job!"
	local root_tmp_dirt=/tmp/rootfile
	local gui_file=$root_tmp_dirt/GUI.tar.bz2
	local gz_gui_file=$root_tmp_dirt/GUI.tar.gz
	
	if [ "$SWITCHBANK" -eq 1 ]; then
		mkdir /overlay/$target_bank
		if [ -f $gui_file ]; then
			bzcat $gui_file | tar -C /overlay/$target_bank -xf -
		else
			tar -C /overlay/$target_bank -zxf $gz_gui_file
		fi
		echo "Restoring GUI file in flash"
		mkdir -p /overlay/$target_bank/root
		cp $gui_file /overlay/$target_bank/root/
		echo 1 > /overlay/$target_bank/root/.reapply_due_to_upgrade
	else
		mkdir /overlay/$running_bank
		if [ -f $gui_file ]; then
			bzcat $gui_file | tar -C /overlay/$running_bank -xf -
		else
			tar -C /overlay/$running_bank -zxf $gz_gui_file
		fi
		echo "Restoring GUI file in flash"
		mkdir -p /overlay/$running_bank/root
		cp $gui_file /overlay/$running_bank/root/
		echo 1 > /overlay/$running_bank/root/.reapply_due_to_upgrade
	fi
	echo "Device Rooted"
}

restore_config_File() {
	local config_tmp=/tmp/config_tmp
	if [ -d $config_tmp ]; then
		echo "Found Config file in ram!"
		if [ ! -d /overlay/homeware_conversion ]; then
			mkdir /overlay/homeware_conversion
			mkdir /overlay/homeware_conversion/etc
			mkdir /overlay/homeware_conversion/etc/config
		fi
		cp $config_tmp/* /overlay/homeware_conversion/etc/config/
		cp /tmp/shadow_file/shadow /overlay/homeware_conversion/etc/
		if [ "$SWITCHBANK" -eq 1 ]; then
			cp /tmp/shadow_file/shadow /overlay/$target_bank/shadow_old
		else
			cp /tmp/shadow_file/shadow /overlay/$running_bank/shadow_old
		fi
		echo "Config file restored to homeware conversion dir! File will be updated on next boot."
	fi
}

preserve_root() {
	local root_tmp_dirt=/tmp/rootfile
	local emergencydir=/tmp/rootfile/emergency
	echo "Copying root file to ram..."
	mkdir /tmp/rootfile
	mkdir $emergencydir
	if [ -f /overlay/$running_bank/root/GUI.tar.bz2 ]; then
		cp /overlay/$running_bank/root/GUI.tar.bz2 $root_tmp_dirt/
	fi
	if [ -f /overlay/$running_bank/root/GUI.tar.gz ]; then
		cp /overlay/$running_bank/root/GUI.tar.gz $root_tmp_dirt/
	fi
	mkdir $emergencydir/etc
	mkdir $emergencydir/etc/init.d 
	mkdir $emergencydir/etc/rc.d 
	mkdir $emergencydir/usr
	mkdir $emergencydir/usr/bin 
	mkdir $emergencydir/lib
	mkdir $emergencydir/lib/upgrade 
	mkdir $emergencydir/sbin
	cp /overlay/$running_bank/lib/upgrade/platform.sh $emergencydir/lib/upgrade/
	cp /overlay/$running_bank/sbin/sysupgrade $emergencydir/sbin/
	cp /overlay/$running_bank/etc/init.d/rootdevice $emergencydir/etc/init.d/
	cp /overlay/$running_bank/usr/bin/rtfd $emergencydir/usr/bin/
	cp /overlay/$running_bank/usr/bin/sysupgrade-safe $emergencydir/usr/bin/
	cp -d /overlay/$running_bank/etc/rc.d/S94rootdevice $emergencydir/etc/rc.d/
	if [ -f $emergencydir/etc/init.d/rootdevice ]; then
		echo "Root file preserved!"
	else
		echo "Root file not copied to ram!"
	fi
}

preserve_config_file() {
	local config_tmp=/tmp/config_tmp
	echo "Copying config file to ram..."
	mkdir /tmp/config_tmp
	mkdir /tmp/shadow_file
	cp /overlay/$running_bank/etc/config/* $config_tmp/
	cp /overlay/$running_bank/etc/shadow /tmp/shadow_file
	if [ -f $config_tmp/network ]; then
		echo "Config file preserved!"
	else
		echo "Config file not copied to ram!"
	fi
}

emergency_restore_root() {
	local emergencydir=/tmp/rootfile/emergency
	echo "Rooting file not found! Using emergency method."
	mkdir /overlay/bank_1 
	mkdir /overlay/bank_2
	cp -dr $emergencydir/* /overlay/bank_1/
	cp -dr $emergencydir/* /overlay/bank_2/
	echo "Device Rooted"
}

platform_do_upgrade() {
	sleep 10
	mount_overlay_if_necessary
	
	local root_tmp_dirt=/tmp/rootfile
	
	local RESTORE_CONFIG=1
	
	if [ -n $SAVE_CONFIG ]; then
		if [ $SAVE_CONFIG -eq 0 ]; then
			RESTORE_CONFIG=0
		fi
	fi
	
	if [ -f $root_tmp_dirt/GUI.tar.bz2 ] || [ -f /overlay/$(cat /proc/banktable/booted)/etc/init.d/rootdevice ]; then
		
		preserve_root
		
		if [ $RESTORE_CONFIG -eq 1 ]; then
			preserve_config_file
		fi
		
		rm -r /overlay/bank_1
		if [ -d /overlay/bank_2 ]; then
			rm -r /overlay/bank_2
		fi
		
		if [ ! -d /overlay/bank_1 ] && [ ! -d /overlay/bank_2 ]; then
			if [ -f $root_tmp_dirt/GUI.tar.bz2 ] || [ -f $root_tmp_dirt/GUI.tar.gz ]; then
				root_device
			else
				emergency_restore_root
			fi
			
			if [ $RESTORE_CONFIG -eq 1 ]; then
				restore_config_File
			fi
			
			if [ "$SWITCHBANK" -eq 1 ]; then
				echo $target_bank > /proc/banktable/active
			fi
			if platform_is_dualbank; then
				if [ "$SWITCHBANK" -eq 1 ] && [ -f /overlay/$target_bank/etc/init.d/rootdevice ]; then
					if [ ! -z $device ]; then
						umount $device
					fi
					platform_do_upgrade_bank $1 $target_bank || exit 1
				elif [ -f /overlay/$running_bank/etc/init.d/rootdevice ]; then
					if [ ! -z $device ]; then
						umount $device
					fi
					platform_do_upgrade_bank $1 $running_bank || exit 1
				else
					echo "Rooting file not present in new config! Aborting... "
					emergency_restore_root
					reboot
				fi
			else
				platform_do_upgrade_bank $1 bank_1 || exit 1
				mkdir -p /overlay/homeware_conversion
			fi
		else
			emergency_restore_root
			echo "Running on dirty config... This could cause bootloop... Restoring file and restarting!"
			reboot
		fi
	else
		echo "Rooting file not present! Terminating upgrade process.."
		reboot
	fi
}

platform_do_upgrade_bank() {
	BANK="$2"

	if [ "$BANK" != "bank_1" ]; then
		if [ "$BANK" != "bank_2" ]; then
			show_error 12 "Only upgrading bank_1 or bank_2 is allowed"
			return 1;
		fi
	fi

	MTD=/dev/`cat /proc/mtd  | grep \"$BANK\" | sed 's/:.*//'`

	if [ -z $MTD ]; then
		show_error 13 "Could not find bank $BANK in /proc/mtd"
		return 1;
	fi

		v "Programming..."
		(get_image "$1" | ((bli_parser > /dev/null ) && bli_unseal) | mtd write - $2 ) || {
			show_error 16 "Flash write failure"
			return 1;
		}

	v "Clearing FVP of $MTD..."
	dd bs=4 count=1 if=/dev/zero of=$MTD 2>/dev/null || {
		show_error 16 "Flash failure while clearing FVP"
		return 1;
	}

	v "Firmware upgrade done"
}
