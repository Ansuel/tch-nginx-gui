# OpenVPN extension — feasibility & asset report

Research report for building a GUI extension for OpenVPN on modgui, following the
pattern of the L2TP/IPsec extension added in commit `1141bd7d08ec80a127e373fee59781d172dcb71a`
(`app_l2tpipsec` in `appInstallRemoveUtility.sh`, `modgui-vpn` IPK).

Sources investigated (all verified locally):

- `tch-nginx-gui` repo (this repo), commit `1141bd7d`.
- `tch_firmware_extracted` repo (`https://github.com/FrancYescO/tch_firmware_extracted`,
  local clone at `tch_firmware_extracted`), all 60+ branches.
- `https://github.com/FrancYescO/sharing_tg789` @ `5c9015930961848259aa883cbe1a20c02a227de4`
  (`modgui-vpn_1.1-0_all.ipk`, sha256 `5604db2e143c339eb1db0cb980e30492c2e5f57c4e35f06b52d224fb4822de18` — verified).
- `https://github.com/Ansuel/GUI_ipk` (local clone at `GUI_ipk`) and the opkg feeds
  configured by `decompressed/gui_file/etc/modgui_scripts/02_specific.sh`.

## 1. Key findings (TL;DR)

1. **No OpenVPN GUI card exists in any extracted Technicolor firmware.** Every branch was
   searched (`www/**` for `vpn|l2tp|ipsec|openvpn`): the only native VPN card anywhere is
   `www/cards/014_l2tp-ipsec-server.lp` (ARM "closed" 16.2/17.2 branches, reused by `modgui-vpn`).
   The OpenVPN card and modal must be **written from scratch**; the L2TP card/modal are the best template.
2. **The `vbnt-l_16.3.7190-2761003-…` branch (vant-f MyRepublic, "Aqua 16.3", brcm63xx-tch
   MIPS/uClibc) contains the complete OpenVPN backend** — binary, init script, UCI config,
   user-file auth script, easy-rsa first-boot key generation, firewall helpers and, most
   importantly, **ready-made transformer mappings** (`rpc.openvpn.*`, `uci.openvpn`,
   `commitapply`). MyRepublic shipped the API but removed the GUI page.
3. The **ARM target firmware of modgui (16.1/16.2/17.x xtream "closed" branches) have no
   OpenVPN at all** — only an "OpenVPN" port-pinning preset (UDP/TCP 1194) already present in
   `www/lua/pfwd_helper.lua` of the firewall card.
4. **Runtime packages already exist in the feeds that modgui configures** for every supported
   arch (see §4), with the single caveat of `kmod-tun` on kernels built without `CONFIG_TUN`
   (same constraint the WireGuard extension already gates on; prebuilt `kmod-tun` IPKs for the
   4.1.38 / 4.1.52 ARM kernels exist in the `Ansuel/GUI_ipk` `kmods-4.1.38` / `kmods-4.1.52` branches).
5. The vbnt-l transformer maps are pure transformer Lua (`ucihelper`, `tch.posix`, `lfs`,
   `io.popen`) from the same GUI generation as `l2tp_ipsec_server.map` → **portable to the ARM
   targets as-is**, same trick `modgui-vpn` used. The vbnt-l **binaries are not portable**
   (MIPS uClibc vs ARM cortex-a9 targets).

## 2. Template: the L2TP/IPsec extension (commit `1141bd7d`)

GUI-side files that must be replicated for `openvpn`:

| File | Change made for l2tpipsec |
|---|---|
| `decompressed/gui_file/etc/modgui_scripts/01_prereq.sh` | add `openvpn_app` to `app_entities` |
| `decompressed/gui_file/etc/modgui_scripts/04_config.sh` | default state from `opkg list-installed`, GUI-repair `refresh` on upgrade |
| `decompressed/gui_file/usr/share/transformer/mappings/uci/modgui.map` | add `openvpn_app` option |
| `decompressed/gui_file/usr/share/transformer/mappings/rpc/system.modgui.map` | add `openvpn` to `app_list` |
| `decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh` | `app_openvpn()` + `call_app_type` case |
| `decompressed/gui_file/www/cards/009_extensions.lp` | arch-gated `mapParams` entry |
| `decompressed/gui_file/www/docroot/modals/applications-modal.lp` | `app_list` + `append_extension_card` entry |
| `decompressed/gui_file/www/lang/{it-it,de-de}/webui-core.po` | translations |
| `tests/test_extension_manager.py` | pin/checksum/ownership/arch-gate tests |
| `README.md`, `CHANGELOG.md`, `docs/extensions.md` | docs |

