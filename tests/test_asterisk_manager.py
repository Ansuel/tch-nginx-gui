import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / "decompressed/gui_file"
MODAL = GUI / "www/docroot/modals/asterisk-profile-modal.lp"
TABS = GUI / "www/snippets/tabs-voice.lp"
UNLOCK = GUI / "usr/share/transformer/scripts/unlock_and_refresh_web_config.lua"
APPLY = GUI / "usr/share/transformer/scripts/applyAsteriskConfig.sh"
COMMIT_APPLY = GUI / "usr/share/transformer/commitapply/uci_pbx.ca"
MAPS = [
    GUI / "usr/share/transformer/mappings/uci/pbx-advanced.map",
    GUI / "usr/share/transformer/mappings/uci/pbx-users.map",
    GUI / "usr/share/transformer/mappings/uci/pbx-voip.map",
]


class AsteriskManagerTests(unittest.TestCase):
    def test_tab_is_only_added_for_asterisk_and_pbx_configurator(self):
        source = TABS.read_text()
        self.assertIn('file_exists("/etc/init.d/asterisk")', source)
        self.assertIn('file_exists("/etc/init.d/pbx-asterisk")', source)
        self.assertIn('asterisk-profile-modal.lp', source)

    def test_existing_dect_tab_logic_is_valid(self):
        source = TABS.read_text()
        self.assertIn('content.variant == "Technicolor TG799vac"', source)
        self.assertNotIn('tinsert(items, tinsert(items,', source)

    def test_modal_uses_real_luci_pbx_config_files(self):
        source = MODAL.read_text()
        self.assertIn('uci.pbx-advanced.advanced.useragent', source)
        self.assertNotIn('uci.pbx-advanced.settings.', source)
        self.assertIn('uci.pbx-users.local_user.@.', source)
        self.assertIn('uci.pbx-voip.voip_provider.@.', source)
        self.assertNotIn('uci.pbx.asterisk', source)

    def test_passwords_are_masked_and_placeholder_is_preserved(self):
        source = MODAL.read_text()
        self.assertIn('type = "password"', source)
        self.assertIn('getValidationPassword', source)
        self.assertIn('row[3] = "********"', source)
        self.assertIn('row[2] = "********"', source)

    def test_status_commands_are_fixed_and_html_escaped(self):
        source = MODAL.read_text()
        for command in (
            "asterisk -V",
            "core show uptime",
            "sip show registry",
            "sip show peers",
            "core show channels",
        ):
            self.assertIn(command, source)
        self.assertIn("escape_html(service_status)", source)
        self.assertIn("escape_html(registrations)", source)

    def test_transformer_maps_cover_all_managed_options(self):
        source = "\n".join(path.read_text() for path in MAPS)
        for config in ("pbx-advanced", "pbx-users", "pbx-voip"):
            self.assertIn(f'registerConfigMap("{config}")', source)
        for option in (
            "useragent",
            "ringtime",
            "rtpstart",
            "rtpend",
            "fullname",
            "defaultuser",
            "secret",
            "register",
            "make_outgoing_calls",
            "outboundproxy",
        ):
            self.assertIn(f'"{option}"', source)

    def test_commit_apply_regenerates_config_then_restarts_asterisk(self):
        commit_apply = COMMIT_APPLY.read_text()
        script = APPLY.read_text()
        for config in ("pbx%-advanced", "pbx%-users", "pbx%-voip"):
            self.assertIn(config, commit_apply)
        self.assertLess(
            script.index("/etc/init.d/pbx-asterisk restart"),
            script.index("/etc/init.d/asterisk restart"),
        )

    def test_voipblock_hooks_are_restored_after_pbx_regeneration(self):
        script = APPLY.read_text()
        self.assertIn("/usr/share/asterisk/agi-bin/voipblock", script)
        self.assertIn("/etc/asterisk/extensions_incoming.conf", script)
        self.assertIn("ASTERISK_MANAGER_VOIPBLOCK", script)
        self.assertIn('AGI(voipblock,${number})', script)
        self.assertIn("[macro-Voipblock]", script)
        self.assertLess(
            script.index("/etc/init.d/pbx-asterisk restart"),
            script.index("ASTERISK_MANAGER_VOIPBLOCK"),
        )
        self.assertLess(
            script.index("ASTERISK_MANAGER_VOIPBLOCK"),
            script.index("/etc/init.d/asterisk restart"),
        )

    def test_access_rule_is_registered(self):
        source = UNLOCK.read_text()
        self.assertIn("asteriskprofilemodal", source)
        self.assertIn("/modals/asterisk-profile-modal.lp", source)

    def test_shell_helper_parses(self):
        subprocess.run(["sh", "-n", APPLY], check=True)

    @unittest.skipUnless(shutil.which("luac"), "luac is not installed")
    def test_lua_sources_parse(self):
        for source in [MODAL, TABS, UNLOCK, *MAPS]:
            with self.subTest(source=source.name):
                subprocess.run(["luac", "-p", source], check=True)


if __name__ == "__main__":
    unittest.main()
