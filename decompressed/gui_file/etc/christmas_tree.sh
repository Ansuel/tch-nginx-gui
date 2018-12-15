#!/bin/sh

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