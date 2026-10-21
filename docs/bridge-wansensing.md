# Bridge mode and WAN sensing

The Internet modal now coordinates bridge mode with the WAN selected in
Broadband. The change was installed and validated on an ARM DGA4130
and a MIPS TG788vn v2; the results and remaining limits are recorded below.

## Usage

1. In Broadband, disable WanSensing and save to expose manual interface selection.
2. Select Ethernet, DSL or the supported optical mode, and configure its VLAN.
3. In Internet, switch to Bridge mode. The selected uplink becomes a LAN bridge
   member; its VLAN ID is retained. There is no Ethernet/DSL port-name allowlist:
   the bridge uses the selected L2 device, including nested aliases and multiple
   WAN ports. The optional local DHCP/PPPoE/static connection
   runs on `br-lan`.
4. To return to automatic detection, enable WanSensing in Broadband. The GUI
   removes its added bridge member and restores the previous routed protocol and
   uplink before enabling sensing. Alternatively, selecting a routed mode in
   Internet restores the sensing state saved at bridge activation. If sensing
   was already disabled, it stays disabled.

Entering bridge directly while sensing is enabled first commits `enable=0`
and calls the firmware's `/etc/init.d/wansensing stop`. Failure to disable or
stop sensing aborts bridge activation. Daemon absence is checked with `pidof`,
allowing up to three short polls for asynchronous shutdown. A legacy stop
returning failure because the daemon already stopped is accepted only after
that absence check.

The tagged DHCP probe `wantag`, when present, and DHCP/PPPoE/DHCPv6 clients on
the same selected L2 device are disabled and brought down. Their previous
`auto` settings, including an unset/default value, are restored on exit.
Clients on distinct VLANs are retained. No firmware sensing scripts are rewritten.

Before joining the WAN to LAN, LAN DHCPv4, DHCPv6, RA and NDP services are
suspended and their original settings saved. On exit, the WAN is detached
before LAN services are restored. This prevents the LAN DHCP/RA servers from
answering on the upstream network.

The Technicolor L2 PPPoE relay (`network.lan.pppoerelay`) also needs attention:
its ebtables rules can drop all local output and non-PPP forwarded frames on
a relay port. On the DGA4130 this prevented DHCP on `br-lan` despite an active
link. Matching relay list entries are suspended through the datamodel and
native relay service; their original indices and values are restored on exit.
Entries on other L2 devices or VLANs remain enabled. The separate
`pppoerelayd.config.enable` can be zero while these L2 rules remain active.

The bridge Internet card and WAN statistics use the logical WAN session's
IPv4/IPv6 addresses and uptime. The Internet popup also includes DHCP, PPPoE
or static settings when a local session is selected. Protocol-to-view lookup
supports the firmware's tainted strings. Pure bridge has no local WAN IP.

The `network.config.bridge_*` options retain the original uplink, routed
protocol, sensing state, competing-client startup settings, original WAN bridge
type, and ports added by the GUI across requests/reboots. Existing LAN ports
are retained. Port removal uses
complete interface names, so `eth4.835` does not match `eth4.8350`.

The VLAN modal resolves `@interface` aliases and edits the selected VLAN
device, preserving its 802.1Q/802.1ad type. It no longer assumes every Ethernet VLAN is `waneth4` or every DSL VLAN
is `wanptm0`. VLAN and Broadband changes during bridging update its membership,
including when a local WAN connection uses `br-lan`.
VLAN settings are read-only while sensing is enabled; stale VLAN fields from
the same form submission that re-enables sensing cannot overwrite its choice.

Legacy bridges have no record of the previous protocol/sensing state. They can
be exited using their current uplink; an explicit sensing enable falls back to
DHCP when the previous routed protocol is unknown. A legacy bridge already
pointing WAN at `br-lan` is adopted only when exactly one WAN-designated
Ethernet port is already a member of the LAN bridge. Ambiguous cases are
rejected; the GUI never adds `br-lan` to itself. An adopted bridge preserves
its existing local connection.

