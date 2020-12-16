#!/bin/sh

LOCK=/tmp/switchover.lock
WAITFILE=/usr/lib/cwmpd/transfers/cwmp_waitforswitchover

. $(dirname $0)/rollback_common.sh

# create a lock dir or exit if it already exists
mkdir $LOCK || exit

if [ -f $WAITFILE ]; then
	rollback_set_initiator DELAYED
fi
# if no switchover waiting, switch banks anyway.

# wait for any voice calls or ongoing VOD to terminate
lua /usr/lib/cwmpd/transfers/checkOngoingServices.lua

# switch
rm -f $WAITFILE

# no need to remove the lock as it is in ram
# and deleting introduces a race condition !!

# reboot reason to UPGRADE as we always upgrade to the same bank
if [ -f /lib/functions/reboot_reason.sh ]; then
	. /lib/functions/reboot_reason.sh
	set_reboot_reason UPGRADE
fi
reboot
