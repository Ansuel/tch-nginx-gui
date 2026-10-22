"""USB-backed MIPS lifecycle and rollback regressions."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'decompressed/gui_file/usr/share/transformer/scripts'
INSTALLER = (SCRIPTS / 'appInstallRemoveUtility.sh').read_text()
HELPER = INSTALLER[INSTALLER.index('legacy_mips_record_packages() {'):
                   INSTALLER.index('extract_bzip_archive() (')]


class LegacyMips(unittest.TestCase):
    def run_sh(self, script):
        return subprocess.run(['sh', '-c', script], capture_output=True, text=True, timeout=10)

    def test_usb_mount_discovery_supports_whole_disks_and_partitions(self):
        start = INSTALLER.index('require_usb_storage() {')
        block = INSTALLER[start:INSTALLER.index('\nlegacy_mips_record_packages()', start)]
        cases = [
            ('/dev/sda /tmp/run/mountd/sda vfat rw,noatime 0 0\n', '/tmp/run/mountd/sda'),
            ('/dev/sdb1 /tmp/run/mountd/sdb1 ext4 rw 0 0\n', '/tmp/run/mountd/sdb1'),
            ('/dev/sda1 /tmp/run/mountd/sda1 vfat ro 0 0\n', None),
            ('/dev/root / squashfs ro 0 0\n', None),
        ]
        for mounts, expected in cases:
            with self.subTest(mounts=mounts), tempfile.TemporaryDirectory() as directory:
                fixture = Path(directory) / 'mounts'
                fixture.write_text(mounts)
                script = block.replace('/proc/mounts', str(fixture)) + '''
mktemp() { echo probe; }
rm() { :; }
require_usb_storage || exit 1
echo "$modgui_usb_root"
'''
                result = self.run_sh(script)
                if expected:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), expected)
                else:
                    self.assertNotEqual(result.returncode, 0)

    def isolated_helper(self, directory):
        # Rewrite once so a Linux /tmp fixture root is not rewritten again.
        source = re.sub(r'/etc/|/usr/|/tmp/', lambda match: directory + match[0], HELPER)
        return source.replace('/proc/mounts', directory + '/mounts')

    def test_bad_archive_rolls_back_without_installing_packages_or_overwriting_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            usb = root / 'tmp/run/mountd/sda'
            usb.mkdir(parents=True)
            (root / 'etc/config').mkdir(parents=True)
            (root / 'mounts').write_text(f'/dev/sda {usb} vfat rw 0 0\n')
            original = usb / 'sharing/config/aria2/aria2.conf'
            original.parent.mkdir(parents=True)
            original.write_text('existing-user-settings\n')
            source = self.isolated_helper(directory)
            result = self.run_sh(source + f'''
require_usb_storage() {{ modgui_usb_root='{usb}'; }}
require_free_space() {{ return 0; }}
set_extension_state() {{ return 0; }}
opkg() {{
  case "$1" in
    list-installed) echo 'libstdcpp - firmware';;
    status) return 1;;
    *) echo UNEXPECTED_PACKAGE_MUTATION; return 1;;
  esac
}}
curl() {{ for value; do destination="$value"; done; echo corrupt > "$destination"; }}
legacy_mips_app install aria2
''')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('checksum mismatch', result.stdout)
            self.assertNotIn('UNEXPECTED_PACKAGE', result.stdout)
            self.assertEqual(original.read_text(), 'existing-user-settings\n')
            self.assertFalse((root / 'etc/.modgui-mips-aria2').exists())
            self.assertFalse((usb / '.modgui-apps/aria2').exists())

    def test_remove_preserves_modified_accounts_and_existing_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'etc/.modgui-mips-aria2'
            state.mkdir(parents=True)
            (root / 'etc/config').mkdir()
            usb = root / 'tmp/run/mountd/sda'
            private = usb / '.modgui-apps/aria2'
            private.mkdir(parents=True)
            (root / 'mounts').write_text(f'/dev/sda {usb} vfat rw 0 0\n')
            for name, value in [('usb', str(usb)), ('private', str(private)), ('packages', '')]:
                (state / name).write_text(value + '\n' if value else '')
            created = {'passwd': 'aria2:x:6800:6800::/var/run/aria2:/bin/false',
                       'group': 'aria2:x:6800:', 'shadow': 'aria2:*:0:0:99999:7:::'}
            for database, value in created.items():
                (state / (database + '-created')).write_text(value + '\n')
                (root / 'etc' / database).write_text(value + '\n')
            customized = created['passwd'].replace('::/var', ':custom account:/var') + '\n'
            (root / 'etc/passwd').write_text(customized)
            result = self.run_sh(self.isolated_helper(directory) + '''
opkg() { [ "$1" = list-installed ] && echo 'libstdcpp - firmware'; }
set_extension_state() { :; }
legacy_mips_app remove aria2
''')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Modified aria2 account was preserved', result.stdout)
            self.assertEqual((root / 'etc/passwd').read_text(), customized)
            self.assertEqual((root / 'etc/group').read_text(), created['group'] + '\n')
            self.assertFalse(private.exists())

    def test_transmission_start_enables_config_and_requires_its_original_usb(self):
        for mounted in (True, False):
            with self.subTest(mounted=mounted), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                state = root / 'etc/.modgui-mips-transmission'
                state.mkdir(parents=True)
                init = root / 'etc/init.d/transmission'
                init.parent.mkdir()
                trace = root / 'trace'
                usb = root / 'tmp/run/mountd/sda'
                (state / 'usb').write_text(str(usb))
                (root / 'mounts').write_text(f'/dev/sda {usb} vfat rw 0 0\n' if mounted else '')
                init.write_text(f'#!/bin/sh\necho "service $1" >> "{trace}"\n')
                init.chmod(0o755)
                result = self.run_sh(self.isolated_helper(directory) + f'''
uci() {{ echo "$*" >> '{trace}'; }}
legacy_mips_app start transmission
''')
                if mounted:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(trace.read_text().splitlines(), [
                        'set transmission.@transmission[0].enabled=1', 'commit transmission', 'service start'])
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(trace.exists())

    def test_service_stop_and_unmanaged_actions_preserve_lifecycle(self):
        cases = [
            ('transmission', True, 'stop', 0, [
                'service stop', 'uci set transmission.@transmission[0].enabled=0',
                'uci commit transmission']),
            ('transmission', True, 'stop', 1, ['service stop']),
            ('aria2', True, 'stop', 0, ['service stop']),
            ('transmission', False, 'start', 0, ['service start']),
            ('transmission', False, 'stop', 0, ['service stop']),
            ('aria2', False, 'start', 0, ['service start']),
        ]
        for app, managed, action, status, expected in cases:
            with self.subTest(app=app, managed=managed, action=action, status=status):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    init = root / 'etc/init.d' / app
                    init.parent.mkdir(parents=True)
                    if managed:
                        (root / 'etc' / ('.modgui-mips-' + app)).mkdir()
                    trace = root / 'trace'
                    init.write_text(f'#!/bin/sh\necho "service $1" >> "{trace}"\nexit {status}\n')
                    init.chmod(0o755)
                    # No USB is mounted: stopping must still work.
                    result = self.run_sh(self.isolated_helper(directory) + f'''
uci() {{ echo "uci $*" >> '{trace}'; }}
legacy_mips_app {action} {app}
''')
                    self.assertEqual(result.returncode, status, result.stderr)
                    self.assertEqual(trace.read_text().splitlines(), expected)

    def test_remove_restores_current_ca_store_after_removing_owned_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'etc/.modgui-mips-transmission'
            state.mkdir(parents=True)
            ca = root / 'etc/ssl/certs/ca-certificates.crt'
            ca.parent.mkdir(parents=True)
            ca.write_text('user-refreshed-roots')
            (state / 'ca-original').write_text('original-roots')
            (state / 'installed').touch()
            (state / 'packages').write_text('ca-bundle\n')
            usb = root / 'tmp/run/mountd/sda'
            private = usb / '.modgui-apps/transmission'
            private.mkdir(parents=True)
            (state / 'private').write_text(str(private))
            (state / 'usb').write_text(str(usb))
            (root / 'mounts').write_text(f'/dev/sda {usb} vfat rw 0 0\n')
            package = root / 'bundle-installed'
            package.touch()
            result = self.run_sh(self.isolated_helper(directory) + f'''
opkg() {{
  case "$1" in
    list-installed) [ ! -f '{package}' ] || echo 'ca-bundle - 1';;
    remove) rm -f '{package}' '{ca}';;
    status) [ ! -f '{package}' ] || echo 'Status: install ok installed';;
  esac
}}
set_extension_state() {{ :; }}
legacy_mips_app remove transmission
''')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(ca.read_text(), 'user-refreshed-roots')
            self.assertFalse(package.exists())

    def test_unmanaged_package_is_not_reported_as_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_sh(self.isolated_helper(directory) + '''
opkg() { echo 'Status: install ok installed'; }
legacy_mips_app remove aria2
''')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Unmanaged aria2 installation', result.stdout)


if __name__ == '__main__':
    unittest.main()
