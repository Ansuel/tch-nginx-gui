# Smartphone telemetry and advanced voice settings

Advanced MMPBX settings are part of the core Voice section. Android phone
management is a separate optional **Smartphone USB** app in Extensions. Installing
it adds its own dashboard card and modal; it does not replace the LTE modem page
or add phone controls to the core Mobile tabs.

The build creates `smartphone.tar.bz2` from `decompressed/smartphone/` and includes
it as an optional app archive. Its runtime, RPC mapping and UI are extracted only
when the app is installed. App removal unregisters the card and page. A GUI upgrade
refreshes an installed app when its bundled archive changes, with a local backup
for recovery.

Installation, removal and refresh use `app_smartphone()` in the existing
`appInstallRemoveUtility.sh`, just like the other extensions. The GUI upgrade
hook calls `appInstallRemoveUtility.sh refresh smartphone`; no separate
Smartphone installer script or installer bundle is required.

The dashboard card updates every 30 seconds and shows battery level/charging,
operator, network technology and signal bars. Its status distinguishes an active
USB tether with mobile data enabled from a connected phone with tethering or
mobile data disabled. The signal percentage is indicative: LTE RSRP at -120 dBm
or below maps to 0%, and -80 dBm or above maps to 100%; the measured dBm value is
shown alongside it. Missing or invalid measurements remain unavailable.
Polling pauses while the page is hidden and stops when the card is removed.
The card uses the same `createSimpleLight` helper, `mobiled.css` signal bars,
Knockout text bindings and `createAjaxUpdateCard` lifecycle as the other dashboard
cards. Its inline refresh callback returns the request to the shared helper,
which prevents overlapping requests and aborts them on card replacement/removal.
There is no separate Smartphone JavaScript asset or independent polling timer.

Enable USB debugging on Android,
connect the phone by USB and authorize the router's ADB key on the phone. USB
tethering itself must also be enabled on Android and supported by the router's
USB networking drivers. The page does not automatically change WAN priorities.

The app installs `adb` through the router's configured opkg feeds, retaining the
package manager's dependency and ABI checks. The BusyBox `timeout` utility is also
required. Existing ADB installations are reused and retained on removal; an ADB
package installed by the app is removed through opkg without forcing dependency
removal. Missing ADB, absent devices and missing USB debugging authorization
are reported in the page. ADB is run by the privileged Transformer backend, not
by the nginx worker; do not make USB device nodes world-writable.

Installation and refresh also run the bundled `drivers.sh` dependency manager.
It updates the configured feeds and installs available USB networking packages
through opkg, preserving normal kernel ABI and architecture checks. It uses
`kmod-usb-net`, `kmod-usb-net-cdc-ether`, `kmod-usb-net-rndis` and
`kmod-usb-net-cdc-ncm`, plus EEM/subset when the feed supplies them.
There are no board names, fixed kernel versions, ABI hashes or manual package
profiles in the installer. `opkg` resolves each package for the running firmware;
kernel dependency failures are reported without forcing compatibility.

For drivers supplied by the configured feeds, installation and refresh prefer
those packages even when a module already exists: missing packages use
`opkg install`, and installed packages use a targeted `opkg upgrade`. Normal
kernel ABI, architecture and file ownership checks remain enabled; neither
manual compatibility packages nor force options are selected. Existing modules
are retained when no matching feed package is available. Drivers built into the
kernel are reused because installing a module cannot replace them.

The installer never unloads active modules. When a package for a loaded driver
is installed or changes version, the modal reports that a router reboot is
required to use the updated driver. This notice survives refreshes until reboot.
Discovery uses the running kernel's module directory and supports flat and
nested layouts. Shared drivers and their autoload entries remain installed when
Smartphone USB is removed. Recovery archives from earlier manual replacements
are retained but are no longer part of the automatic installer.

Unavailable packages or feed errors do not prevent installing the telemetry
app. Their result is saved in `/etc/modgui-smartphone-drivers.status` and shown
in the modal. The card shows the router-side tether interface and link. The
modal also shows its actual IPv4 address and configured gateway, USB bus speed,
loaded modules and driver installation status, even when ADB is unauthorized or
not exposed. Missing card telemetry rows are hidden and reappear when valid.
These checks do not start DHCP or change WAN, DNS, routes or firewall rules.

### Optional IPv4 uplink controls

The modal has explicit controls for **Solo collegamento DHCP**, **Fallback
della WAN attuale**, and **Linea principale; WAN attuale come fallback**.
**Disattiva e ripristina** removes the app's uplink configuration. These actions
run on the router and do not require ADB authorization or Android root. USB
tethering and mobile data still need to be enabled on the phone.

