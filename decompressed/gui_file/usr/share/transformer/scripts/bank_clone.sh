#!/bin/sh

is_dual_bank()
{
  grep -c "\"bank_2\"" /proc/mtd >/dev/null
}

if ! is_dual_bank; then
  echo "Single bank devices not supported"
  exit 1
fi

bootedname=$( cat /proc/banktable/booted )
notbootedname=$( cat /proc/banktable/notbooted )

bootedmtd=/dev/mtd$(grep -E "$bootedname" /proc/mtd | sed "s/mtd\([0-9]\):.*\($bootedname\).*/\1/")
notbootedmtd=/dev/mtd$(grep -E "$notbootedname" /proc/mtd | sed "s/mtd\([0-9]\):.*\($notbootedname\).*/\1/")

if [ -d /overlay/$notbootedname ]; then
	rm -r /overlay/$notbootedname
fi

#optional: prepare_root_runonce $notbootedname

mtd erase $notbootedname
mtd write $bootedmtd $notbootedname