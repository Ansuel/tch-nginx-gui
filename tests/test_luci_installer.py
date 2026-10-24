"""Verify service activation on legacy and current rc.common implementations."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh"
WIRELESS_SETUP = INSTALLER.parents[5] / "luci_wireless/setup.sh"


class LuciActivation(unittest.TestCase):
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
