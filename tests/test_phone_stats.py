"""Exercise Android telemetry and VPN transactions without touching a phone."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'decompressed/smartphone/usr/bin/phone_stats.sh'


class PhoneStatsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.env = dict(os.environ, PATH=f'{self.directory}:/usr/bin:/bin',
                        PHONE_TEST_DIR=str(self.directory))
        self.write('timeout', '''#!/bin/sh
if [ "$1" = --help ]; then
    if [ "$TIMEOUT_LEGACY" = 1 ]; then echo 'Usage: timeout [-t SECS] PROG ARGS';
    else echo 'Usage: timeout SECS PROG ARGS'; fi
    exit 0
fi
if [ "$TIMEOUT_LEGACY" = 1 ]; then [ "$1" = -t ] || exit 90; shift; fi
case "$1" in ''|*[!0-9]*) exit 91 ;; esac
shift
exec "$@"
''')
        self.write('adb', f'#!{sys.executable}\n' + '''import json, os, pathlib, subprocess, sys
root = pathlib.Path(os.environ['PHONE_TEST_DIR'])
args = sys.argv[1:]
with (root / 'adb.log').open('a') as log:
    log.write(json.dumps(args) + '\\n')
if args == ['devices']:
    print('List of devices attached')
    state = os.environ.get('ADB_STATE', 'unauthorized' if os.environ.get('UNAUTHORIZED') else 'device')
    if state != 'absent':
        print('fixture\\t' + state)
    if os.environ.get('MULTIPLE_DEVICES'):
        print('second\\tdevice')
    sys.exit(1 if os.environ.get('ADB_QUERY_FAIL') else 0)
if args == ['get-state']:
    sys.exit(1 if os.environ.get('UNAUTHORIZED') else 0)
if args == ['shell', 'dumpsys', 'battery']:
    print('  level: 75\\n  temperature: 300\\n  voltage: 4200\\n  status: 2\\n  health: 2')
elif args == ['shell', 'dumpsys', 'telephony.registry']:
    print('mSignalStrength=CellSignalStrengthLte: rsrp=-95 rsrq=-10 rssnr=120 CellSignalStrengthNr: ssRsrp=2147483647')
    print('getRilDataRadioTechnology=14 nrState=' + os.environ.get('NR_STATE', 'NONE'))
    print('mDataConnectionState=2\\nmOperatorAlphaLong=Example,')
elif args == ['shell', 'getprop', 'ro.build.version.sdk']:
    print('29')
elif args == ['shell', 'ip', '-4', 'route'] or args == ['shell', 'ip', 'route']:
    print('192.168.42.0/24 dev rndis0 proto kernel scope link src 192.168.42.1')
elif args == ['shell', 'ip', 'link']:
    print('10: tun0: <POINTOPOINT,UP>')
elif args == ['shell', 'ip', '-4', 'addr', 'show', 'dev', 'rndis0']:
    print('10: rndis0: <BROADCAST,UP' + ('> state DOWN' if os.environ.get('TETHER_DOWN') else ',LOWER_UP> state UP'))
    print('    inet 192.168.42.1/24 scope global rndis0')
elif args == ['shell', 'cat', '/proc/meminfo']:
    print('MemTotal: 4096000 kB\\nMemAvailable: 2048000 kB')
elif args == ['shell', 'cat', '/proc/loadavg']:
    print('0.1 0.2 0.3 1/100 100')
elif len(args) == 2 and args[1].startswith('command -v screencap'):
    print('TCH_STATUS|' + ('1' if os.environ.get('NO_SCREEN') else '0'))
elif len(args) == 2 and args[1].startswith('umask 077; screencap -p '):
    status = '1' if os.environ.get('FAIL_CAPTURE') else '0'
    (root / 'remote.png').write_bytes(b'not a PNG' if os.environ.get('BAD_SCREEN') else bytes.fromhex('89504e470d0a1a0a') + b'fixture')
    print('TCH_STATUS|' + status)
elif args[:1] == ['pull']:
    pathlib.Path(args[2]).write_bytes((root / 'remote.png').read_bytes())
elif len(args) == 2 and args[1].startswith('input keyevent '):
    print('TCH_STATUS|0')
elif len(args) == 2 and args[1].startswith("su -c '"):
    command = args[1][7:].split("'; printf", 1)[0]
    if os.environ.get('DENY_ROOT'):
        print('TCH_STATUS|1')
        sys.exit(0)  # Old ADB can report transport success for remote failures.
    if command == 'id -u':
        print('0')
        print('TCH_STATUS|0')
    elif 'cleanup()' in command:
        status = subprocess.run(['sh', '-c', command]).returncode
        print('TCH_STATUS|' + str(status))
        sys.exit(0)
''')
        # Simulate enough kernel state to execute the original remote transaction.
        self.write('iptables', f'#!{sys.executable}\n' + '''import json, os, pathlib, sys
root = pathlib.Path(os.environ['PHONE_TEST_DIR']); args = sys.argv[1:]
path = root / 'firewall.json'
state = json.loads(path.read_text()) if path.exists() else []
table = 'filter'
if args[:1] == ['-t']:
    table = args[1]; args = args[2:]
op, chain, *rule = args; key = [table, chain, rule]
if op == '-N':
    if key in state: sys.exit(1)
    state.append(key)
elif op in ('-A', '-I'):
    if os.environ.get('FAIL_FIREWALL') and chain == 'TCH_PHONE_FWD': sys.exit(1)
    state.append(key)
elif op == '-D':
    if os.environ.get('FAIL_DELETE'): sys.exit(1)
    if key not in state: sys.exit(1)
    state.remove(key)
elif op == '-C':
    sys.exit(0 if key in state else 1)
elif op == '-S':
    sys.exit(0 if [table, chain, []] in state else 1)
elif op in ('-F', '-X'):
    state = [item for item in state if item[:2] != [table, chain]]
path.write_text(json.dumps(state))
''')
        self.write('ip', f'#!{sys.executable}\n' + '''import os, pathlib, sys
root = pathlib.Path(os.environ['PHONE_TEST_DIR']); args = sys.argv[1:]
rule = root / 'rule'; route = root / 'route'
if args == ['-o', '-4', 'addr', 'show', 'dev', 'usb0']:
    if os.environ.get('HOST_TEST_IP'): print('26: usb0 inet 10.2.3.4/24 brd 10.2.3.255 scope global usb0')
elif args == ['-4', 'route', 'show', 'dev', 'usb0']:
    if os.environ.get('HOST_TEST_IP'): print('default via 10.2.3.1 dev usb0')
elif args == ['rule', 'show']:
    if rule.exists(): print(rule.read_text())
elif args[:2] == ['rule', 'add']:
    rule.write_text('29999: from all iif rndis0 lookup 29999')
elif args[:2] == ['rule', 'del']:
    if rule.exists(): rule.unlink()
elif args[:3] == ['route', 'show', 'table']:
    if route.exists(): print(route.read_text())
elif args[:2] == ['route', 'add']:
    route.write_text('default dev tun0')
elif args[:2] == ['route', 'flush']:
    if route.exists(): route.unlink()
''')
        self.write('chown', '#!/bin/sh\nexit 0\n')
        self.write('od', '#!/bin/sh\nexit 127\n')  # Simulate a minimal BusyBox environment.

    def write(self, name, content):
        path = self.directory / name
        path.write_text(content)
        path.chmod(0o755)

    def run_phone(self, action='get_stats', **env):
        script = self.directory / 'phone_stats.sh'
        source = SCRIPT.read_text().replace(
            '/usr/share/modgui-smartphone/radio.awk',
            str(ROOT / 'decompressed/smartphone/usr/share/modgui-smartphone/radio.awk'))
        source = source.replace('/sys/bus/usb/devices', str(self.directory / 'usb'))
        source = source.replace('/sys/module/', str(self.directory / 'modules') + '/')
        source = source.replace('/etc/modgui-smartphone-drivers.status', str(self.directory / 'drivers.status'))
        script.write_text(source.replace('/var/run/modgui-smartphone-screen', str(self.directory / 'screen')))
        script.chmod(0o755)
        return subprocess.run([str(script), action], env={**self.env, **env},
                              capture_output=True, text=True, timeout=15)

    def firewall(self):
        path = self.directory / 'firewall.json'
        return json.loads(path.read_text()) if path.exists() else []

    def test_lte_with_unavailable_nr_metrics_is_not_5g(self):
        result = self.run_phone()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('NET|4G (LTE)', result.stdout)
        self.assertIn('BATT|75%', result.stdout)
        self.assertIn('TETHER|Attivo (rndis0 - IP: 192.168.42.1)', result.stdout)

    def test_connected_nr_is_5g(self):
        self.assertIn('NET|5G (NSA)', self.run_phone(NR_STATE='CONNECTED').stdout)

    def test_non_root_capabilities_hide_privileged_features(self):
        result = self.run_phone(DENY_ROOT='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ROOT_ACCESS|0', result.stdout)
        self.assertIn('TAILSCALE_CLI|0', result.stdout)
        self.assertIn('SCREEN_CAPTURE|1', result.stdout)

    def test_display_controls_use_explicit_wake_and_sleep_keys(self):
        for action, key in [('screen_wake', '224'), ('screen_sleep', '223')]:
            self.assertEqual(self.run_phone(action, DENY_ROOT='1').returncode, 0)
            self.assertIn('input keyevent ' + key, (self.directory / 'adb.log').read_text())

    def test_screen_capture_works_without_root_and_uses_private_permissions(self):
        result = self.run_phone('capture_screen', DENY_ROOT='1')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        frame = self.directory / 'screen/frame.png'
        self.assertEqual(frame.read_bytes()[:8], bytes.fromhex('89504e470d0a1a0a'))
        self.assertEqual(frame.stat().st_mode & 0o777, 0o640)
        self.assertFalse(list((self.directory / 'screen').glob('.capture.*')))
        self.assertIn('rm', (self.directory / 'adb.log').read_text())

    def test_invalid_or_failed_capture_does_not_replace_the_previous_frame(self):
        directory = self.directory / 'screen'
        directory.mkdir()
        frame = directory / 'frame.png'
        frame.write_bytes(b'previous frame')
        for flag in ('BAD_SCREEN', 'FAIL_CAPTURE'):
            result = self.run_phone('capture_screen', **{flag: '1'})
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(frame.read_bytes(), b'previous frame')
            self.assertFalse(list(directory.glob('.capture.*')))

    def test_tether_address_without_carrier_is_not_reported_active(self):
        result = self.run_phone(TETHER_DOWN='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('TETHER|Configurato, collegamento inattivo', result.stdout)

    def test_missing_adb_and_usb_authorization_are_errors(self):
        (self.directory / 'adb').unlink()
        result = self.run_phone()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ADB is not installed', result.stdout)
        self.assertIn('ERROR_CODE|adb_missing', result.stdout)

    def test_unauthorized_device_does_not_claim_success(self):
        result = self.run_phone(UNAUTHORIZED='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('authorize USB debugging', result.stdout)
        self.assertIn('ERROR_CODE|unauthorized', result.stdout)

    def test_adb_connection_errors_are_distinct_and_do_not_run_commands(self):
        cases = [({'ADB_STATE': 'absent'}, 'no_device'),
                 ({'ADB_STATE': 'offline'}, 'offline'),
                 ({'MULTIPLE_DEVICES': '1'}, 'multiple_devices'),
                 ({'ADB_STATE': 'no permissions'}, 'adb_error'),
                 ({'ADB_QUERY_FAIL': '1'}, 'adb_error')]
        for env, code in cases:
            with self.subTest(code=code, env=env):
                (self.directory / 'adb.log').write_text('')
                result = self.run_phone('reboot', **env)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('ERROR_CODE|' + code, result.stdout)
                calls = [json.loads(line) for line in (self.directory / 'adb.log').read_text().splitlines()]
                self.assertEqual(calls, [['devices']])

    def test_legacy_busybox_timeout_is_supported(self):
        result = self.run_phone(TIMEOUT_LEGACY='1')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('BATT|75%', result.stdout)

    def test_usb_identity_is_available_without_an_adb_transport(self):
        usb = self.directory / 'usb' / '2-1'
        usb.mkdir(parents=True)
        (usb / 'idVendor').write_text('22b8\n')
        (usb / 'product').write_text('moto g32\n')
        interface = usb.with_name('2-1:1.0')
        interface.mkdir()
        for name, value in [('Class', 'ef'), ('SubClass', '04'), ('Protocol', '01')]:
            (interface / ('bInterface' + name)).write_text(value + '\n')
        net = interface / 'net/usb0'
        net.mkdir(parents=True)
        (net / 'flags').write_text('0x1003\n')
        (net / 'carrier').write_text('1\n')
        (usb / 'speed').write_text('12\n')
        (self.directory / 'modules/rndis_host').mkdir(parents=True)
        (self.directory / 'drivers.status').write_text('USB drivers loaded.\n')
        result = self.run_phone(ADB_STATE='absent', TIMEOUT_LEGACY='1', HOST_TEST_IP='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ERROR_CODE|usb_only', result.stdout)
        self.assertIn('USB_DEV|moto g32', result.stdout)
        self.assertIn('USB_ADB|0', result.stdout)
        self.assertIn('HOST_IF|usb0', result.stdout)
        self.assertIn('HOST_ADMIN|up', result.stdout)
        self.assertIn('HOST_CARRIER|1', result.stdout)
        self.assertIn('USB_SPEED|12', result.stdout)
        self.assertIn('HOST_MODULES|rndis_host', result.stdout)
        self.assertIn('HOST_DRIVER_STATUS|USB drivers loaded.', result.stdout)
        self.assertIn('HOST_IPV4|10.2.3.4/24', result.stdout)
        self.assertIn('HOST_GATEWAY|10.2.3.1', result.stdout)
        result = self.run_phone(UNAUTHORIZED='1')
        self.assertIn('ERROR_CODE|unauthorized', result.stdout)
        self.assertIn('USB_DEV|moto g32', result.stdout)

    def test_root_denied_does_not_claim_success(self):
        result = self.run_phone('start_vpn', DENY_ROOT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SUCCESS', result.stdout)
        self.assertEqual(self.firewall(), [])

    def test_restart_is_idempotent_and_stop_removes_owned_state(self):
        for _ in range(2):
            result = self.run_phone('start_vpn')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(len(self.firewall()), 7)
        result = self.run_phone('stop_vpn')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.firewall(), [])
        self.assertFalse((self.directory / 'rule').exists())
        self.assertFalse((self.directory / 'route').exists())

    def test_partial_firewall_failure_rolls_back(self):
        result = self.run_phone('start_vpn', FAIL_FIREWALL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.firewall(), [])
        self.assertFalse((self.directory / 'rule').exists())
        self.assertFalse((self.directory / 'route').exists())

    def test_existing_android_firewall_rules_are_preserved(self):
        unrelated = [['nat', 'POSTROUTING', ['-o', 'rmnet0', '-j', 'MASQUERADE']]]
        (self.directory / 'firewall.json').write_text(json.dumps(unrelated))
        self.assertEqual(self.run_phone('start_vpn').returncode, 0)
        self.assertEqual(self.run_phone('stop_vpn').returncode, 0)
        self.assertEqual(self.firewall(), unrelated)

    def test_failed_teardown_is_reported(self):
        self.assertEqual(self.run_phone('start_vpn').returncode, 0)
        result = self.run_phone('stop_vpn', FAIL_DELETE='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SUCCESS', result.stdout)

    def test_unrelated_policy_table_is_preserved(self):
        (self.directory / 'rule').write_text('29999: from all lookup 123')
        (self.directory / 'route').write_text('unrelated route')
        result = self.run_phone('start_vpn')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.directory / 'route').read_text(), 'unrelated route')
        self.assertEqual(self.firewall(), [])

    def test_arbitrary_action_cannot_reach_android(self):
        result = self.run_phone('start_vpn; reboot')
        self.assertNotEqual(result.returncode, 0)
        calls = [json.loads(line) for line in (self.directory / 'adb.log').read_text().splitlines()]
        self.assertEqual(calls, [['devices'], ['get-state']])


if __name__ == '__main__':
    unittest.main()
