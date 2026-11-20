# Native Ethernet EasyMesh setup

The EasyMesh card provides **Setup and role** for native controller and Ethernet
booster operation. A network needs one controller; each participating access
point runs an agent. This setup does not configure wireless backhaul.

## Compatibility

Initialization is offered when the native MultiAP agent and controller binaries,
executable init scripts, platform library, Transformer mappings and original ROM
configuration are present. The ROM template must contain the expected global
sections, valid enable flags and controller credential sections. Detection does
not depend on a board name or firmware version.

The initializer uses only the device's own firmware files. It does not install
mesh binaries, copy components from another board or overwrite an existing
MultiAP configuration. Detection makes setup available; it does not establish
that every firmware with those components is stable or interoperable.

This feature was compared with the upstream
[Technicolor Wi-Fi booster implementation](https://github.com/seud0nym/tch-gui-unhide/tree/master/supplemental/wifi-booster).
Its Telstra-specific port assignments, service changes and alternate mesh
backend are not applied to other firmware.

## Native firmware integration

Source review of the original
[RPTEM 1.0.4](https://github.com/FrancYescO/tch_firmware_extracted/tree/RPTEM_1.0.4_CLOSED)
and
[AGTHF 1.3.7](https://github.com/FrancYescO/tch_firmware_extracted/tree/AGTHF_1.3.7_CLOSED)
confirmed the shared `multiap` global sections, controller credential schema,
`web` interface/credential associations and native Transformer commit/apply
service hooks. Setup retains each device's own ROM defaults, binaries, startup
scripts and service ordering. It does not install either reference firmware's
backend onto another device.

Explicit role selection updates the native Wi-Fi Conductor flag when exposed
and disables automatic controller selection when that option exists. Topology
uses the native `FriendlyName`, model and association fields, including the
optional local Ethernet client inventory. Missing objects on older firmware
are tolerated. Radio bands come from the device rather than the reference
firmware's fixed radio names.

This is a source compatibility review; these two reference firmware images
were not tested on hardware as part of this validation.

## Initialization and roles

1. Open the EasyMesh card and confirm native initialization if it is
   offered. Initialization validates the native `web.main` interface/credential
   associations and seeds the controller profiles from the active main Wi-Fi
   configuration. Both services remain disabled until a role is selected.
2. Select **Controller and local agent** on the controller. Only one device on
   the Ethernet network should use this role.
3. Prepare each booster as an Ethernet bridge using Broadband and Internet.
   A DHCP or static management connection on `br-lan` can retain management
   access. LAN DHCP, DHCPv6, RA and NDP services must be disabled so the booster
   does not advertise competing network configuration.
4. Select **Ethernet booster (agent only)** on each booster. The setup validates
   the uplink and bridge prerequisites before enabling the agent. A pre-existing
   access-point bridge is accepted only when its physical Ethernet uplink,
   bridge membership and disabled LAN advertisement services can be verified.
5. Refresh the setup page and check **Agent connection** and the controller's
   extender count. Edit managed Wi-Fi settings on the controller and verify
   propagation to each participating radio.

Check for PPPoE relay restrictions on the chosen Ethernet port and duplicate
secondary LAN addresses when preparing existing router configurations. Use the
bridge helper to coordinate topology changes; do not copy fixed port lists or
blanket service-disable commands from a different firmware. Keep a private
configuration backup and a recovery path before changing bridge membership or
management addressing.

Bridged-node cards open the explicit role selector instead of the combined
on/off switch. This prevents a booster from accidentally enabling another
controller. Turning a mesh role on disables native primary band steering;
turning mesh off does not automatically re-enable it.

All supported layouts share the top navigation: **EasyMesh Configuration**,
**Setup and role**, **Topology** and **Devices**. The native devices inventory is
available on both layouts. Broadband and Internet remain separate setup shortcuts.
Optional stock pages are linked only when their files and access rules exist.

Deploy the complete GUI bundle when updating older installations: the three
native newEM modal files, their assets and web access rules are required even
when only parts of the native layout are used. Devices inventory tolerates older
web helpers without the native rate/data formatters.

## Credential and service handling

Initialization supports active LAN main networks using WPA2-PSK, with either
split-band or shared-band profiles. Shared profiles require matching live SSIDs
and keys on their associated radios. Ambiguous associations, inactive main
networks, protected backhaul interfaces and unsupported security modes are
rejected before the staged configuration is published.

Factory credentials and unused profiles are not activated. The new configuration
is staged in a private directory and published atomically with mode `0600`.
Privileged initialization runs inside Transformer; the unprivileged web worker
does not write the configuration directly. Rendering the card or setup page
does not start a mesh service.

Role changes use native UCI mappings and commit/apply behavior. Radio RPC setters
must remain low-level: the native agent uses them to apply received settings to
the actual radios. The Wireless UI edits managed controller profiles directly.
Redirecting agent RPC writes back into controller profiles prevents the local
radio from receiving configuration even when a remote booster updates correctly.

## Validation and limits

Live validation with a native MultiAP 1.1.24 DGA4130 controller and DGA4132
Ethernet booster covered:

- Explicit initialization and role selection through the browser UI.
- Controller registration of one remote agent with Ethernet backhaul.
- Independent temporary SSID changes on the main 2.4 GHz and 5 GHz profiles,
  propagation to local and remote radio configuration, and restoration of the
  original settings.
- SSID, key and security equality through persisted UCI and native wireless ubus
  APIs on all four main radios.
- Agent shutdown and rejoining through the setup UI while retaining management
  access and synchronized credentials.
- Role-safe cards, access checks and card refresh for modal URLs with queries.
- Four sequential software reboots: controller, booster, booster, controller,
  allowing the mesh to recover between reboots. Both nodes rejoined automatically
  after each reboot, with one controller and one remote agent. Observed control
  plane recovery ranged from approximately two to two and a half minutes.
- Final native radio checks confirmed all four main radios operational with
  SSID, key and security matching persisted configuration. Roles, management
  bridge, disabled LAN DHCP/RA services and deployed sources survived the reboots.

Regression fixtures cover initialization safeguards, role handling, managed
radios, model image selection and topology rendering. The topology uses bundled
model images when available and generic icons otherwise, and tolerates missing
optional inventory and malformed parent relationships.

Before declaring a firmware combination stable, validate:

- Cold boot and overlapping startup of both nodes in either order, including
  recovery when the controller becomes available after the booster.
- Ethernet disconnection and reconnection with automatic agent recovery,
  without duplicate controllers or DHCP servers.
- Sustained operation with multiple clients, credential changes, client roaming
  and throughput measurements.
- Additional native firmware/backend versions with the same detected features.

Client roaming, throughput, over-air packet capture, wireless backhaul, guest
propagation, power removal and simultaneous startup were not validated.
The live results above establish an Ethernet proof of concept on that tested
pair; capability detection is not a compatibility guarantee for all devices.
