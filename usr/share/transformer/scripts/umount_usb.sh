# Copyright (c) 2015 Technicolor

. $IPKG_INSTROOT/lib/functions/contentsharing.sh

# _umount_it_devices <value>
# Each <value> is the name of a partition (sdaX). Eject this partition.
#
# ITERATOR CALLBACK
#
_umount_it_devices () {
  local device="${1}"

  logger -t umount-usb "Ejecting ${device}"
  cs_eject_device "${device}"
}

# Load /var/state/usb config.
LOAD_STATE=1
config_load usb

# For section 'unmount', for each value of list 'device', call _umount_it_devices.
config_list_foreach unmount device _umount_it_devices

# For config 'usb', for section 'unmount', clear values of list 'device'.
uci_set_state usb unmount device ""
uci_commit usb
