"""Verify service activation on legacy and current rc.common implementations."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh"
WIRELESS_SETUP = INSTALLER.parents[5] / "luci_wireless/setup.sh"


class LuciActivation(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua"), "Lua required")
    def test_gui_upgrade_prepares_terminal_before_dispatch(self):
        source = (INSTALLER.parents[1] / "mappings/rpc/system.modgui.map").read_text()
        utility = source[source.index("local SYSTEM_MODGUI_UTILITY_ ="):source.index("local SYSTEM_MODGUI_DEBUGLOG_ =")]
        terminal = source[source.index("local SYSTEM_MODGUI_SCRIPTREQUEST_ ="):source.index("local SYSTEM_MODGUI_APP_ =")]
        prelude = '''
local maps, launches, log = {}, 0, "previous GUI update log"
local prepare_command_log
local commands_helper = {upgradegui = "start-stop-daemon -x /usr/share/transformer/scripts/wrapper.sh upgradegui"}
register = function(map) maps[map.objectType.name] = map end
os.remove = function() end
local fail_log = false
io.open = function(path, mode)
    if mode == nil then return {read = function() return "Complete" end, close = function() end} end
    if path == "/tmp/command_log" then
        if fail_log then return nil, "no space" end
        log = ""
    end
    return {write = function() end, close = function() end}
end
local async_exec = function()
    assert(maps["rpc.system.modgui.executeCommand."].get.state() == "Requested")
    assert(log == "")
    launches = launches + 1
end
'''
        assertions = '''
local send = maps["rpc.system.modgui.utility."].set.sendcmd
send(nil, "sendcmd", "upgradegui")
assert(launches == 1)
fail_log = true
local ok, err = send(nil, "sendcmd", "upgradegui")
assert(ok == nil and err == "no space" and launches == 1)
'''
        result = subprocess.run(["lua", "-"], input=prelude + utility + terminal + assertions,
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_feed_failure_stops_before_installing_packages(self):
        source = INSTALLER.read_text()
        start = source.index("app_luci() {")
        function = source[start:source.index("\napp_amule()", start)]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            opkg = root / "opkg"
            opkg.write_text('#!/bin/sh\necho "$*" >> "$TEST_ROOT/actions"\nexit 7\n')
            opkg.chmod(0o755)
            result = subprocess.run(
                ["sh", "-c", function + '\nmarketing_version=18.3; cpu_type=armv7l; app_luci install'],
                env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}", "TEST_ROOT": str(root)},
                capture_output=True, text=True, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((root / "actions").read_text(), "update\n")
            self.assertIn("another opkg process", result.stdout)

    @unittest.skipUnless(shutil.which("lua"), "Lua required")
    def test_duplicate_requests_preserve_log_and_stale_requests_can_retry(self):
        mapping = INSTALLER.parents[1] / "mappings/rpc/system.modgui.map"
        source = mapping.read_text()
        snippet = source[source.index("local SYSTEM_MODGUI_SCRIPTREQUEST_ ="):]
        prelude = '''
local maps, launches, log_writes = {}, 0, 0
local now, running = 100, ""
register = function(map) maps[map.objectType.name] = map end
os.time = function() return now end
os.remove = function() end
io.open = function(path, mode)
    if mode == nil then return nil end
    if path == "/tmp/command_log" then log_writes = log_writes + 1 end
    return {write = function() end, close = function() end}
end
io.popen = function() return {read = function() return running end, close = function() end} end
local async_exec = function() launches = launches + 1 end
'''
        assertions = '''
local app = maps["rpc.system.modgui.app."].set.sendcmd
local state = maps["rpc.system.modgui.executeCommand."].set.state
app(nil, "sendcmd", "install_luci")
assert(launches == 1 and log_writes == 1)
local ok, err = app(nil, "sendcmd", "install_luci")
assert(ok == nil and err and launches == 1 and log_writes == 1)
now = 110; running = "123\\n"
state(nil, "state", "In Progress")
ok, err = app(nil, "sendcmd", "install_luci")
assert(ok == nil and err and launches == 1 and log_writes == 1)
state(nil, "state", "Complete")
ok, err = app(nil, "sendcmd", "install_luci")
assert(ok == nil and err and launches == 1 and log_writes == 1)
state(nil, "state", "Requested")
running = ""
app(nil, "sendcmd", "install_luci")
assert(launches == 2 and log_writes == 2)
state(nil, "state", "Error")
app(nil, "sendcmd", "install_luci")
assert(launches == 3)
'''
        result = subprocess.run(["lua", "-"], input=prelude + snippet + assertions,
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def activate(self, enabled_status):
        source = INSTALLER.read_text()
        start = source.index("      /etc/init.d/uhttpd enable")
        activation = source[start:source.index("    }", start)]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            service = root / "uhttpd"
            calls = root / "calls"
            service.write_text(
                '#!/bin/sh\necho "$1" >> "$TEST_CALLS"\n'
                'case "$1" in\nenable) exit 1;;\n'
                f'enabled) exit {enabled_status};;\nrestart) exit 0;;\nesac\n'
            )
            service.chmod(0o755)
            script = "activate() {\n" + activation.replace("/etc/init.d/uhttpd", str(service)) + "}\nactivate\n"
            result = subprocess.run(
                ["sh", "-c", script],
                env={**os.environ, "TEST_CALLS": str(calls)},
                capture_output=True, timeout=5,
            )
            return result.returncode, calls.read_text().splitlines()

    def test_legacy_enable_status_does_not_prevent_startup(self):
        status, calls = self.activate(0)
        self.assertEqual(status, 0)
        self.assertEqual(calls, ["enable", "enabled", "restart"])

    def test_missing_boot_link_stops_installation(self):
        status, calls = self.activate(1)
        self.assertNotEqual(status, 0)
        self.assertEqual(calls, ["enable", "enabled"])

    def test_quantenna_worker_only_starts_with_a_remote_radio(self):
        source = WIRELESS_SETUP.read_text()
        start = source.index("    if lua -e '")
        activation = source[start:source.index("    ;;", start)]
        for quantenna in (False, True):
            with self.subTest(quantenna=quantenna), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                service, calls = root / "qtn", root / "calls"
                service.write_text('#!/bin/sh\necho "$1" >> "$TEST_CALLS"\nexit 0\n')
                service.chmod(0o755)
                result = subprocess.run(
                    ["sh", "-c", f"lua() {{ return {0 if quantenna else 1}; }}\n" +
                     activation.replace("/etc/init.d/modgui-luci-qtn", str(service))],
                    env={**os.environ, "TEST_CALLS": str(calls)},
                    capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls.read_text().splitlines(),
                                 ["enable", "restart"] if quantenna else ["stop", "disable"])


if __name__ == "__main__":
    unittest.main()
