# LuCI wireless on Technicolor DGA4130

Implemented and tested on 2026-10-17 against the modem at 192.168.1.1,
Damson 19.4, ARMv7, with LuCI openwrt-18.06 branch
`git-20.155.55668-a972bdb`. Other models and firmware remain unverified.

## Installation and packaging

All adapter files live in `decompressed/luci_wireless`. The build produces a
separate `luci_wireless.tar.bz2` release asset. Neither its contents nor the
archive are embedded in `GUI.tar.bz2`. The ARM LuCI extension installer fetches
this optional asset for the installed GUI release through the existing
checksum-verified download mechanism, then runs its `setup.sh`.
The main GUI carries only the extension installation/removal hook.
Existing LuCI installations need the extension reinstalled to obtain the adapter.

The installer preserves the original network controller, patches its wireless
route and invalidates LuCI caches, including both optional Quantenna modules.
Other backends retain the upstream page.
Removal restores the controller and removes the adapter. If additional 5 GHz
networks still exist, the small Quantenna runtime and boot service are retained
to preserve them; the LuCI UI is removed. Without those networks the service and
runtime are removed too. Installation/removal/reinstallation was exercised on
the modem without removing its LuCI packages.

## Interface and native Wi-Fi

The existing `/cgi-bin/luci/admin/network/wireless` page displays both radios,
channel, width, SSIDs, operational state and associated stations with signal
and PHY rates. Client rows also join hostname and IPv4/IPv6 addresses from
`hostmanager.device`. Expandable details show available connection/idle time,
RX/TX traffic and packet counters, failures/retries, data rates, authentication,
cipher, link flags and radio capabilities. Full native station data is requested
instead of the short response; only an explicit whitelist enters the view.
Disconnected history entries with empty flags and zero RSSI are excluded.
Missing metrics are omitted, and zero counters remain visible. Additional remote
BSS clients retain their available RPC metrics and receive the same host lookup.
Layout follows legacy LuCI: per-radio Add, per-network
Enable/Disable, Edit and removal for adapter-created networks. Editing uses
Device Configuration and Interface Configuration sections, with General
Setup and Wireless Security tabs and the standard LuCI password widget.

Saved keys start masked and can be revealed/hidden with the asterisk. They are
loaded only in authenticated edit forms, excluded from overview/status data,
and edit responses use `Cache-Control: no-store`. Blank keys preserve the
existing key; an unchanged save does not reload the radio.

Radio power, channel/width, native SSID, AP state and PSK use Technicolor's
Transformer paths. Paired/band-steered credential editing is blocked and
referred to the native GUI. Writes are validated and differences applied;
failures attempt restoration. Main AP enable state uses its radio switch,
matching native firmware behavior. Generic iwinfo/mac80211 configuration does
not work on this firmware.

Broadcom 2.4 GHz creation uses native named wifi-iface and wifi-ap instances,
chooses free slots and attaches to an existing network. Required encryption is
WPA2-PSK. No independent DHCP/firewall configuration is created.

## Additional Quantenna 5 GHz networks

The native daemon explicitly rejects multi-SSID creation on radio 1. Merely
adding `wl1_2` and an AP to `/etc/config/wireless` cannot provision the remote
chip. The adapter instead uses the firmware's `qtn_call_qcsapi.sh` wrapper,
reserving available remote slots `wifi2` and `wifi3`. It never manages or removes
the native `wifi0`/`wifi1` networks or an occupied unmanaged slot.

New networks share the primary 5 GHz radio's network (LAN on the tested modem).
They do not provide separate guest isolation, VLAN, DHCP or firewall rules.
SSID names currently accept letters, digits, dot, underscore and hyphen, up to
32 bytes: the vendor RPC command parser truncates strings containing spaces.
The form explains this restriction. Passwords support spaces and symbols.

The adapter derives WPA2 PSKs locally with PBKDF2-HMAC-SHA1 (4096 iterations,
Lua BitOp), transmits only hexadecimal keys and verifies the chip's SSID,
WPA2 beacon, authentication mode, cipher and key before enabling a network.
Vendor command replies can contain asynchronous messages (for example
`group assoc_limit 99`) instead of `complete`. Setters therefore require
read-back of the requested state, with bounded polling/retries. The RPC launcher
executes the wrapper's child in place so timeout also closes its output pipe.
Radio restoration also runs when pausing RF fails or loses its acknowledgement;
creation errors identify the failed operation without including arguments/keys.
The standard IEEE/password test
vector was verified on the modem and additional vectors against Python
hashlib. Derivation runs before any RF suspension and its result is cached.

Creating a BSS briefly suspends 5 GHz RF because vendor defaults activate a
new BSS immediately. A watchdog removes the new BSS and restores RF if the
creator crashes. Existing native hostapd state is reloaded after RF restoration.
Creation runs as a detached job: the initial LuCI POST returns a progress page
before RF is paused. That page polls a dedicated JSON response and redirects to
the edit form after completion, recovering from a brief Wi-Fi disconnection.
The job directory has mode 700 and records have mode 600; credentials are
removed from the job file before provisioning, and never enter status JSON.
The LuCI server's original timeout settings are retained.
The private `/etc/config/luci_qtn` file (mode 600) stores the original key,
derived key, SSID and desired state. This config is independent of native
`wireless` sections. The `modgui-luci-qtn` procd service starts at boot and
reconciles every 15 seconds, restoring missing BSSs after remote radio loss.
Failures and recovery are logged without credentials.

