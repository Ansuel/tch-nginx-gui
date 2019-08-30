LOG_LOCATION=/tmp/command_log

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('$1','$2')"
	lua -e "$cmd"
}
#################################################

if [ -f $LOG_LOCATION ]; then
	rm $LOG_LOCATION
	touch $LOG_LOCATION
fi

set_transformer "rpc.system.modgui.executeCommand.state" "Requested"

$1 2>$LOG_LOCATION >$LOG_LOCATION

set_transformer "rpc.system.modgui.executeCommand.state" "Complete"

rm $LOG_LOCATION