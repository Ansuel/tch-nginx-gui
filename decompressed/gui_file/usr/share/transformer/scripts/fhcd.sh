#!/bin/sh

action="$1"
fhcd_running=$(ubus list -S fhcd)

# if fhcd is not running just execute the given action
[ -z "$fhcd_running" ] && {
	eval "$action"
	exit
}

doublequote='"'
backslash='\'
ubus call fhcd config_changed '{"action":"'"${action//$doublequote/$backslash$doublequote}"'"}'
