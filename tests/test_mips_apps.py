"""Regression cases from legacy MIPS extension installation failures."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh').read_text()


def function(name, following):
    start = SOURCE.index(name + '() ')
    return SOURCE[start:SOURCE.index('\n' + following, start)]


class MipsApps(unittest.TestCase):
    def run_sh(self, source):
        return subprocess.run(['sh', '-c', source], text=True, capture_output=True, timeout=10)

    def test_usb_prerequisite_never_sets_false_installed_flags(self):
        for name, following in [('app_amule', 'app_aria2'), ('app_aria2', '# Never'),
                                ('app_transmission', 'app_telstra')]:
            with self.subTest(app=name):
                source = function('legacy_mips_record_packages', 'extract_bzip_archive') + function(name, following) + '''
cpu_type=mips
marketing_version=17.2
require_usb_storage() { return 1; }
install_from_github() { echo UNEXPECTED_DOWNLOAD; }
uci() { echo UNEXPECTED_STATE; }
''' + name + ' install'
                result = self.run_sh(source)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')

    def test_failed_voipblock_download_is_not_executed(self):
        source = function('run_voipblock', 'app_voipblock_for_mmpbx') + '''
curl() { return 22; }
ash() { echo UNEXPECTED_EXECUTION; }
run_voipblock tch_install_for_mmpbx
'''
        result = self.run_sh(source)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

    def test_failed_archive_download_cleans_staging_and_preserves_cwd(self):
        app = 'modgui-test-' + uuid.uuid4().hex
        source = function('install_from_github', '############') + '''
ping() { return 0; }
curl() { return 22; }
tar() { echo UNEXPECTED_EXTRACTION; }
before="$PWD"
install_from_github example/repo ''' + app + '''
status=$?
[ "$status" != 0 ] && [ "$PWD" = "$before" ] && [ ! -e /tmp/''' + app + ''' ]
'''
        result = self.run_sh(source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')

    def test_space_guard_rejects_inactive_bank_capacity(self):
        # A separate /overlay bank can have room while /usr's active overlay
        # cannot fit the app. No installer may use that bank as its budget.
        import re
        self.assertIsNone(re.search(r'require_free_space\s+\d+\s+/overlay', SOURCE))
        guard = function('require_free_space', 'adblock_cleanup_dns')
        result = self.run_sh(guard + '''
df() { echo '/dev/active 20800 13100 7700 63% /'; }
require_free_space 16384 /usr
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('7700 KB available', result.stdout)

    def test_amule_remove_is_a_supported_successful_action(self):
        result = self.run_sh(function('app_amule', 'app_aria2') + '''
opkg() { :; }
uci() { :; }
app_amule remove
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_luci_mips_dispatch_uses_integrated_storage_guard_on_supported_firmware(self):
        helper = SOURCE[SOURCE.index('luci_mips_state='):SOURCE.index('require_usb_storage() {')]
        for version in ('16.1', '16.2', '16.3', '17.2', '18.3', '19.4'):
            with self.subTest(version=version):
                result = self.run_sh(helper + function('app_luci', 'app_amule') + '''
cpu_type=mips
require_free_space() { echo STORAGE_GUARD; return 1; }
uci() { echo UNEXPECTED_STATE_WRITE; }
marketing_version=''' + version + '\napp_luci install')
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, 'STORAGE_GUARD\n')
                self.assertEqual(result.stderr, '')

    def test_luci_checksum_failure_rolls_back_without_touching_vendor_uci(self):
        helper = SOURCE[SOURCE.index('luci_mips_state='):SOURCE.index('require_usb_storage() {')]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in ['etc/config', 'etc/opkg', 'usr/lib/lua', 'usr/lib/opkg/info', 'tmp']:
                (root / path).mkdir(parents=True, exist_ok=True)
            vendor = root / 'usr/lib/lua/uci.so'
            vendor.write_bytes(b'vendor-binding')
            manifest = root / 'usr/lib/opkg/info/lua-uci.list'
            manifest.write_text('/usr/lib/lua/uci.so\n')
            # Run the real rollback against isolated paths and a corrupt
            # downloaded archive. No package installation may be attempted.
            for prefix in ['/etc/', '/usr/', '/tmp/', '/www_luci']:
                helper = helper.replace(prefix, directory + prefix)
            result = self.run_sh(helper + '''
require_free_space() { return 0; }
opkg() { [ "$1" = list-installed ] && echo 'base - 1'; }
curl() { for value; do destination="$value"; done; echo corrupt > "$destination"; }
luci_mips_install
''')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('checksum mismatch', result.stdout)
            self.assertEqual(vendor.read_bytes(), b'vendor-binding')
            self.assertEqual(manifest.read_text(), '/usr/lib/lua/uci.so\n')
            self.assertFalse((root / 'etc/.modgui-luci-mips').exists())
            self.assertFalse(list((root / 'tmp').iterdir()))

    def test_bzip_decompression_failure_never_runs_tar(self):
        result = self.run_sh(function('extract_bzip_archive', 'require_free_space') + '''
bzcat() { return 1; }
tar() { echo UNEXPECTED_EXTRACTION; }
extract_bzip_archive broken.tar.bz2 /tmp
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

    def test_uninstalled_blacklist_remove_does_not_run_external_uninstaller(self):
        result = self.run_sh(function('app_blacklist', 'app_xupnp') + '''
uci() { return 1; }
install_from_github() { echo UNEXPECTED_UNINSTALL; }
app_blacklist remove
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
