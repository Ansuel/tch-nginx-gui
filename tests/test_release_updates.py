"""Offline integration checks: python3 -m unittest discover -s tests -v."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CHECKVER = ROOT / 'decompressed/gui_file/usr/share/transformer/scripts/checkver'


class ReleaseUpdates(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.rootdevice = self.home/'rootdevice'
        self.rootdevice.write_text('version_gui=9.7.7-abc\n')
        self.check = self.home/'checkver'
        self.check.write_text(CHECKVER.read_text().replace('/etc/init.d/rootdevice', str(self.rootdevice)))
        self.check.chmod(0o755)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.data = self.home / 'gui_build/data'
        self.data.mkdir(parents=True)
        self.archives = self.home / 'gui_build/compressed'
        self.archives.mkdir()
        (self.data/'type').write_text('DEV')
        self.env = {**os.environ, 'HOME': str(self.home),
                    'PATH': str(self.bin) + ':' + os.environ['PATH'],
                    'GH_TOKEN': 'fixture', 'GITHUB_REPOSITORY': 'Ansuel/tch-nginx-gui',
                    'GITHUB_SHA': 'abcdef', 'FIXTURE': str(self.home)}
        self.mock('curl', '''
import os, pathlib, sys
root = pathlib.Path(os.environ['FIXTURE'])
args = sys.argv[1:]
assert '-kfLsS' in args or all(flag in args for flag in ('-k', '-f', '-L'))
url = next(a for a in args if a.startswith('https://'))
with (root / 'requests').open('a') as f: f.write(url + '\\n')
path = root / 'assets' / url.split('/download/')[1]
if 'channel-stable/latest.version' in url and os.environ.get('STABLE_ERROR'):
    error = os.environ['STABLE_ERROR']
    if '-w' in args: print('\\n'+('503' if error == 'http' else '000'), end='')
    sys.exit(22 if error == 'http' else 28)
if not path.is_file():
    if '-w' in args: print('\\n404', end='')
    sys.exit(22)
if '-o' in args or '--output' in args:
    flag = '-o' if '-o' in args else '--output'
    pathlib.Path(args[args.index(flag)+1]).write_bytes(path.read_bytes())
else: sys.stdout.buffer.write(path.read_bytes())
if '-w' in args:
    sys.stdout.flush()
    print('\\n200', end='')
''')
        self.mock('gh', '''
import json, os, pathlib, sys
root = pathlib.Path(os.environ['FIXTURE'])
a = sys.argv[1:]
with (root/'gh-calls').open('a') as f: f.write(json.dumps(a)+'\\n')
if os.environ.get('GH_FAIL'): sys.exit(1)
if a[0] == 'api': print(os.environ.get('MATCHED', '') if 'target_commitish' in a[-1] else os.environ.get('TAGS', ''))
elif a[:2] == ['release', 'view']:
    print('abcdef' if 'targetCommitish' in a else os.environ.get('DRAFT', 'false'))
elif a[:2] == ['release', 'download']:
    pattern = a[a.index('--pattern')+1]
    print({'SOURCE_COMMIT':'abcdef', 'CHANNEL':'dev', 'latest.version':os.environ.get('CURRENT','9.7.8')}[pattern])
''')

    def mock(self, name, body):
        path = self.bin / name
        path.write_text('#!' + sys.executable + '\n' + body)
        path.chmod(0o755)

    def asset(self, name, value):
        path = self.home / 'assets' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)

    def checkver(self, *arguments, success=True):
        result = subprocess.run(['bash', str(self.check), *map(str, arguments)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result.stdout.strip()

    def script(self, name, success=True):
        result = subprocess.run(['bash', str(ROOT / 'scripts' / name)], cwd=self.data,
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def publish_fixture(self):
        (self.data/'version').write_text('9.7.9')
        (self.data/'type').write_text('DEV')
        (self.archives/'GUI_dev.tar.bz2').write_bytes(b'fixture')
        digest = hashlib.sha256(b'fixture').hexdigest()
        (self.archives/'SHA256SUMS').write_text(digest + '  GUI_dev.tar.bz2\n')
        (self.archives/'MD5SUMS').write_text(hashlib.md5(b'fixture').hexdigest() + '  GUI_dev.tar.bz2\n')

    def calls(self):
        return [json.loads(line) for line in (self.home/'gh-calls').read_text().splitlines()]

    def test_checkver_retains_channel_selection_and_stable_fallback(self):
        for command in ('lua', 'logger', 'ping', 'sleep'):
            self.mock(command, 'pass')
        self.mock('uci', """
