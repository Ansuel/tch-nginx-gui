#!/bin/sh
set -eu
state=/usr/share/modgui-luci-wireless
case "${1:-install}" in
  install)
    [ -f /usr/lib/lua/luci/controller/admin/network.lua ] || exit 1
    cd "$(dirname "$0")"
    mkdir -p "$state"
    find usr etc -type f | sed 's|^|/|' > "$state/files.new"
    cp -Rp usr/. /usr/
    cp -Rp etc/. /etc/
    cp setup.sh "$state/setup.sh"
    printf '%s\n' "$state/setup.sh" >> "$state/files.new"
    lua /usr/share/transformer/scripts/configure_luci_wireless.lua
    mv "$state/files.new" "$state/files"
    /etc/init.d/modgui-luci-qtn enable || /etc/init.d/modgui-luci-qtn enabled
    /etc/init.d/modgui-luci-qtn restart
    ;;
  remove)
    controller=/usr/lib/lua/luci/controller/admin/network.lua
    if [ -f "$controller.modgui-wireless-original" ] && grep -q 'luci.model.tch_wireless' "$controller"; then
      cp "$controller.modgui-wireless-original" "$controller"
      rm -f "$controller.modgui-wireless-original"
    fi
    rm -f /tmp/luci-indexcache /tmp/luci-modulecache/6C7563692E636F6E74726F6C6C65722E61646D696E2E6E6574776F726B /tmp/luci-modulecache/6C7563692E6D6F64656C2E7463685F776972656C657373
    rm -f /tmp/luci-modulecache/6D6F646775692E6C7563695F71746E /tmp/luci-modulecache/6D6F646775692E7770615F70736B
    keep_qtn=0
    if [ -f /usr/lib/lua/modgui/luci_qtn.lua ] && lua -e 'os.exit(#require("modgui.luci_qtn").list()>0 and 0 or 1)'; then
      keep_qtn=1
      echo 'Keeping the small Quantenna runtime to preserve configured 5 GHz networks'
    else
      /etc/init.d/modgui-luci-qtn stop || true
      /etc/init.d/modgui-luci-qtn disable || true
    fi
    if [ -f "$state/files" ]; then
      while IFS= read -r file; do
        case "$file" in
          /usr/lib/lua/modgui/luci_qtn.lua|/usr/lib/lua/modgui/wpa_psk.lua|/usr/share/modgui-luci-wireless/qtn-worker.lua|/etc/init.d/modgui-luci-qtn)
            [ "$keep_qtn" = 0 ] || continue ;;
        esac
        case "$file" in /usr/lib/lua/luci/*|/usr/lib/lua/modgui/luci_qtn.lua|/usr/lib/lua/modgui/wpa_psk.lua|/usr/share/modgui-luci-wireless/*|/usr/share/transformer/scripts/configure_luci_wireless.lua|/etc/init.d/modgui-luci-qtn) rm -f "$file" ;; *) exit 1 ;; esac
      done < "$state/files"
      rm -f "$state/files"
    fi
    ;;
  *) exit 1 ;;
esac
