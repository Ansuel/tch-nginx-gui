"""Regression tests for the native Extensions manager integrations."""

from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / "decompressed/gui_file"
INSTALLER = GUI / "usr/share/transformer/scripts/appInstallRemoveUtility.sh"
RPC_MAP = GUI / "usr/share/transformer/mappings/rpc/system.modgui.map"
UCI_MAP = GUI / "usr/share/transformer/mappings/uci/modgui.map"
MODAL = GUI / "www/docroot/modals/applications-modal.lp"
CARD = GUI / "www/cards/009_extensions.lp"
CONFIG = GUI / "etc/modgui_scripts/04_config.sh"

EXTENSIONS = {
    "adblock": "adblock_app",
    "rsyncd": "rsyncd_app",
    "speedtest": "speedtest_app",
    "adguardhome": "adguardhome_app",
    "openspeedtest": "openspeedtest_app",
    "wireguard": "wireguard_app",
    "l2tpipsec": "l2tpipsec_app",
    "openvpn": "openvpn_app",
    "tailscale": "tailscale_app",
    "dumaos": "dumaos_app",
}


class ExtensionManager(unittest.TestCase):
    def test_extensions_are_whitelisted_dispatched_and_mapped(self):
        installer = INSTALLER.read_text()
        rpc_map = RPC_MAP.read_text()
        uci_map = UCI_MAP.read_text()
        config = CONFIG.read_text()

        for app, option in EXTENSIONS.items():
            with self.subTest(app=app):
                self.assertIn(f'"{app}",', rpc_map)
                self.assertIn(f"  {app})", installer)
                self.assertIn(f"app_{app}()", installer)
                self.assertIn(f'"{option}"', uci_map)
                self.assertIn(f"modgui.app.{option}", config)

    def test_downloaded_binaries_use_official_https_sources(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_speedtest()")
        end = installer.index("install_specific_files()", start)
        downloaded_extensions = installer[start:end]
        self.assertIn("https://install.speedtest.net/app/cli/", downloaded_extensions)
        self.assertIn("https://static.adguard.com/adguardhome/release/", downloaded_extensions)
        self.assertNotIn("curl | sh", downloaded_extensions)
        self.assertNotIn("curl | ash", downloaded_extensions)

    def test_adguard_install_does_not_reconfigure_dns(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_adguardhome()")
        end = installer.index("install_specific_files()", start)
        adguard = installer[start:end]

        self.assertNotIn("dnsmasq", adguard)
        self.assertNotIn("port 53", adguard)
        self.assertIn('"$adguard_bin" -s install', adguard)
        self.assertIn("require_free_space 49152 /opt", adguard)
        self.assertIn('adguard_work="/tmp/AdGuardHomeWork"', adguard)
        self.assertIn("$3 == \"jffs2\"", adguard)

    def test_rsync_removal_only_removes_an_owned_dependency(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_rsyncd()")
        end = installer.index("app_speedtest()", start)
        rsyncd = installer[start:end]
        self.assertIn("opkg remove rsyncd", rsyncd)
        self.assertIn('if [ -f "$rsync_owned" ]', rsyncd)
        self.assertIn("opkg remove rsync", rsyncd)

    def test_armv7_adguard_uses_soft_float_binary(self):
        installer = INSTALLER.read_text()
        self.assertIn('armv7*) adguard_arch="armv5"', installer)

    def test_openspeedtest_is_pinned_verified_and_keeps_nginx_global_config(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_openspeedtest()")
        end = installer.index("install_specific_files()", start)
        openspeedtest = installer[start:end]
        self.assertIn(
            'openspeedtest_commit="f4263546f50694a154fdd27a03000390949068df"',
            openspeedtest,
        )
        self.assertIn(
            'openspeedtest_sha256="f8d239bc4183c214c0747ec1a1c418fd33773683f82e7ee8327cf734ea6a4987"',
            openspeedtest,
        )
        self.assertIn("sha256sum", openspeedtest)
        self.assertIn("server_openspeedtest.conf", openspeedtest)
        self.assertNotIn("/etc/nginx/nginx.conf", openspeedtest)

    def test_wireguard_is_capability_gated_pinned_and_installs_disabled(self):
        installer = INSTALLER.read_text()
        defaults = (GUI / "usr/share/modgui-wireguard/wireguard.default").read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("app_l2tpipsec()", start)
        wireguard = installer[start:end]
        modal = MODAL.read_text()

        self.assertIn("CONFIG_TUN=y", wireguard)
        self.assertIn("19.4.0866-3401052", wireguard)
        self.assertIn("tun-vbntj-damson-4.1.52.ko", wireguard)
        self.assertIn("wireguard_install_tun", wireguard)
        self.assertIn("wireguard_remove_tun", wireguard)
        self.assertIn(
            'wireguard_commit="7ac8fe29a7ab64eb0c9c9774bb36cf2c7648399e"',
            wireguard,
        )
        self.assertIn(
            'wireguard_sha256="0cd9777ae758b180a140a11e24eea1716c001fcd2ef82adb0b43225b4929610b"',
            wireguard,
        )
        self.assertIn("sha256sum", wireguard)
        self.assertIn("raw.githubusercontent.com/seud0nym/openwrt-wireguard-go/$wireguard_commit", wireguard)
        self.assertNotIn("uci set network.", wireguard)
        self.assertNotIn("uci set firewall.", wireguard)
        self.assertIn("wireguard.wg.enabled='0'", wireguard)
        self.assertIn("wireguard.wg.allow_lan='0'", wireguard)
        self.assertIn("wireguard.wg.allow_wan='0'", wireguard)
        self.assertIn("option allow_lan '0'", defaults)
        self.assertIn("option allow_wan '0'", defaults)
        self.assertNotIn("firewall.modgui_wireguard_udp=rule", wireguard)
        self.assertIn("kernel_has_tun", modal)
        self.assertIn("built without TUN support", modal)

    def test_wireguard_removal_is_ownership_aware(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("app_l2tpipsec()", start)
        wireguard = installer[start:end]
        self.assertIn('wireguard_owned="/etc/.modgui-wireguard-go-installed"', wireguard)
        self.assertIn('[ -f "$wireguard_owned" ]', wireguard)
        self.assertIn("opkg remove wireguard-go", wireguard)
        self.assertIn("Remove manually configured WireGuard network interfaces", wireguard)
        self.assertIn("wireguard_cleanup_network", wireguard)
        self.assertIn("web.wireguard_card", wireguard)
        self.assertIn("modgui-wireguard-gui.tar.gz", wireguard)

    def test_wireguard_card_and_apply_configuration_on_enable(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("app_l2tpipsec()", start)
        wireguard = installer[start:end]
        card = (GUI / "www/cards/016_wireguard.lp").read_text()
        modal = (GUI / "www/docroot/modals/wireguard-modal.lp").read_text()
        apply_script = (GUI / "usr/share/transformer/scripts/wireguardApply.sh").read_text()
        config = CONFIG.read_text()

        for path in (
            GUI / "usr/share/modgui-wireguard/wireguard.default",
            GUI / "usr/share/transformer/mappings/uci/wireguard.map",
            GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map",
            GUI / "usr/share/transformer/commitapply/uci_wireguard.ca",
            GUI / "usr/share/transformer/scripts/wireguardApply.sh",
            GUI / "usr/share/transformer/scripts/wireguardStatus.sh",
            GUI / "usr/share/transformer/scripts/wireguardKeygen.sh",
            GUI / "www/cards/016_wireguard.lp",
            GUI / "www/docroot/modals/wireguard-modal.lp",
            GUI / "www/lang/it-it/webui-wireguard.po",
        ):
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

        self.assertIn("wireguard_prepare_config", wireguard)
        self.assertIn("wireguard_backup_gui", wireguard)
        self.assertIn("wireguard_repair_gui", wireguard)
        self.assertIn("wireguardApply.sh", wireguard)
        self.assertIn("/opt/modgui-wireguard-gui.tar.gz", config)
        self.assertIn("appInstallRemoveUtility.sh refresh wireguard", config)

        self.assertIn("network.modgui_wg0.proto='wireguard'", apply_script)
        self.assertIn("wireguard_modgui_wg0", apply_script)
        self.assertIn("firewall.modgui_wireguard_zone", apply_script)
        self.assertIn("firewall.modgui_wireguard_to_lan", apply_script)
        self.assertIn("firewall.modgui_wireguard_to_wan", apply_script)
        self.assertIn("wireguard.wg.listen_port", apply_script)
        self.assertIn('grep -q \'"proto": "none"\'', apply_script)
        self.assertIn("/etc/init.d/network restart", apply_script)
        self.assertNotIn("firewall.modgui_wan_to_wireguard", apply_script)
        self.assertIn("firewall.modgui_wireguard_zone.input='REJECT'", apply_script)
        self.assertNotIn("firewall.modgui_lan_to_wireguard=forwarding", apply_script)
        self.assertIn("valid_cidr", apply_script)
        self.assertIn('[ "$endpoint_port" -le 65535 ]', apply_script)
        self.assertIn('[ "$keepalive" -le 320 ]', apply_script)
        self.assertIn('valid_key "$preshared_key"', apply_script)
        self.assertIn("umask 077", (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn("printf '%s\\n'", (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn('if [ "$2" = "export" ]',
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn('server_public="${3:-$(uci -q get wireguard.wg.public_key)}"',
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn("chmod 600 /tmp/modgui-wireguard-client.conf",
                      (GUI / "usr/share/transformer/scripts/wireguardKeygen.sh").read_text())
        self.assertIn("A pre-existing WireGuard runtime is installed; refusing to remove it", wireguard)
        self.assertIn(".modgui-openvpn-tun-installed", wireguard)
        self.assertIn("30-modgui-openvpn-tun", wireguard)

        self.assertIn("uci.wireguard.wg.enabled", card)
        self.assertIn("wireguardStatus.sh", card)
        self.assertIn("wireguardStatus.sh", modal)
        self.assertIn("wireguardKeygen.sh", modal)
        self.assertNotIn("?keygen=", modal)
        self.assertIn('data-value="WG_KEYGEN_INTERFACE"', modal)
        self.assertIn("plain(ngx.var.http_host)", modal)
        self.assertIn(
            'plain(host:gsub(":%d+$", ""):gsub("[^A-Za-z0-9.%-]", ""))',
            modal,
        )
        self.assertIn('run_keygen("interface export")', modal)
        self.assertIn('["uci.wireguard.wg.private_key"] = private', modal)
        self.assertIn('server_public = getvalue("uci.wireguard.wg.public_key")', modal)
        self.assertIn('local submitted_private = plain(post_args.private_key)', modal)
        self.assertIn('if submitted_private == "********" then submitted_private = "" end', modal)
        self.assertIn('if submitted_private ~= "" then', modal)
        self.assertIn('validators.private_key = valid_private_key', modal)
        self.assertIn('post_helper.handleQuery(map_params, validators)', modal)
        self.assertIn('content.private_key = getvalue("uci.wireguard.wg.private_key")', modal)
        self.assertIn('type = "password"', modal)
        self.assertIn('if value == "********" then return true end', modal)
        self.assertIn("uci.wireguard.peer.@.", modal)
        self.assertIn('name = "uci.wireguard.peer.@."',
                       (GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map").read_text())
        peer_map = (GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map").read_text()
        self.assertIn('param == "preshared_key" and value ~= ""', peer_map)
        self.assertIn('tostring(value or "") == "********"', peer_map)


    def test_l2tpipsec_is_pinned_fixed_and_starts_disabled(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_l2tpipsec()")
        end = installer.index("install_specific_files()", start)
        vpn = installer[start:end]

        self.assertIn(
            'l2tpipsec_commit="5c9015930961848259aa883cbe1a20c02a227de4"',
            vpn,
        )
        self.assertIn(
            'l2tpipsec_sha256="5604db2e143c339eb1db0cb980e30492c2e5f57c4e35f06b52d224fb4822de18"',
            vpn,
        )
        self.assertIn("sha256sum", vpn)
        self.assertIn("modgui-vpn_1.1-0_all.ipk", vpn)
        self.assertIn("grep -q '^xl2tpd version:'", vpn)
        self.assertIn("/etc/init.d/modgui-ipsec restart", vpn)
        self.assertNotIn("l2tpipsec_fix_runtime", vpn)
        self.assertIn("modgui-l2tp-ipsec-gui.tar.gz", vpn)
        self.assertIn("l2tpipsec_set_enabled 0", vpn)
        self.assertNotIn("--force-overwrite", vpn)
        self.assertNotIn("spuctl", vpn)
        self.assertNotIn("/etc/init.d/ipsec restart", vpn)
        self.assertGreaterEqual(vpn.count("l2tpipsec_rollback_install"), 5)

    def test_l2tpipsec_removal_tracks_owned_packages(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_l2tpipsec()")
        end = installer.index("install_specific_files()", start)
        vpn = installer[start:end]
        self.assertIn(".modgui-l2tp-ipsec-packages", vpn)
        self.assertIn("grep -Fxq", vpn)
        self.assertIn("opkg remove \"$package\"", vpn)
        self.assertLess(
            vpn.index("l2tpipsec_remove_owned_package strongswan-default"),
            vpn.index("grep '^strongswan-mod-'"),
        )
        self.assertLess(
            vpn.index("l2tpipsec_remove_owned_package strongswan-ipsec"),
            vpn.index("l2tpipsec_remove_owned_package strongswan\n"),
        )
        self.assertIn("delete web.l2tpipsecserver_card", vpn)

    def test_l2tpipsec_is_only_shown_on_supported_cpus(self):
        modal = MODAL.read_text()
        card = CARD.read_text()
        architecture_gate = (
            'if cputype:match("^armv7") or cputype:match("^mips") then\n'
            '\tmapParams.l2tpipsec_application = "uci.modgui.app.l2tpipsec_app"\n'
            "end"
        )
        self.assertIn(architecture_gate, modal)
        self.assertIn(architecture_gate, card)

    def test_openvpn_is_safe_gated_and_starts_disabled(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_openvpn()")
        end = installer.index("install_specific_files()", start)
        vpn = installer[start:end]
        modal = MODAL.read_text()
        card = CARD.read_text()

        self.assertIn("openvpn-openssl openvpn-easy-rsa", vpn)
        self.assertIn("openvpn_has_tun", vpn)
        self.assertIn("CONFIG_TUN=y", vpn)
        self.assertIn("A pre-existing OpenVPN installation was found", vpn)
        self.assertIn(".modgui-openvpn-packages", vpn)
        self.assertIn("openvpn.server.enabled=0", vpn)
        self.assertIn("openvpnGenerateKeys.sh", vpn)
        self.assertIn("openvpnApply.sh", vpn)
        self.assertIn('openvpn_gui_backup="/opt/modgui-openvpn-gui.tar.gz"', vpn)
        self.assertIn('openvpn_backup_gui || return 1', vpn)
        self.assertIn('tar -xzf "$openvpn_gui_backup" -C /', vpn)
        self.assertIn('openvpn_repair_gui', vpn)
        self.assertIn('if [ -d "$openvpn_openssl_lib/usr/lib" ]', vpn)
        self.assertIn('openvpn_register_client', vpn)
        self.assertIn('openvpnClientRoute.sh', vpn)
        self.assertIn('openvpn.client.map', vpn)
        self.assertIn('openvpn.client.ssid.map', vpn)
        self.assertIn("firewall.modgui_openvpn", vpn)
        self.assertNotIn("--force-overwrite", vpn)
        self.assertIn('mapParams.openvpn_application = "uci.modgui.app.openvpn_app"', modal)
        self.assertIn('mapParams.openvpn_application = "uci.modgui.app.openvpn_app"', card)
        config = CONFIG.read_text()
        self.assertIn('/opt/modgui-openvpn-gui.tar.gz', config)
        self.assertIn('appInstallRemoveUtility.sh refresh openvpn', config)

    def test_openvpn_assets_are_present(self):
        expected = (
            GUI / "usr/share/modgui-openvpn/openvpn.default",
            GUI / "usr/share/modgui-openvpn/checkpwd.sh",
            GUI / "usr/share/transformer/mappings/uci/openvpn.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.server.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.client.map",
            GUI / "usr/share/transformer/mappings/rpc/openvpn.client.ssid.map",
            GUI / "usr/share/transformer/commitapply/uci_openvpn.ca",
            GUI / "usr/share/transformer/scripts/openvpnApply.sh",
            GUI / "usr/share/transformer/scripts/openvpnGenerateKeys.sh",
            GUI / "usr/share/transformer/scripts/openvpnClientRoute.sh",
            GUI / "etc/hotplug.d/iface/95-modgui-openvpn-client",
            GUI / "www/cards/015_openvpn-server.lp",
            GUI / "www/docroot/modals/openvpn-server-modal.lp",
        )
        for path in expected:
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

    def test_openvpn_client_keeps_main_route_and_discovers_ssids(self):
        apply_script = (GUI / "usr/share/transformer/scripts/openvpnApply.sh").read_text()
        route_script = (GUI / "usr/share/transformer/scripts/openvpnClientRoute.sh").read_text()
        ssid_map = (GUI / "usr/share/transformer/mappings/rpc/openvpn.client.ssid.map").read_text()
        modal = (GUI / "www/docroot/modals/openvpn-server-modal.lp").read_text()
        self.assertIn("route-nopull", apply_script)
        self.assertIn("dev tun1", apply_script)
        self.assertIn("unreachable default", route_script)
        self.assertIn('network ~= "lan"', ssid_map)
        self.assertIn('rpc.openvpn.client.ssid.', modal)
        self.assertIn('local raw = string.untaint(value or "")', modal)
        self.assertIn('local path = item.path and string.untaint(item.path)', modal)
        self.assertNotIn("route_guest_24", route_script)
        self.assertNotIn("route_guest_5", route_script)

    def test_tailscale_is_pinned_gated_and_starts_disabled(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_tailscale()")
        end = installer.index("install_specific_files()", start)
        tailscale = installer[start:end]
        modal = MODAL.read_text()
        card = CARD.read_text()
        config = CONFIG.read_text()

        self.assertIn('tailscale_version="1.102.4"', tailscale)
        self.assertIn(
            'tailscale_sha256="b981a59cb85fb923ee6e1860ee6934772c83a840a6627f0dbfd7711ed690b869"',
            tailscale,
        )
        self.assertIn(
            'tailscale_sha256="9dd1e6a592a014bbaea0103167ffe299adeda4ba14e078ce9c2895364f6c4c3f"',
            tailscale,
        )
        self.assertIn("https://pkgs.tailscale.com/stable/", tailscale)
        self.assertIn("sha256sum", tailscale)
        self.assertIn("tailscale_has_tun", tailscale)
        self.assertIn("CONFIG_TUN=y", tailscale)
        self.assertIn("A pre-existing Tailscale installation was found", tailscale)
        self.assertIn("tailscale.service.enabled=0", tailscale)
        self.assertIn("tailscale.service.connect=0", tailscale)
        self.assertIn(".modgui-tailscale-packages", tailscale)
        self.assertIn("modgui-tailscale-gui.tar.gz", tailscale)
        self.assertIn("tailscale_has_space 131072 /tmp", tailscale)
        self.assertIn("/tmp/modgui-tailscale-runtime", tailscale)
        self.assertIn("tailscale.service.download_url", tailscale)
        self.assertNotIn("opkg install ca-bundle", tailscale)
        self.assertIn('curl -kfL "https://pkgs.tailscale.com/stable/', tailscale)
        self.assertNotIn("curl | sh", tailscale)
        self.assertIn('mapParams.tailscale_application = "uci.modgui.app.tailscale_app"', modal)
        self.assertIn('mapParams.tailscale_application = "uci.modgui.app.tailscale_app"', card)
        self.assertIn("appInstallRemoveUtility.sh refresh tailscale", config)

    def test_tailscale_assets_and_safe_routing_are_present(self):
        expected = (
            GUI / "usr/share/modgui-tailscale/tailscale.default",
            GUI / "usr/share/modgui-tailscale/tailscale.init",
            GUI / "usr/share/modgui-tailscale/tailscale.bootstrap",
            GUI / "usr/share/modgui-tailscale/tailscale.connect",
            GUI / "usr/share/transformer/mappings/uci/tailscale.map",
            GUI / "usr/share/transformer/commitapply/uci_tailscale.ca",
            GUI / "usr/share/transformer/scripts/tailscaleApply.sh",
            GUI / "usr/share/transformer/scripts/tailscaleStatus.sh",
            GUI / "www/cards/016_tailscale.lp",
            GUI / "www/docroot/modals/tailscale-modal.lp",
            GUI / "www/lang/it-it/webui-tailscale.po",
        )
        for path in expected:
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

        apply_script = (GUI / "usr/share/transformer/scripts/tailscaleApply.sh").read_text()
        connect_script = (GUI / "usr/share/modgui-tailscale/tailscale.connect").read_text()
        modal = (GUI / "www/docroot/modals/tailscale-modal.lp").read_text()
        self.assertIn("--netfilter-mode=off", connect_script)
        self.assertIn("firewall.modgui_tailscale_to_lan", apply_script)
        self.assertIn("firewall.modgui_tailscale_to_wan", apply_script)
        self.assertIn("firewall.modgui_tailscale_zone.device='tailscale0'", apply_script)
        self.assertNotIn("firewall.modgui_wan_to_tailscale", apply_script)
        init_script = (GUI / "usr/share/modgui-tailscale/tailscale.init").read_text()
        self.assertIn("chown root:nogroup", connect_script)
        self.assertIn("chmod 640", connect_script)
        self.assertIn("tailscale.bootstrap", init_script)
        self.assertIn("tailscale.connect", init_script)
        self.assertNotIn("sleep 1", apply_script)
        self.assertIn("https://login%.tailscale%.com/", modal)
        self.assertNotIn("authkey", modal.lower())

    def test_dumaos_is_pinned_verified_detected_and_armv7_only(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_dumaos()")
        end = installer.index("install_specific_files()", start)
        dumaos = installer[start:end]
        modal = MODAL.read_text()
        card = CARD.read_text()
        config = CONFIG.read_text()
        dumaos_card = (GUI / "usr/share/modgui-dumaos/015_dumaos.lp").read_text()

        self.assertIn(
            'dumaos_commit="884a5351b3a7659f7bf8397ee079eec5ea33cfe0"',
            dumaos,
        )
        self.assertIn('dumaos_version="2.0-32"', dumaos)
        self.assertIn('dumaos_tag="dumaos-repack-v$dumaos_version"', dumaos)
        self.assertIn('dumaos-repack_${dumaos_version}_all.ipk', dumaos)
        self.assertIn(
            'dumaos_sha256="a811a5d0ae8ba2e95ae05f573ce5debe6ca30259654910cfc1fd79681f9ae6c4"',
            dumaos,
        )
        self.assertIn("releases/download/$dumaos_tag/$dumaos_package", dumaos)
        self.assertIn('dumaos_installed_version', dumaos)
        self.assertIn("sha256sum", dumaos)
        self.assertIn('opkg install "$dumaos_tmp"', dumaos)
        self.assertNotIn("--force-overwrite", dumaos)
        self.assertIn("opkg remove dumaos-repack", dumaos)
        self.assertIn("dumaos_install_qos_module", dumaos)
        self.assertIn("act-connmark-damson-4.1.52.ko", dumaos)
        self.assertIn("/www/cards/015_dumaos.lp", dumaos)
        self.assertIn("/usr/share/modgui-dumaos/015_dumaos.lp", dumaos)
        self.assertIn("uci set web.dumaos_card=card", dumaos)
        self.assertIn("uci set web.dumaos_card.card=015_dumaos.lp", dumaos)
        self.assertIn("uci set web.dumaos_card.modal=duma_desktop_index", dumaos)
        self.assertIn("uci -q delete web.dumaos_card", dumaos)
        self.assertIn('href="/desktop"', dumaos_card)
        self.assertIn('onclick="event.stopPropagation()"', dumaos_card)
        self.assertIn('ontouchend="event.stopPropagation()"', dumaos_card)
        self.assertNotIn(":81", dumaos_card)
        self.assertIn('status = "rpc.dumaos.status"', dumaos_card)
        self.assertIn("/usr/share/transformer/mappings/rpc/dumaos.map", dumaos)
        self.assertIn('mapParams.dumaos_application = "uci.modgui.app.dumaos_app"', modal)
        self.assertIn('mapParams.dumaos_application = "uci.modgui.app.dumaos_app"', card)
        self.assertIn('local dumaos_link = "/desktop"', modal)
        self.assertIn("reboot the gateway after installation and after removal", modal)
        self.assertIn("opkg status dumaos-repack", config)
        self.assertIn("dumaos_remove_firewall", dumaos)
        self.assertIn('"DumaOS UI" | dumaos_ui', dumaos)
        self.assertNotIn("firewall.dumaos_ui=rule", dumaos)
        self.assertNotIn("curl | sh", dumaos)
        self.assertNotIn("curl | ash", dumaos)

    def test_arm_only_extensions_are_hidden_on_mips(self):
        modal = MODAL.read_text()
        card = CARD.read_text()
        condition = (
            'if cputype:match("^armv7") or cputype == "aarch64" '
            'or cputype == "arm64" then'
        )
        for source in (modal, card):
            self.assertIn(condition, source)
            block = source[source.index(condition):]
            block = block.split('if marketing_version >= 17.3 then', 1)[0]
            self.assertIn("speedtest_app", block)
            self.assertIn("adguardhome_app", block)
            self.assertIn("wireguard_app", block)
            self.assertIn("tailscale_app", block)

    def test_shell_sources_parse(self):
        sources = (
            INSTALLER,
            CONFIG,
            GUI / "usr/share/transformer/scripts/tailscaleApply.sh",
            GUI / "usr/share/transformer/scripts/tailscaleStatus.sh",
            GUI / "usr/share/transformer/scripts/wireguardApply.sh",
            GUI / "usr/share/transformer/scripts/wireguardStatus.sh",
            GUI / "usr/share/transformer/scripts/wireguardKeygen.sh",
            GUI / "usr/share/modgui-tailscale/tailscale.init",
            GUI / "usr/share/modgui-tailscale/tailscale.bootstrap",
            GUI / "usr/share/modgui-tailscale/tailscale.connect",
        )
        for source in sources:
            with self.subTest(source=source.name):
                subprocess.run(["sh", "-n", source], check=True)

    @unittest.skipUnless(shutil.which("luac"), "luac is not installed")
    def test_lua_sources_parse(self):
        sources = (
            RPC_MAP,
            UCI_MAP,
            MODAL,
            CARD,
            GUI / "usr/share/transformer/mappings/uci/tailscale.map",
            GUI / "usr/share/transformer/mappings/uci/wireguard.map",
            GUI / "usr/share/transformer/mappings/uci/wireguard.peer.map",
            GUI / "www/cards/016_tailscale.lp",
            GUI / "www/docroot/modals/tailscale-modal.lp",
            GUI / "www/cards/016_wireguard.lp",
            GUI / "www/docroot/modals/wireguard-modal.lp",
        )
        for source in sources:
            with self.subTest(source=source.name):
                subprocess.run(["luac", "-p", source], check=True)


if __name__ == "__main__":
    unittest.main()
