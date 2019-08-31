LOG_LOCATION=/tmp/command_log

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('$1','$2')"
	lua -e "$cmd"
}
#################################################

if [ -f $LOG_LOCATION ]; then
	echo "Wrapper: command_log file already exist, appending to the last execution (or concurrent) logging..."
fi

set_transformer "rpc.system.modgui.executeCommand.state" "Requested"

$1 2>$LOG_LOCATION >$LOG_LOCATION
sync

set_transformer "rpc.system.modgui.executeCommand.state" "Complete"

sleep 1

set_transformer "rpc.system.modgui.executeCommand.state" "Idle"
rm $LOG_LOCATION
