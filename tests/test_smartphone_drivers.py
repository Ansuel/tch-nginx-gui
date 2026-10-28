"""Exercise feed-based USB dependencies across kernel layouts and failures."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MANAGER = ROOT / 'decompressed/smartphone/usr/share/modgui-smartphone/drivers.sh'
PACKAGES = {'kmod-usb-net': 'usbnet', 'kmod-usb-net-cdc-ether': 'cdc_ether',
            'kmod-usb-net-rndis': 'rndis_host', 'kmod-usb-net-cdc-ncm': 'cdc_ncm',
            'kmod-usb-net-cdc-eem': 'cdc_eem', 'kmod-usb-net-cdc-subset': 'cdc_subset'}


class SmartphoneDriversTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('bin', 'etc/modules.d', 'sys/module', 'lib/modules', 'state'):
            (self.root / directory).mkdir(parents=True)
        self.env = dict(os.environ, PATH=str(self.root / 'bin') + ':/usr/bin:/bin',
                        FIXTURE=str(self.root), KERNEL_RELEASE='6.6.42-vendor',
                        KERNEL_ABI='6.6.42-build-abcd', FEED_ABI='6.6.42-build-abcd')
        self.mock('uname', 'echo "$KERNEL_RELEASE"')
        self.mock('modprobe', '''echo "modprobe $1" >> "$FIXTURE/modules.log"
[ "$FAIL_MODPROBE" != 1 ] || exit 1
[ "$FAIL_LOAD" != "$1" ] || exit 1
mkdir -p "$FIXTURE/sys/module/$1"
''')
        self.mock('insmod', '''echo "insmod $1" >> "$FIXTURE/modules.log"
module=${1##*/}; module=${module%.ko}
[ "$FAIL_LOAD" != "$module" ] || exit 1
mkdir -p "$FIXTURE/sys/module/$module"
''')
        self.mock('opkg', f'''#!{sys.executable}
import os, pathlib, sys
r = pathlib.Path(os.environ['FIXTURE']); args = sys.argv[1:]
with (r/'opkg.log').open('a') as f: f.write(' '.join(args)+'\\n')
assert not any(a.startswith('--force') for a in args), args
op, *names = args
packages = {PACKAGES!r}
if op == 'update': sys.exit(int(os.environ.get('FAIL_UPDATE', '0')))
elif op == 'list':
    for name in packages:
        if name not in os.environ.get('MISSING', '').split(): print(name + ' - 1.0')
    # Vendor/manual names are deliberately not part of automatic selection.
    print('kmod-rndis-host-otherboard-4.1.38-manual - 1.0')
elif op == 'status':
    if (r/'state'/names[0]).exists(): print('Status: install user installed')
    else: sys.exit(1)
elif op == 'install':
    assert os.environ['FEED_ABI'] == os.environ['KERNEL_ABI'], 'opkg: incompatible kernel dependency'
    for name in names:
        assert name in packages, name
        if os.environ.get('FAIL_PACKAGE') == name: sys.exit(1)
        (r/'state'/name).touch()
        folder = r/'lib/modules'/os.environ['KERNEL_RELEASE']/os.environ.get('MODULE_LAYOUT', '')
        folder.mkdir(parents=True, exist_ok=True)
        (folder/(packages[name]+'.ko')).write_text('module from feed')
else: raise AssertionError(args)
''', python=True)
        source = MANAGER.read_text()
        for prefix in ('/etc/', '/lib/', '/sys/'):
            source = source.replace(prefix, str(self.root) + prefix)
        self.script = self.root / 'drivers.sh'
        self.script.write_text(source)

    def mock(self, name, body, python=False):
        file = self.root / 'bin' / name
        file.write_text(body if python else '#!/bin/sh\n' + body + '\n')
        file.chmod(0o755)

    def run_manager(self, **env):
        return subprocess.run(['sh', str(self.script)], text=True, capture_output=True,
                              env={**self.env, **env}, timeout=15)

    def test_installs_native_packages_across_kernel_versions_and_layouts(self):
        for release, layout in [('4.1.38', ''), ('4.1.52', 'kernel/drivers/net/usb'),
                                ('6.6.42-vendor', 'kernel/drivers/net/usb')]:
            with self.subTest(release=release):
                for state in (self.root/'state').iterdir(): state.unlink()
                for module in (self.root/'sys/module').iterdir(): module.rmdir()
                result = self.run_manager(KERNEL_RELEASE=release, MODULE_LAYOUT=layout,
                                          KERNEL_ABI=release+'-build', FEED_ABI=release+'-build')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue((self.root/'lib/modules'/release/layout/'rndis_host.ko').exists())
                self.assertIn('rndis_host', (self.root/'etc/modules.d/60-modgui-smartphone-net').read_text())
        self.assertNotIn('--force', (self.root/'opkg.log').read_text())
        self.assertNotIn('install kmod-rndis-host-otherboard', (self.root/'opkg.log').read_text())

    def test_existing_vendor_module_is_preserved_without_package_or_reload(self):
        module = self.root/'lib/modules/6.6.42-vendor/rndis_host.ko'
        module.parent.mkdir(parents=True)
        module.write_text('independently installed vendor driver')
        (self.root/'sys/module/rndis_host').mkdir()
        result = self.run_manager()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(module.read_text(), 'independently installed vendor driver')
        self.assertNotIn('install kmod-usb-net-rndis', (self.root/'opkg.log').read_text())
        self.assertNotIn('modprobe rndis_host', (self.root/'modules.log').read_text())

    def test_builtin_modules_do_not_require_installation_or_loading(self):
        folder = self.root/'lib/modules/6.6.42-vendor'
        folder.mkdir()
        (folder/'modules.builtin').write_text('kernel/drivers/net/usb/rndis_host.ko\n')
        result = self.run_manager()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('install kmod-usb-net-rndis', (self.root/'opkg.log').read_text())
        self.assertNotIn('modprobe rndis_host', (self.root/'modules.log').read_text())
        self.assertNotIn('rndis_host', (self.root/'etc/modules.d/60-modgui-smartphone-net').read_text())

    def test_kernel_dependency_rejection_is_not_bypassed(self):
        result = self.run_manager(FEED_ABI='different-kernel')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root/'sys/module/rndis_host').exists())
        self.assertNotIn('--force', (self.root/'opkg.log').read_text())
        self.assertIn('kernel compatibility', result.stdout)

    def test_optional_missing_protocols_do_not_block_existing_drivers(self):
        result = self.run_manager(MISSING='kmod-usb-net-cdc-eem kmod-usb-net-cdc-subset')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('optional packages not supplied', result.stdout)
        self.assertTrue((self.root/'sys/module/rndis_host').exists())

    def test_feed_failure_does_not_change_loaded_modules(self):
        (self.root/'sys/module/rndis_host').mkdir()
        result = self.run_manager(FAIL_UPDATE='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.root/'sys/module/rndis_host').exists())
        self.assertFalse((self.root/'modules.log').exists())

    def test_load_failure_is_reported_without_unload_or_forcing(self):
        result = self.run_manager(FAIL_LOAD='rndis_host')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('could not be installed or loaded', result.stdout)
        self.assertNotIn('rmmod', (self.root/'modules.log').read_text())

    def test_refresh_reuses_installed_modules(self):
        self.assertEqual(self.run_manager().returncode, 0)
        (self.root/'opkg.log').write_text('')
        (self.root/'modules.log').write_text('')
        self.assertEqual(self.run_manager().returncode, 0)
        self.assertNotIn('install ', (self.root/'opkg.log').read_text())
        self.assertEqual((self.root/'modules.log').read_text(), '')

    def test_legacy_loading_fallback_finds_nested_module_files(self):
        result = self.run_manager(FAIL_MODPROBE='1', MODULE_LAYOUT='kernel/drivers/net/usb')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('kernel/drivers/net/usb/rndis_host.ko', (self.root/'modules.log').read_text())

    def test_no_available_drivers_does_not_claim_success(self):
        result = self.run_manager(MISSING=' '.join(PACKAGES))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No USB network drivers available', result.stdout)
        self.assertFalse((self.root/'modules.log').exists())


if __name__ == '__main__':
    unittest.main()
