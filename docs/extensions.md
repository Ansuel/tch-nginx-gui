# Extensions

The **Extensions** card detects installed applications and exposes only the apps
supported by the gateway architecture. Install and remove operations run in the
background, so reopen the card after an operation to refresh its state.

| Extension | Architectures | Source | Notes |
| --- | --- | --- | --- |
| Adblock | ARM and MIPS | Configured `opkg` feeds | Enabled after installation and managed by its init service. |
| aMule | ARMv7 and MIPS | ARM: configured `opkg` feed; MIPS: pinned legacy IPKs | Installs stopped. Writable USB storage is required to start; configuration and downloads survive removal. WebUI uses port 4711. |
| rsyncd | ARM and MIPS | Configured `opkg` feeds | No unauthenticated shares are created. Configure `/etc/rsyncd.conf` before starting it. |
| Ookla Speedtest | ARM, ARM64 | Official Ookla archive | Start opens the terminal with live progress and the result; the latest result is also retained in the card. |
| OpenSpeedTest | All | Pinned OpenSpeedTest archive | Browser-based LAN/Wi-Fi test on port 5678; requires about 40 MB of free persistent storage. |
| AdGuard Home | ARM, ARM64 | Official AdGuard stable archive | Installed under `/opt/AdGuardHome`; initial setup is available on port 3000. |
| WireGuard | Matching kernel module in opkg, or ARM/ARM64/MIPS with reviewed TUN | Configured opkg feeds | Installs the selected runtime and a card to manage the tunnel interface, peers and an opt-in firewall zone; everything stays disabled until configured. |
| L2TP/IPsec VPN | ARMv7 and MIPS | Pinned `modgui-vpn`, configured opkg feeds | Adds the legacy strongSwan/xl2tpd server card; installation leaves the server disabled. |
| OpenVPN | ARMv7 and MIPS with TUN | `openvpn-openssl`, `openvpn-easy-rsa` | Adds server and client tabs, user management, profile export and optional SSID-to-client routing; both modes install disabled. |
| Tailscale | ARMv7, ARM64 with kernel TUN | Official pinned Tailscale static archive | Adds a native status card and controls for tailnet login, subnet routes, exit-node advertising, accepted routes and Tailscale SSH; installs disabled. |
| DumaOS | Supported ARMv7, kernel 4.1.52 | Pinned `dumaos-repack` 2.0-46 IPK | Installs the DumaOS 3.3.90 UI/QoS stack and links its authenticated interface from the Extensions card. Other kernels, including 4.1.38, are rejected before installation. |

AdGuard Home installation deliberately does not stop dnsmasq, claim DNS port 53,
or change DHCP settings. Complete its first-run wizard and choose non-conflicting
ports before changing the gateway DNS configuration. Removing AdGuard Home removes
its program directory and configuration. On gateways with a JFFS2 overlay, the YAML
configuration remains persistent while runtime databases use tmpfs because their
storage engine is incompatible with JFFS2. Do not move DHCP responsibility to
AdGuard Home on those gateways because runtime lease data does not survive a reboot.

Adblock and rsyncd require valid feeds for the gateway firmware. If `opkg update`
or package installation fails, fix the feeds before retrying from the card.

WireGuard and SPU install from the configured opkg feeds, with no fixed package
versions. On ARMv7 the feed setup registers
`https://francyesco.github.io/GUI_ipk/base` and probes both
`kernel/<uname -r>` and `kernel/<uname -r>-<product>` under that site. Product
names are normalized, for example `VBNT-O_fastweb` becomes `vbnto`. Existing
custom feeds with the same source name are preserved.

VPN availability in the Extensions card/modal is checked by Transformer and exposed
as boolean datamodel fields. The nginx worker must not invoke opkg probes: legacy
opkg requires a privileged lock even for reads and otherwise falsely reports that
compatible modules are missing. Probe results are cached for 30 seconds.

