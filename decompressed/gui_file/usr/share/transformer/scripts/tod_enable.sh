#!/bin/sh
enabled=$(uci get firewall.tod.reload)
if [ ${enabled} == "1" ]
then
  /etc/init.d/firewall reload
else
  iptables -F timeofday_fw
fi