Installer behaviour to mirror (all in `app_l2tpipsec`): pinned commit + sha256 verified IPK,
package-ownership tracking (`/etc/.modgui-*-packages`, reverse-order removal), refuse when a
pre-existing install is detected, `require_free_space`, start disabled, GUI files backed up to
`/opt/*.tar.gz` and restored by `refresh`, `set_extension_state`, rollback helper on every
failure path.

The `modgui-vpn_1.1-0_all.ipk` layout (the model for a new `modgui-openvpn` all-arch IPK):

```
CONTROL (Depends: xl2tpd, strongswan-default)
etc/config/vpn, etc/config/ipsec
etc/init.d/l2tp-ipsec-server        # uci->conf setup + start/stop, state in uci_state
etc/init.d/modgui-ipsec             # procd wrapper; closes inherited lock fd: ipsec "$@" 1000>&-
etc/ppp/options.xl2tpd.template, etc/xl2tpd/xl2tpd.conf.template
lib/functions/firewall-l2tp-ipsec-server.sh   # own chain inserted into zone_wan_input, keyed
                                              # on uci_get_state vpn state l2tpipsecserver_active
usr/lib/l2tpipsecserver/setup.sh    # uci -> daemon config files (CHAP secrets, PSK, pools, DHCP opt 121)
usr/share/transformer/mappings/{uci,rpc}/l2tp_ipsec_server.map, uci/ipsec.map
usr/share/transformer/commitapply/uci_{ipsec,l2tp_ipsec_server}.ca
www/cards/014_l2tp-ipsec-server.lp
www/docroot/modals/l2tp-ipsec-server-modal.lp
www/lang/it-it/webui-l2tp-ipsec-server.po
preinst/postinst/prerm/postrm
```

## 3. Source assets: firmware branch `vbnt-l_16.3.7190-…` (MyRepublic vant-f, Aqua 16.3)

Retrieve with (local clone):

```sh
cd tch_firmware_extracted
B=vbnt-l_16.3.7190-2761003-20170907085601-501361d1f0abcd3206e49f0897c4a6cca07a114d
git show "origin/$B":<path> > <dest>
# or browse: https://github.com/FrancYescO/tch_firmware_extracted/tree/<B>/<path>
```

### 3.1 Transformer/GUI API (portable, pure Lua — reuse almost as-is)

| Path | Role |
|---|---|
| `usr/share/transformer/mappings/uci/openvpn.map` | `uci_1to1` map for config `openvpn`, sections `openvpn`: `enabled, client, port, proto, dev, ca, cert, key, dh, server, server_bk, cipher, comp_lzo, tls_auth, keepalive, duplicate_cn, max_clients, user, verb, name, script_security, auth_user_pass_verify, …` + lists `remote`, `push` |
| `usr/share/transformer/mappings/rpc/openvpn.map` | `rpc.openvpn.server.{ca,cert,key,dh}` read/write — GET reads `/etc/openvpn/{ca.crt,server.crt,server.key,dh2048.pem}`, SET writes them (CRLF-normalized). `rpc.openvpn.server.client.{ca,cert,key}` read-only: download `/etc/openvpn/client.{crt,key}` to build a client profile |
| `usr/share/transformer/mappings/rpc/openvpn.server.map` | `rpc.openvpn.server.user.@` CRUD (`username`/`password`) backed by plaintext `/etc/openvpn/psw-file` (lines `user<TAB>pass`) |
| `usr/share/transformer/commitapply/uci_openvpn.ca` | one line: `^openvpn%. /etc/init.d/openvpn restart` |
| `usr/share/transformer/mappings/rpc/ssid_ass_vpn.map` | optional MyRepublic extra: bind SSID ap4/ap5 to a VPN client routing table (skip for v1) |

The card can drive everything through these objects: enable/port/proto/`push` via
`uci.openvpn.@openvpn[server]`, certs via `rpc.openvpn.server*`, users via
`rpc.openvpn.server.user`. This is strictly more capable than the L2TP card needs were.

### 3.2 Runtime files (portable scripts; binaries are NOT portable)

