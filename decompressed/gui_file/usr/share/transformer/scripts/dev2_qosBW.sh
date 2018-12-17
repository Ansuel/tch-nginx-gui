#!/bin/sh
/etc/init.d/qos reload
type=$(uci get wansensing.global.l2type)
if [ ${type} == "VDSL" ]
then
  /etc/init.d/xtm reload
else
  /etc/init.d/ethernet reload
fi