import os, pathlib, sys
if 'get' in sys.argv: print(os.environ['TEST_CHANNEL'])
else:
    with (pathlib.Path(os.environ['FIXTURE'])/'uci-calls').open('a') as f:
        f.write(' '.join(sys.argv[1:])+'\\n')
""")
        self.env['TEST_CHANNEL'] = 'dev'
        self.asset('channel-dev/latest.version', '9.7.9\n')
        self.checkver()
        self.assertIn('set modgui.gui.new_ver=9.7.9', (self.home/'uci-calls').read_text())
        self.asset('channel-stable/latest.version', '9.8.0\n')
        self.checkver()
        self.assertIn('set modgui.gui.new_ver=9.8.0 STABLE', (self.home/'uci-calls').read_text())
        self.env['TEST_CHANNEL'] = 'stable'
        self.rootdevice.write_text('version_gui=9.8.0-abc\n')
        (self.home/'uci-calls').unlink()
        self.checkver()
        self.assertIn('set modgui.gui.outdated_ver=0', (self.home/'uci-calls').read_text())

    def test_missing_and_invalid_channels(self):
        self.checkver('ReleaseVersion', 'preview', success=False)
        for value in ['<html>Error</html>', '9.7.9\n10.0.0', '9.7.9\nerror', '../evil', '']:
            self.asset('channel-dev/latest.version', value)
            self.checkver('ReleaseVersion', 'dev', success=False)
        self.asset('channel-dev/latest.version', '9.7.9\n')
        self.assertEqual(self.checkver('ReleaseVersion', 'dev'), '9.7.9')

    def test_verified_download_pins_version_and_rejects_corruption(self):
        self.mock('sha256sum', 'raise SystemExit("Router must not require SHA-256")')
        self.mock('mktemp', 'raise SystemExit("Router must not require mktemp")')
        self.asset('channel-stable/latest.version', '9.7.9')
        self.asset('9.7.9/GUI.tar.bz2', 'good archive')
        digest = hashlib.md5(b'good archive').hexdigest()
        self.asset('9.7.9/MD5SUMS', digest+'  GUI.tar.bz2\n')
        destination = self.home/'download'
        self.checkver('DownloadStable', destination)
        self.assertEqual(destination.read_text(), 'good archive')
        self.asset('9.7.9/GUI.tar.bz2', 'corrupt')
        self.checkver('DownloadStable', destination, success=False)
        self.assertEqual(destination.read_text(), 'good archive')
        self.assertEqual(list(self.home.glob('download.part.*')), [])
        self.asset('9.7.9/MD5SUMS', digest+'  wrong-file.tar.bz2\n')
        self.checkver('DownloadStable', destination, success=False)
        requests = (self.home/'requests').read_text()
        self.assertIn('/download/9.7.9/GUI.tar.bz2', requests)
        self.assertNotIn('/download/channel-stable/GUI.tar.bz2', requests)

    def test_upgrade_download_flow_preserves_original_selection(self):
        # Stop before installation; all filesystem writes stay inside the fixture.
        source = (CHECKVER.parent/'upgradegui').read_text().split(
            'set_transformer "rpc.system.modgui.executeCommand.state" "Clearing"')[0]
        source = source.replace('/usr/bin/curl', str(self.bin/'curl'))
        source = source.replace('/usr/share/transformer/scripts/checkver', str(CHECKVER))
        download = self.home/'downloads'
        source = source.replace('WORKING_DIR="/tmp"', 'WORKING_DIR="'+str(download)+'"')
        source = source.replace('PERMANENT_STORE_DIR="/root"', 'PERMANENT_STORE_DIR="'+str(self.home/'recovery')+'"')
        source = source.replace('/tmp/$CHECKSUM_FILE', str(download)+'/$CHECKSUM_FILE')
        source += '\nprintf "RESULT:%s:%s\\n" "$FILE_NAME" "$FORCE_SAVE_GUI"\n'
        fixture_script = self.home/'upgrade-download'
        fixture_script.write_text(source)
        self.mock('uci', 'import os; print(os.environ["TEST_CHANNEL"])')
        self.mock('df', 'print("header\\n/dev/root 99999 0 99999 /overlay")')
        for command in ('lua', 'ubus', 'logger'):
            self.mock(command, 'pass')
        cases = [('stable', '9.7.8', 'GUI.tar.bz2', '0', False, False),
                 ('dev', '9.7.8', 'GUI_dev.tar.bz2', '0', False, False),
                 ('preview', '9.8.0', 'GUI.tar.bz2', '1', False, False),
                 ('dev', '9.7.8', None, None, True, False),
                 ('dev', '9.7.8', 'GUI_dev.tar.bz2', '1', False, True),
                 ('dev', 'missing', 'GUI_dev.tar.bz2', '0', False, False),
                 ('preview', 'missing', 'GUI_preview.tar.bz2', '0', False, False),
                 ('stable', 'missing', None, None, False, False),
                 ('dev', 'invalid', None, None, False, False),
                 ('dev', 'http', None, None, False, False),
                 ('dev', 'timeout', None, None, False, False),
                 ('dev', 'bad_checksum', None, None, False, False),
                 ('dev', 'missing_archive', None, None, False, False)]
        for channel, stable, filename, force, corrupt, offline in cases:
            with self.subTest(channel=channel, stable=stable, corrupt=corrupt, offline=offline):
                shutil.rmtree(download, ignore_errors=True)
                download.mkdir()
                self.env['TEST_CHANNEL'] = channel
                self.env.pop('STABLE_ERROR', None)
                for selected, version in [('stable', stable), ('dev', '9.7.9'), ('preview', '9.7.9')]:
                    asset = 'GUI.tar.bz2' if selected == 'stable' else 'GUI_'+selected+'.tar.bz2'
                    self.asset('channel-'+selected+'/latest.version', version)
                    self.asset(version+'/'+asset, selected)
                    digest = hashlib.md5(selected.encode()).hexdigest()
                    if corrupt and selected == 'dev':
                        digest = '0'*32
                    # DEV and PREVIEW share the fixture version; keep both checksum rows.
                    path = self.home/'assets'/version/'MD5SUMS'
                    previous = path.read_text() if path.exists() else ''
                    rows = [row for row in previous.splitlines() if not row.endswith('  '+asset)]
                    self.asset(version+'/MD5SUMS', '\n'.join(rows+[digest+'  '+asset])+'\n')
                pointer = self.home/'assets/channel-stable/latest.version'
                if stable == 'missing':
                    pointer.unlink()
                elif stable == 'invalid':
                    pointer.write_text('invalid')
                elif stable in ('http', 'timeout'):
                    self.env['STABLE_ERROR'] = stable
                elif stable in ('bad_checksum', 'missing_archive'):
                    pointer.write_text('9.8.0')
                    self.asset('9.8.0/MD5SUMS', '0'*32+'  GUI.tar.bz2\n')
                    archive = self.home/'assets/9.8.0/GUI.tar.bz2'
                    if stable == 'bad_checksum':
                        archive.write_text('bad stable')
                    elif archive.exists():
                        archive.unlink()
                if offline:
                    (download/'GUI_dev.tar.bz2').write_text('offline upload')
                result = subprocess.run(['bash', str(fixture_script), 'Manual'],
                                        env=self.env, capture_output=True, text=True)
                if corrupt or filename is None:
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertFalse((download/'GUI_dev.tar.bz2').exists())
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn('RESULT:'+filename+':'+force, result.stdout)

    def test_checkver_download_commands_do_not_touch_uci(self):
        self.mock('uci', 'raise SystemExit("Unexpected UCI access")')
        self.asset('channel-stable/latest.version', '9.7.8')
        self.asset('9.7.8/GUI.tar.bz2', 'stable')
        self.asset('9.7.8/MD5SUMS', hashlib.md5(b'stable').hexdigest()+'  GUI.tar.bz2\n')
        destination = self.home/'recovery.tar.bz2'
        result = subprocess.run(['sh', str(CHECKVER), 'DownloadStable', str(destination)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(destination.read_bytes(), b'stable')
        # Supply installed firmware metadata only inside the test fixture.
        rootdevice = self.home/'rootdevice'
        rootdevice.write_text('version_gui=9.7.8-abc\n')
        installed_check = self.home/'checkver-installed'
        installed_check.write_text(CHECKVER.read_text().replace('/etc/init.d/rootdevice', str(rootdevice)))
        self.asset('9.7.8/module.tar.bz2', 'module')
        self.asset('9.7.8/MD5SUMS', hashlib.md5(b'module').hexdigest()+'  module.tar.bz2\n')
        result = subprocess.run(['sh', str(installed_check), 'DownloadInstalled', 'module.tar.bz2', str(destination)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(destination.read_bytes(), b'module')

    def test_versioning_ignores_channel_tags_and_handles_rollover(self):
        self.env.pop('GITHUB_EVENT_NAME', None)
        (self.data/'last_log').write_text('abc build')
        self.env['TAGS'] = '9.99.99\nchannel-dev\n9.8.0\nchannel-stable'
        self.script('1-increment_autobuild_ver.sh')
        self.assertEqual((self.data/'version').read_text().strip(), '10.0.0')
        self.env['TAGS'] = 'channel-dev'
        self.script('1-increment_autobuild_ver.sh', success=False)
        self.env['GH_FAIL'] = '1'
        self.script('1-increment_autobuild_ver.sh', success=False)
        (self.data/'last_log').write_text('abc [9.7.9]')
        self.script('1-increment_autobuild_ver.sh')
        self.assertEqual((self.data/'version').read_text().strip(), '9.7.9')

    def test_rerun_reuses_release_version(self):
        (self.data/'last_log').write_text('abc build')
        self.env.update(MATCHED='9.7.9', TAGS='9.7.9\n9.8.0')
        self.script('1-increment_autobuild_ver.sh')
        self.assertEqual((self.data/'version').read_text().strip(), '9.7.9')
        self.assertEqual(len(self.calls()), 1)

    def test_pr_without_releases_can_build(self):
        (self.data/'last_log').write_text('abc build')
        self.env['GITHUB_EVENT_NAME'] = 'pull_request'
        self.script('1-increment_autobuild_ver.sh')
        self.assertEqual((self.data/'version').read_text().strip(), '0.0.0')

    def test_pr_uses_target_channel(self):
        self.env.update(GITHUB_BASE_REF='preview', GITHUB_REF_NAME='123/merge')
        self.mock('git', 'print("abc PR merge")')
        self.script('0-detect-build-type.sh')
        self.assertEqual((self.data/'type').read_text().strip(), 'PREVIEW')

    def test_publication_order(self):
        self.publish_fixture()
        self.script('7-push-release.sh')
        mutations = [a for a in self.calls() if a[0] == 'release']
        self.assertEqual([a[:3] for a in mutations], [
            ['release','create','9.7.9'], ['release','edit','9.7.9'],
            ['release','create','channel-dev']])
        self.assertIn('--draft', mutations[0])
        self.assertIn('--draft=false', mutations[1])
        self.assertIn('--latest=false', mutations[2])

    def test_published_retry_does_not_overwrite_archives(self):
        self.publish_fixture()
        self.env['TAGS'] = '9.7.9\nchannel-dev'
        self.script('7-push-release.sh')
        uploads = [a for a in self.calls() if a[:2] == ['release','upload']]
        self.assertEqual(len(uploads), 1)
        self.assertEqual(uploads[0][2:4], ['channel-dev', 'latest.version'])

    def test_auth_failure_and_downgrade_do_not_publish(self):
        self.publish_fixture()
        self.env['GH_FAIL'] = '1'
        self.script('7-push-release.sh', success=False)
        self.env.pop('GH_FAIL')
        self.env.update(TAGS='channel-dev', CURRENT='9.8.0')
        self.script('7-push-release.sh', success=False)
        self.assertFalse(any(a[:2] in [['release','create'], ['release','upload'], ['release','edit']] for a in self.calls()))


if __name__ == '__main__':
    unittest.main()