| Path | Role / notes |
|---|---|
| `usr/sbin/openvpn` | 2.3.11, **MIPS MSB uClibc (brcm63xx-tch)** — reference only, cannot run on ARM targets |
| `etc/init.d/openvpn` | standard OpenWrt (chaos_calmer) procd init: renders `/var/etc/openvpn-<sec>.conf` from UCI sections, respawn, also starts free-standing `/etc/openvpn/*.conf`. The feed `openvpn-*` IPK ships an equivalent init — prefer the feed one, keep vbnt-l's as reference |
| `etc/openvpn/checkpwd.sh` | user/pass auth against `/etc/openvpn/psw-file` (`auth_user_pass_verify "/etc/openvpn/checkpwd.sh via-env"`) |
| `etc/openvpn/server_up.sh` / `server_down.sh` / `client_up.sh` / `client_down.sh` | call `ip_up_cb`/`ip_down_cb` from `lib/functions/vpn_common_inc.sh` |
| `etc/uci-defaults/tch_0090-openvpn-key-generate` | first-boot CA/server/**shared client** cert gen with **easy-rsa 3 batch syntax** (`easyrsa --batch init-pki`, `build-ca nopass`, `gen-req`, `sign`) — matches feed `openvpn-easy-rsa 3.x` on ARM, must be adapted for the 2013 easy-rsa 2.x package on the mips feed |
| `etc/openvpn/dh2048.pem` | pregenerated DH params |
| `etc/config/openvpn` | default sections: `server` (tun/udp 1194, `server 10.8.0.0 255.255.255.0`, `duplicate_cn 1`, `keepalive 10 120`, `cipher AES-128-CBC`, psw-file auth, up/down scripts, `script_security 3`) + `client1..client5` |
| `lib/functions/vpn_common_inc.sh`, `vpn_openvpn.sh` | dynamic iptables wiring — **MyRepublic-specific**: inserts/removes `VPN_COMMON_*`-commented rules next to the `delegate_input/output/forward` chain rules |
| `etc/config/firewall` (line ~150) | factory ships `DROP udp wan --> 1194` ("openvpn") — server off by default at firewall level too |
| `usr/lib/opkg/info/*.control` | provenance: `openvpn-openssl 2.3.11-2`, `openvpn-server 1.0-1` (Technicolor key-gen + checkpwd pkg), `openvpn-easy-rsa`, `conf-openvpn`, `vpn-common`, `mappings-mrvpn` ("Transformer myrepublic vpn mapping files") |

Firewall note for modgui: the ARM targets use fw3-style `zone_wan_input`; `modgui-vpn` already
proves the right pattern there — a dedicated chain inserted into `zone_wan_input` keyed on the
service state (`firewall-l2tp-ipsec-server.sh` style: open `udp 1194` [+ `tcp 1194` fallback]
only while enabled). Do **not** reuse vbnt-l's `delegate_*` helpers unless verified on target.
`www/lua/pfwd_helper.lua` on all target firmwares already exposes an "OpenVPN" 1194 pinhole preset
(purely a GUI convenience, independent of the service).

### 3.3 What vbnt-l does NOT provide

- No card, modal, `.po`, or web rules for OpenVPN (`www` only references it in `pfwd_helper.lua`).
- No TR-069 mapping for OpenVPN; the RPC maps were consumed by MyRepublic's remote management.

## 4. Runtime packages per target (feeds already configured by `02_specific.sh`)

| Target (`02_specific.sh` case) | Feed | openvpn | deps | kmod-tun |
|---|---|---|---|---|
| armv7l 18.\*/19.\* | Ansuel `GUI_ipk/kernel-4.1` (+ macoers VANTW) | `openvpn-openssl 2.4.5-4.2` (`arm_cortex-a9_neon`, ~216 KB), `openvpn-mbedtls`, `openvpn-nossl`, `openvpn-easy-rsa 3.0.4` | `liblzo`, `libopenssl`/`libmbedtls` present in feed | **missing** in feed; prebuilt `kmod-tun` IPKs published in `Ansuel/GUI_ipk` branches `kmods-4.1.38` / `kmods-4.1.52` (`kmod-tun-damson-4.1.52-manual_4.1.52-1_brcm963xx.ipk`, kernel-matched magic — gate on kernel version, reuse the `wireguard_tun_supported()` check: `/dev/net/tun` or `CONFIG_TUN=y` from `/proc/config.gz`; on 20.3.c/21.4 TUN is already built in) |
| armv7l 17.3\* | `repository.ilpuntotecnico.com/files/roleo/public/agtef/1.1.0/brcm63xx-tch` | `openvpn-openssl 2.3.18-1` (+ mbedtls/polarssl/nossl variants), `openvpn-easy-rsa (2013-01-30, easy-rsa 2.x)` | `liblzo`, `libopenssl` present | `kmod-tun 3.4.11-1` present |
| armv7l 16.1\*/16.2\* (xtream) | `FrancYescO/789vacv2_opkg/xtream35b` | **not present** | — | not present → self-host the IPK in `sharing_tg789` (pinned+sha256, like `modgui-vpn`) or skip these old builds at v1 |
| mips 16.\*/17.\* | `archive.openwrt.org/chaos_calmer/15.05.1/brcm63xx/generic` | `openvpn-openssl 2.3.6-5` | `liblzo`, `libopenssl` present | `kmod-tun 3.18.23-1` present (kernel-magic `kernel (=3.18.23-1-…)` — same constraint regime the L2TP kmods already live with) |

