#!/bin/sh
#.Distributed under the terms of the GNU General Public License (GPL) version 2.0
#.2014-2017 Christian Schoenebeck <christian dot schoenebeck at gmail dot com>
. /lib/functions.sh
. /lib/functions/network.sh
VERSION="2.7.6-11"
SECTION_ID=""
VERBOSE=0
MYPROG=$(basename $0)
LOGFILE=""
PIDFILE=""
UPDFILE=""
DATFILE=""
ERRFILE=""
TLDFILE=/usr/share/public_suffix_list.dat.gz
CHECK_SECONDS=0
FORCE_SECONDS=0
RETRY_SECONDS=0
LAST_TIME=0
CURR_TIME=0
NEXT_TIME=0
EPOCH_TIME=0
REGISTERED_IP=""
LOCAL_IP=""
URL_USER=""
URL_PASS=""
URL_PENC=""
UPD_ANSWER=""
ERR_LAST=0
ERR_UPDATE=0
PID_SLEEP=0
IPV4_REGEX="[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
IPV6_REGEX="\(\([0-9A-Fa-f]\{1,4\}:\)\{1,\}\)\(\([0-9A-Fa-f]\{1,4\}\)\{0,1\}\)\(\(:[0-9A-Fa-f]\{1,4\}\)\{1,\}\)"
LUCI_HELPER=$(printf %s "$MYPROG" | grep -i "luci")
BIND_HOST=$(which host)
KNOT_HOST=$(which khost)
DRILL=$(which drill)
HOSTIP=$(which hostip)
NSLOOKUP=$(which nslookup)
NSLOOKUP_MUSL=$($(which nslookup) localhost 2>&1 | grep -F "(null)")
WGET=$(which wget)
WGET_SSL=$(which wget-ssl)
CURL=$(which curl)
CURL_SSL=$($(which curl) -V 2>/dev/null | grep "Protocols:" | grep -F "https")
CURL_PROXY=$(find /lib /usr/lib -name libcurl.so* -exec grep -i "all_proxy" {} 2>/dev/null \;)
UCLIENT_FETCH=$(which uclient-fetch)
UCLIENT_FETCH_SSL=$(find /lib /usr/lib -name libustream-ssl.so* 2>/dev/null)
upd_privateip=$(uci -q get ddns.global.upd_privateip) || upd_privateip=0
ddns_rundir=$(uci -q get ddns.global.ddns_rundir) || ddns_rundir="/var/run/ddns"
[ -d $ddns_rundir ] || mkdir -p -m755 $ddns_rundir
ddns_logdir=$(uci -q get ddns.global.ddns_logdir) || ddns_logdir="/var/log/ddns"
[ -d $ddns_logdir ] || mkdir -p -m755 $ddns_logdir
ddns_loglines=$(uci -q get ddns.global.ddns_loglines) || ddns_loglines=250
ddns_loglines=$((ddns_loglines + 1))
ddns_dateformat=$(uci -q get ddns.global.ddns_dateformat) || ddns_dateformat="%F %R"
DATE_PROG="date +'$ddns_dateformat'"
USE_CURL=$(uci -q get ddns.global.use_curl) || USE_CURL=0
[ -n "$CURL" ] || USE_CURL=0
load_all_config_options()
{
local __PKGNAME="$1"
local __SECTIONID="$2"
local __VAR
local __ALL_OPTION_VARIABLES=""
config_cb()
{
if [ ."$2" = ."$__SECTIONID" ]; then
option_cb()
{
__ALL_OPTION_VARIABLES="$__ALL_OPTION_VARIABLES $1"
}
else
option_cb() { return 0; }
fi
}
config_load "$__PKGNAME"
[ -z "$__ALL_OPTION_VARIABLES" ] && return 1
for __VAR in $__ALL_OPTION_VARIABLES
do
config_get "$__VAR" "$__SECTIONID" "$__VAR"
done
return 0
}
load_all_service_sections() {
local __DATA=""
config_cb()
{
[ "$1" = "service" ] && __DATA="$__DATA $2"
}
config_load "ddns"
eval "$1=\"$__DATA\""
return
}
start_daemon_for_all_ddns_sections()
{
local __EVENTIF="$1"
local __SECTIONS=""
local __SECTIONID=""
local __IFACE=""
load_all_service_sections __SECTIONS
for __SECTIONID in $__SECTIONS; do
config_get __IFACE "$__SECTIONID" interface "wan"
[ -z "$__EVENTIF" -o "$__IFACE" = "$__EVENTIF" ] || continue
if [ $VERBOSE -eq 0 ]; then
/usr/lib/ddns/dynamic_dns_updater.sh -v 0 -S "$__SECTIONID" -- start &
else
/usr/lib/ddns/dynamic_dns_updater.sh -v "$VERBOSE" -S "$__SECTIONID" -- start
fi
done
}
stop_section_processes() {
local __PID=0
local __PIDFILE="$ddns_rundir/$1.pid"
[ $# -ne 1 ] && write_log 12 "Error calling 'stop_section_processes()' - wrong number of parameters"
[ -e "$__PIDFILE" ] && {
__PID=$(cat $__PIDFILE)
ps | grep "^[\t ]*$__PID" >/dev/null 2>&1 && kill $__PID || __PID=0
}
[ $__PID -eq 0 ]
}
stop_daemon_for_all_ddns_sections() {
local __EVENTIF="$1"
local __SECTIONS=""
local __SECTIONID=""
local __IFACE=""
load_all_service_sections __SECTIONS
for __SECTIONID in $__SECTIONS;	do
config_get __IFACE "$__SECTIONID" interface "wan"
[ -z "$__EVENTIF" -o "$__IFACE" = "$__EVENTIF" ] || continue
stop_section_processes "$__SECTIONID"
done
}
write_log() {
local __LEVEL __EXIT __CMD __MSG
local __TIME=$(date +%H%M%S)
[ $1 -ge 10 ] && {
__LEVEL=$(($1-10))
__EXIT=1
} || {
__LEVEL=$1
__EXIT=0
}
shift
[ $__EXIT -eq 0 ] && __MSG="$*" || __MSG="$* - TERMINATE"
case $__LEVEL in
0)	__CMD="logger -p user.emerg -t ddns-scripts[$$] $SECTION_ID: $__MSG"
__MSG=" $__TIME EMERG : $__MSG" ;;
1)	__CMD="logger -p user.alert -t ddns-scripts[$$] $SECTION_ID: $__MSG"
__MSG=" $__TIME ALERT : $__MSG" ;;
2)	__CMD="logger -p user.crit -t ddns-scripts[$$] $SECTION_ID: $__MSG"
__MSG=" $__TIME  CRIT : $__MSG" ;;
3)	__CMD="logger -p user.err -t ddns-scripts[$$] $SECTION_ID: $__MSG"
__MSG=" $__TIME ERROR : $__MSG" ;;
4)	__CMD="logger -p user.warn -t ddns-scripts[$$] $SECTION_ID: $__MSG"
__MSG=" $__TIME  WARN : $__MSG" ;;
5)	__CMD="logger -p user.notice -t ddns-scripts[$$] $SECTION_ID: $__MSG"
__MSG=" $__TIME  note : $__MSG" ;;
6)	__CMD="logger -p user.info -t ddns-scripts[$$] $SECTION_ID: $__MSG"
__MSG=" $__TIME  info : $__MSG" ;;
7)	__MSG=" $__TIME       : $__MSG";;
*) 	return;;
esac
[ $VERBOSE -gt 0 -o $__EXIT -gt 0 ] && echo -e "$__MSG"
if [ ${use_logfile:-1} -eq 1 -o $VERBOSE -gt 1 ]; then
echo -e "$__MSG" >> $LOGFILE
[ $VERBOSE -gt 1 ] || sed -i -e :a -e '$q;N;'$ddns_loglines',$D;ba' $LOGFILE
fi
[ -n "$LUCI_HELPER" ] && return
[ $__LEVEL -eq 7 ] && return
__CMD=$(echo -e "$__CMD" | tr -d '\n' | tr '\t' '     ')
[ $__EXIT  -eq 1 ] && {
$__CMD
exit 1
}
[ $use_syslog -eq 0 ] && return
[ $((use_syslog + __LEVEL)) -le 7 ] && $__CMD
return
}
urlencode() {
local __STR __LEN __CHAR __OUT
local __ENC=""
local __POS=1
[ $# -ne 2 ] && write_log 12 "Error calling 'urlencode()' - wrong number of parameters"
__STR="$2"
__LEN=${#__STR}
while [ $__POS -le $__LEN ]; do
__CHAR=$(expr substr "$__STR" $__POS 1)
case "$__CHAR" in
[-_.~a-zA-Z0-9] )
__OUT="${__CHAR}"
;;
* )
__OUT=$(printf '%%%02x' "'$__CHAR" )
;;
esac
__ENC="${__ENC}${__OUT}"
__POS=$(( $__POS + 1 ))
done
eval "$1=\"$__ENC\""
return 0
}
get_service_data() {
[ $# -ne 3 ] && write_log 12 "Error calling 'get_service_data()' - wrong number of parameters"
__FILE="/etc/ddns/services"
[ $use_ipv6 -ne 0 ] && __FILE="/etc/ddns/services_ipv6"
mkfifo pipe_$$
sed '/^#/d; /^[ \t]*$/d; s/\"//g' $__FILE  > pipe_$$ &
while read __SERVICE __DATA __ANSWER; do
if [ "$__SERVICE" = "$service_name" ]; then
__URL=$(echo "$__DATA" | grep "^http")
[ -z "$__URL" ] && __SCRIPT="/usr/lib/ddns/$__DATA"
eval "$1=\"$__URL\""
eval "$2=\"$__SCRIPT\""
eval "$3=\"$__ANSWER\""
rm pipe_$$
return 0
fi
done < pipe_$$
rm pipe_$$
eval "$1=\"\""
eval "$2=\"\""
eval "$3=\"\""
return 1
}
get_seconds() {
[ $# -ne 3 ] && write_log 12 "Error calling 'get_seconds()' - wrong number of parameters"
case "$3" in
"days" )	eval "$1=$(( $2 * 86400 ))";;
"hours" )	eval "$1=$(( $2 * 3600 ))";;
"minutes" )	eval "$1=$(( $2 * 60 ))";;
* )		eval "$1=$2";;
esac
return 0
}
timeout() {
#.copied from http://www.ict.griffith.edu.au/anthony/software/timeout.sh
#.Anthony Thyssen     6 April 2011
SIG=-TERM
while [ $# -gt 0 ]; do
case "$1" in
--)
shift;
break ;;
[0-9]*)
TIMEOUT="$1" ;;
-*)
SIG="$1" ;;
*)
break ;;
esac
shift
done
"$@" &
command_pid=$!
sleep_pid=0
(
trap 'kill -TERM $sleep_pid; return 1' 1 2 3 15
sleep $TIMEOUT &
sleep_pid=$!
wait $sleep_pid
kill $SIG $command_pid >/dev/null 2>&1
return 1
) &
timeout_pid=$!
wait $command_pid
status=$?
kill $timeout_pid 2>/dev/null
wait $timeout_pid 2>/dev/null
return $status
}
verify_host_port() {
local __HOST=$1
local __PORT=$2
local __NC=$(which nc)
local __NCEXT=$($(which nc) --help 2>&1 | grep "\-w" 2>/dev/null)
local __IP __IPV4 __IPV6 __RUNPROG __PROG __ERR
[ $# -ne 2 ] && write_log 12 "Error calling 'verify_host_port()' - wrong number of parameters"
__IPV4=$(echo $__HOST | grep -m 1 -o "$IPV4_REGEX$")
__IPV6=$(echo $__HOST | grep -m 1 -o "$IPV6_REGEX")
[ -z "$__IPV4" -a -z "$__IPV6" ] && {
if [ -n "$BIND_HOST" ]; then
__PROG="BIND host"
__RUNPROG="$BIND_HOST $__HOST >$DATFILE 2>$ERRFILE"
elif [ -n "$KNOT_HOST" ]; then
__PROG="Knot host"
__RUNPROG="$KNOT_HOST $__HOST >$DATFILE 2>$ERRFILE"
elif [ -n "$DRILL" ]; then
__PROG="drill"
__RUNPROG="$DRILL -V0 $__HOST A >$DATFILE 2>$ERRFILE"
__RUNPROG="$__RUNPROG; $DRILL -V0 $__HOST AAAA >>$DATFILE 2>>$ERRFILE"
elif [ -n "$HOSTIP" ]; then
__PROG="hostip"
__RUNPROG="$HOSTIP $__HOST >$DATFILE 2>$ERRFILE"
__RUNPROG="$__RUNPROG; $HOSTIP -6 $__HOST >>$DATFILE 2>>$ERRFILE"
else
__PROG="BusyBox nslookup"
__RUNPROG="$NSLOOKUP $__HOST >$DATFILE 2>$ERRFILE"
fi
write_log 7 "#> $__RUNPROG"
eval $__RUNPROG
__ERR=$?
[ $__ERR -gt 0 ] && {
write_log 3 "DNS Resolver Error - $__PROG Error '$__ERR'"
write_log 7 "$(cat $ERRFILE)"
return 2
}
if [ -n "$BIND_HOST" -o -n "$KNOT_HOST" ]; then
__IPV4=$(cat $DATFILE | awk -F "address " '/has address/ {print $2; exit}' )
__IPV6=$(cat $DATFILE | awk -F "address " '/has IPv6/ {print $2; exit}' )
elif [ -n "$DRILL" ]; then
__IPV4=$(cat $DATFILE | awk '/^'"$lookup_host"'/ {print $5}' | grep -m 1 -o "$IPV4_REGEX")
__IPV6=$(cat $DATFILE | awk '/^'"$lookup_host"'/ {print $5}' | grep -m 1 -o "$IPV6_REGEX")
elif [ -n "$HOSTIP" ]; then
__IPV4=$(cat $DATFILE | grep -m 1 -o "$IPV4_REGEX")
__IPV6=$(cat $DATFILE | grep -m 1 -o "$IPV6_REGEX")
else
__IPV4=$(cat $DATFILE | sed -ne "/^Name:/,\$ { s/^Address[0-9 ]\{0,\}: \($IPV4_REGEX\).*$/\\1/p }")
__IPV6=$(cat $DATFILE | sed -ne "/^Name:/,\$ { s/^Address[0-9 ]\{0,\}: \($IPV6_REGEX\).*$/\\1/p }")
fi
}
if [ $force_ipversion -ne 0 ]; then
__ERR=0
[ $use_ipv6 -eq 0 -a -z "$__IPV4" ] && __ERR=4
[ $use_ipv6 -eq 1 -a -z "$__IPV6" ] && __ERR=6
[ $__ERR -gt 0 ] && {
[ -n "$LUCI_HELPER" ] && return 4
write_log 14 "Verify host Error '4' - Forced IP Version IPv$__ERR don't match"
}
fi
$__NC --help 2>&1 | grep -i "NO OPT l!" >/dev/null 2>&1 && \
write_log 12 "Busybox nc (netcat) compiled without '-l' option, error 'NO OPT l!'"
$__NC --help 2>&1 | grep "\-w" >/dev/null 2>&1 && __NCEXT="TRUE"
[ $force_ipversion -ne 0 -a $use_ipv6 -ne 0 -o -z "$__IPV4" ] && __IP=$__IPV6 || __IP=$__IPV4
if [ -n "$__NCEXT" ]; then
__RUNPROG="$__NC -w 1 $__IP $__PORT </dev/null >$DATFILE 2>$ERRFILE"
write_log 7 "#> $__RUNPROG"
eval $__RUNPROG
__ERR=$?
[ $__ERR -eq 0 ] && return 0
write_log 3 "Connect error - BusyBox nc (netcat) Error '$__ERR'"
write_log 7 "$(cat $ERRFILE)"
return 3
else
__RUNPROG="timeout 2 -- $__NC $__IP $__PORT </dev/null >$DATFILE 2>$ERRFILE"
write_log 7 "#> $__RUNPROG"
eval $__RUNPROG
__ERR=$?
[ $__ERR -eq 0 ] && return 0
write_log 3 "Connect error - BusyBox nc (netcat) timeout Error '$__ERR'"
return 3
fi
}
verify_dns() {
local __ERR=255
local __CNT=0
[ $# -ne 1 ] && write_log 12 "Error calling 'verify_dns()' - wrong number of parameters"
write_log 7 "Verify DNS server '$1'"
while [ $__ERR -ne 0 ]; do
verify_host_port "$1" "53"
__ERR=$?
if [ -n "$LUCI_HELPER" ]; then
return $__ERR
elif [ $__ERR -ne 0 -a $VERBOSE -gt 1 ]; then
write_log 4 "Verify DNS server '$1' failed - Verbose Mode: $VERBOSE - NO retry on error"
return $__ERR
elif [ $__ERR -ne 0 ]; then
__CNT=$(( $__CNT + 1 ))
[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && \
write_log 14 "Verify DNS server '$1' failed after $retry_count retries"
write_log 4 "Verify DNS server '$1' failed - retry $__CNT/$retry_count in $RETRY_SECONDS seconds"
sleep $RETRY_SECONDS &
PID_SLEEP=$!
wait $PID_SLEEP
PID_SLEEP=0
fi
done
return 0
}
verify_proxy() {
local __TMP __HOST __PORT
local __ERR=255
local __CNT=0
[ $# -ne 1 ] && write_log 12 "Error calling 'verify_proxy()' - wrong number of parameters"
write_log 7 "Verify Proxy server 'http://$1'"
__TMP=$(echo $1 | awk -F "@" '{print $2}')
[ -z "$__TMP" ] && __TMP="$1"
__HOST=$(echo $__TMP | grep -m 1 -o "$IPV6_REGEX")
if [ -n "$__HOST" ]; then
__PORT=$(echo $__TMP | awk -F "]:" '{print $2}')
else
__HOST=$(echo $__TMP | awk -F ":" '{print $1}')
__PORT=$(echo $__TMP | awk -F ":" '{print $2}')
fi
[ -z "$__PORT" ] && {
[ -n "$LUCI_HELPER" ] && return 5
write_log 14 "Invalid Proxy server Error '5' - proxy port missing"
}
while [ $__ERR -gt 0 ]; do
verify_host_port "$__HOST" "$__PORT"
__ERR=$?
if [ -n "$LUCI_HELPER" ]; then
return $__ERR
elif [ $__ERR -gt 0 -a $VERBOSE -gt 1 ]; then
write_log 4 "Verify Proxy server '$1' failed - Verbose Mode: $VERBOSE - NO retry on error"
return $__ERR
elif [ $__ERR -gt 0 ]; then
__CNT=$(( $__CNT + 1 ))
[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && \
write_log 14 "Verify Proxy server '$1' failed after $retry_count retries"
write_log 4 "Verify Proxy server '$1' failed - retry $__CNT/$retry_count in $RETRY_SECONDS seconds"
sleep $RETRY_SECONDS &
PID_SLEEP=$!
wait $PID_SLEEP
PID_SLEEP=0
fi
done
return 0
}
do_transfer() {
local __URL="$1"
local __ERR=0
local __CNT=0
local __PROG  __RUNPROG
[ $# -ne 1 ] && write_log 12 "Error in 'do_transfer()' - wrong number of parameters"
if [ -n "$WGET_SSL" -a $USE_CURL -eq 0 ]; then
__PROG="$WGET_SSL -nv -t 1 -O $DATFILE -o $ERRFILE"
if [ -n "$bind_network" ]; then
local __BINDIP
[ $use_ipv6 -eq 0 ] && __RUNPROG="network_get_ipaddr" || __RUNPROG="network_get_ipaddr6"
eval "$__RUNPROG __BINDIP $bind_network" || \
write_log 13 "Can not detect local IP using '$__RUNPROG $bind_network' - Error: '$?'"
write_log 7 "Force communication via IP '$__BINDIP'"
__PROG="$__PROG --bind-address=$__BINDIP"
fi
if [ $force_ipversion -eq 1 ]; then
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -4" || __PROG="$__PROG -6"
fi
if [ $use_https -eq 1 ]; then
if [ "$cacert" = "IGNORE" ]; then
__PROG="$__PROG --no-check-certificate"
elif [ -f "$cacert" ]; then
__PROG="$__PROG --ca-certificate=${cacert}"
elif [ -d "$cacert" ]; then
__PROG="$__PROG --ca-directory=${cacert}"
elif [ -n "$cacert" ]; then
write_log 14 "No valid certificate(s) found at '$cacert' for HTTPS communication"
fi
fi
[ -z "$proxy" ] && __PROG="$__PROG --no-proxy"
__RUNPROG="$__PROG '$__URL'"
__PROG="GNU Wget"
elif [ -n "$CURL" ]; then
__PROG="$CURL -RsS -o $DATFILE --stderr $ERRFILE"
[ -z "$CURL_SSL" -a $use_https -eq 1 ] && \
write_log 13 "cURL: libcurl compiled without https support"
if [ -n "$bind_network" ]; then
local __DEVICE
network_get_physdev __DEVICE $bind_network || \
write_log 13 "Can not detect local device using 'network_get_physdev $bind_network' - Error: '$?'"
write_log 7 "Force communication via device '$__DEVICE'"
__PROG="$__PROG --interface $__DEVICE"
fi
if [ $force_ipversion -eq 1 ]; then
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -4" || __PROG="$__PROG -6"
fi
if [ $use_https -eq 1 ]; then
if [ "$cacert" = "IGNORE" ]; then
__PROG="$__PROG --insecure"
elif [ -f "$cacert" ]; then
__PROG="$__PROG --cacert $cacert"
elif [ -d "$cacert" ]; then
__PROG="$__PROG --capath $cacert"
elif [ -n "$cacert" ]; then
write_log 14 "No valid certificate(s) found at '$cacert' for HTTPS communication"
fi
fi
if [ -z "$proxy" ]; then
__PROG="$__PROG --noproxy '*'"
elif [ -z "$CURL_PROXY" ]; then
write_log 13 "cURL: libcurl compiled without Proxy support"
fi
__RUNPROG="$__PROG '$__URL'"
__PROG="cURL"
elif [ -n "$UCLIENT_FETCH" ]; then
__PROG="$UCLIENT_FETCH -q -O $DATFILE"
[ -n "$__BINDIP" ] && \
write_log 14 "uclient-fetch: FORCE binding to specific address not supported"
if [ $force_ipversion -eq 1 ]; then
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -4" || __PROG="$__PROG -6"
fi
[ $use_https -eq 1 -a -z "$UCLIENT_FETCH_SSL" ] && \
write_log 14 "uclient-fetch: no HTTPS support! Additional install one of ustream-ssl packages"
[ -z "$proxy" ] && __PROG="$__PROG -Y off" || __PROG="$__PROG -Y on"
if [ $use_https -eq 1 ]; then
if [ "$cacert" = "IGNORE" ]; then
__PROG="$__PROG --no-check-certificate"
elif [ -f "$cacert" ]; then
__PROG="$__PROG --ca-certificate=$cacert"
elif [ -n "$cacert" ]; then
write_log 14 "No valid certificate file '$cacert' for HTTPS communication"
fi
fi
__RUNPROG="$__PROG '$__URL' 2>$ERRFILE"
__PROG="uclient-fetch"
elif [ -n "$WGET" ]; then
__PROG="$WGET -q -O $DATFILE"
[ -n "$__BINDIP" ] && \
write_log 14 "BusyBox Wget: FORCE binding to specific address not supported"
[ $force_ipversion -eq 1 ] && \
write_log 14 "BusyBox Wget: Force connecting to IPv4 or IPv6 addresses not supported"
[ $use_https -eq 1 ] && \
write_log 14 "BusyBox Wget: no HTTPS support"
[ -z "$proxy" ] && __PROG="$__PROG -Y off"
__RUNPROG="$__PROG '$__URL' 2>$ERRFILE"
__PROG="Busybox Wget"
else
write_log 13 "Neither 'Wget' nor 'cURL' nor 'uclient-fetch' installed or executable"
fi
while : ; do
write_log 7 "#> $__RUNPROG"
eval $__RUNPROG
__ERR=$?
[ $__ERR -eq 0 ] && return 0
[ -n "$LUCI_HELPER" ] && return 1
write_log 3 "$__PROG Error: '$__ERR'"
write_log 7 "$(cat $ERRFILE)"
[ $VERBOSE -gt 1 ] && {
write_log 4 "Transfer failed - Verbose Mode: $VERBOSE - NO retry on error"
return 1
}
__CNT=$(( $__CNT + 1 ))
[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && \
write_log 14 "Transfer failed after $retry_count retries"
write_log 4 "Transfer failed - retry $__CNT/$retry_count in $RETRY_SECONDS seconds"
sleep $RETRY_SECONDS &
PID_SLEEP=$!
wait $PID_SLEEP
PID_SLEEP=0
done
write_log 12 "Error in 'do_transfer()' - program coding error"
}
send_update() {
local __IP
[ $# -ne 1 ] && write_log 12 "Error calling 'send_update()' - wrong number of parameters"
if [ $upd_privateip -eq 0 ]; then
[ $use_ipv6 -eq 0 ] && __IP=$(echo $1 | grep -v -E "(^0|^10\.|^100\.6[4-9]\.|^100\.[7-9][0-9]\.|^100\.1[0-1][0-9]\.|^100\.12[0-7]\.|^127|^169\.254|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.|^192\.168)")
[ $use_ipv6 -eq 1 ] && __IP=$(echo $1 | grep "^[0-9a-eA-E]")
else
__IP=$(echo $1 | grep -m 1 -o "$IPV4_REGEX")
[ -z "$__IP" ] && __IP=$(echo $1 | grep -m 1 -o "$IPV6_REGEX")
fi
[ -z "$__IP" ] && {
write_log 3 "No or private or invalid IP '$1' given! Please check your configuration"
return 127
}
if [ -n "$update_script" ]; then
write_log 7 "parsing script '$update_script'"
. $update_script
else
local __URL __ERR
__URL=$(echo $update_url | sed -e "s#\[USERNAME\]#$URL_USER#g"	-e "s#\[PASSWORD\]#$URL_PASS#g" \
-e "s#\[PARAMENC\]#$URL_PENC#g"	-e "s#\[PARAMOPT\]#$param_opt#g" \
-e "s#\[DOMAIN\]#$domain#g"	-e "s#\[IP\]#$__IP#g")
[ $use_https -ne 0 ] && __URL=$(echo $__URL | sed -e 's#^http:#https:#')
do_transfer "$__URL" || return 1
write_log 7 "DDNS Provider answered:\n$(cat $DATFILE)"
[ -z "$UPD_ANSWER" ] && return 0
grep -i -E "$UPD_ANSWER" $DATFILE >/dev/null 2>&1
return $?
fi
}
get_local_ip () {
local __CNT=0
local __RUNPROG __DATA __URL __ERR
[ $# -ne 1 ] && write_log 12 "Error calling 'get_local_ip()' - wrong number of parameters"
write_log 7 "Detect local IP on '$ip_source'"
while : ; do
if [ -n "$ip_network" ]; then
[ $use_ipv6 -eq 0 ] && __RUNPROG="network_get_ipaddr" \
|| __RUNPROG="network_get_ipaddr6"
eval "$__RUNPROG __DATA $ip_network" || \
write_log 13 "Can not detect local IP using $__RUNPROG '$ip_network' - Error: '$?'"
[ -n "$__DATA" ] && write_log 7 "Local IP '$__DATA' detected on network '$ip_network'"
elif [ -n "$ip_interface" ]; then
local __DATA4=""; local __DATA6=""
if [ -n "$(which ip)" ]; then
write_log 7 "#> ip -o addr show dev $ip_interface scope global >$DATFILE 2>$ERRFILE"
ip -o addr show dev $ip_interface scope global >$DATFILE 2>$ERRFILE
__ERR=$?
if [ $__ERR -eq 0 ]; then
sed -i "/BROADCAST/d; /inet6 f/d; s/sec//g; s/forever/-1/g; s/\/.*preferred_lft//g; s/^.*$ip_interface *//g" $DATFILE
local __TIME4=0;  local __TIME6=0
local __TYP __ADR __TIME
while read __TYP __ADR __TIME; do
__TIME=${__TIME:-0}
[ "$__TYP" = "inet6" -a $__TIME6 -ge 0 -a \( $__TIME -lt 0 -o $__TIME -gt $__TIME6 \) ] && {
__DATA6="$__ADR"
__TIME6="$__TIME"
}
[ "$__TYP" = "inet" -a $__TIME4 -ge 0 -a \( $__TIME -lt 0 -o $__TIME -gt $__TIME4 \) ] && {
__DATA4="$__ADR"
__TIME4="$__TIME"
}
done < $DATFILE
else
write_log 3 "ip Error: '$__ERR'"
write_log 7 "$(cat $ERRFILE)"
fi
else
write_log 7 "#> ifconfig $ip_interface >$DATFILE 2>$ERRFILE"
ifconfig $ip_interface >$DATFILE 2>$ERRFILE
__ERR=$?
if [ $__ERR -eq 0 ]; then
__DATA4=$(awk '
/inet addr:/ {
$1="";
$3="";
$4="";
FS=":";
$0=$0;
$1="";
FS=" ";
$0=$0;
print $1;
}' $DATFILE
)
__DATA6=$(awk '
/inet6/ && /: [0-9a-eA-E]/ {
FS="/";
$0=$0;
$2="";
FS=" ";
$0=$0;
print $3;
}' $DATFILE
)
else
write_log 3 "ifconfig Error: '$__ERR'"
write_log 7 "$(cat $ERRFILE)"
fi
fi
[ $use_ipv6 -eq 0 ] && __DATA="$__DATA4" || __DATA="$__DATA6"
[ -n "$__DATA" ] && write_log 7 "Local IP '$__DATA' detected on interface '$ip_interface'"
elif [ -n "$ip_script" ]; then
write_log 7 "#> $ip_script >$DATFILE 2>$ERRFILE"
eval $ip_script >$DATFILE 2>$ERRFILE
__ERR=$?
if [ $__ERR -eq 0 ]; then
__DATA=$(cat $DATFILE)
[ -n "$__DATA" ] && write_log 7 "Local IP '$__DATA' detected via script '$ip_script'"
else
write_log 3 "$ip_script Error: '$__ERR'"
write_log 7 "$(cat $ERRFILE)"
fi
elif [ -n "$ip_url" ]; then
do_transfer "$ip_url"
[ $use_ipv6 -eq 0 ] \
&& __DATA=$(grep -m 1 -o "$IPV4_REGEX" $DATFILE) \
|| __DATA=$(grep -m 1 -o "$IPV6_REGEX" $DATFILE)
[ -n "$__DATA" ] && write_log 7 "Local IP '$__DATA' detected on web at '$ip_url'"
else
write_log 12 "Error in 'get_local_ip()' - unhandled ip_source '$ip_source'"
fi
[ -n "$__DATA" ] && {
eval "$1=\"$__DATA\""
return 0
}
[ -n "$LUCI_HELPER" ] && return 1
write_log 7 "Data detected:"
write_log 7 "$(cat $DATFILE)"
[ $VERBOSE -gt 1 ] && {
write_log 4 "Get local IP via '$ip_source' failed - Verbose Mode: $VERBOSE - NO retry on error"
return 1
}
__CNT=$(( $__CNT + 1 ))
[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && \
write_log 14 "Get local IP via '$ip_source' failed after $retry_count retries"
write_log 4 "Get local IP via '$ip_source' failed - retry $__CNT/$retry_count in $RETRY_SECONDS seconds"
sleep $RETRY_SECONDS &
PID_SLEEP=$!
wait $PID_SLEEP
PID_SLEEP=0
done
write_log 12 "Error in 'get_local_ip()' - program coding error"
}
get_registered_ip() {
local __CNT=0
local __ERR=255
local __REGEX  __PROG  __RUNPROG  __DATA  __IP
[ $# -lt 1 -o $# -gt 2 ] && write_log 12 "Error calling 'get_registered_ip()' - wrong number of parameters"
[ $is_glue -eq 1 -a -z "$BIND_HOST" ] && write_log 14 "Lookup of glue records is only supported using BIND host"
write_log 7 "Detect registered/public IP"
[ $use_ipv6 -eq 0 ] && __REGEX="$IPV4_REGEX" || __REGEX="$IPV6_REGEX"
if [ -n "$BIND_HOST" ]; then
__PROG="$BIND_HOST"
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -t A"  || __PROG="$__PROG -t AAAA"
if [ $force_ipversion -eq 1 ]; then
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -4"  || __PROG="$__PROG -6"
fi
[ $force_dnstcp -eq 1 ] && __PROG="$__PROG -T"
[ $is_glue -eq 1 ] && __PROG="$__PROG -v"
__RUNPROG="$__PROG $lookup_host $dns_server >$DATFILE 2>$ERRFILE"
__PROG="BIND host"
elif [ -n "$KNOT_HOST" ]; then
__PROG="$KNOT_HOST"
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -t A"  || __PROG="$__PROG -t AAAA"
if [ $force_ipversion -eq 1 ]; then
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -4"  || __PROG="$__PROG -6"
fi
[ $force_dnstcp -eq 1 ] && __PROG="$__PROG -T"
__RUNPROG="$__PROG $lookup_host $dns_server >$DATFILE 2>$ERRFILE"
__PROG="Knot host"
elif [ -n "$DRILL" ]; then
__PROG="$DRILL -V0"
if [ $force_ipversion -eq 1 ]; then
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG -4"  || __PROG="$__PROG -6"
fi
[ $force_dnstcp -eq 1 ] && __PROG="$__PROG -t" || __PROG="$__PROG -u"
__PROG="$__PROG $lookup_host"
[ -n "$dns_server" ] && __PROG="$__PROG @$dns_server"
[ $use_ipv6 -eq 0 ] && __PROG="$__PROG A"  || __PROG="$__PROG AAAA"
__RUNPROG="$__PROG >$DATFILE 2>$ERRFILE"
__PROG="drill"
elif [ -n "$HOSTIP" ]; then
__PROG="$HOSTIP"
[ $force_dnstcp -ne 0 ] && \
write_log 14 "hostip - no support for 'DNS over TCP'"
__IP=$(echo $dns_server | grep -m 1 -o "$IPV4_REGEX")
[ -z "$__IP" ] && __IP=$(echo $dns_server | grep -m 1 -o "$IPV6_REGEX")
[ -z "$__IP" -a -n "$dns_server" ] && {
__IP="\`$HOSTIP"
[ $use_ipv6 -eq 1 -a $force_ipversion -eq 1 ] && __IP="$__IP -6"
__IP="$__IP $dns_server | grep -m 1 -o"
[ $use_ipv6 -eq 1 -a $force_ipversion -eq 1 ] \
&& __IP="$__IP '$IPV6_REGEX'" \
|| __IP="$__IP '$IPV4_REGEX'"
__IP="$__IP \`"
}
[ $use_ipv6 -eq 1 ] && __PROG="$__PROG -6"
[ -n "$dns_server" ] && __PROG="$__PROG -r $__IP"
__RUNPROG="$__PROG $lookup_host >$DATFILE 2>$ERRFILE"
__PROG="hostip"
elif [ -n "$NSLOOKUP" ]; then
[ $force_dnstcp -ne 0 ] && \
write_log 14 "Busybox nslookup - no support for 'DNS over TCP'"
[ -n "$NSLOOKUP_MUSL" -a -n "$dns_server" ] && \
write_log 14 "Busybox compiled with musl - nslookup don't support the use of DNS Server"
[ $force_ipversion -ne 0 ] && \
write_log 5 "Busybox nslookup - no support to 'force IP Version' (ignored)"
__RUNPROG="$NSLOOKUP $lookup_host $dns_server >$DATFILE 2>$ERRFILE"
__PROG="BusyBox nslookup"
else
write_log 12 "Error in 'get_registered_ip()' - no supported Name Server lookup software accessible"
fi
while : ; do
write_log 7 "#> $__RUNPROG"
eval $__RUNPROG
__ERR=$?
if [ $__ERR -ne 0 ]; then
write_log 3 "$__PROG error: '$__ERR'"
write_log 7 "$(cat $ERRFILE)"
else
if [ -n "$BIND_HOST" -o -n "$KNOT_HOST" ]; then
if [ $is_glue -eq 1 ]; then
__DATA=$(cat $DATFILE | grep "^$lookup_host" | grep -om1 "$__REGEX" )
else
__DATA=$(cat $DATFILE | awk -F "address " '/has/ {print $2; exit}' )
fi
elif [ -n "$DRILL" ]; then
__DATA=$(cat $DATFILE | awk '/^'"$lookup_host"'/ {print $5; exit}' )
elif [ -n "$HOSTIP" ]; then
__DATA=$(cat $DATFILE | grep -om1 "$__REGEX")
elif [ -n "$NSLOOKUP" ]; then
__DATA=$(cat $DATFILE | sed -ne "/^Name:/,\$ { s/^Address[0-9 ]\{0,\}: \($__REGEX\).*$/\\1/p }" )
fi
[ -n "$__DATA" ] && {
write_log 7 "Registered IP '$__DATA' detected"
eval "$1=\"$__DATA\""
return 0
}
write_log 4 "NO valid IP found"
__ERR=127
fi
[ -n "$LUCI_HELPER" ] && return $__ERR
[ -n "$2" ] && return $__ERR
[ $VERBOSE -gt 1 ] && {
write_log 4 "Get registered/public IP for '$lookup_host' failed - Verbose Mode: $VERBOSE - NO retry on error"
return $__ERR
}
__CNT=$(( $__CNT + 1 ))
[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && \
write_log 14 "Get registered/public IP for '$lookup_host' failed after $retry_count retries"
write_log 4 "Get registered/public IP for '$lookup_host' failed - retry $__CNT/$retry_count in $RETRY_SECONDS seconds"
sleep $RETRY_SECONDS &
PID_SLEEP=$!
wait $PID_SLEEP
PID_SLEEP=0
done
write_log 12 "Error in 'get_registered_ip()' - program coding error"
}
get_uptime() {
[ $# -ne 1 ] && write_log 12 "Error calling 'verify_host_port()' - wrong number of parameters"
local __UPTIME=$(cat /proc/uptime)
eval "$1=\"${__UPTIME%%.*}\""
}
trap_handler() {
local __PIDS __PID
local __ERR=${2:-0}
local __OLD_IFS=$IFS
local __NEWLINE_IFS='
'
[ $PID_SLEEP -ne 0 ] && kill -$1 $PID_SLEEP 2>/dev/null
case $1 in
0)	if [ $__ERR -eq 0 ]; then
write_log 5 "PID '$$' exit normal at $(eval $DATE_PROG)\n"
else
write_log 4 "PID '$$' exit WITH ERROR '$__ERR' at $(eval $DATE_PROG)\n"
fi ;;
1)	write_log 6 "PID '$$' received 'SIGHUP' at $(eval $DATE_PROG)"
/usr/lib/ddns/dynamic_dns_updater.sh -v "0" -S "$__SECTIONID" -- start || true
exit 0 ;;
2)	write_log 5 "PID '$$' terminated by 'SIGINT' at $(eval $DATE_PROG)\n";;
3)	write_log 5 "PID '$$' terminated by 'SIGQUIT' at $(eval $DATE_PROG)\n";;
15)	write_log 5 "PID '$$' terminated by 'SIGTERM' at $(eval $DATE_PROG)\n";;
*)	write_log 13 "Unhandled signal '$1' in 'trap_handler()'";;
esac
__PIDS=$(pgrep -P $$)
IFS=$__NEWLINE_IFS
for __PID in $__PIDS; do
kill -$1 $__PID
done
IFS=$__OLD_IFS
[ -f $DATFILE ] && rm -f $DATFILE
[ -f $ERRFILE ] && rm -f $ERRFILE
trap - 0 1 2 3 15
[ $1 -gt 0 ] && kill -$1 $$
}
split_FQDN() {
[ $# -ne 4 ] && write_log 12 "Error calling 'split_FQDN()' - wrong number of parameters"
[ -z "$1"  ] && write_log 12 "Error calling 'split_FQDN()' - missing FQDN to split"
[ -f $TLDFILE ] || write_log 12 "Error calling 'split_FQDN()' - missing file '$TLDFILE'"
local _HOST _FDOM _CTLD _FTLD
local _SET="$@"
local _PAR=$(echo "$1" | tr [A-Z] [a-z] | tr "." " ")
set -- $_PAR
_PAR=""
while [ -n "$1" ] ; do
_PAR="$1 $_PAR"
shift
done
set -- $_PAR
_PAR=""
while [ -n "$1" ] ; do
if [ -z "$_CTLD" ]; then
_CTLD="$1"
shift
else
_CTLD="$1.$_CTLD"
shift
fi
zcat $TLDFILE | grep -E "^$_CTLD$" >/dev/null 2>&1 && {
_FTLD="$_CTLD"
_FDOM="$1"
continue
}
zcat $TLDFILE | grep -E "^\*.$_CTLD$" >/dev/null 2>&1 && {
[ -z "$1" ] && break
if zcat $TLDFILE | grep -E "^!$1.$_CTLD$" >/dev/null 2>&1 ; then
_FTLD="$_CTLD"
else
_FTLD="$1.$_CTLD"
shift
fi
_FDOM="$1"; shift
}
[ -n "$_FTLD" ] && break
done
while [ -n "$1" ]; do
_HOST="$1 $_HOST"
shift
done
_HOST=$(echo $_HOST | tr " " ".")
set -- $_SET
[ -n "$_FTLD" ] && {
eval "$2=$_FTLD"
eval "$3=$_FDOM"
eval "$4=$_HOST"
return 0
}
eval "$2=''"
eval "$3=''"
eval "$4=''"
return 1
}
expand_ipv6() {
#.Author:  Florian Streibelt <florian@f-streibelt.de>
#.         https://github.com/mutax/IPv6-Address-checks
[ $# -ne 2 ] && write_log 12 "Error calling 'expand_ipv6()' - wrong number of parameters"
INPUT="$(echo "$1" | tr 'A-F' 'a-f')"
[ "$INPUT" = "::" ] && INPUT="::0"
O=""
while [ "$O" != "$INPUT" ]; do
O="$INPUT"
INPUT=$( echo "$INPUT" | sed	-e 's|:\([0-9a-f]\{3\}\):|:0\1:|g' \
-e 's|:\([0-9a-f]\{3\}\)$|:0\1|g' \
-e 's|^\([0-9a-f]\{3\}\):|0\1:|g' \
-e 's|:\([0-9a-f]\{2\}\):|:00\1:|g' \
-e 's|:\([0-9a-f]\{2\}\)$|:00\1|g' \
-e 's|^\([0-9a-f]\{2\}\):|00\1:|g' \
-e 's|:\([0-9a-f]\):|:000\1:|g' \
-e 's|:\([0-9a-f]\)$|:000\1|g' \
-e 's|^\([0-9a-f]\):|000\1:|g' )
done
ZEROES=""
echo "$INPUT" | grep -qs "::"
if [ "$?" -eq 0 ]; then
GRPS="$( echo "$INPUT" | sed  's|[0-9a-f]||g' | wc -m )"
GRPS=$(( GRPS-1 ))
MISSING=$(( 8-GRPS ))
while [ $MISSING -gt 0 ]; do
ZEROES="$ZEROES:0000"
MISSING=$(( MISSING-1 ))
done
INPUT=$( echo "$INPUT" | sed	-e 's|\(.\)::\(.\)|\1'$ZEROES':\2|g' \
-e 's|\(.\)::$|\1'$ZEROES':0000|g' \
-e 's|^::\(.\)|'$ZEROES':0000:\1|g;s|^:||g' )
fi
if [ $(echo $INPUT | wc -m) != 40 ]; then
write_log 4 "Error in 'expand_ipv6()' - invalid IPv6 found: '$1' expanded: '$INPUT'"
eval "$2='invalid'"
return 1
fi
eval "$2=$INPUT"
return 0
}
