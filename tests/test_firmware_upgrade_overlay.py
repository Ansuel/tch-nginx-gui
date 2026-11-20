"""Regression coverage for firmware upgrade overlay cleanup and logging."""

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PLATFORM = ROOT / "decompressed/base/lib/upgrade/platform.sh"


class FirmwareUpgradeOverlay(unittest.TestCase):
    def test_cleanup_includes_hidden_entries(self):
        source = PLATFORM.read_text()
        cleanup = 'rm -rf "$overlay_dir"/* "$overlay_dir"/.[!.]* "$overlay_dir"/..?*'
        self.assertIn(cleanup, source)

        with tempfile.TemporaryDirectory() as directory:
            overlay = Path(directory)
            (overlay / "visible").write_text("visible")
            (overlay / ".wget-hsts").write_text("hidden")
            (overlay / "..whiteout").write_text("whiteout")
            result = subprocess.run(
                ["sh", "-c", cleanup],
                env={"overlay_dir": directory},
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(overlay.iterdir()), [])

    def test_latest_log_is_outside_rotated_modgui_directory(self):
        source = PLATFORM.read_text()
        self.assertIn(
            "upgrade_log_latest=/overlay/firmware_upgrade_log.latest", source
        )
        self.assertIn('cp "$logging_file" "$upgrade_log_latest"', source)
        self.assertIn("save_upgrade_log\n", source)


if __name__ == "__main__":
    unittest.main()
