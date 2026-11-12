#!/bin/sh

backend="Stopped"
online="false"
ip_address=""
dns_name=""
version="$(uci -q get tailscale.service.version)"
[ -n "$version" ] || version="$(uci -q get tailscale.service.download_url | sed -n 's|.*tailscale_\([0-9][0-9.]*\)_[^/]*\.tgz|\1|p')"
auth_url=""
phase="stopped"
message="Service disabled"
enabled="$(uci -q get tailscale.service.enabled)"
service_running="false"

ip_address="$(ip -4 addr show dev tailscale0 2>/dev/null | awk '/inet / { sub("/.*", "", $2); print $2; exit }')"

if [ -r /tmp/modgui-tailscale-auth ]; then
  auth_url="$(grep -Eo 'https://login\.tailscale\.com/[^[:space:]]+' /tmp/modgui-tailscale-auth | tail -n 1)"
fi

read_worker_status() {
  [ -r "$1" ] || return 0
  worker_state="$(sed -n 's/^state=//p' "$1" | tail -n 1)"
  worker_message="$(sed -n 's/^message=//p' "$1" | tail -n 1)"
  [ -z "$worker_state" ] || phase="$worker_state"
  [ -z "$worker_message" ] || message="$worker_message"
}

# nginx runs as nobody: rc.common's running command attempts to create a
# root-owned procd lock. Inspect processes without taking locks or calling ubus.
daemon_running=false
pidof tailscaled >/dev/null 2>&1 && daemon_running=true
if [ "$enabled" = "1" ] && { [ "$daemon_running" = true ] ||
  pgrep -f '^(/bin/sh )?/usr/share/modgui-tailscale/tailscale[.]bootstrap$' >/dev/null 2>&1; }; then
	service_running="true"
	phase="starting"
	message="Preparing Tailscale"
	read_worker_status /tmp/modgui-tailscale-runtime-status
	read_worker_status /tmp/modgui-tailscale-connect-status
fi
if [ "$service_running" = "true" ] && [ -n "$auth_url" ]; then
	phase="authorization_required"
	message="Authorization required"
fi
if [ "$daemon_running" = true ] && [ -n "$ip_address" ] && [ -S /var/run/tailscale/tailscaled.sock ]; then
  online="true"
  phase="connected"
  message="Connected"
fi
if [ "$service_running" = "true" ] && [ ! -S /var/run/tailscale/tailscaled.sock ] && \
    { [ "$phase" = "connected" ] || [ -z "$phase" ]; }; then
	online="false"
	phase="starting"
	message="Preparing Tailscale"
fi
if [ "$service_running" != "true" ]; then
	online="false"
	phase="stopped"
	message="Service stopped"
fi
backend="$phase"

[ -n "$backend" ] || backend="Stopped"
[ "$online" = "true" ] || online="false"

funnel_state=disabled
funnel_message="Funnel disabled"
funnel_url=""
funnel_approval_url=""
if [ "$service_running" = true ] && [ "$(uci -q get tailscale.service.funnel_enabled)" = 1 ] &&
  [ "$(uci -q get tailscale.service.connect)" = 1 ]; then
  funnel_state=waiting
  funnel_message="Waiting for Tailscale connection"
  if [ -r /tmp/modgui-tailscale-funnel-status ]; then
    funnel_state="$(sed -n 's/^state=//p' /tmp/modgui-tailscale-funnel-status | tail -n 1)"
    funnel_message="$(sed -n 's/^message=//p' /tmp/modgui-tailscale-funnel-status | tail -n 1)"
    funnel_url="$(sed -n 's/^url=//p' /tmp/modgui-tailscale-funnel-status | tail -n 1)"
    funnel_approval_url="$(sed -n 's/^approval_url=//p' /tmp/modgui-tailscale-funnel-status | tail -n 1)"
  fi
  if [ "$online" != true ] && [ "$funnel_state" = active ]; then
    funnel_state=waiting
    funnel_url=""
  fi
fi
printf 'backend=%s\nonline=%s\nip=%s\ndns=%s\nversion=%s\nauth_url=%s\nphase=%s\nmessage=%s\n' \
  "$backend" "$online" "$ip_address" "$dns_name" "$version" "$auth_url" "$phase" "$message"
printf 'funnel_state=%s\nfunnel_message=%s\nfunnel_url=%s\nfunnel_approval_url=%s\n' \
  "$funnel_state" "$funnel_message" "$funnel_url" "$funnel_approval_url"

ssh_state=disabled
ssh_message="Funnel disabled"
ssh_url=""
ssh_approval_url=""
if [ "$service_running" = true ] && [ "$(uci -q get tailscale.service.funnel_ssh_enabled)" = 1 ] &&
  [ "$(uci -q get tailscale.service.connect)" = 1 ]; then
  ssh_state=waiting
  if [ -r /tmp/modgui-tailscale-funnel-ssh-status ]; then
    ssh_state="$(sed -n 's/^state=//p' /tmp/modgui-tailscale-funnel-ssh-status | tail -n 1)"
    ssh_message="$(sed -n 's/^message=//p' /tmp/modgui-tailscale-funnel-ssh-status | tail -n 1)"
    ssh_url="$(sed -n 's/^url=//p' /tmp/modgui-tailscale-funnel-ssh-status | tail -n 1)"
    ssh_approval_url="$(sed -n 's/^approval_url=//p' /tmp/modgui-tailscale-funnel-ssh-status | tail -n 1)"
  fi
  if [ "$online" != true ] && [ "$ssh_state" = active ]; then ssh_state=waiting; ssh_url=""; fi
fi
printf 'funnel_ssh_state=%s\nfunnel_ssh_message=%s\nfunnel_ssh_url=%s\nfunnel_ssh_approval_url=%s\n' \
  "$ssh_state" "$ssh_message" "$ssh_url" "$ssh_approval_url"
