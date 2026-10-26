#!/bin/sh

LOG_LOCATION=/tmp/command_log

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('$1','$2')"
	lua -e "$cmd"
}
#################################################

finish() {
	status=$?
	trap - EXIT HUP INT TERM
	if [ "$status" -ne 0 ]; then
		printf '\nCommand failed (exit status %s).\n' "$status" >> "$LOG_LOCATION"
		set_transformer "rpc.system.modgui.executeCommand.state" "Error"
	else
		set_transformer "rpc.system.modgui.executeCommand.state" "Complete"
	fi
	exit "$status"
}

trap finish EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP

set_transformer "rpc.system.modgui.executeCommand.state" "In Progress"

# Use one file descriptor so stderr cannot overwrite stdout. Keep the final
# state and log until the next command: polling may miss a one-second window.
$1 >"$LOG_LOCATION" 2>&1
exit $?
