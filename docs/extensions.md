# Extensions

The **Extensions** card detects installed applications and exposes only the apps
supported by the gateway architecture. Install and remove operations run in the
background, so reopen the card after an operation to refresh its state.

| Extension | Architectures | Source | Notes |
| --- | --- | --- | --- |
| Adblock | ARM and MIPS | Configured `opkg` feeds | Enabled after installation and managed by its init service. |
| rsyncd | ARM and MIPS | Configured `opkg` feeds | No unauthenticated shares are created. Configure `/etc/rsyncd.conf` before starting it. |
| Ookla Speedtest | ARM, ARM64 | Official Ookla archive | A run is started from the card; reopen it to display the latest result. |
| AdGuard Home | ARM, ARM64 | Official AdGuard stable archive | Installed under `/opt/AdGuardHome`; initial setup is available on port 3000. |

AdGuard Home installation deliberately does not stop dnsmasq, claim DNS port 53,
or change DHCP settings. Complete its first-run wizard and choose non-conflicting
ports before changing the gateway DNS configuration. Removing AdGuard Home removes
its program directory and configuration. On gateways with a JFFS2 overlay, the YAML
configuration remains persistent while runtime databases use tmpfs because their
storage engine is incompatible with JFFS2. Do not move DHCP responsibility to
AdGuard Home on those gateways because runtime lease data does not survive a reboot.

Adblock and rsyncd require valid feeds for the gateway firmware. If `opkg update`
or package installation fails, fix the feeds before retrying from the card.

## Hardware validation

The full install, start, stop and remove cycle was validated on a DGA4130 running
firmware 19.4 (ARMv7, Linux 4.1.52, JFFS2 overlay):

- Adblock 3.5.5-4 from the configured opkg feed;
- rsync/rsyncd 3.1.3-1 from the configured opkg feed;
- Ookla Speedtest 1.2.0.84 using the official ARM archive;
- AdGuard Home 0.107.79 using the official ARM soft-float archive and tmpfs runtime data.

After validation, all test packages, services, configuration created by the tests,
open ports and temporary files were removed. dnsmasq and the router web interface
remained available.
