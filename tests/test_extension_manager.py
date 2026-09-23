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

    def test_wireguard_is_capability_gated_pinned_and_non_configuring(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("install_specific_files()", start)
        wireguard = installer[start:end]
        modal = MODAL.read_text()

        self.assertIn("CONFIG_TUN=y", wireguard)
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
        self.assertNotIn("51820", wireguard)
        self.assertIn("kernel_has_tun", modal)
        self.assertIn("built without TUN support", modal)

    def test_wireguard_removal_is_ownership_aware(self):
        installer = INSTALLER.read_text()
        start = installer.index("app_wireguard()")
        end = installer.index("install_specific_files()", start)
        wireguard = installer[start:end]
        self.assertIn('wireguard_owned="/etc/.modgui-wireguard-go-installed"', wireguard)
        self.assertIn('[ -f "$wireguard_owned" ]', wireguard)
        self.assertIn("opkg remove wireguard-go", wireguard)

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
            GUI / "usr/share/transformer/commitapply/uci_openvpn.ca",
            GUI / "usr/share/transformer/scripts/openvpnApply.sh",
            GUI / "usr/share/transformer/scripts/openvpnGenerateKeys.sh",
            GUI / "www/cards/015_openvpn-server.lp",
            GUI / "www/docroot/modals/openvpn-server-modal.lp",
        )
        for path in expected:
            with self.subTest(path=path):
                self.assertTrue(path.is_file())

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
            block = block[:block.index("end")]
            self.assertIn("speedtest_app", block)
            self.assertIn("adguardhome_app", block)
            self.assertIn("wireguard_app", block)

    def test_shell_sources_parse(self):
        for source in (INSTALLER, CONFIG):
            with self.subTest(source=source.name):
                subprocess.run(["sh", "-n", source], check=True)

    @unittest.skipUnless(shutil.which("luac"), "luac is not installed")
    def test_lua_sources_parse(self):
        for source in (RPC_MAP, UCI_MAP, MODAL, CARD):
            with self.subTest(source=source.name):
                subprocess.run(["luac", "-p", source], check=True)


if __name__ == "__main__":
    unittest.main()
