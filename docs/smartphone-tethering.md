# Smartphone telemetry and advanced voice settings

The Mobile section includes a Smartphone tab. Enable USB debugging on Android,
connect the phone by USB and authorize the router's ADB key on the phone. USB
tethering itself must also be enabled on Android and supported by the router's
USB networking drivers. The page does not automatically change WAN priorities.

The router needs an `adb` executable compatible with its firmware and CPU, plus
the BusyBox `timeout` utility. Install ADB from a trusted feed compatible with
that firmware. Missing ADB, absent devices and missing USB debugging authorization
are reported in the page. ADB is run by the privileged Transformer backend, not
by the nginx worker; do not make USB device nodes world-writable.

Battery and radio telemetry do not require Android root. Mobile data commands,
VPN sharing and the optional Tailscale CLI status require root authorization on
the phone. Sharing also requires a kernel tunnel (`tun*` or `tailscale*`), Android
iptables support and an active USB tether interface. A userspace-only VPN without
such an interface cannot be shared by this feature. The VPN controls configure
IPv4 forwarding only; they do not provide an IPv6 kill switch or DNS leak protection.

VPN sharing uses its own `TCH_PHONE_NAT` and `TCH_PHONE_FWD` chains, policy priority
29999 and route table 29999. Conflicting policy/table state is rejected. Repeated
activation replaces the owned state; stopping removes it, and failed activation
rolls it back. Unrelated Android firewall chains and VPN-provider rules are retained.
Router broadband LEDs remain managed by the router's normal LED service.

The Voice section includes an Advanced tab. Settings use the normal validated
Transformer save/apply flow. Ports and services unavailable in the current
firmware's datamodel are omitted. Empty text fields and Disabled keep-alive are
saved, and backend errors are shown instead of a success notification. Vendor
firmware determines which SIP, STUN and DSP options are actually supported.

Regression checks:

```sh
python3 -m unittest discover -s tests -v
```

The phone tests simulate ADB, Android routing and firewall commands, including
authorization failure, rollback, repeated activation, teardown and preservation
of unrelated state. They do not require or modify a real phone.
