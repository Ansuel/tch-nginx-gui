#!/bin/sh
# Copyright (c) 2016 Technicolor
if [ -f /lib/functions/mmpbx-config-dump.sh ]; then
source /lib/functions/mmpbx-config-dump.sh

collect_config_dump /tmp/mmpbx_dump
fi
