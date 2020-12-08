#!/bin/sh

. /lib/functions.sh

SCRIPT_DIR=$(dirname $0)
ERROR_FILE=$1
CONFIG=cwmp_transfer


char_encoding()
{
  lua <<EOF - $1
local name = arg[1]
local escapes = ":/?#[]@!$&'()*+;="
local function escape_char(x)
  if escapes:find(x, nil, true) then
    return ("%%%02X"):format(x:byte(1))
  else
    return x
  end
end
name =name:gsub(".", escape_char)
io.write(name)
EOF
}

do_upgrade()
{
  local url="$1"
  local SWITCHOVER_TYPE="normal"
  WAIT_FOR_SWITCHOVER_FILE="/usr/lib/cwmpd/transfers/cwmp_waitforswitchover"
  rm -f $WAIT_FOR_SWITCHOVER_FILE
  if [ -x /usr/bin/sysupgrade-safe ]; then
    # Modgui: detected acs upgrade, skip version spoof
    # (use the real firmware version in versioncusto)
    echo 1 > /overlay/.skip_version_spoof

    if ! [ -z "$(grep bank_2 /proc/mtd)" ]; then
      $SCRIPT_DIR/rollback.sh record
      if [ "$(uci get cwmpd.cwmpd_config.upgrade_switchovertype)" = "1" ]; then
        SWITCHOVER_TYPE="delayed"
      fi
    else
      WAIT_FOR_SWITCHOVER_FILE="/"
    fi

    if [ $SWITCHOVER_TYPE = "delayed" ]; then
      /usr/bin/sysupgrade-safe -o "$url"
    else
      /usr/bin/lua /usr/lib/cwmpd/transfers/checkOngoingServices.lua
      /usr/bin/sysupgrade-safe "$url"
    fi

    UERR=$?

    if [ $UERR -eq 0 ]; then
      if [ $SWITCHOVER_TYPE = "delayed" ]; then
        touch $WAIT_FOR_SWITCHOVER_FILE
      fi
      exit 0
    else
      return $UERR
    fi
  else
    echo "no sysupgrade-safe found"
  fi
}