## Expanded firmware sample (2026-10-21)

The sample contains **25 firmware branches and 289 source files**, pinned to
commit hashes from [FrancYescO/tch_firmware_extracted](https://github.com/FrancYescO/tch_firmware_extracted).
The normalized fixtures and per-file SHA-256 hashes are saved in
[`tests/fixtures/bridge-firmwares.json`](../tests/fixtures/bridge-firmwares.json).
They retain literal network/XTM/Ethernet defaults, not a provisioned modem's
runtime configuration. Missing archived files are listed explicitly and were
not treated as proof that a device lacks that feature.

| Branch | Service | Sensing states in sampled config |
| --- | --- | --- |
| `15.28.6169_FW_120_TG582nv2` | missing | 0 |
| `16.1.6637-2081001_FW_108_MOS_TG789vacXtream` | start-stop-daemon | 2 |
| `16.2.8706_FW_214_IAD_TG789vacXtream` | legacy | 3 |
| `17.2.0214_FW_219_DGA4131` | procd | 2 |
| `18.3.n.0482_FW_264_DGA4131` | procd | 2 |
| `18.3.n.0482_FW_232_FGA2130` | procd | 2 |
| `19.4.0629_FW_06_DGA4134` | procd | 0 |
| `AGTEF_1.0.2_002_closed` | procd | 3 |
| `AGTEF_2.4.5_CLOSED` | procd | 3 |
| `AGTHP_1.0.1_001_CLOSED` | procd | 3 |
| `AGTHP_2.4.5_CLOSED` | procd | 3 |
| `AGTHF_1.3.6_CLOSED` | procd | 3 |
| `AGTSA_1.0.0_001_CLOSED` | procd | 3 |
| `MST_DGA4130_17.3.0165.1681007` | procd | 3 |
| `MST_TG588v_v2_16.2.7064.2201001` | legacy | 2 |
| `MST.TG789vac.v2-17.2.278-0901008` | procd | 3 |
| `TG389ac_gant-1_17.1.7992-0001012-20180515151413_PROD` | procd | 0 |
| `TN_SWE_TG799vacXtream_17.1.7937-1281014-20180313133921-Official` | procd | 4 |
| `Tiscali_DGA4130_17.1.7970-0001001-20180301141418` | procd | 6 |
| `DGA2231_vcnt-c_18.3.g.0301-official` | procd | 2 |
| `vcnt-2_19.4.l.0393-MR1-RB` | procd | 5 |
| `vcnt-a_20.3.c.0501-MR22.1-RA` | procd | 7 |
| `vbnt-v_20.3.c.0432-MR21.1-RA` | procd | 7 |
| `vant-f_CRF363-15.18.6052-420-RA` | start-stop-daemon | 4 |
| `172339h1441002closed` | procd | 2 |

Relevant differences found:

- DGA4131 scripts rewrite WAN in L3, whereas AGTEF/AGTHP and other families
  rewrite its lower layer in L2. Stopping the service covers both.
- The init scripts use procd (20 samples), `service_start`/`service_stop`
  (2), or `start-stop-daemon` (2). TG582nv2 has no archived sensing service or
  configuration. The native service is used rather than forced process kills.
- ATM PVC names include `atm0`, `atm1`, `atmwan`, `atm_wan`, `atm_8_35` and
  `atm_8_81`. Broadband now reads XTM devices, preserves the selected PVC/VLAN
  and refuses to fabricate a missing DSL device.
- VLAN names include `wanptm0`, `vlan_data`, `vlan_ptm0`, `vlan_wan`,
  `ptm0_v881` and `eth4_v881`. Selection preserves existing names and VID values.
- Telstra 19.4/20.3 scripts copy `ppp` or `ipoe` into `wan` and configure `wan6`
  alongside it. Suspending only `wantag` was insufficient; competing clients on
  the selected L2 are now suspended too.
- WANs can already have a bridge type or a list of ports. The type is cleared
  while those ports belong to `br-lan`, then restored on exit. Lists and nested
  aliases are resolved without assuming a single `eth4`/`ptm0` port.

### Limits exposed by the larger sample

Four source configurations (the three MST samples and Tiscali) contain ATM
PVCs with `ulp=ppp`. These are PPPoA transports, not Ethernet ports. Transparent
Ethernet bridging cannot preserve that encapsulation. Bridge activation, or
switching an active bridge onto such a PVC, now fails before altering sensing,
LAN membership or XTM settings. Other Ethernet ATM PVCs remain eligible. This
change does not silently convert PPPoA to PPPoE or implement a PPPoA half bridge.

DGA4134 19.4 and TG389ac contain `enable=0` but no detection states. Explicit
sensing activation is rejected when the datamodel confirms both state lists
are empty; a working manual bridge is retained. Missing inventory support is
not treated as proof that sensing is absent.

The generic bridge code accepts other selected L2 names such as `eth5`,
`eth10.835`, `ptm1`, `gpon0`, `sfp0` and vendor-named devices. These additional
name/alias tests demonstrate configuration independence, not hardware support
for every possible netdev. A raw-IP/mobile interface, PPP-only transport or a
Wi-Fi mode unable to forward Ethernet frames cannot become an Ethernet bridge
merely by selecting it in the GUI.

## Automated validation

`tests/test_bridge_modes.py` executes the Lua transition helper, mode dispatcher,
Broadband operations and VLAN modal with firmware-shaped datamodel fixtures.
The firmware matrix exercises **70 Broadband-to-bridge combinations** using
literal defaults from the 25 snapshots: 66 configuration roundtrips and 4
expected PPPoA rejections. The same-technology selection, original uplink, LAN
members and VID values are checked. Separate cases cover optical selection,
arbitrary L2 names, configured Ethernet WAN ports with other numbers, WAN port
lists, nested aliases, client isolation,
automatic/manual sensing restoration, empty-state sensing rejection on the
respective firmware snapshots, local connections on `br-lan`, exact port
removal, request persistence, missing/empty sensing and failed disable/stop
operations. These tests mock the datamodel and service invocation; they do not
execute vendor scripts or emulate the switch/DSL driver. The native-stop
verification shell is separately exercised with mocked already-stopped,
asynchronously-stopping and still-running daemons.

The full local suite passed **230 tests** with
`python3 -m unittest discover -s tests -q`. In addition, **111 isolated Lua
fixtures passed on each physical modem** using its own Lua VM. Installed
runtime files were checked against the payload's SHA-256 manifest.

## Live validation (2026-10-21)

The 14-file GUI payload was installed on both devices. Original network
settings were restored after testing; private rollback backups remain on
each device under `/root/modgui-bridge-20261021/`.

| Device and runtime | Original WAN | Observed results |
| --- | --- | --- |
| DGA4130, Homeware 19.4, ARMv7, Lua 5.1.5 | DHCP on `eth4` | DHCP on `br-lan` acquired the original WAN address; routed, bridge, pure bridge, local DHCP and sensing transitions succeeded; the relay list was restored on routed exit |
| TG788vn v2, Mint 17.2, MIPS, Lua 5.1.5 | Legacy bridge with local DHCP on `br-lan`, physical WAN `eth3` | Legacy bridge adopted; routed, bridge, pure bridge, local DHCP and sensing transitions succeeded; DHCP on `br-lan` reacquired the original WAN address |

The DGA4130 had an existing `wan_mode=pppoe` value despite its effective WAN
protocol being DHCP. Its original configuration, including that discrepancy,
was preserved after validation.

The PPPoE relay conflict described above was reproduced on the DGA4130:
DHCP on `br-lan` stayed pending for 60 seconds while the relay filters were
active. Suspending the matching L2 relay entry allowed DHCP to acquire an
address within ten seconds. The final roundtrip verified that the original
relay list was restored on routed exit.

### GUI checks

On the TG788vn v2, the Internet card showed bridge mode, DHCP enabled, the
logical WAN address and session uptime. The popup showed DHCP selected,
Connected, and the session's IPv4 address, gateway and DNS servers. These
checks complement the automated cases for initially empty IP bindings,
subsequent polling, IPv6 bindings and the WAN statistics card.

After the first configuration restore, Transformer was running but refused
client connections on the TG788vn v2. Restarting Transformer and nginx
recovered the GUI; dashboard and popup were then checked again. HTTP status
alone was not treated as proof of a working dashboard.

A subsequent browser check reproduced a DGA4130 dashboard failure in the
bridge helper: `table.concat` rejected tainted configuration strings when
loading the Broadband mode helper from WAN statistics. Joining values with
the taint-aware concatenation operator preserves their taint and avoids the
error. The regression was exercised with the actual `web.taint` module on
both modems, in addition to the isolated fixtures. After installing the helper
and restarting only nginx, authenticated dashboards were checked again on
both devices without changing network settings.

### Card consistency checks (2026-10-22)

The DGA4130's Internet card and polling endpoint used the saved `wan_mode`
value even though the actual WAN protocol was DHCP. A shared reader now
keeps bridge topology explicit but otherwise gives the effective WAN protocol
precedence. Internet cards, polling and WAN statistics therefore agree even
when vendor scripts leave the saved mode stale.

On the TG788vn v2, a legacy local connection on `br-lan` lost its physical
uplink during card selection because Lua table keys distinguish tainted
interface names from plain strings. Valid interface-name tokens are now
normalized for internal set lookup. Broadband mode selection resolves the
physical uplink, and the Ethernet card and modal read that port's link state
and speed instead of comparing the logical WAN's `br-lan` name with a port.
The selected Ethernet port is refreshed on subsequent checks rather than
cached when the Lua module is first loaded.

Browser verification showed DHCP active on the DGA4130 Internet card and
Ethernet connected at 100 Mbps on the TG788vn v2 Broadband card, alongside
its bridge Internet session. Regression cases also cover a saved uplink
through an alias and a vendor-named VLAN, multiple WAN-designated ports and
changing the selected port without reloading the Lua module. The eight GUI
files changed for this check were backed up, nginx alone was restarted, and
all six network configuration packages remained byte-identical.

### Recovery and final state

Actual network transitions ran sequentially on one modem at a time. Every
test had a detached device-local watchdog able to restore original GUI files
and six UCI packages after SSH loss. An earlier overlapping TG788vn v2 test
was interrupted and the watchdog restored the original files and
configuration. That recovery was verified before reinstallation and the
successful sequential run.

Original runtime files, the originally absent-file inventory and six packages
(`network`, `wansensing`, `ethernet`, `xtm`, `firewall`, `dhcp`) were backed up
privately. Final checks compared all six packages byte-for-byte, compared
installed runtime files with staging, and checked WAN address, HTTP and
backend access before canceling watchdogs. Both devices retained the updated
GUI with their original network configuration and no active test watchdog.

### Remaining hardware limits

The TG788vn v2's native sensing scripts hardcode `eth4` and an Ethernet VLAN
881 PPPoE path, while the tested device uses `eth3`. The test proves that
sensing can be re-enabled and its process starts, not that native
auto-detection supports `eth3`. Vendor sensing scripts were not rewritten.

The live links tested were Ethernet. DSL/SFP, tagged upstream service traffic,
PPPoE authentication, static local sessions, client-to-upstream bridge
forwarding and persistence across a device reboot require their respective
physical setup for end-to-end validation. Compare network and sensing
configuration, bridge membership and logs across these additional tests.
Fixture success establishes configuration handling, not physical support for
every named device. The PPPoA transport limits described above still apply.
