#!/bin/sh
# Copyright (c) 2015 Technicolor

# Check if this platform has reboot_reason functionality, and set reason if so.
if [[ -f /lib/functions/reboot_reason.sh ]]; then
	. /lib/functions/reboot_reason.sh
	set_reboot_reason $(uci -p /var/state/ get system.warmboot.rebootreason)
fi

reboot
