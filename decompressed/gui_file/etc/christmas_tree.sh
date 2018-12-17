#!/bin/sh

if [ "$(date +'%m%d')" != "1224" ] && [ "$(date +'%m%d')" != "1225" ]; then
    echo "Date not correct cleaning and exiting..."
	sed -i '/christmas_tree/d' /etc/crontabs/root
	sh -c "sleep 2 && /usr/share/transformer/scripts/restart_leds.sh &"
    killall christmas_tree.sh
    exit
fi

if [ "$( ps | grep -c 'christmas_tree.sh')" -gt "3" ]; then
    echo "Already running, exiting..."
    exit
fi

randd(){
	local random=
	while [ "${#random}" -lt 1 ]
	do
		random="$random$(head -n1 /dev/urandom | tr -dc 0-9)"
		random=$(echo "$random" | sed -e 's/^\(.\{1\}\).*/\1/')
	done
	echo $random
}

while [ 1 ]; do
	for filename in /sys/class/leds/*; do
		random=$(randd)
		if [ $random -lt 5 ]; then
	        echo 255 > "$filename/brightness"
		fi
	    random=$(randd)
		if [ $random -lt 5 ]; then
	        echo 0 > "$filename/brightness"
		fi
	done
done