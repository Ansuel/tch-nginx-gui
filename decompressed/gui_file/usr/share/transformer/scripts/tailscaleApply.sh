#!/bin/sh

enabled="$(uci -q get tailscale.service.enabled)"
connect="$(uci -q get tailscale.service.connect)"
port="$(uci -q get tailscale.service.port)"
hostname="$(uci -q get tailscale.service.hostname)"
advertise_routes="$(uci -q get tailscale.service.advertise_routes)"
advertise_exit_node="$(uci -q get tailscale.service.advertise_exit_node)"
accept_routes="$(uci -q get tailscale.service.accept_routes)"
ssh_enabled="$(uci -q get tailscale.service.ssh)"
funnel_enabled="$(uci -q get tailscale.service.funnel_enabled)"
funnel_port="$(uci -q get tailscale.service.funnel_port)"
funnel_target_port="$(uci -q get tailscale.service.funnel_target_port)"
funnel_target_ip="$(uci -q get tailscale.service.funnel_target_ip)"
funnel_ssh_enabled="$(uci -q get tailscale.service.funnel_ssh_enabled)"
funnel_ssh_port="$(uci -q get tailscale.service.funnel_ssh_port)"
funnel_ssh_target_ip="$(uci -q get tailscale.service.funnel_ssh_target_ip)"
funnel_ssh_target_port="$(uci -q get tailscale.service.funnel_ssh_target_port)"
[ -n "$funnel_target_ip" ] || funnel_target_ip=127.0.0.1
[ -n "$funnel_ssh_target_ip" ] || funnel_ssh_target_ip=127.0.0.1
[ -n "$funnel_ssh_target_port" ] || funnel_ssh_target_port=22

remove_network() {
  uci -q delete firewall.modgui_tailscale_udp
  uci -q delete firewall.modgui_tailscale_to_lan
  uci -q delete firewall.modgui_tailscale_to_wan
  uci -q delete firewall.modgui_lan_to_tailscale
  uci -q delete firewall.modgui_tailscale_zone
  uci -q delete network.modgui_tailscale
  uci commit firewall
  uci commit network
  /etc/init.d/network reload >/dev/null 2>&1
  /etc/init.d/firewall reload >/dev/null 2>&1
}

configure_network() {
  uci -q delete network.modgui_tailscale
  uci set network.modgui_tailscale=interface
  uci set network.modgui_tailscale.proto='none'
  uci set network.modgui_tailscale.ifname='tailscale0'

  uci -q delete firewall.modgui_tailscale_zone
  uci set firewall.modgui_tailscale_zone=zone
  uci set firewall.modgui_tailscale_zone.name='tailscale'
  uci add_list firewall.modgui_tailscale_zone.network='modgui_tailscale'
  uci set firewall.modgui_tailscale_zone.device='tailscale0'
  uci set firewall.modgui_tailscale_zone.input='ACCEPT'
  uci set firewall.modgui_tailscale_zone.output='ACCEPT'
  uci set firewall.modgui_tailscale_zone.forward='REJECT'
  uci set firewall.modgui_tailscale_zone.masq='1'
  uci set firewall.modgui_tailscale_zone.mtu_fix='1'

  uci -q delete firewall.modgui_tailscale_udp
  uci set firewall.modgui_tailscale_udp=rule
  uci set firewall.modgui_tailscale_udp.name='Allow-ModGUI-Tailscale'
  uci set firewall.modgui_tailscale_udp.src='wan'
  uci set firewall.modgui_tailscale_udp.proto='udp'
  uci set firewall.modgui_tailscale_udp.dest_port="$port"
  uci set firewall.modgui_tailscale_udp.target='ACCEPT'

  uci -q delete firewall.modgui_tailscale_to_lan
  if [ -n "$advertise_routes" ]; then
    uci set firewall.modgui_tailscale_to_lan=forwarding
    uci set firewall.modgui_tailscale_to_lan.src='tailscale'
    uci set firewall.modgui_tailscale_to_lan.dest='lan'
  fi

  uci -q delete firewall.modgui_tailscale_to_wan
  if [ "$advertise_exit_node" = "1" ]; then
    uci set firewall.modgui_tailscale_to_wan=forwarding
    uci set firewall.modgui_tailscale_to_wan.src='tailscale'
    uci set firewall.modgui_tailscale_to_wan.dest='wan'
  fi

  uci -q delete firewall.modgui_lan_to_tailscale
  if [ "$accept_routes" = "1" ]; then
    uci set firewall.modgui_lan_to_tailscale=forwarding
    uci set firewall.modgui_lan_to_tailscale.src='lan'
    uci set firewall.modgui_lan_to_tailscale.dest='tailscale'
  fi

  uci commit network
  uci commit firewall
  /etc/init.d/network reload >/dev/null 2>&1 || return 1
  /etc/init.d/firewall reload >/dev/null 2>&1 || return 1
}

