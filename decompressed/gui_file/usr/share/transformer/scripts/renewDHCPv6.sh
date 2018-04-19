#!/bin/sh
while read line;
do
	if [ -n "$line" ];then
		pid=$(COLUMNS=512 ps | grep odhcp | grep -w $line | awk '{print $1}')
		kill -SIGUSR1 $pid
	fi;
done < /tmp/.dhcpv6_clients;
rm /tmp/.dhcpv6_clients