## Validation and limits

* Created, enabled and removed an additional protected 2.4 GHz network; verified
  native AP status and LAN bridge membership.
* Created and updated an additional 5 GHz network, enabled it, and verified
  remote SSID, WPA2 security, derived key and private persistent configuration.
  A random test password included spaces and symbols.
* Deleted only the tracked test BSS on the remote chip; the service recreated
  it with its saved SSID, key and enabled state. The boot service is enabled.
* Checked LuCI Add on 5 GHz and the edit/password controls in the browser.
  Verified password/text/password input toggling without logging its value,
  and a no-op save returning `No changes to apply`.
* Compared all native wireless configuration fields against the pre-test
  backup: zero semantic differences. Existing user-created networks are kept.
* Local Python suite: 114 tests, including mocked QTN operations, failure
  cleanup, reconciliation, input/ownership checks and archive separation.
  All extension Lua files also parse under the modem's native interpreter;
  fresh empty-config creation was checked with its actual UCI binding.
* Regression validation after the reported 5 GHz save error: three consecutive
  creations and activations succeeded (25–26 seconds each), with removal after
  each attempt. Tests also cover vendor notifications, lost acknowledgements
  and restoration after a failed RF pause.
  A complete HTTP form test uses a random password with spaces/symbols and
  verifies submission, detached provisioning, status JSON and the edit page.

Final state: both original radios operational, three existing 2.4 GHz networks
and two native 5 GHz networks retained; both disposable Quantenna networks
removed. The optional adapter is installed and its boot service is running.
Removal with zero additional networks also removed its runtime and boot link;
the final reinstall restored them successfully.

A full modem reboot, client association to the new test SSID, throughput,
radio channel/width changes and replacement of a real existing PSK were not
exercised. Scan/join, WPS, security-mode selection and band-steering editing
remain outside this implementation. Tests use disposable SSIDs and random keys;
no real keys are recorded here.

QCSAPI reference: <https://github.com/openwrt-es/qcsapi/blob/master/qcsapi.h>.
Observed behavior and compatibility claims above are based on the modem tests.

## Legacy MIPS support (TG788vn v2, 24 October 2026)

The optional adapter is now installed by the MIPS LuCI extension path too.
Legacy Chaos Calmer controllers use `template("admin_network/wifi_overview")`
instead of `cbi(...)`; the controller patch supports both layouts and keeps
the original controller for removal. Templates resolve `build_url` explicitly
and use table display styles compatible with the old theme. The Quantenna
worker is enabled only when a Quantenna radio is configured.

Validated on a TG788vn v2 running Mint 17.2, MIPS, Lua 5.1.5 and LuCI
git-16.043.44305-e2f9172: adapter installation and repeat installation succeeded;
native radio/SSID/station RPCs and the five editable fields were available;
the browser rendered the live 2.4 GHz overview and Add Wireless Network form.
The Quantenna service remained disabled, and `/etc/config/wireless` was
byte-for-byte unchanged. Existing SSIDs, keys and radio settings were retained.

Local regression coverage includes both controller variants, legacy template
rendering without a global `url` or token, MIPS installer failure propagation,
and Quantenna service gating (36 focused tests passed).

Subsequent user-authorized live tests created a disabled WPA2 test network,
verified its generated key internally without printing it, changed its SSID
through the LuCI edit form while preserving its key, and changed SSID/key
through the native adapter. Key readback converges asynchronously after apply;
an immediate read can still contain the previous key. A no-op form submission
returned `No changes to apply`; the reveal/hide control changed input type
password/text/password without logging the value.

The first activation was followed by an unexpected modem reboot. Its cause
was not established, and the boot log contained no retained panic evidence.
The user requested one retry: creation and activation succeeded, both SSIDs
were operational, and monitoring recorded approximately four minutes with
17 MiB free memory and no further reboot. The modem remained up through the
final cleanup (45 minutes of uptime). This does not establish long-term
stability or prove the cause of the first reboot.

The retry used a persistent backup and an automatic cleanup service. Cleanup
removed the UCI sections, but its bounded reload failed because this firmware's
`timeout` does not accept the newer duration syntax. The residual runtime SSID
was detected separately and removed with the native wireless reload. Final
checks found only the original active SSID, no test sections or pending wireless
changes, and wireless/network/firewall files byte-for-byte identical to their
retry backups. The wireless digest also matched the original pre-test digest.
The temporary boot service, scripts, generated keys and backups were removed.

No additional activation cycle was performed after automatic approval review
rejected it as exceeding the single retry. Client association, throughput,
deliberate channel/width changes and other MIPS models remain unverified.
