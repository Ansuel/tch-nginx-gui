"""Exercise aMule ownership/rollback and DumaOS target rejection."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh"


class AmuleLifecycle(unittest.TestCase):
    def function(self, directory):
        source = SOURCE.read_text()
        source = source[source.index("app_amule() {"):source.index("\napp_aria2()", source.index("app_amule() {"))]
        for path in ("/etc/modgui-amule", "/etc/init.d/amule", "/usr/bin/amuled", "/usr/bin/amuleweb"):
            source = source.replace(path, str(directory / Path(path).name))
        return source

    def run_case(self, extra, action="install"):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = self.function(root)
            harness = r'''
set_extension_state() { echo "STATE:$*"; }
require_usb_storage() { return 0; }
require_free_space() { return 0; }
cpu_type=armv7l
opkg() { [ "$1" != status ]; }
'''
            result = subprocess.run(["sh", "-c", source + harness + extra + "\napp_amule " + action], cwd=tmp, text=True, capture_output=True)
            return result, (root / "modgui-amule").exists()

    def test_generated_init_is_executable_and_parses(self):
        source = SOURCE.read_text()
        start = source.index("  amule_write_init() {")
        end = source.index("  amule_publish_password()", start)
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "amule"
            writer = source[start:end].replace("/etc/init.d/amule", str(target))
            subprocess.run(["sh", "-c", writer + "\namule_write_init"], check=True)
            subprocess.run(["sh", "-n", str(target)], check=True)
            self.assertEqual(target.stat().st_mode & 0o777, 0o755)

    def test_failed_feed_does_not_write_state(self):
        result, state = self.run_case('opkg() { return 1; }')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(state)
        self.assertNotIn("STATE:", result.stdout)

    def test_unmanaged_install_is_preserved(self):
        result, state = self.run_case("opkg() { echo 'Status: install user installed'; }")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing to overwrite", result.stdout)
        self.assertFalse(state)

    def test_wrong_architecture_is_rejected(self):
        result, state = self.run_case('cpu_type=aarch64')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(state)

    def test_partial_install_rolls_back_only_new_packages(self):
        extra = r'''
opkg() {
  case "$1" in
    update) return 0 ;;
    list-installed)
      echo 'stock-library - 1'
      [ ! -f amule-added ] || echo 'amule - 3'
      [ ! -f new-dependency-added ] || echo 'new-dependency - 1'
      return 0 ;;
    install) touch amule-added new-dependency-added; return 1 ;;
    status) [ -f "$2-added" ] && echo 'Status: install user installed' ;;
    remove) echo "$2" >> removed; rm -f "$2-added" ;;
  esac
}
'''
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            script = self.function(root) + "\ncpu_type=armv7l\nrequire_free_space() { return 0; }\nset_extension_state() { :; }\n" + extra + "\napp_amule install"
            result = subprocess.run(["sh", "-c", script], cwd=tmp, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(set((root / "removed").read_text().splitlines()), {"amule", "new-dependency"})
            self.assertFalse((root / "modgui-amule").exists())

    def test_dumaos_rejects_unsupported_kernel_before_package_operations(self):
        source = SOURCE.read_text()
        helper = source[source.index("dumaos_platform_supported() {"):source.index("\n# Shared TUN")]
        start = source.index("app_dumaos() {")
        function = source[start:source.index("\napp_smartphone()", start)]
        for cpu, kernel in (("armv7l", "4.1.38"), ("mips", "3.4.11-rt19")):
            with self.subTest(cpu=cpu, kernel=kernel):
                harness = f"\ncpu_type={cpu}\nuname() {{ echo {kernel}; }}\nopkg() {{ echo UNEXPECTED_PACKAGE_OPERATION; }}\nrequire_free_space() {{ echo UNEXPECTED_SPACE_CHECK; }}\n"
                result = subprocess.run(["sh", "-c", helper + function + harness + "app_dumaos install"], text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("UNEXPECTED", result.stdout)


if __name__ == "__main__":
    unittest.main()
