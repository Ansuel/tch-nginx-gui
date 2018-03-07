RAMFS_COPY_BIN="/usr/bin/bli_parser /usr/bin/bli_unseal /usr/bin/bli_unseal_rsa /usr/bin/bli_unseal_rsa_helper /usr/bin/bli_unseal_aes128 /usr/bin/bli_unseal_aes128_helper /usr/bin/bli_unseal_sha1 /usr/bin/bli_unseal_sha1_helper /usr/bin/bli_unseal_sha256 /usr/bin/bli_unseal_aes256 /usr/bin/bli_unseal_aes256_helper /usr/bin/bli_unseal_zip /usr/bin/bli_unseal_zip_helper /usr/bin/bli_unseal_open /bin/busybox:/bin/sed:/usr/bin/tail:/usr/bin/cut:/bin/mkdir:/bin/mktemp:/bin/rm:/usr/bin/mkfifo:/usr/bin/sha256sum:/usr/bin/tee /usr/bin/curl `ls /etc/ssl/certs/*.0`"

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
	if [ "`cat /proc/rip/8003`" != "`bli_field "$INFO" varid`" ]; then
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
		sleep 1
		mount -o remount,rw /overlay
		sleep 1
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
ROOT_TMP_DIR=/tmp/root

root_device() {
	echo "GUI File found! Good Job!"
	ROOT_FILE=$ROOT_TMP_DIR/GUI.tar.bz2
	
	if [ "$SWITCHBANK" -eq 1 ]; then
		mkdir /overlay/$target_bank
		bzcat $ROOT_FILE | tar -C /overlay/$target_bank -xf -
		echo "Restoring GUI file in flash"
		mkdir -p /overlay/$target_bank/root/
		cp $ROOT_FILE /overlay/$target_bank/root/
	else
		mkdir /overlay/$running_bank
		bzcat $ROOT_FILE | tar -C /overlay/$running_bank -xf -
		echo "Restoring GUI file in flash"
		mkdir -p /overlay/$running_bank/root/
		cp $ROOT_FILE /overlay/$running_bank/root/
	fi
	echo "Device Rooted"
}

preserve_root() {
	echo "Copying root file to ram..."
	mkdir -p $ROOT_TMP_DIR/
	if [ -f /overlay/$running_bank/root/GUI.tar.bz2 ]; then
		cp /overlay/$running_bank/root/GUI.tar.bz2 $ROOT_TMP_DIR
	else
		mkdir -p $ROOT_TMP_DIR/etc/init.d/ $ROOT_TMP_DIR/etc/rc.d/ $ROOT_TMP_DIR/usr/bin/ $ROOT_TMP_DIR/lib/upgrade/ $ROOT_TMP_DIR/sbin/
		cp /overlay/$running_bank/lib/upgrade/platform.sh $ROOT_TMP_DIR/lib/upgrade/
		cp /overlay/$running_bank/sbin/sysupgrade $ROOT_TMP_DIR/sbin/
		cp /overlay/$running_bank/etc/init.d/rootdevice $ROOT_TMP_DIR/etc/init.d/
		cp /overlay/$running_bank/usr/bin/rtfd $ROOT_TMP_DIR/usr/bin/
		cp /overlay/$running_bank/usr/bin/sysupgrade-safe $ROOT_TMP_DIR/usr/bin/
		cp -d /overlay/$running_bank/etc/rc.d/S94rootdevice $ROOT_TMP_DIR/etc/rc.d/
	fi
	echo "Root file preserved!"
}

emergency_restore_root() {
	echo "Rooting file not found! Using emergency method."
	mkdir /overlay/bank_1 /overlay/bank_2
	cp -dr $ROOT_TMP_DIR/* /overlay/bank_1/
	cp -dr $ROOT_TMP_DIR/* /overlay/bank_2/
	echo "Device Rooted"
}

platform_do_upgrade() {
	mount_overlay_if_necessary
	if [ -f /$ROOT_TMP_DIR/GUI.tar.bz2 ] || [ -f /overlay/$(cat /proc/banktable/booted)/etc/init.d/rootdevice ]
	then
		preserve_root
		rm -r /overlay/*
		if [ -f /$ROOT_TMP_DIR/GUI.tar.bz2 ]
		then
			root_device
		else
			emergency_restore_root
		fi
		if [ ! -z $device ]; then
			umount $device
		fi
		if [ "$SWITCHBANK" -eq 1 ]; then
			echo $target_bank > /proc/banktable/active
		fi
		if platform_is_dualbank; then
			if [ "$SWITCHBANK" -eq 1 ]; then
				platform_do_upgrade_bank $1 $target_bank || exit 1
			else
				platform_do_upgrade_bank $1 $running_bank || exit 1
			fi
		else
			platform_do_upgrade_bank $1 bank_1 || exit 1
			mkdir -p /overlay/homeware_conversion
		fi
	else
		echo "Rooting file not present! Terminating upgrade process.."
		exit 0
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
