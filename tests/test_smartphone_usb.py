"""Exercise USB mode changes through the shell helper with mocked ADB and sysfs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

APP = Path(__file__).resolve().parents[1] / 'decompressed/smartphone'


class SmartphoneUsbTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        usb = self.root / 'sys/bus/usb/devices/1-1'
        usb.mkdir(parents=True)
        (usb / 'idVendor').touch()
        (usb / 'serial').write_text('example-usb\n')
        adb_interface = usb.with_name('1-1:1.0')
        net_interface = usb.with_name('1-1:1.1')
        for interface, descriptor in ((adb_interface, ('ff', '42', '01')),
                                      (net_interface, ('02', '0d', '00'))):
            interface.mkdir()
            for attribute, value in zip(('Class', 'SubClass', 'Protocol'), descriptor):
                (interface / ('bInterface' + attribute)).write_text(value + '\n')
        self.driver = net_interface / 'net/usb0/device/driver'
        self.driver.parent.mkdir(parents=True)
        self.driver.symlink_to('rndis_host')
        for driver in ('cdc_ncm', 'rndis_host'):
            (self.root / 'sys/bus/usb/drivers' / driver).mkdir(parents=True)
        (self.root / 'var/run').mkdir(parents=True)
        (self.root / 'mode').write_text('rndis\n')

        binary = self.root / 'bin'
        binary.mkdir()
        self.mock(binary, 'sleep', 'exit 0')
        self.mock(binary, 'uname', 'echo "${MOCK_KERNEL:-6.6.0}"')
        self.mock(binary, 'timeout', '[ "$1" != --help ] || exit 0\nshift\nexec "$@"')
        self.mock(binary, 'adb', '''
case "$*" in
    start-server) exit 0 ;;
    devices) printf 'List of devices attached\nexample-usb\tdevice\n'; exit ;;
    get-state|'-s example-usb get-state') echo device; exit ;;
    '-s example-usb shell svc usb getFunctions') cat "$FIXTURE/mode"; exit ;;
    '-s example-usb shell svc usb setFunctions '*)
        echo "$*" >> "$FIXTURE/calls"
        echo "$7" > "$FIXTURE/mode"
        case "$7" in
            ncm) [ "${NO_BIND:-0}" = 0 ] || exit 1; driver=cdc_ncm ;;
            rndis) driver=rndis_host ;;
            *) exit 90 ;;
        esac
        ln -sfn "$driver" "$FIX_DRIVER"
        exit 1 # Android can drop the ADB transport before returning success.
        ;;
esac
exit 91
''')
        self.env = dict(os.environ, PATH=f'{binary}:/usr/bin:/bin',
                        FIXTURE=str(self.root), FIX_DRIVER=str(self.driver))
        self.helper = self.root / 'phone_stats.sh'
        source = (APP / 'usr/bin/phone_stats.sh').read_text()
        for prefix in ('/sys/', '/var/run/', '/etc/modgui-', '/usr/share/modgui-smartphone/'):
            source = source.replace(prefix, str(self.root) + prefix)
        self.helper.write_text(source)

    def mock(self, binary, name, body):
        file = binary / name
        file.write_text('#!/bin/sh\n' + body + '\n')
        file.chmod(0o755)

    def run_helper(self, action, **env):
        return subprocess.run(['sh', str(self.helper), action], capture_output=True,
                              text=True, env={**self.env, **env}, timeout=5)

    def test_unbound_rndis_control_interface_reports_expected_driver(self):
        interface = self.driver.parents[3]
        for attribute, value in zip(('Class', 'SubClass', 'Protocol'), ('ef', '04', '01')):
            (interface / ('bInterface' + attribute)).write_text(value + '\n')
        shutil.rmtree(interface / 'net')

        info = self.run_helper('get_usb_info').stdout.splitlines()
        self.assertIn('USB_NETWORK|1', info)
        self.assertIn('HOST_UNBOUND_DRIVER|rndis_host', info)
        self.assertFalse(any(line.startswith('HOST_IF|') for line in info))

        (interface / 'driver').symlink_to('rndis_host')
        info = self.run_helper('get_usb_info').stdout.splitlines()
        self.assertIn('USB_NETWORK|1', info)
        self.assertNotIn('HOST_UNBOUND_DRIVER|rndis_host', info)

    def test_switches_both_ways_and_checks_bound_driver(self):
        result = self.run_helper('usb_ncm')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        info = self.run_helper('get_usb_info').stdout
        self.assertIn('HOST_DRIVER|cdc_ncm', info)
        self.assertIn('HOST_NCM|1', info)
        self.assertEqual(self.run_helper('usb_ncm').returncode, 0)
        self.assertEqual(self.run_helper('usb_rndis').returncode, 0)
        self.assertEqual(self.driver.readlink(), Path('rndis_host'))
        self.assertEqual(len((self.root / 'calls').read_text().splitlines()), 2)

    def test_missing_driver_does_not_change_android(self):
        (self.root / 'sys/bus/usb/drivers/cdc_ncm').rmdir()
        result = self.run_helper('usb_ncm')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('driver cdc_ncm non è disponibile', result.stdout)
        self.assertFalse((self.root / 'calls').exists())

    def test_unconfirmed_usb_mode_restores_previous_transport(self):
        result = self.run_helper('usb_ncm', NO_BIND='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('non ha confermato', result.stdout)
        self.assertEqual((self.root / 'mode').read_text().strip(), 'rndis')
        self.assertFalse((self.root / 'var/run/modgui-smartphone-usb-switch').exists())

    def test_legacy_kernel_blocks_ncm_before_sending_the_command(self):
        legacy = {'MOCK_KERNEL': '4.1.38'}
        status = self.run_helper('get_usb_info', **legacy).stdout.splitlines()
        self.assertIn('HOST_NCM_BLOCKED|1', status)
        self.assertNotIn('HOST_NCM|1', status)
        result = self.run_helper('usb_ncm', **legacy)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('può bloccare la rete del router', result.stdout)
        self.assertFalse((self.root / 'calls').exists())
        self.assertEqual(self.run_helper('usb_rndis', **legacy).returncode, 0)


if __name__ == '__main__':
    unittest.main()
