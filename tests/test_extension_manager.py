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
