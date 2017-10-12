#!/bin/sh
#.Distributed under the terms of the GNU General Public License (GPL) version 2.0
#.2014-2017 Christian Schoenebeck <christian dot schoenebeck at gmail dot com>
. /usr/lib/ddns/dynamic_dns_functions.sh
usage() {
cat << EOF
Usage:
$MYPROG [options] -- command
Commands:
get_local_ip        using given INTERFACE or NETWORK or SCRIPT or URL
get_registered_ip   for given FQDN
verify_dns          given DNS-SERVER
verify_proxy        given PROXY
start               start given SECTION
reload              force running ddns processes to reload changed configuration
restart             restart all ddns processes
Parameters:
-6                  => use_ipv6=1          (default 0)
-d DNS-SERVER       => dns_server=SERVER[:PORT]
-f                  => force_ipversion=1   (default 0)
-g                  => is_glue=1           (default 0)
-i INTERFACE        => ip_interface=INTERFACE; ip_source="interface"
-l FQDN             => lookup_host=FQDN
-n NETWORK          => ip_network=NETWORK; ip_source="network"
-p PROXY            => proxy=[USER:PASS@]PROXY:PORT
-s SCRIPT           => ip_script=SCRIPT; ip_source="script"
-t                  => force_dnstcp=1      (default 0)
-u URL              => ip_url=URL; ip_source="web"
-S SECTION          SECTION to start
-h                  => show this help and exit
-L                  => use_logfile=1    (default 0)
-v LEVEL            => VERBOSE=LEVEL    (default 0)
-V                  => show version and exit
EOF
}
usage_err() {
printf %s\\n "$MYPROG: $@" >&2
usage >&2
exit 255
}
SECTION_ID="lucihelper"
LOGFILE="$ddns_logdir/$SECTION_ID.log"
DATFILE="$ddns_rundir/$SECTION_ID.$$.dat"
ERRFILE="$ddns_rundir/$SECTION_ID.$$.err"
DDNSPRG="/usr/lib/ddns/dynamic_dns_updater.sh"
VERBOSE=0
use_syslog=0
use_logfile=0
use_ipv6=0
force_ipversion=0
force_dnstcp=0
is_glue=0
use_https=0
while getopts ":6d:fghi:l:n:p:s:S:tu:Lv:V" OPT; do
case "$OPT" in
6)	use_ipv6=1;;
d)	dns_server="$OPTARG";;
f)	force_ipversion=1;;
g)	is_glue=1;;
i)	ip_interface="$OPTARG"; ip_source="interface";;
l)	lookup_host="$OPTARG";;
n)	ip_network="$OPTARG"; ip_source="network";;
p)	proxy="$OPTARG";;
s)	ip_script="$OPTARG"; ip_source="script";;
t)	force_dnstcp=1;;
u)	ip_url="$OPTARG"; ip_source="web";;
h)	usage; exit 255;;
L)	use_logfile=1;;
v)	VERBOSE=$OPTARG;;
S)	SECTION=$OPTARG;;
V)	printf %s\\n "ddns-scripts $VERSION"; exit 255;;
:)	usage_err "option -$OPTARG missing argument";;
\?)	usage_err "invalid option -$OPTARG";;
*)	usage_err "unhandled option -$OPT $OPTARG";;
esac
done
shift $((OPTIND - 1 ))
[ $# -eq 0 ] && usage_err "missing command"
__RET=0
case "$1" in
get_registered_ip)
[ -z "$lookup_host" ] && usage_err "command 'get_registered_ip': 'lookup_host' not set"
write_log 7 "-----> get_registered_ip IP"
IP=""
get_registered_ip IP
__RET=$?
[ $__RET -ne 0 ] && IP=""
printf "%s" "$IP"
;;
verify_dns)
[ -z "$dns_server" ] && usage_err "command 'verify_dns': 'dns_server' not set"
write_log 7 "-----> verify_dns '$dns_server'"
verify_dns "$dns_server"
__RET=$?
;;
verify_proxy)
[ -z "$proxy" ] && usage_err "command 'verify_proxy': 'proxy' not set"
write_log 7 "-----> verify_proxy '$proxy'"
verify_proxy "$proxy"
__RET=$?
;;
get_local_ip)
[ -z "$ip_source" ] && usage_err "command 'get_local_ip': 'ip_source' not set"
[ -n "$proxy" -a "$ip_source" = "web" ] && {
export HTTP_PROXY="http://$proxy"
export HTTPS_PROXY="http://$proxy"
export http_proxy="http://$proxy"
export https_proxy="http://$proxy"
}
IP=""
if [ "$ip_source" = "web" -o  "$ip_source" = "script" ]; then
write_log 7 "-----> timeout 3 -- get_local_ip IP"
timeout 3 -- get_local_ip IP
else
write_log 7 "-----> get_local_ip IP"
get_local_ip IP
fi
__RET=$?
;;
start)
[ -z "$SECTION" ] &&  usage_err "command 'start': 'SECTION' not set"
if [ $VERBOSE -eq 0 ]; then
$DDNSPRG -v 0 -S $SECTION -- start &
else
$DDNSPRG -v $VERBOSE -S $SECTION -- start
fi
;;
reload)
$DDNSPRG -- reload
;;
restart)
$DDNSPRG -- stop
sleep 1
$DDNSPRG -- start
;;
*)
__RET=255
;;
esac
[ -f $DATFILE ] && rm -f $DATFILE
[ -f $ERRFILE ] && rm -f $ERRFILE
return $__RET
