#!/bin/sh
# Copyright (c) 2013 Technicolor
tz=`uci get system.@system[0].timezone`
[ -n "${tz}" ] && echo "$tz" > /tmp/TZ
date -k