The vbnt-l binaries themselves are `MIPS MSB uClibc brcm63xx-tch` (16.3/Aqua vintage): useful as
last-resort donor binaries for old MIPS targets, not usable on ARM.

## 5. Recommended build plan (`modgui-openvpn`)

1. **New all-arch IPK `modgui-openvpn`** in `FrancYescO/sharing_tg789` (pinned commit + sha256),
   containing only arch-independent parts:
   - transformer maps from vbnt-l §3.1 (`uci/openvpn.map`, `rpc/openvpn.map`,
     `rpc/openvpn.server.map`, `commitapply/uci_openvpn.ca`; skip `ssid_ass_vpn.map` at v1);
   - `etc/config/openvpn` defaults from vbnt-l §3.2 (server section; add `enabled 0`);
   - `etc/openvpn/checkpwd.sh` (+ `server_up.sh`/`server_down.sh` — or drop them and reuse the
     feed package's init + a `firewall-modgui-openvpn.sh` chain helper modeled on
     `lib/functions/firewall-l2tp-ipsec-server.sh` from `modgui-vpn`);
   - key generation script adapted from `tch_0090-openvpn-key-generate` with a branch for
     easy-rsa 2.x (mips feed) vs 3.x (ARM feed), run once on first start;
   - `www/cards/0XX_openvpn-server.lp`, `www/docroot/modals/openvpn-server-modal.lp`,
     `www/lang/it-it/webui-openvpn-server.po` — **new work**, modeled on the L2TP card/modal,
     backed by `uci.openvpn` + `rpc.openvpn.server.*` + `rpc.openvpn.server.user`;
   - CONTROL `Depends: openvpn-openssl, openvpn-easy-rsa` (kmod-tun handled by the installer).
2. **Installer `app_openvpn()`** mirroring `app_l2tpipsec`: arch gate (`armv7*|mips*`),
   TUN gate, `require_free_space`, refuse if `opkg list-installed | grep -q '^openvpn-'`
   (pre-existing install), ownership file `/etc/.modgui-openvpn-packages`, install
   `openvpn-openssl` (+`openvpn-easy-rsa`, +`kmod-tun` when TUN missing and a matching pinned
   kmod exists) from the already-configured feeds, then pinned `modgui-openvpn`; binary
   smoke test (`openvpn --version`) before `set_extension_state openvpn_app 1`; GUI
   backup/restore to `/opt/modgui-openvpn-gui.tar.gz` + `refresh` action + `04_config.sh`
   repair hook, exactly like l2tpipsec.
3. **Enable path**: card writes `uci.openvpn.@openvpn[server].enabled` → commit → commitapply
   restarts `/etc/init.d/openvpn` (standard procd init — the `1000>&-` procd-lock trick of
   `modgui-ipsec` should not be needed, but verify `restart` from commitapply does not hang);
   firewall chain helper opens UDP-1194 only while active (mirror the L2TP chain pattern).
4. **Registration & docs/tests**: same 6-file GUI registration as §2, tests in
   `tests/test_extension_manager.py` (pin, sha256, ownership, arch gate, TUN gate, disabled-by-default).

## 6. Risks / open questions

- **TUN on ARM 18/19**: the feed lacks `kmod-tun`; the GUI_ipk `kmods-4.1.*` artifacts are
  kernel-exact (`vermagic`/ipk magic). Installer must pin per-kernel IPKs or refuse (like WireGuard).
- **easy-rsa version drift** between feeds (3.x vs 2.x) — key-gen script must branch.
- **psw-file** stores clear-text passwords (same exposure as the L2TP CHAP secrets the existing
  card accepts); `rpc.openvpn.server.user` reads/writes that file directly — keep it under `/etc`
  and out of any backup tar.
- **`vpn_common_inc.sh` delegate-chain firewall** from vbnt-l is MyRepublic-specific; use the
  proven `zone_wan_input` chain approach instead (or verify delegate chains exist on the ARM target first).
- **Maps assume paths** `/etc/openvpn/{ca.crt,server.crt,server.key,dh2048.pem,client.crt,client.key,psw-file}` —
  key-gen must place files exactly there, and the card's "download client profile" flow reads the
  shared client cert (single client cert + per-user password, exactly like vbnt-l).
- xtream 16.1/16.2 (`xtream35b`) feed has no openvpn at all — v1 should gate them out unless
  self-hosted IPKs are produced.
- macoers VANTW feed returned HTTP 403 during this research — could not confirm openvpn there
  (18/19 arm devices already covered by the Ansuel feed anyway).
