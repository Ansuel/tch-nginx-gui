"""Exercise cache selection and recovery without network or a real daemon."""
import hashlib
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / 'decompressed/gui_file/usr/share/modgui-tailscale/tailscale.bootstrap'
INSTALLER = ROOT / 'decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh'


class TailscaleBootstrap(unittest.TestCase):
    def run_bootstrap(self, cache='valid', download=True, bad_download=False, runtime=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = root / 'payload.tgz'
            with tarfile.open(payload, 'w:gz') as archive:
                for name in ('tailscale', 'tailscaled'):
                    data = b'#!/bin/sh\necho DAEMON_OK\n'
                    member = tarfile.TarInfo('tailscale_test/' + name)
                    member.mode = 0o755
                    member.size = len(data)
                    archive.addfile(member, io.BytesIO(data))
            digest = hashlib.sha256(payload.read_bytes()).hexdigest()
            cached = root / 'cache.tgz'
            if cache != 'missing':
                cached.write_bytes(payload.read_bytes() if cache == 'valid' else b'corrupt')
            if runtime:
                (root / 'runtime').mkdir()
                for name in ('tailscale', 'tailscaled'):
                    binary = root / 'runtime' / name
                    binary.write_text('#!/bin/sh\necho DAEMON_OK\n')
                    binary.chmod(0o755)
            source = BOOTSTRAP.read_text().replace('/tmp/modgui-tailscale-', str(root / 'boot-'))
            source = source.replace('/var/run/tailscale', str(root / 'socket'))
            source = source.replace('/dev/net', str(root / 'dev'))
            (root / 'dev').mkdir()
            # A symlink to an existing character device avoids privileged mknod.
            (root / 'dev/tun').symlink_to('/dev/null')
            prelude = '''
uci() {
 case "$3" in
 tailscale.service.runtime_dir) echo "$TEST_ROOT/runtime" ;;
 tailscale.service.state_dir) echo "$TEST_ROOT/state" ;;
 tailscale.service.archive_path) echo "$TEST_ROOT/cache.tgz" ;;
 tailscale.service.archive_sha256) echo "$TEST_HASH" ;;
 tailscale.service.download_url) [ "$TEST_DOWNLOAD" = 1 ] && echo https://example.invalid/runtime.tgz ;;
 esac
}
curl() {
 echo download >> "$TEST_ROOT/downloads"
 if [ "$TEST_BAD" = 1 ]; then echo corrupt > "$4"; else cp "$TEST_ROOT/payload.tgz" "$4"; fi
}
'''
            result = subprocess.run(['sh', '-c', prelude + source], text=True,
                                    capture_output=True, timeout=5,
                                    env=dict(os.environ, TEST_ROOT=str(root), TEST_HASH=digest,
                                             TEST_DOWNLOAD=str(int(download)), TEST_BAD=str(int(bad_download))))
            return (result.returncode, result.stdout, (root / 'downloads').exists(),
                    cached.exists() and cached.read_bytes() == payload.read_bytes())

    def test_valid_cache_starts_without_download_even_with_recovery_url(self):
        self.assertEqual(self.run_bootstrap(), (0, 'DAEMON_OK\n', False, True))

    def test_missing_and_corrupt_cache_are_recovered(self):
        for cache in ('missing', 'corrupt'):
            with self.subTest(cache=cache):
                self.assertEqual(self.run_bootstrap(cache=cache), (0, 'DAEMON_OK\n', True, True))

    def test_bad_download_never_executes_or_replaces_cache(self):
        code, output, downloaded, valid = self.run_bootstrap(cache='corrupt', bad_download=True)
        self.assertNotEqual(code, 0)
        self.assertEqual(output, '')
        self.assertTrue(downloaded)
        self.assertFalse(valid)

    def test_unavailable_cache_without_url_fails_closed(self):
        code, output, downloaded, _ = self.run_bootstrap(cache='missing', download=False)
        self.assertNotEqual(code, 0)
        self.assertEqual(output, '')
        self.assertFalse(downloaded)

    def test_existing_runtime_skips_download(self):
        self.assertEqual(self.run_bootstrap(cache='missing', runtime=True)[:3],
                         (0, 'DAEMON_OK\n', False))

    def test_installer_prefers_runtime_then_cache_with_four_mb_reserve(self):
        source = INSTALLER.read_text()
        start = source.index('    # Prefer extracted binaries')
        end = source.index('    mkdir -p "$tailscale_runtime_dir"', start)
        for available, mode in ((72096, 'runtime'), (57000, 'compressed'), (72095, 'cache'),
                                (34096, 'cache'), (34095, 'download')):
            with self.subTest(available=available, mode=mode):
                script = '''
tailscale_runtime_dir=/tmp/modgui-tailscale-runtime
tailscale_storage_dir=$tailscale_runtime_dir
tailscale_archive_path=''
tailscale_download_url=https://example.invalid/pinned.tgz
du() {
 if [ "$#" = 3 ]; then printf '31000 cli\n37000 daemon\n'; else echo '30000 archive'; fi
}
tailscale_has_space() { [ "$2" = /opt ] && [ "$AVAILABLE" -ge "$1" ]; }
tailscale_try_persistent_runtime() { [ "$TEST_MODE" = compressed ]; }
'''
                result = subprocess.run(['sh', '-c', script + source[start:end] +
                                         '\nprintf "runtime=%s\\nstorage=%s\\narchive=%s\\nurl=%s\\n" "$tailscale_runtime_dir" "$tailscale_storage_dir" "$tailscale_archive_path" "$tailscale_download_url"'],
                                        env=dict(os.environ, AVAILABLE=str(available), TEST_MODE=mode),
                                        text=True, capture_output=True, check=True)
                expected = {'runtime': '/opt/tailscale', 'compressed': '/opt/tailscale', 'cache': '/opt/modgui-tailscale-cache',
                            'download': '/tmp/modgui-tailscale-runtime'}[mode]
                self.assertIn('storage=' + expected, result.stdout)
                self.assertIn('archive=' + (expected + '/runtime.tgz' if mode == 'cache' else '') + '\n', result.stdout)
                self.assertIn('runtime=' + ('/opt/tailscale' if mode in ('runtime', 'compressed') else '/tmp/modgui-tailscale-runtime') + '\n', result.stdout)
                self.assertIn('url=' + ('' if mode in ('runtime', 'compressed') else 'https://example.invalid/pinned.tgz') + '\n', result.stdout)

    def test_persistent_trial_copies_exact_bytes_and_cleans_up_on_failure(self):
        source = INSTALLER.read_text()
        start = source.index('  tailscale_try_persistent_runtime() {')
        end = source.index('\n  tailscale_register_gui()', start)
        for mode in ('success', 'space', 'write'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source_dir = root / 'source'
                source_dir.mkdir()
                for binary, length in (('tailscale', 1048576 + 123), ('tailscaled', 512345)):
                    (source_dir / binary).write_bytes(b'x' * length)
                helper = source[start:end].replace('target=/opt/tailscale', 'target="$TEST_ROOT/runtime"')
                prelude = '''
tailscale_source="$TEST_ROOT/source"
tailscale_has_space() {
 echo "$1" >> "$TEST_ROOT/checks"
 [ "$TEST_MODE" != space ] || [ "$(wc -l < "$TEST_ROOT/checks")" -lt 2 ]
}
dd() { [ "$TEST_MODE" != write ] && command dd "$@"; }
'''
                result = subprocess.run(['sh', '-c', prelude + helper + '\ntailscale_try_persistent_runtime'],
                                        env=dict(os.environ, TEST_ROOT=str(root), TEST_MODE=mode),
                                        text=True, capture_output=True, timeout=5)
                if mode == 'success':
                    self.assertEqual(result.returncode, 0, result.stderr)
                    for binary in ('tailscale', 'tailscaled'):
                        self.assertEqual((root / 'runtime' / binary).read_bytes(),
                                         (source_dir / binary).read_bytes())
                    self.assertEqual((root / 'checks').read_text().splitlines(),
                                     ['5120', '5120', '5120', '4096'])
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse((root / 'runtime').exists())
