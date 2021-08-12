#!/bin/sh
. /lib/functions.sh

old_kill_remaining() { # [ <signal> [ <loop> ] ]
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

# Old Kill remaining implementation
if ! type 'kill_remaining' >/dev/null 2>/dev/null; then
	kill_remaining=old_kill_remaining
fi

old_do_upgrade() {
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

# New implementation use ubus that are not compatible with our script that use custom args
if ! type 'platform_do_upgrade' >/dev/null 2>/dev/null; then
	do_upgrade=old_do_upgrade
fi
