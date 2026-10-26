#!/bin/sh

umask 077

keygen_lock=/tmp/modgui-wireguard-keygen.lock
mkdir "$keygen_lock" 2>/dev/null || {
  echo "Another WireGuard key generation is already running" >&2
  exit 1
}
trap 'rm -rf "$keygen_lock"' EXIT HUP INT TERM

wg_tool=""
[ -x /usr/bin/wg-go ] && wg_tool="/usr/bin/wg-go"
[ -n "$wg_tool" ] || wg_tool="$(command -v wg 2>/dev/null)"
if [ -z "$wg_tool" ]; then
  echo "WireGuard runtime is not installed"
  exit 1
fi

public_of() {
  # The Go userspace tool reads stdin line-by-line and reports EOF when the
  # final key is not newline terminated.
  printf '%s\n' "$1" | "$wg_tool" pubkey 2>/dev/null
}

case "$1" in
interface)
  if [ "$2" = "export" ]; then
    private="$("$wg_tool" genkey 2>/dev/null)"
    public="$(public_of "$private")"
    { [ -n "$private" ] && [ -n "$public" ]; } || {
      echo "Key generation failed" >&2
      exit 1
    }
    echo "private=$private"
    echo "public=$public"
    exit 0
  fi
  private="$(uci -q get wireguard.wg.private_key)"
  if [ -n "$private" ] && [ "$2" != "force" ]; then
    public="$(public_of "$private")"
    [ -n "$public" ] || exit 1
    echo "public=$public"
    exit 0
  fi
  private="$("$wg_tool" genkey 2>/dev/null)"
  public="$(public_of "$private")"
  { [ -n "$private" ] && [ -n "$public" ]; } || {
    echo "Key generation failed" >&2
    exit 1
  }
  uci set wireguard.wg.private_key="$private"
  uci set wireguard.wg.public_key="$public"
  uci commit wireguard
  chmod 600 /etc/config/wireguard
  echo "public=$public"
  ;;
client | client-profile)
  client_mode="$1"
  server_public="${3:-$(uci -q get wireguard.wg.public_key)}"
  [ -n "$server_public" ] || {
    echo "Generate the gateway key pair first" >&2
    exit 1
  }
  port="${4:-$(uci -q get wireguard.wg.listen_port)}"
  [ -n "$port" ] || port=51820
  endpoint_host="$(printf '%s' "${2:-}" | tr -cd 'A-Za-z0-9.-')"
  [ -n "$endpoint_host" ] || endpoint_host="vpn.example.net"
  address="${5:-$(uci -q get wireguard.wg.address)}"
  server_address="${address%/*}"
  prefix="${address#*/}"
  network_base="${server_address%.*}"
  case "$prefix" in
  '' | *[!0-9]*) prefix="24" ;;
  esac
  case "$network_base" in
  '' | *[!0-9.]*) network_base="10.66.66" ;;
  esac

  requested_address="${7%/32}"
  requested_octet="${requested_address##*.}"
  case "$requested_octet" in
  '' | *[!0-9]*) requested_octet=0 ;;
  esac
  if [ "${requested_address%.*}" = "$network_base" ] &&
    [ "$requested_octet" -ge 2 ] && [ "$requested_octet" -le 254 ] &&
    [ "$requested_address" != "$server_address" ]; then
    client_octet="$requested_octet"
    client_address="$requested_address"
  else
    # Root CLI fallback. The WebUI supplies an address selected through
    # Transformer because the Nginx worker cannot read the mode-0600 UCI file.
    client_octet=2
    while [ "$client_octet" -le 254 ]; do
      client_address="$network_base.$client_octet"
      if [ "$client_address" != "$server_address" ] &&
        ! uci -q show wireguard 2>/dev/null | grep -F "allowed_ips='$client_address/32'" >/dev/null; then
        break
      fi
      client_octet=$((client_octet + 1))
    done
  fi
  [ "$client_octet" -le 254 ] || {
    echo "No free client address is available" >&2
    exit 1
  }

  peer_name="$(printf '%s' "${6:-client-$client_octet}" | tr -cd 'A-Za-z0-9_. -' | cut -c1-64)"
  [ -n "$peer_name" ] || peer_name="client-$client_octet"
  client_private="$("$wg_tool" genkey 2>/dev/null)"
  client_public="$(public_of "$client_private")"
  preshared="$("$wg_tool" genpsk 2>/dev/null)"
  { [ -n "$client_private" ] && [ -n "$client_public" ] && [ -n "$preshared" ]; } || {
    echo "Key generation failed" >&2
    exit 1
  }
  cat > /tmp/modgui-wireguard-client.conf <<EOF
[Interface]
PrivateKey=$client_private
Address=$client_address/32

[Peer]
PublicKey=$server_public
PresharedKey=$preshared
Endpoint=$endpoint_host:$port
AllowedIPs=$network_base.0/$prefix
EOF
  if [ "$(id -u)" = "0" ]; then
    chown root:nogroup /tmp/modgui-wireguard-client.conf
    chmod 640 /tmp/modgui-wireguard-client.conf
  else
    chmod 600 /tmp/modgui-wireguard-client.conf
  fi
  if [ "$client_mode" = "client" ]; then
    peer_section="$(uci add wireguard peer)" || {
      rm -f /tmp/modgui-wireguard-client.conf
      exit 1
    }
    uci set "wireguard.$peer_section.enabled=1" &&
      uci set "wireguard.$peer_section.name=$peer_name" &&
      uci set "wireguard.$peer_section.public_key=$client_public" &&
      uci set "wireguard.$peer_section.preshared_key=$preshared" &&
      uci set "wireguard.$peer_section.endpoint_host=" &&
      uci set "wireguard.$peer_section.endpoint_port=" &&
      uci set "wireguard.$peer_section.allowed_ips=$client_address/32" &&
      uci set "wireguard.$peer_section.persistent_keepalive=" &&
      uci commit wireguard || {
        uci -q delete "wireguard.$peer_section"
        uci -q commit wireguard
        rm -f /tmp/modgui-wireguard-client.conf
        exit 1
      }
  fi
  printf '%s\n' "$peer_name" > /tmp/modgui-wireguard-client.name
  if [ "$(id -u)" = "0" ]; then
    chown root:nogroup /tmp/modgui-wireguard-client.name
    chmod 640 /tmp/modgui-wireguard-client.name
  else
    chmod 600 /tmp/modgui-wireguard-client.name
  fi
  echo "public=$client_public"
  echo "preshared=$preshared"
  echo "peer=$peer_name"
  echo "address=$client_address/32"
  if [ "$client_mode" = "client" ] && [ "$(uci -q get wireguard.wg.enabled)" = "1" ]; then
    /usr/share/transformer/scripts/wireguardApply.sh >/dev/null 2>&1 || {
      echo "Peer saved, but the running interface could not be refreshed" >&2
      exit 1
    }
  fi
  ;;
*)
  echo "Usage: $0 interface|client|client-profile [endpoint-host]"
  exit 1
  ;;
esac
