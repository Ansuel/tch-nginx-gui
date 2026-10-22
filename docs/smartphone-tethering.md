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

On 22 October 2026 the read-only telemetry path was also verified on a Moto G32
running Android 13, using ADB 1.0.32 installed from the test router's opkg feed.
USB authorization, battery, temperature, LTE operator/signal and memory readings
worked. VPN sharing and WAN failover were not enabled during that test.
