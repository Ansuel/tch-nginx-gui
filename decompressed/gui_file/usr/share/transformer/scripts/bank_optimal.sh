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

if [ "$bootedname" == "bank_1"]; then
  /usr/share/transformer/scripts/bank_clone.sh
  rm -rf /overlay/bank_2
  #prepare_root_runonce bank_2
  #prepare_gui_install bank_2
  echo "bank_1" > /proc/banktable/active
  rm -rf /overlay/bank_1
  mtd -r erase bank_1
elif [ "$bootedname" == "bank_2" ]; then
  rm -rf /overlay/bank_1
  #prepare_root_runonce bank_1
  echo "bank_1" > /proc/banktable/active
  mtd erase bank_1
else
 return 1
fi

return 0
