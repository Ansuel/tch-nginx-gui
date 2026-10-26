#!/bin/sh

backend="Stopped"
online="false"
ip_address=""
dns_name=""
version="$(uci -q get tailscale.service.download_url | sed -n 's|.*tailscale_\([0-9][0-9.]*\)_[^/]*\.tgz|\1|p')"
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

if [ "$enabled" = "1" ] && /etc/init.d/tailscale running >/dev/null 2>&1; then
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
if [ -n "$ip_address" ] && [ -S /var/run/tailscale/tailscaled.sock ]; then
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
printf 'backend=%s\nonline=%s\nip=%s\ndns=%s\nversion=%s\nauth_url=%s\nphase=%s\nmessage=%s\n' \
  "$backend" "$online" "$ip_address" "$dns_name" "$version" "$auth_url" "$phase" "$message"
