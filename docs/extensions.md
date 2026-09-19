# Extensions

The **Extensions** card detects installed applications and exposes only the apps
supported by the gateway architecture. Install and remove operations run in the
background, so reopen the card after an operation to refresh its state.

| Extension | Architectures | Source | Notes |
| --- | --- | --- | --- |
| Adblock | ARM and MIPS | Configured `opkg` feeds | Enabled after installation and managed by its init service. |
| rsyncd | ARM and MIPS | Configured `opkg` feeds | No unauthenticated shares are created. Configure `/etc/rsyncd.conf` before starting it. |
| Ookla Speedtest | ARM, ARM64 | Official Ookla archive | A run is started from the card; reopen it to display the latest result. |
| OpenSpeedTest | All | Pinned OpenSpeedTest archive | Browser-based LAN/Wi-Fi test on port 5678; requires about 40 MB of free persistent storage. |
| AdGuard Home | ARM, ARM64 | Official AdGuard stable archive | Installed under `/opt/AdGuardHome`; initial setup is available on port 3000. |
| WireGuard | ARM, ARM64 with kernel TUN | Pinned `openwrt-wireguard-go` package | Installs only the userspace runtime; it creates no interface, key, route or firewall rule. |

AdGuard Home installation deliberately does not stop dnsmasq, claim DNS port 53,
or change DHCP settings. Complete its first-run wizard and choose non-conflicting
ports before changing the gateway DNS configuration. Removing AdGuard Home removes
its program directory and configuration. On gateways with a JFFS2 overlay, the YAML
configuration remains persistent while runtime databases use tmpfs because their
storage engine is incompatible with JFFS2. Do not move DHCP responsibility to
AdGuard Home on those gateways because runtime lease data does not survive a reboot.

Adblock and rsyncd require valid feeds for the gateway firmware. If `opkg update`
or package installation fails, fix the feeds before retrying from the card.

WireGuard is offered only when the running kernel has TUN support. Its package URL
is pinned to repository commit `7ac8fe29a7ab64eb0c9c9774bb36cf2c7648399e`
and the downloaded IPK is checked with SHA-256 before installation. The runtime
uses roughly 20 MB of RAM for each active interface. Tunnel configuration remains
an explicit administrator action; the extension never opens UDP 51820 or changes
the network and firewall configuration. Removal is refused while WireGuard UCI
interfaces still exist, and a package that predated the extension is never removed.

## Hardware validation

The full install, start, stop and remove cycle was validated on a DGA4130 running
firmware 19.4 (ARMv7, Linux 4.1.52, JFFS2 overlay):

- Adblock 3.5.5-4 from the configured opkg feed;
- rsync/rsyncd 3.1.3-1 from the configured opkg feed;
- Ookla Speedtest 1.2.0.84 using the official ARM archive;
- AdGuard Home 0.107.79 using the official ARM soft-float archive and tmpfs runtime data.
- OpenSpeedTest revision f4263546 using its checksum-verified archive; a real browser
  test reached 349.7 Mbps download, 430.1 Mbps upload, 4 ms ping and 0 ms jitter.

WireGuard compatibility was also checked on that DGA4130. Firmware 19.4 reports
`# CONFIG_TUN is not set` and has no `/dev/net/tun`, so the guarded installer was
verified to refuse installation without downloading a package or changing network,
firewall, feed or extension state. A live tunnel cannot be validated on this firmware;
firmware 20.3.c or 21.4 with `CONFIG_TUN=y` is required by the upstream runtime.

After validation, all test packages, services, configuration created by the tests,
open ports and temporary files were removed. dnsmasq and the router web interface
remained available.