get_url()
{
  local URL=$1
  local username=$2
  local password=$3

  local usrinfo=

  if [ ! -z $username ]; then
    usrinfo=$(char_encoding "$username")
  fi

  if [ ! -z $password ]; then
    password=$(char_encoding "$password")
    usrinfo="$usrinfo:$password"
  fi

  if [ ! -z $usrinfo ]; then
    local proto=$(echo $URL | awk -F// "{print \$1;}")
    local host=$(echo $URL | awk -F// "{print \$2;}")
    URL="$proto//$usrinfo@$host"
  fi

  echo $URL
}

get_uci_id()
{
  local cmdkey="$1"
  local id=$(uci show -q $CONFIG | grep ".id='$cmdkey$'" | cut -d. -f2)
  if [ $? -ne 0 ]; then
    id=
  fi
  echo $id
}

get_started()
{
  local cmdkey="$1"
  local started="no"

  local id=$(get_uci_id "$cmdkey")
  if [ ! -z $id ]; then
    started=$(uci -q get $CONFIG.$id.started)
    if [ $? -ne 0 ]; then
      started="no"
    fi
  fi
  echo $started
}

set_started()
{
  local cmdkey="$1"
  local value=$2
  local url=$3
  if [ -z $value ]; then
    value="yes"
  fi
  local id=$(get_uci_id "$cmdkey")
  if [ "$value" = "yes" ]; then
    if [ -z $id ]; then
      uci show $CONFIG >/dev/null 2>/dev/null
      if [ $? -ne 0 ]; then
        #config does not exist, create it
        lua -e "require('uci').cursor():create_config_file('$CONFIG')"
      fi
      id=$(uci add $CONFIG transfer)
      uci rename $CONFIG.$id=$id
      uci set $CONFIG.$id.id="$cmdkey"
    fi
    uci set $CONFIG.$id.started=yes
    if [ ! -z $url ]; then
      uci set $CONFIG.$id.url="$url"
    fi
    [ -n $remember_bank ] && remember_bank $id
    uci commit
    return
  fi
  if [ "$value" = "no" ]; then
    if [ ! -z $id ]; then
      uci delete $CONFIG.$id
      uci commit $CONFIG
    fi
    return
  fi
}

set_error()
{
  local cmdkey="$1"
  local error="$2"
  local id=$(get_uci_id "$cmdkey")
  uci set $CONFIG.$id.error="$error"
  uci commit $CONFIG
}

get_error()
{
  local cmdkey="$1"
  local id=$(get_uci_id "$cmdkey")
  local value=$(uci -q get $CONFIG.$id.error)
  if [ -z $value ]; then
    value="0"
  fi
  if is_dual_bank && [ -f /proc/banktable/active ]; then
    local expected=$(uci get $CONFIG.$id.bank)
    local active=$(cat /proc/banktable/active)
    local booted=$(cat /proc/banktable/booted)
    if [ -z $expected ]; then
      # The previous firmware did not record the expected active bank so we
      # are not able to check it. Assume it is correct.
      expected=$active
    fi
    if [ "$expected" != "$active" ]; then
      value="2,programming new firmware failed"
    elif [ "$active" != "$booted" ]; then
      value="3,starting new firmware failed"
      # reset active bank to make future reboots predictable
      # (the upgrade failed so we must keep on booting the current firmware)
      cat /proc/banktable/booted >/proc/banktable/active
    fi
  fi
  echo $value
}

platform_is_dualbank() {
  grep bank_2 /proc/mtd >/dev/null
  return $?
}

#sanity checks
if [ "$TRANSFER_TYPE" != "download" ]; then
  echo "supports only download, not $TRANSFER_TYPE"
  exit 1
fi

if [ -z $TRANSFER_URL ]; then
  echo "no URL specified"
  ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Firmware upgrade error", "SpecificProblem":"no URL specified" }'

  if [ -f  /var/state/cwmpd ]; then
    local failure_count
    config_load cwmpd
    config_get failure_count cwmpd_config acs_upgrade_failures "0"
    failure_count=$(( failure_count + 1 ))
    sed -i "/cwmpd.cwmpd_config.acs_upgrade_failures/d" /var/state/cwmpd
    uci -P /var/state set cwmpd.cwmpd_config.acs_upgrade_failures="${failure_count}"
    uci -P /var/state commit cwmpd
  fi
  exit 1
fi

if [ -z $TRANSFER_ID ]; then
  #replace with something longer than 32 chars
  TRANSFER_ID="===Default==PlaceHolder==NULL==ID=="
else
  uciid=$(get_uci_id "$TRANSFER_ID")
  if [ -z $uciid ]; then
    TRANSFER_ID_DECODED=`echo $TRANSFER_ID | sed 's/../0x&\n/g' | awk '{ printf("%c",$0)}'`
    uciid=$(get_uci_id "$TRANSFER_ID_DECODED")
    if [ ! -z $uciid ]; then
      echo "FOUND matching TRANSFER_ID in DECODED form. Assuming upgraded from old build with transfer_id_space issue."
      TRANSFER_ID=$TRANSFER_ID_DECODED
    fi
  fi
fi

if [ "$TRANSFER_ACTION" = "start" ]; then
  E="0"
  STARTED=$(get_started "$TRANSFER_ID")
  if [ "$STARTED" != "yes" ]; then
    URL=$(get_url "$TRANSFER_URL" "$TRANSFER_USERNAME" "$TRANSFER_PASSWORD")
    set_started "$TRANSFER_ID" yes "$URL"
    uci show $CONFIG

    ubus send cwmpd.transfer '{ "session": "begins", "type": "upgrade" }'
    do_upgrade "$URL"
    #if do_upgrade returns, the upgrade failed, remember that
    if [ $? -eq 1 ]; then
      E="1,download upgrade image failed"
    else
      E="1,upgrade failed (not a valid signed rbi?)"
    fi

    set_error "$TRANSFER_ID" "$E"
    ubus send cwmpd.transfer '{ "session": "ends", "type": "upgrade" }'

    # In case of single bank, reboot the board
    platform_is_dualbank
    SINGLE_BANK=$?
    if [ $SINGLE_BANK == "1" ]; then
      echo "Single bank board, rebooting system..."
      reboot -f
      sleep 5
      echo b 2>/dev/null >/proc/sysrq-trigger
    fi
  else
    if [ -d $SCRIPT_DIR/target ]; then
      id="$(get_uci_id "$TRANSFER_ID")"
      if ! TARGET="$(uci get "$CONFIG.$id.target")"; then
        TARGET=gateway
      fi
      if ! echo "$TARGET" | grep -Eqx '[A-Za-z0-9_-]+'; then
        echo "Invalid target"
        exit 1
      fi

      GET_ERROR_PATH="$SCRIPT_DIR/target/$TARGET/get_error"
      if ! [ -x "$GET_ERROR_PATH" ]; then
        echo "Missing check_error script"
        exit 1
      fi

      STORED_ERROR="$(uci -q get "$CONFIG.$id.error")"
      if ! E="$("$GET_ERROR_PATH" "${STORED_ERROR:-0}" "$SCRIPT_DIR" "$CONFIG.$id" "$TRANSFER_ID")"; then
        echo "Unable to retrieve error"
        exit 1
      fi
    else 
      #retrieve error
      E=$(get_error "$TRANSFER_ID")
    if
  fi
  if [ "$E" != "0" ]; then
    local msg=$(echo $E | cut -d, -f2)
    echo "Upgrade error: $msg"
    if [ ! -z $ERROR_FILE ]; then
      echo $msg >$ERROR_FILE
    fi

    if [ -f  /var/state/cwmpd ]; then
      local failure_count
      config_load cwmpd
      config_get failure_count cwmpd_config acs_upgrade_failures "0"
      failure_count=$(( failure_count + 1 ))
      sed -i "/cwmpd.cwmpd_config.acs_upgrade_failures/d" /var/state/cwmpd
      uci -P /var/state set cwmpd.cwmpd_config.acs_upgrade_failures="${failure_count}"
      uci -P /var/state commit cwmpd
    fi

    ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Firmware upgrade error", "SpecificProblem":"'"$(echo $E | cut -d, -f2)"'", "AdditionalText":"URL='"$TRANSFER_URL"'"}'
    exit 1
  fi
  ubus send FaultMgmt.Event '{ "Source":"cwmpd", "EventType":"ACS provisioning", "ProbableCause":"Firmware upgrade success", "SpecificProblem":"", "AdditionalText":"URL='"$TRANSFER_URL"'"}'

  if [ -f /var/state/cwmpd ]; then
    local upgrade_time=$(date "+%FT%TZ")
    sed -i "/cwmpd.cwmpd_config.acs_last_upgrade_time/d" /var/state/cwmpd
    uci -P /var/state set cwmpd.cwmpd_config.acs_last_upgrade_time="${upgrade_time}"
    uci -P /var/state commit cwmpd
  fi

  exit 0
fi

if [ "$TRANSFER_ACTION" = "cleanup" ]; then
  if [ -d $SCRIPT_DIR/target ]; then
    id=$(get_uci_id "$TRANSFER_ID")
    if ! TARGET="$(uci get "$CONFIG.$id.target")"; then
      TARGET=gateway
    fi
    if ! echo "$TARGET" | grep -Eqx '[A-Za-z0-9_-]+'; then
      echo "Invalid target"
      exit 1
    fi

    CLEANUP_PATH="$SCRIPT_DIR/target/$TARGET/cleanup"
    if ! [ -x "$CLEANUP_PATH" ]; then
      echo "Missing cleanup script"
      exit 1
    fi

    set_started "$TRANSFER_ID" no
    exec "$CLEANUP_PATH" "$SCRIPT_DIR" "$CONFIG.$id" "$TRANSFER_ID"
  else
    set_started "$TRANSFER_ID" no
    # Remove RAW storage information if coming from legacy SW (transfer ID is hexadecimal)
    if [ -f /proc/banktable/legacy_upgrade/key ]; then
      [ "$TRANSFER_ID" == $(cat /proc/banktable/legacy_upgrade/key | hexdump -v -e '/1 "%02X"') ] && echo "1" > /proc/banktable/erase_upgrade_info
    fi
    # Upgrade finished succesfully, remove database and transfer information from passive bank (for dual bank platform)
    if is_dual_bank; then
      [ -f /overlay/$(cat /proc/banktable/notbooted 2>/dev/null)/etc/cwmpd.db ] && rm /overlay/$(cat /proc/banktable/notbooted)/etc/cwmpd.db
      [ -f /overlay/$(cat /proc/banktable/notbooted 2>/dev/null)/etc/config/cwmp_transfer ] && rm /overlay/$(cat /proc/banktable/notbooted)/etc/config/cwmp_transfer
    fi
    exit 0
  fi
fi

echo "Unknown transfer action: $TRANSFER_ACTION"
exit 1