# Disabling must work even when connection settings are invalid or the
# daemon cannot answer Funnel requests. Preserve failed Funnel ownership
# markers for retry, but always stop the daemon and remove its network.
if [ "$enabled" != "1" ]; then
  /usr/share/modgui-tailscale/tailscale.connect funnel-stop || echo "Cannot clear saved HTTP Funnel configuration; stopping daemon" >&2
  /usr/share/modgui-tailscale/tailscale.connect funnel-ssh-stop || echo "Cannot clear saved SSH Funnel configuration; stopping daemon" >&2
  if [ -S /var/run/tailscale/tailscaled.sock ]; then
    /usr/sbin/tailscale down >/dev/null 2>&1
  fi
  /etc/init.d/tailscale disable
  /etc/init.d/tailscale stop >/dev/null 2>&1 || exit 1
  rm -f /tmp/modgui-tailscale-auth
  remove_network
  exit 0
fi

if [ "$funnel_enabled" = "1" ]; then
  case "$funnel_port" in 443 | 8443 | 10000) ;; *) echo "Invalid Funnel HTTPS port" >&2; exit 1 ;; esac
  /usr/share/modgui-tailscale/tailscale.connect validate-target "$funnel_target_ip" "$funnel_target_port" || {
    echo "Invalid Funnel destination IP or port" >&2; exit 1;
  }
fi
if [ "$funnel_ssh_enabled" = 1 ]; then
  case "$funnel_ssh_port" in 443 | 8443 | 10000) ;; *) echo "Invalid SSH Funnel port" >&2; exit 1 ;; esac
  [ "$funnel_enabled" != 1 ] || [ "$funnel_ssh_port" != "$funnel_port" ] || {
    echo "HTTP and SSH Funnel must use different public ports" >&2; exit 1;
  }
  /usr/share/modgui-tailscale/tailscale.connect validate-target "$funnel_ssh_target_ip" "$funnel_ssh_target_port" || {
    echo "Invalid SSH Funnel destination IP or port" >&2; exit 1;
  }
  if [ "$funnel_ssh_target_ip" = 127.0.0.1 ] &&
    { [ "$funnel_ssh_target_port" = 22 ] || [ "$funnel_ssh_target_port" = 2222 ]; } &&
    [ "$(uci -q get tailscale.service.funnel_ssh_password_auth)" != 1 ]; then
    { [ -s /etc/dropbear/authorized_keys ] || [ -s /root/.ssh/authorized_keys ]; } || {
      echo "Install an SSH public key before enabling SSH Funnel" >&2; exit 1;
    }
  fi
fi

[ "$enabled" = "1" ] || enabled=0
[ "$connect" = "1" ] || connect=0
[ "$advertise_exit_node" = "1" ] || advertise_exit_node=0
[ "$accept_routes" = "1" ] || accept_routes=0
[ "$ssh_enabled" = "1" ] || ssh_enabled=0
[ -n "$port" ] || port=41641

case "$port" in '' | *[!0-9]*) echo "Invalid Tailscale port" >&2; exit 1 ;; esac
[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 1
case "$hostname" in '' | [!a-zA-Z0-9]* | *[!a-zA-Z0-9.-]*) echo "Invalid Tailscale hostname" >&2; exit 1 ;; esac
case "$advertise_routes" in
  '') ;;
  *[!0-9./]*) echo "Invalid advertised subnet" >&2; exit 1 ;;
  *)
    ip="${advertise_routes%/*}"
    prefix="${advertise_routes#*/}"
    [ "$ip" != "$advertise_routes" ] || { echo "Advertised subnet requires CIDR notation" >&2; exit 1; }
    case "$prefix" in '' | *[!0-9]*) exit 1 ;; esac
    [ "$prefix" -ge 1 ] && [ "$prefix" -le 32 ] || exit 1
    ;;
esac

if [ ! -c /dev/net/tun ] && zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_TUN=y$'; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
fi
[ -c /dev/net/tun ] || { echo "TUN is unavailable" >&2; exit 1; }
configure_network || exit 1
/etc/init.d/tailscale enable
/etc/init.d/tailscale restart >/dev/null 2>&1 || exit 1
# Runtime download and `tailscale up` are intentionally handled by procd.
# Transformer kills commit/apply commands after 30 seconds, while a cold-start
# download on low-storage gateways can legitimately take longer.
exit 0