The manager discovers the USB network device and the current IPv4 WAN in a
masquerading firewall zone. netifd owns DHCP on its dedicated `modgui_phone`
interface, which joins that existing WAN zone and inherits its firewall/NAT
policy. Existing WAN interface settings and metrics are retained. A DHCP-only
connection does not install an Internet default route. In routing modes, the
phone receives a secondary main-table metric while owned policy tables select
the verified preferred line for ordinary IPv4 traffic.

The supervised `modgui-smartphone-uplink` service probes `1.1.1.1` and
`9.9.9.9` using each line's own source address and routing table, so a working
fallback cannot mask a failed primary. Three failed checks withdraw a line;
two successes restore the preferred line. Removing a link selects the remaining
ready line. Local management routes remain in the main table. Existing marked
routing policies (for example provider voice rules) and IPv6 retain their
original behavior. Existing connections may need to reconnect after switching.

The app reserves IPv4 routing tables `29996`–`29998` and rule priorities `90`,
`91`, `100`, `101`; occupied reservations are rejected before activation.
Support for prefix-suppression rules is checked by capability, without a fixed
kernel-version profile. Firmware lacking that capability can still use the
DHCP-only mode. All arguments reaching subprocesses come from enum actions,
validated interface names or numeric network state. The existing authenticated
modal, CSRF validation and Transformer RPC allowlist cover these controls.

Configuration is stored in `/etc/config/smartphone`; runtime status and control
locks live in root-only `/var/run/modgui-smartphone-uplink`. DNS selection uses
`/var/run/modgui-smartphone-dns/resolv.conf`, readable by dnsmasq. The previous
resolver setting is retained; explicit DNS server entries and no-resolv settings
are preserved. Stop and failed apply restore only owned sections, WAN-zone
membership and resolver fields, preserving unrelated configuration changes.
App removal stops the uplink before deleting its files. Refresh restarts an
enabled monitor while retaining its mode; boot and USB reconnection reuse the
stored configuration.

Battery and radio telemetry do not require Android root. Mobile data commands,
VPN sharing and the optional Tailscale CLI status require root authorization on
the phone. Their controls are omitted when the phone does not grant root;
Tailscale peer controls also require the Tailscale CLI to exist on the phone.
Sharing also requires a kernel tunnel (`tun*` or `tailscale*`), Android
iptables support and an active USB tether interface. A userspace-only VPN without
such an interface cannot be shared by this feature. The VPN controls configure
IPv4 forwarding only; they do not provide an IPv6 kill switch or DNS leak protection.

VPN sharing uses its own `TCH_PHONE_NAT` and `TCH_PHONE_FWD` chains, policy priority
29999 and route table 29999. Conflicting policy/table state is rejected. Repeated
activation replaces the owned state; stopping removes it, and failed activation
rolls it back. Unrelated Android firewall chains and VPN-provider rules are retained.
Router broadband LEDs remain managed by the router's normal LED service. Android
command outcomes are checked with an explicit remote status marker, including
with older ADB 1.0.32 builds that do not propagate remote shell exit codes.

The display controls are explicit: **Accendi display** sends Android keycode 224
(WAKEUP) and **Spegni display** sends keycode 223 (SLEEP). They do not unlock the
phone. The former ambiguous power-toggle button (keycode 26) is no longer used.

**Mostra schermo** captures a PNG through ADB without root and shows it in the
router interface. **Aggiorna immagine** requests another snapshot; this is not a
video stream or remote touch control. Capture uses `screencap` and `adb pull`, so
it also works with ADB 1.0.32. Android may blank protected app content. The frame
is served only through the app's authenticated image endpoint, with no browser
caching, and the temporary copy on the phone is removed after transfer. The
router keeps the most recent frame in a directory readable only by root and
nginx's group; removing the app deletes it.

The Voice section includes an Advanced tab. Settings use the normal validated
Transformer save/apply flow. Ports and services unavailable in the current
firmware's datamodel are omitted. Empty text fields and Disabled keep-alive are
saved, and backend errors are shown instead of a success notification. Vendor
firmware determines which SIP, STUN and DSP options are actually supported.

Regression checks:

```sh
python3 -m unittest discover -s tests -v
```

The app lifecycle tests cover install, remove, reinstall, dependency failures,
archive validation, preservation of pre-existing ADB and files, upgrade recovery
and rollback after a backend restart failure. The phone tests simulate ADB,
Android routing and firewall commands, including
authorization failure, rollback, repeated activation, teardown and preservation
of unrelated state. They do not require or modify a real phone.

