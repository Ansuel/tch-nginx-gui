"""Exercise optional-service shutdown, recovery and preservation on old firmware."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FILES = ROOT / 'decompressed/gui_file'
POLICY = FILES / 'usr/share/transformer/scripts/ispConfigHelper.sh'
SERVICES = ('weburl', 'dnsfilter', 'dlnad', 'mvfs', 'mud', 'gre-hotspotd', 'generic_pnpd', 'samba', 'samba-nmbd')

class ServicePolicy(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        for path in ('etc/init.d', 'etc/config', 'rom/etc/init.d', 'rom/etc/config',
                     'etc/ssl/paired', 'bin', 'state'):
            (self.base / path).mkdir(parents=True)
        self.config = {}
        self.actions = self.base / 'actions'
        self.env = dict(os.environ, POLICY_ROOT=str(self.base),
                        PATH=f'{self.base / "bin"}:{os.environ["PATH"]}')
        service = '''#!/bin/sh
name=${0##*/}
echo "$name $1" >> "$POLICY_ROOT/actions"
[ ! -e "$POLICY_ROOT/fail-$name-$1" ] || exit 1
case "$1" in
  stop) echo stopped > "$POLICY_ROOT/state/$name" ;;
  restart) echo running > "$POLICY_ROOT/state/$name" ;;
  enable) echo enabled > "$POLICY_ROOT/state/$name.boot" ;;
  disable) echo disabled > "$POLICY_ROOT/state/$name.boot" ;;
esac
'''
        for name in SERVICES:
            for prefix in ('etc', 'rom/etc'):
                file = self.base / prefix / 'init.d' / name
                file.write_text(service)
                file.chmod(0o755)
        uci = self.base / 'bin/uci'
        uci.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ['POLICY_ROOT'])
path = root / 'config.json'
data = json.loads(path.read_text())
args = sys.argv[1:]
if args[0] == '-q': args.pop(0)
command, key = args[:2]
if command == 'get':
    if key not in data: sys.exit(1)
    print(data[key])
elif command == 'show':
    if (root / ('fail-' + key)).exists(): sys.exit(1)
    found = False
    for name, value in data.items():
        if name.startswith(key + '.'):
            print(name + '=' + (value if name.count('.') == 1 else repr(value)))
            found = True
    if not found: sys.exit(1)
elif command == 'set':
    key, value = key.split('=', 1)
    data[key] = value
    path.write_text(json.dumps(data))
    with (root / 'actions').open('a') as log: log.write('uci set ' + key + '=' + value + '\\n')
elif command == 'commit': pass
else: sys.exit(1)
''')
        uci.chmod(0o755)
        source = POLICY.read_text().replace('/rom/etc/', '@ROM@/')
        source = source.replace('/etc/', str(self.base / 'etc') + '/')
        source = source.replace('@ROM@/', str(self.base / 'rom/etc') + '/')
        self.script = self.base / 'policy.sh'
        self.script.write_text(source)

    def run_policy(self, command, expected_code=0):
        (self.base / 'config.json').write_text(json.dumps(self.config))
        result = subprocess.run(['sh', str(self.script), command], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, expected_code, result.stderr)
        self.assertEqual(result.stderr, '')
        self.config = json.loads((self.base / 'config.json').read_text())
        actions = self.actions.read_text().splitlines() if self.actions.exists() else []
        self.actions.unlink(missing_ok=True)
        return actions

    def test_parental_off_stops_both_and_reenable_starts_selected_mode(self):
        self.config['parental.general.enable'] = '0'
        self.assertEqual(self.run_policy('parental'), ['weburl stop', 'weburl disable', 'dnsfilter stop', 'dnsfilter disable'])
        self.config['parental.general.enable'] = '1'
        self.assertEqual(self.run_policy('parental'), ['dnsfilter stop', 'dnsfilter disable', 'weburl enable', 'weburl restart'])
        self.assertEqual((self.base / 'state/weburl').read_text().strip(), 'running')
        self.config['parental.general.mode'] = 'dns'
        self.assertEqual(self.run_policy('parental'), ['weburl stop', 'weburl disable', 'dnsfilter enable', 'dnsfilter restart'])

    def test_dlna_stops_entire_group_and_restarts_in_dependency_order(self):
        self.config['dlnad.config.enabled'] = '0'
        self.assertEqual(self.run_policy('dlna'), ['dlnad stop', 'dlnad disable', 'mud stop', 'mud disable', 'mvfs stop', 'mvfs disable'])
        self.assertEqual((self.base / 'state/mvfs.boot').read_text().strip(), 'disabled')
        self.config['dlnad.config.enabled'] = '1'
        self.assertEqual(self.run_policy('dlna'), ['mvfs enable', 'mvfs restart', 'mud enable', 'mud restart', 'dlnad enable', 'dlnad restart'])
        self.assertEqual((self.base / 'state/mvfs').read_text().strip(), 'running')
        self.assertEqual((self.base / 'state/mvfs.boot').read_text().strip(), 'enabled')

    def test_install_synchronizes_boot_links_without_restarting_enabled_features(self):
        self.config.update({'parental.general.enable': '1', 'dlnad.config.enabled': '1',
                            'modgui.var.keep_isp_services': '1'})
        self.assertEqual(self.run_policy('sync'), ['dnsfilter stop', 'dnsfilter disable',
                         'weburl enable', 'mvfs enable', 'mud enable', 'dlnad enable'])
        self.config.update({'parental.general.enable': '0', 'dlnad.config.enabled': '0'})
        self.assertEqual(self.run_policy('sync'), ['weburl stop', 'weburl disable', 'dnsfilter stop', 'dnsfilter disable',
                          'dlnad stop', 'dlnad disable', 'mud stop', 'mud disable', 'mvfs stop', 'mvfs disable'])

    def test_unused_factory_isp_daemons_are_stopped_and_disabled(self):
        self.assertEqual(self.run_policy('isp'), ['gre-hotspotd stop', 'gre-hotspotd disable',
                                                 'generic_pnpd stop', 'generic_pnpd disable'])

    def test_explicit_isp_preservation_flag(self):
        self.config['modgui.var.keep_isp_services'] = '1'
        self.assertEqual(self.run_policy('isp'), [])

    def test_custom_init_and_unknown_firmware_are_preserved(self):
        (self.base / 'etc/init.d/gre-hotspotd').write_text('# custom\n')
        (self.base / 'rom/etc/init.d/generic_pnpd').unlink()
        self.assertEqual(self.run_policy('isp'), [])

    def test_gre_configuration_is_preserved_and_ui_apply_reenables_service(self):
        (self.base / 'etc/config/gre_intf').touch()
        self.config['gre_intf.custom'] = 'tunnel'
        self.assertFalse(any(a.startswith('gre-hotspotd') for a in self.run_policy('isp')))
        self.assertEqual(self.run_policy('gre'), ['gre-hotspotd enable', 'gre-hotspotd restart'])

    def test_unreadable_gre_configuration_is_preserved(self):
        (self.base / 'etc/config/gre_hotspotd').touch()
        (self.base / 'fail-gre_hotspotd').touch()
        self.assertFalse(any(a.startswith('gre-hotspotd') for a in self.run_policy('isp')))

    def test_configured_server_and_registered_pairing_are_preserved(self):
        for key, value in [('generic_app.pnpserver.url', 'https://operator.invalid'),
                           ('generic_app.pnpserver.registered', '1')]:
            self.config = {key: value}
            self.assertFalse(any(a.startswith('generic_pnpd') for a in self.run_policy('isp')))
        self.config = {}
        (self.base / 'etc/ssl/paired/certificate').touch()
        self.assertFalse(any(a.startswith('generic_pnpd') for a in self.run_policy('isp')))

    def test_paired_symlink_is_preserved(self):
        (self.base / 'etc/ssl/paired/cert').symlink_to(self.base / 'nonexistent')
        self.assertFalse(any(a.startswith('generic_pnpd') for a in self.run_policy('isp')))

    def test_broken_config_and_pairing_directory_links_are_preserved(self):
        (self.base / 'etc/config/gre_hotspotd').symlink_to(self.base / 'missing')
        (self.base / 'etc/ssl/paired').rmdir()
        (self.base / 'etc/ssl/paired').symlink_to(self.base / 'missing')
        self.assertEqual(self.run_policy('isp'), [])

    def test_stop_error_is_reported_without_skipping_other_services(self):
        self.config['dlnad.config.enabled'] = '0'
        (self.base / 'fail-dlnad-stop').touch()
        self.assertEqual(self.run_policy('dlna', 1), ['dlnad stop', 'dlnad disable', 'mud stop', 'mud disable', 'mvfs stop', 'mvfs disable'])

    def test_custom_pnp_config_is_preserved(self):
        (self.base / 'etc/config/generic_app').write_text('custom')
        (self.base / 'rom/etc/config/generic_app').write_text('stock')
        self.config['generic_app.pnpserver'] = 'pnpserver'
        self.assertFalse(any(a.startswith('generic_pnpd') for a in self.run_policy('isp')))

    def test_missing_services_are_supported(self):
        for name in SERVICES:
            (self.base / 'etc/init.d' / name).unlink()
        self.config.update({'parental.general.enable': '0', 'dlnad.config.enabled': '0'})
        self.assertEqual(self.run_policy('sync'), [])

    def test_gui_and_boot_entry_points_reach_the_policy(self):
        rules = FILES / 'usr/share/transformer/commitapply'
        for filename, command in [('uci_parental.ca', 'parental'), ('uci_dlnad.ca', 'dlna'),
                                  ('gre_hotspot.ca', 'gre'), ('uci_generic_pnpd.ca', 'pnp')]:
            self.assertIn('ispConfigHelper.sh ' + command, (rules / filename).read_text())
        install = (FILES / 'etc/modgui_scripts/06_network.sh').read_text()
        self.assertNotIn('/etc/rc.local', install)
        self.assertIn('/usr/share/transformer/scripts/ispConfigHelper.sh refresh', install)
        self.assertFalse((FILES / 'etc/init.d/modgui-service-policy').exists())
        self.assertFalse((FILES / 'usr/share/transformer/scripts/servicePolicy.sh').exists())

    def test_datausage_and_legacy_samba_keep_native_handling(self):
        rules = (FILES / 'usr/share/transformer/commitapply/uci_datausage.ca').read_text()
        self.assertIn('/etc/init.d/datausaged reload', rules)
        self.assertIn('/etc/init.d/datausaged restart', rules)
        self.assertNotIn('ispConfigHelper.sh', rules)
        self.assertFalse((FILES / 'usr/share/transformer/commitapply/uci_datausage_notifier.ca').exists())
        self.assertNotIn('datausage_policy', POLICY.read_text())
        self.assertNotIn('legacy_samba_policy', POLICY.read_text())

    def test_invalid_isp_does_not_apply_policy_or_mask_setup_error(self):
        source = (FILES / 'usr/share/transformer/scripts/ispConfigHelper.sh').read_text()
        source = source.replace('/etc/init.d', str(self.base / 'etc/init.d'))
        self.script.chmod(0o755)
        (self.base / 'config.json').write_text('{}')
        result = subprocess.run(['sh', '-s', '--', 'setup', 'UnknownISP'], input=source,
                                env=dict(self.env, debug='0'), text=True, capture_output=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('Invalid ISP', result.stdout)
        self.assertFalse(self.actions.exists())

if __name__ == '__main__':
    unittest.main()
