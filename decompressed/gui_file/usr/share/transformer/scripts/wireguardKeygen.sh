#!/bin/sh

umask 077

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
client)
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
  network_base="${address%/*}"
  prefix="${address#*/}"
  client_address="${network_base%.*}.10"
  [ "$client_address" != "$network_base" ] || client_address="${network_base%.*}.11"
  case "$client_address" in
  '' | *[!0-9.]*) client_address="10.66.66.10" ;;
  esac
  case "$prefix" in
  '' | *[!0-9]*) prefix="24" ;;
  esac
  client_private="$("$wg_tool" genkey 2>/dev/null)"
  client_public="$(public_of "$client_private")"
  preshared="$("$wg_tool" genpsk 2>/dev/null)"
  { [ -n "$client_private" ] && [ -n "$client_public" ] && [ -n "$preshared" ]; } || {
    echo "Key generation failed" >&2
    exit 1
  }
  cat > /tmp/modgui-wireguard-client.conf <<EOF
[Interface]
PrivateKey = $client_private
Address = $client_address/32

[Peer]
PublicKey = $server_public
PresharedKey = $preshared
Endpoint = $endpoint_host:$port
AllowedIPs = $network_base/$prefix
PersistentKeepalive = 25
EOF
  chmod 600 /tmp/modgui-wireguard-client.conf
  echo "public=$client_public"
  ;;
*)
  echo "Usage: $0 interface|client [endpoint-host]"
  exit 1
  ;;
esac