Radio parsing uses only the current data SIM snapshot and ignores historical logs.
LTE band zero means unknown; when needed the band is derived from EARFCN.
LTE identity includes ECI, eNB ID, sector, ECGI and TAC when Android exposes them.
RSSNR accepts negative values and uses the Android SDK version to select dB units.
Unavailable fields remain N/A. Radio tests use synthetic snapshots only.

### ADB connection diagnostics and USB network drivers

The helper inspects `adb devices` before issuing phone commands. It reports
separate `ERROR_CODE` values for `adb_missing`, `no_device`, `unauthorized`,
`offline`, `multiple_devices` and `adb_error`. The RPC and modal preserve these
codes; the card displays the specific state and the modal explains the recovery
action. `no_device` means no ADB transport, which can also mean USB debugging is
disabled; it does not prove that the USB cable is disconnected. Accept the RSA
authorization prompt for the router, whose key differs from the computer's key.
When sysfs exposes an ADB or USB networking function but ADB has no transport,
`usb_only` reports the USB product name and asks to enable USB debugging.
USB discovery does not require an authorized ADB connection. This distinguishes
a USB-connected phone without ADB from an actual `unauthorized` ADB transport.

ADB and USB tethering are independent. ADB does not require RNDIS or CDC network
drivers. To create a router-side network interface, tethering requires `usbnet`
and the driver matching the function exposed by the phone: commonly
`rndis_host` (`kmod-usb-net-rndis`, with CDC Ethernet dependencies), or `cdc_ncm`
(`kmod-usb-net-cdc-ncm`). CDC ECM uses `cdc_ether`
(`kmod-usb-net-cdc-ether`). Use packages matching the Technicolor firmware's
kernel and ABI from its configured feeds. Loading a driver does not enable
tethering on the phone or configure a DHCP/WAN connection on the router.

Read-only checks on 2026-10-27 found:

| Router | USB network drivers | Phone state |
| --- | --- | --- |
| Router A | RNDIS, CDC Ethernet and CDC NCM installed and loaded | Motorola moto g32 exposes RNDIS `ef/04/01`, but the old driver does not match it; no ADB interface exposed |
| Router B | CDC Ethernet and CDC NCM installed and loaded; RNDIS package absent | No USB phone enumerated |

Neither router had ADB or the Smartphone helper installed during these checks.
On router A, the phone's interface modalias is
`usb:v22B8p2E24d0419dc00dsc00dp00icEFisc04ip01in00`. The installed
`rndis_host.ko` has generic aliases for `e0/01/03`, `ef/01/01` and `02/02/ff`,
but none for `ef/04/01`. Its sysfs driver directory has no bound USB interface,
and no USB network interface exists. This points to a driver matching gap,
not a missing CDC package or a need for `adb-enablemodem`. Supporting this phone
requires a compatible driver update/backport or a separately verified device
binding workaround. No binding or network configuration was changed by the audit.
A subsequent driver installation and live test on 2026-10-28
resolved this matching gap with the CDC/RNDIS pair from the configured VBNT-S
feed: `usb0` appeared, carrier became active, and the phone supplied a DHCP lease.
For an RNDIS phone, router B needs its compatible `kmod-usb-net-rndis` package;
missing RNDIS cannot explain the absence of the phone from the USB device tree.

`adb-enablemodem` is not a generic Android tethering enabler. Its upstream init
script handles a specific TP-Link LTE module (`2357:000d`), starts its web server
and registers its USB serial ID. It neither bypasses Android's ADB authorization
nor enables tethering on the Motorola.

