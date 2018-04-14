#!/bin/sh

unset CDPATH

SCRIPTNAME=/etc/fwdassist.sh

CUSTO_RULES=/etc/ra_forward.sh

export RA_NAME=
export DATAFILE=
export ENABLED=
export IFNAME=
export LAN_PORT=
export WAN_PORT=
export WAN_IP=

load_value()
{
  local DATAFILE=$1
  local KEY=$2
  local L=$(grep $KEY $DATAFILE)
  if [ -n $L ]; then
    echo $L | cut -d'=' -f 2 | tr -d ' '
  fi  
}

get_state_value()
{
  local option=$1

  uci -P /var/state get ra.$RA_NAME.$option 2>/dev/null
}

state_value_changed()
{
  local option=$1
  local oldvalue=$2
  
  local V=$(get_state_value $option)
  if [ "$V" = $oldvalue ]; then
    # not changed
    return 1
  fi
  return 0
}

status_changed()
{
  state_value_changed enabled $ENABLED && return 0
  state_value_changed wanip $WAN_IP && return 0
  state_value_changed lanport $LAN_PORT && return 0
  state_value_changed wanport $WAN_PORT && return 0
  # value not changed
  return 1
}

apply()
{
  local RULE=$1
  logger -t RAFWD -- $RULE
  iptables $RULE
}

apply_rules()
{
  if [ -z $WAN_IP ]; then
    return
  fi

  #if [ -x $CUSTO_RULES ]; then
  #  $CUSTO_RULES
  #else
    if [ "$ENABLED" = "1" ]; then
      ACT="-I"
    else
      ACT="-D"
    fi
	
	local LAN_PORT="443"
	
    local FWD_RULE="-t nat $ACT PREROUTING -m tcp -p tcp --dst $WAN_IP --dport $WAN_PORT -j REDIRECT --to-ports $LAN_PORT"
    local FWD_NULL="-t nat $ACT PREROUTING -p tcp --dst $WAN_IP --dport $LAN_PORT -j REDIRECT --to-port 65535"
    local ACCEPT_RULE="-t filter $ACT INPUT -p tcp --dst $WAN_IP --dport $LAN_PORT -j ACCEPT"

    if [ "$LAN_PORT" != "$WAN_PORT" ]; then
      apply "$FWD_RULE"
      apply "$FWD_NULL"
    fi
    apply "$ACCEPT_RULE"
  #fi
}

disable()
{
  local enabled=$ENABLED
  local wanip=$WAN_IP
  local lanport=$LAN_PORT
  local wanport=$WAN_PORT

  ENABLED=0
  WAN_IP=$(get_state_value wanip)
  LAN_PORT=$(get_state_value lanport)
  WAN_PORT=$(get_state_value wanport)

  apply_rules

  ENABLED=$enabled
  WAN_IP=$wanip
  LAN_PORT=$lanport
  WAN_PORT=$wanport
}

update_state()
{
  if [ ! -f /etc/config/ra ]; then
    touch /etc/config/ra
  fi
  uci -P /var/state set ra.$RA_NAME=rastate
  uci -P /var/state set ra.$RA_NAME.enabled=$ENABLED
  uci -P /var/state set ra.$RA_NAME.wanip=$WAN_IP
  uci -P /var/state set ra.$RA_NAME.lanport=$LAN_PORT
  uci -P /var/state set ra.$RA_NAME.wanport=$WAN_PORT
}

redirect()
{
  DATAFILE=$1
  ENABLED=$(load_value $DATAFILE enabled)
  IFNAME=$(load_value $DATAFILE ifname)
  LAN_PORT=$(load_value $DATAFILE lanport)
  local WAN_PORT=$(load_value $DATAFILE wanport)

  if [ -z $IFNAME ]; then
    return
  fi
  WAN_IP=$(lua -e "dm=require'datamodel';r=dm.get('rpc.network.interface.@$IFNAME.ipaddr'); \
           if r and r[1] then print(r[1].value) end")

  if status_changed ; then
    disable
    apply_rules
    update_state
  fi

}

lock()
{
  local lockdir=/var/lock/ra-$RA_NAME
  mkdir $lockdir
  while [ $? -ne 0 ]; do
    sleep 1
    mkdir $lockdir
  done
}

unlock()
{
  rmdir /var/lock/ra-$RA_NAME
}

# make sure it gets reloaded when the firewall is restarted
# we create the uci config before the actuals rules in case the
# custom rules want to update the section.
# They will have to set reloqd to 1 if they set rules into one
# of the internal chains. (not recommended though)
COMMIT_FIREWALL=0
S=$(uci get firewall.fwdassist.path 2>/dev/null)
if [ "$S" != "$SCRIPTNAME" ]; then
  uci set firewall.fwdassist=include
  uci set firewall.fwdassist.path=$SCRIPTNAME
  COMMIT_FIREWALL=1
fi
S=$(uci get firewall.fwdassist.reload 2>/dev/null)
if [ "$S" != 0 ]; then
  uci set firewall.fwdassist.reload=0
  COMMIT_FIREWALL=1
fi
if [ $COMMIT_FIREWALL -ne 0 ]; then
  uci commit firewall
fi

for datafile in $(ls /var/run/assistance/*); do
  RA_NAME=$(basename $datafile)
  lock
  redirect $datafile
  unlock
done