Native WireGuard is preferred when a package matches the running kernel release
and has no known ABI mismatch. An explicit kernel dependency must match the
installed kernel package exactly; an unpinned package is also checked against the
virtual kernel published in its feed. The kernel loader must accept the module;
forced loading is never used. Tools and protocol integration come from opkg.
A GUI-owned Go installation is migrated while preserving tunnel configuration;
its installed package is cached only for rollback during that migration.
Unmanaged Go installations and other configured tunnels prevent migration.
If no matching native package exists, the installer uses `wireguard-go` from
the configured feeds with the shared TUN lifecycle. The existing module loader
handles boot loading. Installation adds a
WireGuard card (and a transformer-backed management modal) to configure the tunnel
address, listen port, a server keypair and per-peer entries. Enabling the interface
creates a netifd `modgui_wg0` interface, the matching peers and an opt-in firewall
zone that only opens UDP `listen_port` and the selected peer-to-LAN/Internet forwarding.
Traffic from the VPN zone to the router itself is rejected by default, and enabling
LAN access does not create the reverse LAN-to-VPN forwarding. The
interface, peers and firewall rules stay disabled until explicitly enabled. Removal
disables and deletes the managed interface and refuses to remove a package that
predated the extension or a manually configured WireGuard interface.


The Tailscale integration takes its Technicolor service layout and GUI concepts from
[`UncleSam1966/Tailscale-Setup`](https://github.com/UncleSam1966/Tailscale-Setup),
but uses a deterministic extension installer: Tailscale 1.102.4 is downloaded from
the official package server for ARM or ARM64 and checked against an architecture-
specific SHA-256 digest. Installation requires roughly 96 MB in `/opt`, or 128 MB of
temporary RAM in low-storage mode. DGA4130-class gateways do not write the large Go
binaries or archive to JFFS2: the official archive is downloaded, checksum-verified
and extracted into `/tmp` when the service first starts after a reboot. WAN access is
therefore required for that first start. The small node identity remains under `/opt`.
A pre-existing Tailscale installation is never
overwritten. The daemon, tailnet connection, UDP WAN rule, subnet forwarding,
exit-node forwarding and Tailscale SSH all remain disabled after installation.
No CA package is installed or upgraded: old firmware trust stores cannot reliably
validate the current package endpoint and may conflict with `https-certificates`.
The download therefore uses ModGUI's compatibility TLS mode, while the pinned digest
remains mandatory and rejects any archive whose bytes differ from the reviewed build.

Enabling the service and **Connect to tailnet** from the Tailscale modal produces an
official `login.tailscale.com` authorization link. No Tailscale account credential or
auth key is stored by the GUI. Runtime preparation and authorization run under the
service manager rather than the 30-second Transformer apply window, so a cold-start
download cannot time out the WebUI save. The dashboard card reports preparation,
authorization-required, connected and error states while this work continues in the
background. Subnet routes and exit-node mode require separate
approval in the Tailscale admin console. Tailscale runs with its own netfilter changes
disabled; named UCI firewall sections expose only the selected features and are
removed when the service or extension is disabled. Removing the extension also
deletes its local node identity, so the old machine entry may still need to be removed
from the Tailscale admin console.

The DumaOS integration pins `dumaos-repack` release `2.0-46` and verifies both the IPK and the
optional Linux 4.1.52 `act_connmark` QoS module before installation. It is shown
only on ARMv7 gateways and requires about 40 MB of persistent free space. The
published package supports kernel 4.1.52 and the AGTEF firmware ABI. The Extensions
modal reports unsupported kernels instead of offering installation. The package
activates the MR22 `ubus` ABI transactionally, with a verified stock backup and
automatic rollback on failed health checks; removal restores the stock stack.
Its name in the Extensions
card opens the authenticated DumaOS interface through the main gateway web server.
The separate DumaOS card is removed on installation and GUI upgrades; the Extensions
modal can still start and stop the two DumaOS services.

aMule uses the configured feed on ARMv7 (`3.0.0-1` in the feed validated on
2026-10-28). MIPS uses the checksum-verified legacy archive at commit
`4a262ed51847dc192d96a4e2c938540cc89a41db`, without running its upstream setup or
removal scripts. Installation records the packages it adds; removal never forces
dependency removal or removes packages that were already installed. An unmanaged
installation is left intact and reported as such.

The service starts only with writable USB storage, detects both whole disks and
partitions, and keeps configuration under `sharing/config/amule` and downloads
under `sharing/download/amule`. A new configuration uses a unique WebUI password
stored in `/etc/modgui-amule.password` (readable by root) and available in the
authenticated Extensions modal through a masked field with a Show password toggle.
The original stays root-only; a separate mode-0400 copy is readable only by the
nginx worker, and is deleted on removal. No password RPC is published. It binds external
control to loopback. The password and USB data survive removal and reinstallation.
Existing USB configuration, including its password, is preserved. No firewall or
UPnP rule is added. Installation leaves the service stopped; Start and Stop are
available on both architectures. The installer generates `/etc/init.d/amule`
directly, without requiring a separate GUI init asset. Stop also terminates the matching `amuleweb`
child that otherwise survives the daemon on older firmware.

## Hardware validation

The full install, start, stop and remove cycle was validated on a DGA4130 running
firmware 19.4 (ARMv7, Linux 4.1.52, JFFS2 overlay):

- Adblock 3.5.5-4 from the configured opkg feed;
- rsync/rsyncd 3.1.3-1 from the configured opkg feed;
- Ookla Speedtest 1.2.0.84 using the official ARM archive;
- AdGuard Home 0.107.79 using the official ARM soft-float archive and tmpfs runtime data.
- OpenSpeedTest revision f4263546 using its checksum-verified archive; a real browser
  test reached 349.7 Mbps download, 430.1 Mbps upload, 4 ms ping and 0 ms jitter.

Firmware 19.4 on the DGA4130 reports `# CONFIG_TUN is not set` and has no stock
`/dev/net/tun`. On the validated DGA4130 kernel (`4.1.52` with the reviewed kernel
hash), the WireGuard installer can use the same pinned, checksum-verified TUN module
already validated by
the OpenVPN and Tailscale extensions. WireGuard, OpenVPN and Tailscale now acquire the
module through one checksum-verified shared lifecycle, so any of them can be installed
first on a clean gateway. Other firmware without built-in TUN remains unsupported
unless a reviewed matching module is available; the installer never loads a module
merely because the kernel version string looks similar. Per-extension ownership marks
prevent one VPN from removing the module or its boot-load entry while another still
uses it. The last owner removes it only if it is no longer in use and its checksum
still matches.

The WireGuard modal can generate the gateway keys and a complete client peer in one
step. It allocates the first free tunnel address, stores the generated public and
preshared keys in the server peer table through Transformer, keeps the client private
key in an owner-only temporary profile when generated by the WebUI (or
`root:nogroup` mode 0640 from the root CLI), and exposes it through an authenticated
`.conf` endpoint and as a QR code rendered with the GUI's existing Wi-Fi QR library.

The L2TP/IPsec integration pins `modgui-vpn` to merge commit
`5c9015930961848259aa883cbe1a20c02a227de4` and verifies its `1.1-0` IPK before
installation. It refuses to overwrite a pre-existing strongSwan setup and records
only the dependencies it installed so removal does not delete packages already on
the gateway. The generated GUI assets are backed up under `/opt` and restored after
a GUI update, fixing the disappearing-card issue. The persistent xl2tpd template
uses `max retries = 100` to mitigate the Android 8–11 90-second disconnect, and the
dedicated IPsec init wrapper closes the inherited procd lock before strongSwan
daemonizes, preventing later restart/stop commands from hanging. The package also
preserves unrelated CHAP users and restores stock xl2tpd/strongSwan files and init
enablement on removal. Hardware crypto/SPU is never enabled because it has been
associated with reproducible router crashes on some DGA413x configurations.

L2TP/IPsec with a shared key and MSCHAPv2 is retained for compatibility but is a
legacy VPN design. Android 12 and later removed native L2TP support. Prefer IKEv2 or
WireGuard for new deployments. Enabling this server opens UDP 500 and 4500, ESP,
and encrypted UDP 1701 on WAN; installation by itself does not enable those rules.

After validation, all test packages, services, configuration created by the tests,
open ports and temporary files were removed. dnsmasq and the router web interface
remained available.

The OpenVPN extension refuses to replace a pre-existing OpenVPN setup and records
only packages it installed. On the reviewed DGA4130 kernel identity, it can load the
SHA-256 verified TUN module from a pinned revision of `GUI_ipk`.
Other kernels without TUN require a compatible `kmod-tun` from their configured
feeds. First start creates the CA and shared server/client certificates with
easy-rsa. The WAN firewall rule follows the server state and uses the configured
protocol and port. Client profiles never contain user credentials. Access from
VPN clients to the LAN is an explicit switch and is disabled by default; the
extension does not route clients' Internet traffic through the gateway.
The Client tab can connect the gateway to a remote OpenVPN server using a CA,
optional client certificate/key and optional username/password. The client uses
`tun1` and `route-nopull`, so it never replaces the gateway's main default route.
Isolated Wi-Fi SSIDs with their own static subnet are discovered dynamically;
the main LAN SSID is excluded. Selected SSIDs are routed and masqueraded through
the client tunnel, with an unreachable fallback route and forwarding reject rule
while the tunnel is down. Additional isolated SSIDs appear when configured in
the gateway's Wi-Fi and network settings. The extension does not create new
radio interfaces or change the state of existing SSIDs.
The client tab accepts PEM CA, optional client certificate and private key, and
optional username/password. It does not import arbitrary `.ovpn` directives;
copy the relevant connection parameters from the provider's profile. Local
router DNS services are not moved into the tunnel, so use a VPN-appropriate
external DNS resolver on the selected SSID when DNS privacy is required.
The current implementation supports one remote client profile. Supporting
multiple simultaneous clients requires distinct tunnel interfaces, credential
files and route tables, plus an explicit SSID-to-profile assignment; simply
duplicating the form would risk routing one SSID through the wrong tunnel.
The extension keeps a backup of its GUI and Transformer files at
`/opt/modgui-openvpn-gui.tar.gz` and restores them after a GUI upgrade when
the installed card or mapping is missing.

On the DGA4130 (Damson 19.4, kernel 4.1.52), the pinned
TUN module loaded successfully. OpenVPN 2.4.5 started with generated CA,
server/client certificates and 2048-bit DH parameters. A local test client
authenticated with a temporary user and completed the TLS handshake, receiving
`10.8.0.6`. Wrong credentials were rejected. The test user and client were
removed, and the server and WAN OpenVPN rule were disabled after the test. The
LAN forwarding switch was not enabled during this validation.
In a second local-only smoke test, the new client connected to the gateway's
own OpenVPN server on `127.0.0.1`, authenticated and received `10.8.0.6` on
`tun1`. No SSID was selected or forwarded. Temporary credentials were removed,
and both OpenVPN modes and the server WAN rule were returned to disabled.

SPU installs alongside L2TP/IPsec when the configured feeds offer a matching `kmod-bcmspu` or `kmod-bcm63xx-tch-spu` package for the running kernel. Module options are inspected: `blog_offload=N` is set only when the driver exposes that parameter. The existing module loader preserves those options at boot. Package or load failures leave software crypto available. SPU remains installed and loaded when the VPN stops or is removed because other IPsec consumers may use it. The earlier validation observed SPU drops under load; it does not establish loss-free hardware operation.

SPU does not accelerate WireGuard's ChaCha20/Poly1305. OpenVPN using AES can potentially use SPU through an OpenSSL engine such as devcrypto/afalg, provided the kernel bridge, engine and matching algorithms are available. The current GUI does not enable such an engine, and OpenVPN/SPU acceleration has not been validated; OpenVPN alone therefore does not install SPU automatically.

Kernel build sources, IPKs and per-module validation belong to
[GUI_ipk](https://github.com/FrancYescO/GUI_ipk), rather than this GUI overlay:

| Distribution | Current contents |
| --- | --- |
| [4.1.52 feed](https://francyesco.github.io/GUI_ipk/kernel/4.1.52/index.html) | TUN, WireGuard, SPU, QoS, netfilter and CDC/RNDIS packages; kernel sources and validation remain in GUI_ipk. |
| [VBNT-O 4.1.38 feed](https://francyesco.github.io/GUI_ipk/kernel/4.1.38-vbnto/index.html) | Router-tested TUN, WireGuard and SPU for the VBNT-O ABI. |
| [VBNT-S 4.1.38 feed](https://francyesco.github.io/GUI_ipk/kernel/4.1.38-vbnts/index.html) | Router-tested TUN, WireGuard and SPU for the VBNT-S ABI. |
| [VBNT-S expanded release](https://github.com/FrancYescO/GUI_ipk/releases/tag/kernel-4.1.38-vbnts-candidates-d399eee) | 213 compiled modules and 212 staged candidate IPKs, including QoS and USB tethering. These additional modules still need router validation. |
| [VBNT-O validation](https://francyesco.github.io/GUI_ipk/validation/4.1.38/index.html) | Per-payload results; functional validation is distinct from load/unload checks. |

The published VBNT-O results include 58 candidates with functional checks,
including `act_connmark`, `act_skbedit` and `sch_hfsc`. These exact payloads can
be considered for packaging in that profile's verified feed.
Those results do not validate the separately compiled VBNT-S modules. USB
candidates need device-level tests; the `4.1.38` `xt_nat` candidate remains quarantined and has no
candidate IPK. Staged candidates are not automatically selected by the GUI.