References: [OpenWrt USB tethering guide](https://openwrt.org/docs/guide-user/network/wan/smartphone.usb.tethering)
and [adb-enablemodem source](https://raw.githubusercontent.com/openwrt/openwrt/master/package/network/utils/adb-enablemodem/files/adb-enablemodem).

### Live validation on router A, 2026-10-28

After app installation, the router's BusyBox 1.23.2 rejected `timeout SECS`;
it requires `timeout -t SECS`. This broke both the RPC outer deadline and every
ADB command inside the helper. The helper returned `adb_error` while the RPC
reported only a generic request failure. Both layers now detect the supported
timeout syntax. Regression tests exercise both command-line dialects.

Installed the four changed runtime/UI files after shell/Lua syntax checks and
`nginx -t`, keeping a backup of the original files. Transformer was
restarted and nginx reloaded. All four installed MD5 hashes match the source.
The real helper and datamodel both returned `ERROR_CODE|usb_only`,
`USB_DEV|moto g32` and `USB_ADB|0`. Browser validation confirmed the USB product
name and ADB-unavailable message in the card and modal. No phone command or
router WAN configuration was changed. The actual phone did not expose an ADB
interface, so accepting an RSA authorization prompt cannot be tested until USB
debugging is enabled on the phone.

# Boot validation on 2026-11-04

On the DGA4132/VBNT-S, the fallback monitor and CDC/RNDIS modules started
after reboot, and the selected uplink remained the existing WAN. No phone
was enumerated on either USB controller: only the root hubs were present,
and ADB listed no transports. Rebinding the empty host controllers did not
recover the device. Physical reconnection/unlocking of the phone is still
needed to validate recovery; this is not an ADB authorization failure.

The reboot also exposed a DNS startup ordering bug: dnsmasq (S19) exhausted
its respawns before the uplink monitor (S95) created the volatile resolver
directory. The existing `modgui-smartphone-uplink` init script now runs
in two boot phases: its S18 link prepares the directory and readable
resolver file only when managed uplink DNS is enabled; its S95 link starts
the monitor after the other networking services. Enable/disable manages both
links. App refresh removes the former separate `modgui-smartphone-dns` script.
The card's absent-device label now explicitly says that no phone was detected
on USB.

The update was deployed with backup at
`/root/smartphone-reboot-backup-20261104/app.tgz`. Live validation recreated
the resolver from an absent runtime directory using the new hook, observed
the monitor repopulate the WAN DNS, restarted dnsmasq and successfully
resolved `example.com` through `127.0.0.1`. No second full router reboot
was performed. Local validation passed 52 existing Smartphone tests, the
boot preparation and init-link lifecycle tests and 20 phone-helper tests,
plus shell syntax and diff whitespace checks.

## USB identity, ADB startup and telemetry errors

The model reported as `USB_DEV` comes from USB descriptors and does not require
a running or authorized ADB connection. Seeing a model therefore does not prove
that Android telemetry is reachable.

The helper explicitly starts the ADB server with a five-second deadline before
querying transports. This allows a cold start more time than a normal ADB
command, while distinguishing server startup failure from unauthorized, offline
or unavailable transports. A separate boot service for ADB is not needed.

The card distinguishes ADB server/connection failures, Android telemetry
failures, helper timeouts and browser/backend communication failures. If the
outer telemetry deadline expires, the RPC wrapper performs a separate bounded
USB-only query, preserving USB identity and tethering diagnostics without
repeating ADB commands. Unknown errors with a USB identity are shown as
USB detected with diagnostics unavailable.

These diagnostics were validated with simulated ADB startup/telemetry failures,
RPC timeouts and card responses. The reported issue on the additional router
could not be reproduced directly because that device was not reachable.

### Automatic recovery of stale USB discovery

A live check found the kernel exposing the phone's ADB interface while an
already running ADB server listed no transports. Restarting only ADB restored
an authorized transport and telemetry. This confirms stale discovery in that
server instance, but does not establish the underlying hotplug failure cause.

During stats polling and independent background checks, the helper retries
this specific condition with a server restart. It first rechecks the transport list under a private lock,
leaves any listed transport (including unauthorized/offline) alone, and limits
recovery attempts to once per minute using boot uptime. A dead process lock
is reclaimable. USB-only diagnostics and router uplink controls do not trigger
recovery. Normal ADB authorization is still required. Attempts and outcomes
are logged with the `modgui-smartphone` tag; no router reboot is needed.

The existing `modgui-smartphone-uplink` init service supervises two separate
instances: an ADB watcher and, when configured, the DHCP/failover monitor.
The watcher performs a lightweight USB/ADB check every 30 seconds without
collecting Android telemetry. It starts on app installation/refresh and boot,
works with the WebUI closed, and stays active when tethering is disabled.
Stopping tethering terminates only the uplink instance; app removal stops
both instances and disables their boot links. The watcher stops its current
check or sleep on termination, avoiding leftover polling processes.

Live validation on DGA4132/VBNT-S confirmed the ADB watcher kept the same
process while tethering was disabled, and that reapplying fallback restored
the separate uplink monitor. Both lines were reachable afterward, Android
telemetry was available through Transformer, and router DNS resolved names.
Local suites passed 56 Smartphone and 28 phone-helper tests, including a
watcher recovery with no GUI requests and termination during its polling loop.
