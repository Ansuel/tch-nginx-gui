"""Exercise optional app installation against a temporary root and package manager."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
APP = ROOT / 'decompressed/smartphone'
INSTALLER = GUI / 'usr/share/transformer/scripts/appInstallRemoveUtility.sh'


class SmartphoneAppTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ('tmp', 'opt', 'etc', 'bin', 'usr/bin'):
            (self.root / folder).mkdir(parents=True, exist_ok=True)
        self.bindir = self.root / 'bin'
        self.env = dict(os.environ, PATH=f'{self.bindir}:/usr/bin:/bin',
                        APP_FIXTURE=str(self.root), APP_REAL_TAR=shutil.which('tar'))
        self.write_mock('tar', '''
# Match the reduced tar feature set shipped by Technicolor BusyBox.
case "$1" in *j*) echo 'unsupported tar bzip2 option' >&2; exit 1 ;; esac
exec "$APP_REAL_TAR" "$@"
''')
        self.write_mock('uci', 'printf "%s\\n" "$*" >> "$APP_FIXTURE/uci.log"\n')
        self.write_mock('restart', 'echo restart >> "$APP_FIXTURE/restarts"\n[ "${FAIL_RESTART:-0}" = 0 ]\n')
        self.write_mock('opkg', '''
echo "$*" >> "$APP_FIXTURE/opkg.log"
case "$1" in
  update) [ "${FAIL_UPDATE:-0}" = 0 ] ;;
  install)
    [ "${FAIL_INSTALL:-0}" = 0 ] || exit 1
    printf '#!/bin/sh\\nexit 0\\n' > "$APP_FIXTURE/bin/adb"
    chmod 755 "$APP_FIXTURE/bin/adb"
    ;;
  remove) rm -f "$APP_FIXTURE/bin/adb" ;;
  *) exit 1 ;;
esac
''')
        self.archive()
        source = INSTALLER.read_text()
        for prefix in ('/tmp/', '/opt/', '/etc/', '/usr/', '/var/run/'):
            source = source.replace(prefix, str(self.root) + prefix)
        source = source.replace('"/$file"', f'"{self.root}/$file"')
        source = source.replace('-C /', '-C ' + shlex.quote(str(self.root)))
        source = source.replace(str(self.root / 'etc/init.d/transformer'), str(self.bindir / 'restart'))
        source = source.replace(str(self.root / 'etc/init.d/nginx'), str(self.bindir / 'restart'))
        self.script = self.root / 'installer.sh'
        self.script.write_text(source)

    def write_mock(self, name, body):
        file = self.bindir / name
        file.write_text('#!/bin/sh\n' + body)
        file.chmod(0o755)

    def archive(self, incomplete=False):
        with tarfile.open(self.root / 'tmp/smartphone.tar.bz2', 'w:bz2') as archive:
            for file in APP.rglob('*'):
                if file.is_file():
                    relative = file.relative_to(APP).as_posix()
                    if incomplete and relative.endswith('smartphone.map'):
                        continue
                    archive.add(file, arcname=relative)

    def run_app(self, action, **env):
        return subprocess.run(['sh', str(self.script), action, 'smartphone'], capture_output=True,
                              text=True, env={**self.env, **env}, timeout=10)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_install_remove_and_reinstall(self):
        self.assert_ok(self.run_app('install'))
        self.assertTrue((self.root / 'etc/.modgui-smartphone-installed').exists())
        self.assertTrue((self.root / 'www/cards/017_smartphone.lp').is_file())
        self.assertTrue((self.root / 'usr/bin/phone_stats.sh').stat().st_mode & 0o111)
        commands = (self.root / 'opkg.log').read_text()
        self.assertEqual(commands.splitlines(), ['update', 'install adb'])
        self.assertIn('web.smartphonemodal.target=/modals/smartphone-modal.lp',
                      (self.root / 'uci.log').read_text())
        self.assertIn('web.smartphonescreen.target=/modals/smartphone-screen.lp',
                      (self.root / 'uci.log').read_text())
        self.assertIn('add_list web.smartphonescreen.roles=admin', (self.root / 'uci.log').read_text())
        self.assertNotIn('web.smartphonescreen.roles=guest', (self.root / 'uci.log').read_text())
        # Use a harmless runtime mock: remove never reaches a phone in this test.
        (self.root / 'usr/bin/phone_stats.sh').write_text('#!/bin/sh\necho VPN_SHARE\\|Inattiva\n')
        self.assert_ok(self.run_app('remove'))
        self.assertFalse((self.root / 'etc/.modgui-smartphone-installed').exists())
        self.assertFalse((self.root / 'www/cards/017_smartphone.lp').exists())
        self.assertIn('remove adb', (self.root / 'opkg.log').read_text())
        self.assert_ok(self.run_app('install'))

    def test_existing_adb_is_retained_on_remove(self):
        self.write_mock('adb', 'exit 0\n')
        self.assert_ok(self.run_app('install'))
        self.assertFalse((self.root / 'opkg.log').exists())
        (self.root / 'usr/bin/phone_stats.sh').write_text('#!/bin/sh\nexit 0\n')
        self.assert_ok(self.run_app('remove'))
        self.assertTrue((self.bindir / 'adb').exists())

    def test_failed_download_does_not_register_the_app(self):
        for flag in ('FAIL_UPDATE', 'FAIL_INSTALL'):
            with self.subTest(flag=flag):
                self.assertNotEqual(self.run_app('install', **{flag: '1'}).returncode, 0)
                self.assertFalse((self.root / 'etc/.modgui-smartphone-installed').exists())
                self.assertFalse((self.root / 'www/docroot/modals/smartphone-modal.lp').exists())

    def test_incomplete_archive_does_not_install_adb_or_partial_ui(self):
        self.archive(incomplete=True)
        result = self.run_app('install')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Incomplete', result.stdout)
        self.assertFalse((self.root / 'opkg.log').exists())
        self.assertFalse((self.root / 'usr/bin/phone_stats.sh').exists())

    def test_upgrade_and_restore_from_backup(self):
        self.assert_ok(self.run_app('install'))
        (self.root / 'www/cards/017_smartphone.lp').unlink()
        (self.root / 'tmp/smartphone.tar.bz2').unlink()
        self.assert_ok(self.run_app('refresh'))
        self.assertTrue((self.root / 'www/cards/017_smartphone.lp').is_file())
        self.assertEqual((self.root / 'opkg.log').read_text().splitlines(), ['update', 'install adb'])

    def test_existing_unmanaged_files_are_not_overwritten(self):
        file = self.root / 'usr/bin/phone_stats.sh'
        file.write_text('user file')
        result = self.run_app('install')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(file.read_text(), 'user file')
        self.assertFalse((self.root / 'opkg.log').exists())

    def test_backend_restart_failure_rolls_back_fresh_install(self):
        result = self.run_app('install', FAIL_RESTART='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'etc/.modgui-smartphone-installed').exists())
        self.assertFalse((self.root / 'www/cards/017_smartphone.lp').exists())
        self.assertFalse((self.root / 'usr/bin/phone_stats.sh').exists())
        self.assertFalse((self.bindir / 'adb').exists())
        self.assertIn('remove adb', (self.root / 'opkg.log').read_text())

    def test_gui_upgrade_uses_the_shared_manager_to_restore_smartphone(self):
        self.assertFalse((GUI / 'usr/share/transformer/scripts/smartphoneApp.sh').exists())
        self.assert_ok(self.run_app('install'))
        radio = self.root / 'usr/share/modgui-smartphone/radio.awk'
        radio.unlink()
        source = (GUI / 'etc/modgui_scripts/04_config.sh').read_text()
        start = source.index('  if [ -f /etc/.modgui-smartphone-installed ]; then')
        block = source[start:source.index('  # Reconcile stale flags', start)]
        for prefix in ('/tmp/', '/opt/', '/etc/', '/usr/', '/www/'):
            block = block.replace(prefix, str(self.root) + prefix)
        manager = str(self.root / 'usr/share/transformer/scripts/appInstallRemoveUtility.sh')
        block = block.replace(manager, 'sh ' + shlex.quote(str(self.script)))
        result = subprocess.run(['sh', '-c', 'logecho() { :; }\n' + block],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assert_ok(result)
        self.assertTrue(radio.is_file())

    def test_core_voice_access_is_added_to_existing_gui_configuration(self):
        source = (GUI / 'etc/modgui_scripts/04_config.sh').read_text()
        function = source[source.index('check_webui_config() {'):source.index('check_variant_friendly_name() {')]
        function = function.replace('/tmp/web_unlock', str(self.root / 'missing-web-unlock'))
        result = subprocess.run(['sh', '-c', function + '\ncheck_webui_config\n'],
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'uci.log').read_text()
        self.assertIn('set web.mmpbxadvancedmodal.target=/modals/mmpbx-advanced-modal.lp', calls)
        self.assertIn('add_list web.ruleset_main.rules=mmpbxadvancedmodal', calls)


if __name__ == '__main__':
    unittest.main()
