#!/bin/sh
#.Distributed under the terms of the GNU General Public License (GPL) version 2.0
#.2014-2017 Christian Schoenebeck <christian dot schoenebeck at gmail dot com>
. $(dirname $0)/dynamic_dns_functions.sh
usage() {
cat << EOF
Usage:
$MYPROG [options] -- command
Commands:
start                Start SECTION or NETWORK or all
stop                 Stop NETWORK or all
Parameters:
-n NETWORK          Start/Stop sections in background monitoring NETWORK, force VERBOSE=0
-S SECTION          SECTION to start
use either -N NETWORK or -S SECTION
-h                  show this help and exit
-V                  show version and exit
-v LEVEL            VERBOSE=LEVEL (default 1)
'0' NO output to console
'1' output to console
'2' output to console AND logfile
+ run once WITHOUT retry on error
'3' output to console AND logfile
+ run once WITHOUT retry on error
+ NOT sending update to DDNS service
EOF
}
usage_err() {
printf %s\\n "$MYPROG: $@" >&2
usage >&2
exit 1
}
while getopts ":hv:n:S:V" OPT; do
case "$OPT" in
h)	usage; exit 0;;
v)	VERBOSE=$OPTARG;;
n)	NETWORK=$OPTARG;;
S)	SECTION_ID=$OPTARG;;
V)	printf %s\\n "ddns-scripts $VERSION"; exit 0;;
:)	usage_err "option -$OPTARG missing argument";;
\?)	usage_err "invalid option -$OPTARG";;
*)	usage_err "unhandled option -$OPT $OPTARG";;
esac
done
shift $((OPTIND - 1 ))
[ -n "$NETWORK" -a -n "$SECTION_ID" ] && usage_err "use either option '-N' or '-S' not both"
[ $# -eq 0 ] && usage_err "missing command"
[ $# -gt 1 ] && usage_err "to much commands"
case "$1" in
start)
if [ -n "$NETWORK" ]; then
start_daemon_for_all_ddns_sections "$NETWORK"
exit 0
fi
if [ -z "$SECTION_ID" ]; then
start_daemon_for_all_ddns_sections
exit 0
fi
;;
stop)
if [ -n "$INTERFACE" ]; then
stop_daemon_for_all_ddns_sections "$NETWORK"
exit 0
else
stop_daemon_for_all_ddns_sections
exit 0
fi
exit 1
;;
reload)
killall -1 dynamic_dns_updater.sh 2>/dev/null
exit $?
;;
*)	usage_err "unknown command - $1";;
esac
PIDFILE="$ddns_rundir/$SECTION_ID.pid"
UPDFILE="$ddns_rundir/$SECTION_ID.update"
DATFILE="$ddns_rundir/$SECTION_ID.dat"
ERRFILE="$ddns_rundir/$SECTION_ID.err"
LOGFILE="$ddns_logdir/$SECTION_ID.log"
[ $VERBOSE -gt 1 -a -f $LOGFILE ] && rm -f $LOGFILE
trap "trap_handler 0 \$?" 0
trap "trap_handler 1"  1
trap "trap_handler 2"  2
trap "trap_handler 3"  3
trap "trap_handler 15" 15
################################################################################
################################################################################
load_all_config_options "ddns" "$SECTION_ID"
ERR_LAST=$?
[ -z "$enabled" ]	  && enabled=0
[ -z "$retry_count" ]	  && retry_count=0
[ -z "$use_syslog" ]      && use_syslog=2
[ -z "$use_https" ]       && use_https=0
[ -z "$use_logfile" ]     && use_logfile=1
[ -z "$use_ipv6" ]	  && use_ipv6=0
[ -z "$force_ipversion" ] && force_ipversion=0
[ -z "$force_dnstcp" ]	  && force_dnstcp=0
[ -z "$ip_source" ]	  && ip_source="network"
[ -z "$is_glue" ]	  && is_glue=0
[ "$ip_source" = "network" -a -z "$ip_network" -a $use_ipv6 -eq 0 ] && ip_network="wan"
[ "$ip_source" = "network" -a -z "$ip_network" -a $use_ipv6 -eq 1 ] && ip_network="wan6"
[ "$ip_source" = "web" -a -z "$ip_url" -a $use_ipv6 -eq 0 ] && ip_url="http://checkip.dyndns.com"
[ "$ip_source" = "web" -a -z "$ip_url" -a $use_ipv6 -eq 1 ] && ip_url="http://checkipv6.dyndns.com"
[ "$ip_source" = "interface" -a -z "$ip_interface" ] && ip_interface="eth1"
[ $ERR_LAST -ne 0 ] && {
[ $VERBOSE -le 1 ] && VERBOSE=2
[ -f $LOGFILE ] && rm -f $LOGFILE
write_log  7 "************ ************** ************** **************"
write_log  5 "PID '$$' started at $(eval $DATE_PROG)"
write_log  7 "ddns version  : $VERSION"
write_log  7 "uci configuration:\n$(uci -q show ddns | grep '=service' | sort)"
write_log 14 "Service section '$SECTION_ID' not defined"
}
write_log 7 "************ ************** ************** **************"
write_log 5 "PID '$$' started at $(eval $DATE_PROG)"
write_log 7 "ddns version  : $VERSION"
write_log 7 "uci configuration:\n$(uci -q show ddns.$SECTION_ID | sort)"
case $VERBOSE in
0) write_log  7 "verbose mode  : 0 - run normal, NO console output";;
1) write_log  7 "verbose mode  : 1 - run normal, console mode";;
2) write_log  7 "verbose mode  : 2 - run once, NO retry on error";;
3) write_log  7 "verbose mode  : 3 - run once, NO retry on error, NOT sending update";;
*) write_log 14 "error detecting VERBOSE '$VERBOSE'";;
esac
[ $enabled -eq 0 ] && write_log 14 "Service section disabled!"
[ -n "$service_name" ] && get_service_data update_url update_script UPD_ANSWER
[ -z "$update_url" -a -z "$update_script" ] && write_log 14 "No update_url found/defined or no update_script found/defined!"
[ -n "$update_script" -a ! -f "$update_script" ] && write_log 14 "Custom update_script not found!"
[ -z "$lookup_host" ] && {
uci -q set ddns.$SECTION_ID.lookup_host="$domain"
uci -q commit ddns
lookup_host="$domain"
}
[ -z "$lookup_host" ] && write_log 14 "Service section not configured correctly! Missing 'lookup_host'"
[ -n "$update_url" ] && {
[ -z "$domain" ] && $(echo "$update_url" | grep "\[DOMAIN\]" >/dev/null 2>&1) && \
write_log 14 "Service section not configured correctly! Missing 'domain'"
[ -z "$username" ] && $(echo "$update_url" | grep "\[USERNAME\]" >/dev/null 2>&1) && \
write_log 14 "Service section not configured correctly! Missing 'username'"
[ -z "$password" ] && $(echo "$update_url" | grep "\[PASSWORD\]" >/dev/null 2>&1) && \
write_log 14 "Service section not configured correctly! Missing 'password'"
[ -z "$param_enc" ] && $(echo "$update_url" | grep "\[PARAMENC\]" >/dev/null 2>&1) && \
write_log 14 "Service section not configured correctly! Missing 'param_enc'"
[ -z "$param_opt" ] && $(echo "$update_url" | grep "\[PARAMOPT\]" >/dev/null 2>&1) && \
write_log 14 "Service section not configured correctly! Missing 'param_opt'"
}
[ -n "$username" ] && urlencode URL_USER "$username"
[ -n "$password" ] && urlencode URL_PASS "$password"
[ -n "$param_enc" ] && urlencode URL_PENC "$param_enc"
if [ "$ip_source" = "script" ]; then
set -- $ip_script	#handling script with parameters, we need a trick
[ -z "$1" ] && write_log 14 "No script defined to detect local IP!"
[ -x "$1" ] || write_log 14 "Script to detect local IP not executable!"
fi
get_seconds CHECK_SECONDS ${check_interval:-10} ${check_unit:-"minutes"}
get_seconds FORCE_SECONDS ${force_interval:-72} ${force_unit:-"hours"}
get_seconds RETRY_SECONDS ${retry_interval:-60} ${retry_unit:-"seconds"}
[ $CHECK_SECONDS -lt 300 ] && CHECK_SECONDS=300
[ $FORCE_SECONDS -gt 0 -a $FORCE_SECONDS -lt $CHECK_SECONDS ] && FORCE_SECONDS=$CHECK_SECONDS
write_log 7 "check interval: $CHECK_SECONDS seconds"
write_log 7 "force interval: $FORCE_SECONDS seconds"
write_log 7 "retry interval: $RETRY_SECONDS seconds"
write_log 7 "retry counter : $retry_count times"
stop_section_processes "$SECTION_ID"
[ $? -gt 0 ] && write_log 7 "'SIGTERM' was send to old process" || write_log 7 "No old process"
echo $$ > $PIDFILE
get_uptime CURR_TIME
[ -e "$UPDFILE" ] && {
LAST_TIME=$(cat $UPDFILE)
[ -z "$LAST_TIME" ] && LAST_TIME=0
[ $LAST_TIME -gt $CURR_TIME ] && LAST_TIME=0
}
if [ $LAST_TIME -eq 0 ]; then
write_log 7 "last update: never"
else
EPOCH_TIME=$(( $(date +%s) - $CURR_TIME + $LAST_TIME ))
EPOCH_TIME="date -d @$EPOCH_TIME +'$ddns_dateformat'"
write_log 7 "last update: $(eval $EPOCH_TIME)"
fi
[ -n "$dns_server" ] && verify_dns "$dns_server"
[ -n "$proxy" ] && {
verify_proxy "$proxy" && {
export HTTP_PROXY="http://$proxy"
export HTTPS_PROXY="http://$proxy"
export http_proxy="http://$proxy"
export https_proxy="http://$proxy"
}
}
get_registered_ip REGISTERED_IP "NO_RETRY"
ERR_LAST=$?
[ $ERR_LAST -eq 0 -o $ERR_LAST -eq 127 ] || get_registered_ip REGISTERED_IP
[ $use_ipv6 -eq 1 ] && expand_ipv6 "$REGISTERED_IP" REGISTERED_IP
write_log 6 "Starting main loop at $(eval $DATE_PROG)"
while : ; do
get_local_ip LOCAL_IP
[ $use_ipv6 -eq 1 ] && expand_ipv6 "$LOCAL_IP" LOCAL_IP
[ $FORCE_SECONDS -eq 0 -o $LAST_TIME -eq 0 ] \
&& NEXT_TIME=0 \
|| NEXT_TIME=$(( $LAST_TIME + $FORCE_SECONDS ))
get_uptime CURR_TIME
if [ $CURR_TIME -ge $NEXT_TIME -o "$LOCAL_IP" != "$REGISTERED_IP" ]; then
if [ $VERBOSE -gt 2 ]; then
write_log 7 "Verbose Mode: $VERBOSE - NO UPDATE send"
elif [ "$LOCAL_IP" != "$REGISTERED_IP" ]; then
write_log 7 "Update needed - L: '$LOCAL_IP' <> R: '$REGISTERED_IP'"
else
write_log 7 "Forced Update - L: '$LOCAL_IP' == R: '$REGISTERED_IP'"
fi
ERR_LAST=0
[ $VERBOSE -lt 3 ] && {
send_update "$LOCAL_IP"
ERR_LAST=$?
}
if [ $ERR_LAST -eq 0 ]; then
get_uptime LAST_TIME
echo $LAST_TIME > $UPDFILE
[ "$LOCAL_IP" != "$REGISTERED_IP" ] \
&& write_log 6 "Update successful - IP '$LOCAL_IP' send" \
|| write_log 6 "Forced update successful - IP: '$LOCAL_IP' send"
elif [ $ERR_LAST -eq 127 ]; then
write_log 3 "No update send to DDNS Provider"
else
write_log 3 "IP update not accepted by DDNS Provider"
fi
fi
[ $VERBOSE -le 2 ] && {
write_log 7 "Waiting $CHECK_SECONDS seconds (Check Interval)"
sleep $CHECK_SECONDS &
PID_SLEEP=$!
wait $PID_SLEEP
PID_SLEEP=0
} || write_log 7 "Verbose Mode: $VERBOSE - NO Check Interval waiting"
REGISTERED_IP=""
get_registered_ip REGISTERED_IP
[ $use_ipv6 -eq 1 ] && expand_ipv6 "$REGISTERED_IP" REGISTERED_IP
if [ "$LOCAL_IP" != "$REGISTERED_IP" ]; then
if [ $VERBOSE -le 1 ]; then
ERR_UPDATE=$(( $ERR_UPDATE + 1 ))
[ $retry_count -gt 0 -a $ERR_UPDATE -gt $retry_count ] && \
write_log 14 "Updating IP at DDNS provider failed after $retry_count retries"
write_log 4 "Updating IP at DDNS provider failed - starting retry $ERR_UPDATE/$retry_count"
continue
else
write_log 4 "Updating IP at DDNS provider failed"
write_log 7 "Verbose Mode: $VERBOSE - NO retry"; exit 1
fi
else
ERR_UPDATE=0
fi
[ $VERBOSE -gt 1 ]  && write_log 7 "Verbose Mode: $VERBOSE - NO reloop"
[ $FORCE_SECONDS -eq 0 ] && write_log 6 "Configured to run once"
[ $VERBOSE -gt 1 -o $FORCE_SECONDS -eq 0 ] && exit 0
write_log 6 "Rerun IP check at $(eval $DATE_PROG)"
done
write_log 12 "Error in 'dynamic_dns_updater.sh - program coding error"
