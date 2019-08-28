LOG_LOCATION=/tmp/command_log

if [ -f $LOG_LOCATION ]; then
	rm $LOG_LOCATION
	touch $LOG_LOCATION
fi

$1 2>&1 | tee $LOG_LOCATION

rm $LOG_LOCATION