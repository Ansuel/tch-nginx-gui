#.Distributed under the terms of the GNU General Public License (GPL) version 2.0
#.2014-2015 Christian Schoenebeck <christian dot schoenebeck at gmail dot com>
local __DUMMY
local __UPDURL="http://[USERNAME]:[PASSWORD]@dynupdate.no-ip.com/nic/update?hostname=[DOMAIN]&myip=[IP]"
[ -z "$username" ] && write_log 14 "Service section not configured correctly! Missing 'username'"
[ -z "$password" ] && write_log 14 "Service section not configured correctly! Missing 'password'"
[ $use_ipv6 -eq 0 ] && __DUMMY="127.0.0.1" || __DUMMY="::1"
write_log 7 "sending dummy IP to 'no-ip.com'"
__URL=$(echo $__UPDURL | sed -e "s#\[USERNAME\]#$URL_USER#g" -e "s#\[PASSWORD\]#$URL_PASS#g" \
-e "s#\[DOMAIN\]#$domain#g" -e "s#\[IP\]#$__DUMMY#g")
[ $use_https -ne 0 ] && __URL=$(echo $__URL | sed -e 's#^http:#https:#')
do_transfer "$__URL" || return 1
write_log 7 "'no-ip.com' answered:\n$(cat $DATFILE)"
grep -E "good|nochg" $DATFILE >/dev/null 2>&1 || return 1
sleep 1
write_log 7 "sending real IP to 'no-ip.com'"
__URL=$(echo $__UPDURL | sed -e "s#\[USERNAME\]#$URL_USER#g" -e "s#\[PASSWORD\]#$URL_PASS#g" \
-e "s#\[DOMAIN\]#$domain#g" -e "s#\[IP\]#$__IP#g")
[ $use_https -ne 0 ] && __URL=$(echo $__URL | sed -e 's#^http:#https:#')
do_transfer "$__URL" || return 1
write_log 7 "'no-ip.com' answered:\n$(cat $DATFILE)"
grep -E "good|nochg" $DATFILE >/dev/null 2>&1
return $?
