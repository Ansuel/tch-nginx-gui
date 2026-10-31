"""Exercise first-install helpers without accessing a router filesystem."""

import io
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'


class RootdeviceInstall(unittest.TestCase):
    def test_tim_unlock_flag_compatibility(self):
        source = (ROOT / 'usr/share/transformer/scripts/ispConfigHelper.sh').read_text()
        function = source[source.index('cwmp_specific_TIM() {'):
                          source.index('check_clean() {')]
        harness = '''
logecho() { printf '%s\\n' "$1"; }
curl() { return 0; }
uci() {
    case "$*" in
        'get cwmpd.cwmpd_config.acs_url') echo 'https://existing.example/acs' ;;
        '-q get env.var.unlockedstatus')
            [ "$UNLOCK_FLAG" != missing ] || return 1
            printf '%s\\n' "$UNLOCK_FLAG"
            ;;
        'set env.var.unlockedstatus=0')
            [ "$UNLOCK_FLAG" != missing ] || { echo 'uci: Invalid argument' >&2; return 1; }
            [ "$UNLOCK_FLAG" != rejected ] || { echo 'uci: Permission denied' >&2; return 1; }
            echo reset
            ;;
        *) echo "Unexpected UCI call: $*" >&2; return 99 ;;
    esac
}
'''
        for flag in ('missing', '0', '1', 'rejected'):
            with self.subTest(flag=flag):
                result = subprocess.run(
                    ['sh', '-c', 'UNLOCK_FLAG=$1\n' + harness + function +
                     '\ncwmp_specific_TIM', 'test', flag],
                    capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr,
                                 'uci: Permission denied\n' if flag == 'rejected' else '')
                self.assertEqual(result.stdout.splitlines().count('reset'),
                                 int(flag == '1'))
                self.assertIn('CWMP Server detected: Undetected', result.stdout)

    def test_led_archive_from_unrelated_working_directory(self):
        tar = shutil.which('gtar') or shutil.which('tar')
        version = subprocess.run([tar, '--version'], capture_output=True, text=True)
        if 'GNU tar' not in version.stdout:
            self.skipTest('GNU tar required for router-compatible verbose output')
        source = (ROOT / 'etc/modgui_scripts/02_specific.sh').read_text()
        function = source[source.index('extract_with_check() {'):
                          source.index('#Some globals var')]
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            dest = base / 'installed'
            dest.mkdir()
            stage = base / 'staging'
            function = function.replace('/tmp/md5check', str(stage))
            function = function.replace('"/$file"', '"$DEST/$file"')
            function = function.replace('orig_file=/$file', 'orig_file=$DEST/$file')
            files = {'etc/ledfw/stateMachines.lua': b'new state machine',
                     'usr/lib/lua/ledframework/ubus.lua': b'new ubus module',
                     'stateMachines.md5sum': b'checksum metadata',
                     'payload.lua': b'-- mentions .md5sum but is not metadata'}
            for expected_status in (1, 0):
                archive = base / 'leds.tar.bz2'
                with tarfile.open(archive, 'w:bz2') as bundle:
                    directories = sorted({str(p) for name in files
                                          for p in Path(name).parents if str(p) != '.'})
                    for name in directories:
                        info = tarfile.TarInfo(name)
                        info.type = tarfile.DIRTYPE
                        info.mode = 0o755
                        bundle.addfile(info)
                    for name, payload in files.items():
                        info = tarfile.TarInfo(name)
                        info.size = len(payload)
                        bundle.addfile(info, io.BytesIO(payload))
                result = subprocess.run(['sh', '-c',
                                         f'DEST={shlex.quote(str(dest))}\n' +
                                         f'tar() {{ {shlex.quote(tar)} "$@"; }}\n' + function +
                                         '\nextract_with_check "$1"', 'test', str(archive)],
                                        cwd=base, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, expected_status, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertFalse(stage.exists())
                self.assertFalse(archive.exists())
                self.assertFalse((dest / 'stateMachines.md5sum').exists())
                for name, payload in files.items():
                    if not name.endswith('.md5sum'):
                        self.assertEqual((dest / name).read_bytes(), payload)

    def wifi_counts(self, response):
        source = (ROOT / 'usr/share/transformer/scripts/restart_leds.sh').read_text()
        block = source[source.index('connected_wl0=0'):source.index('for i in 0 1')]
        block = block.replace('transformer-cli', 'transformer_cli')
        harness = '''
transformer_cli() {
    [ "$*" = 'get rpc.hosts.host.' ] || exit 99
    printf '%s\\n' "$RESPONSE"
}
'''
        result = subprocess.run(['sh', '-c', 'RESPONSE=$1\n' + harness + block +
                                 '\nprintf "%s %s\\n" "$connected_wl0" "$connected_wl1"',
                                 'test', response], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        return result.stdout.strip()

    def test_unavailable_or_empty_host_mapping(self):
        for response in ('ERROR\tinvalid path rpc.hosts.', '',
                         'ERROR retrieving hosts failed',
                         'socket error for get: connection refused'):
            with self.subTest(response=response):
                self.assertEqual(self.wifi_counts(response), '0 0')

    def test_sparse_hosts_and_multiple_clients_are_counted_once(self):
        self.assertEqual(self.wifi_counts('''
rpc.hosts.host.2.L2Interface [string] = wl0
rpc.hosts.host.2.State [boolean] = 1
rpc.hosts.host.9.State [boolean] = 1
rpc.hosts.host.9.L2Interface [string] = wl0
rpc.hosts.host.15.State [boolean] = 1
rpc.hosts.host.15.L2Interface [string] = wl1
rpc.hosts.host.20.State [boolean] = 0
rpc.hosts.host.20.L2Interface [string] = wl1
rpc.hosts.host.25.State [boolean] = 1
rpc.hosts.host.25.L2Interface [string] = eth0
'''), '2 1')

    def test_migrated_uci_value_remains_one_argument(self):
        source = (ROOT / 'etc/modgui_scripts/01_prereq.sh').read_text()
        function = source[source.index('move_env_var() {'):
                          source.index('create_section_modgui() {')]
        with tempfile.TemporaryDirectory() as directory:
            function = function.replace('/etc/config/modgui', directory + '/modgui')
            harness = '''
uci() {
    case "$1:$2" in
        'get:-q')
            [ "$3" != 'env.var.isp' ] || printf '%s\\n' 'Provider with spaces *'
            ;;
        'set:modgui.var.isp='*)
            [ "$#" = 2 ] && [ "$2" = 'modgui.var.isp=Provider with spaces *' ] || exit 99
            printf '%s\\n' migrated
            ;;
    esac
}
'''
            result = subprocess.run(['sh', '-c', harness + function + '\nmove_env_var'],
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')
            self.assertEqual(result.stdout.strip(), 'migrated')


if __name__ == '__main__':
    unittest.main()
