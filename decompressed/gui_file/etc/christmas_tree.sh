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

trap "kill 0" SIGINT

randd(){
	grep -m1 -ao '[1-7]' /dev/urandom | head -n1
}

powerOnOffRandom(){
	while [ 1 ]; do
		rand=$(randd)
		echo 255 > "$1"/brightness
		echo powering up "$1" for $rand seconds
		sleep $(( $rand - 1 ))
		echo 0 > "$1"/brightness
		sleep $(( $rand - 1 ))
	done
}

for filename in /sys/class/leds/*; do
	( powerOnOffRandom "$filename" ) &
done

wait