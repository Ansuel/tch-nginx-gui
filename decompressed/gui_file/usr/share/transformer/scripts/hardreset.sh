#!/bin/sh
get_alive_processes(){
	if [[ $1 != "PID" && $1 != "NAME" ]]; then echo; exit; fi
	alive_processes=""
	for i in $(find /proc/[0-9]* -name exe -maxdepth 1); do
		name=$(readlink $i);
		if [[ ! -z $name ]]; then
			basename_process=$(basename $name)
			case $basename_process in
				busybox|rtfd|dropbear|boot|procd)
					# exclude some processes that might hang while killing
					;;
				*)
					if [[ $1 == "NAME" ]]; then
						alive_processes="$(basename $name) $alive_processes";
					fi
					if [[ $1 == "PID" ]]; then
						alive_processes="$(echo $i | sed 's|/proc/\([0-9]*\)/exe|\1|') $alive_processes";
					fi
					;;
			esac
		fi
	done
	echo $alive_processes
}

kill_running_processes() {
	# First stop watchdog to prevent a reboot while killing processes
	[ -f /etc/init.d/watchdog-tch ] && /etc/init.d/watchdog-tch stop
	# Gently remove the processes according to their start order
	for i in $(ls /etc/rc.d/S* | sort -r); do
		case $(basename $(readlink $i)) in
			boot|network|dropbear) # don't stop these processes
				echo "Don't stop $i"
				;;
			mm*|transformer) # Some processes need a bit of time to stop
				echo "Stopping $i ..."
				$i stop
				sleep 1
				;;
			*)
				echo "Stopping $i ..."
				$i stop
				;;
		esac
	done

#Stop mmpbx kindly if's not yet stopped and give it time of 30 sec max
	if [ -f /var/state/mmpbx ]; then
	   last_mmpbx_state=`cat /var/state/mmpbx | grep "mmpbx.state" | tail -1`;
		if [ $last_mmpbx_state != "mmpbx.state='NA'" ]; then

			#if stopping is on progress, then don't stop again, and let it continue to stop
			if [ $last_mmpbx_state != "mmpbx.state='STOPPING'" ]; then
			echo "mmpbx is in state $last_mmpbx_state => stop it";
			/etc/init.d/mmpbxd stop
			else
			echo "mmpbx is in state STOPPING, let it continue";
			fi

			timeout=30;
			wait_time=0;
			# wait maximum 30s for mmpbx to be completely stopped
			while [ $last_mmpbx_state != "mmpbx.state='NA'" ] && [ $wait_time -lt $timeout ]; do
			sleep 1;
			wait_time=`expr $wait_time + 1`;
			last_mmpbx_state=`cat /var/state/mmpbx | grep "mmpbx.state" | tail -1`; #last state is written in the last line of /var/state/mmpbx
			echo "$last_mmpbx_state , time is $wait_time seconds";
			done
		fi
	else
		echo "/var/state/mmpbx doesn't exist";
	fi

	echo "Processes stopped !"
	# Be a bit less gently to processes that would still be out there
	alive_processes_name=$(get_alive_processes NAME)
	for i in $alive_processes_name; do
		echo "killing $i..."
		killall $i
		sleep 1
	done
	# Now it is really time to shut down remaining processes...
	alive_processes_pid=$(get_alive_processes PID)
	if [[ -n "$alive_processes_pid" ]]; then
		echo "Still some processes alive, hard kill them ($alive_processes_pid)"
		kill -9 $alive_processes_pid
	fi
}

OVERLAY_TYPE=""
if ( mount | grep 'on /overlay type jffs2' >/dev/null ) ; then
	OVERLAY_TYPE="jffs2"
elif ( mount | grep 'ubi0:user on /overlay type ubifs' >/dev/null ) ; then
	OVERLAY_TYPE="ubifs"
else
	echo "Error: Unknown overlay type"
	echo
	exit 1
fi

if [ "$OVERLAY_TYPE" = "jffs2" ] ; then
	# enable fallback in case killing all processes hangs or the erase fails 
	touch /overlay/rtfd_all
fi

# kill processes to make sure no process is writting in the overlay
kill_running_processes

if [ "$OVERLAY_TYPE" = "jffs2" ] ; then

	echo "unmounting overlay..."
	# Unmount the overlay seems to be not working, instead set it as read only
	mount -type overlayfs -o ro,remount /
	# unmount the overlay lower filesystem
	umount /overlay

	# clean up partition and reboot
	if [ $(grep -c userfs /proc/mtd) -ne 0 ]; then
		# board started as legacy
		mtd -r erase userfs
	else
		mtd -r erase rootfs_data
        mtd -r erase data_vol   #Lantiq overlay partition
	fi

	echo "erase failed, use fallback mechanism"
	reboot
else
	rm -rf /overlay/* ; sync ; reboot
fi