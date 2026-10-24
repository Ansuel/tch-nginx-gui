"""Disable factory listeners while preserving custom and legacy VPN setups."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'decompressed/gui_file/usr/share/transformer/scripts/ispConfigHelper.sh'


class DefaultServices(unittest.TestCase):
    def cleanup(self, custom_iperf=False, custom_l2tp=False, custom_init=False,
                profile=False, vpn_marker='', proto="'dhcp'", baseline=True,
                services=True, iperf_flag='1', network_readable=True, repeats=1):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            etc, rom = base / 'etc', base / 'rom/etc'
            for root in (etc, rom):
                for folder in ('init.d', 'config', 'xl2tpd'):
                    (root / folder).mkdir(parents=True)
            state, actions = base / 'state', base / 'actions'
            state.write_text(iperf_flag)
            for name in ('iperf', 'xl2tpd'):
                script = '''#!/bin/sh
name="${0##*/}"
if [ "$name:$1" = iperf:stop ]; then
  [ "$(cat "$STATE")" = 1 ] || exit 1
fi
echo "$name $1" >> "$ACTIONS"
'''
                for root in (etc, rom):
                    (root / 'init.d' / name).write_text(script)
                    (root / 'init.d' / name).chmod(0o755)
            iperf_config = 'enabled=1\nproto=TCP\nport=5001\n'
            l2tp_config = '[global]\nport = 1701\n;[lns default]\n;[lac left]\n'
            if profile:
                l2tp_config += '  [lns default]\nip range = 192.168.1.2-192.168.1.3\n'
            for root in (etc, rom):
                (root / 'config/iperf').write_text(iperf_config)
                (root / 'xl2tpd/xl2tpd.conf').write_text(l2tp_config)
            if custom_iperf:
                (etc / 'config/iperf').write_text(iperf_config.replace('5001', '5201'))
            if custom_l2tp:
                (etc / 'xl2tpd/xl2tpd.conf').write_text(l2tp_config + 'custom = yes\n')
            if custom_init:
                for name in ('iperf', 'xl2tpd'):
                    with (etc / 'init.d' / name).open('a') as stream:
                        stream.write('# custom init\n')
            if vpn_marker:
                (etc / vpn_marker).touch()
            if not baseline:
                shutil.rmtree(base / 'rom')
            if not services:
                shutil.rmtree(etc / 'init.d')
            source = HELPER.read_text().split('purge_default_services() {', 1)[1]
            source = 'purge_default_services() {' + source.split('firewall_specific_sip_rules_FASTWEB()', 1)[0]
            source = source.replace('/rom/etc/', '@FACTORY@/')
            source = source.replace('/etc/', str(etc) + '/').replace('@FACTORY@', str(rom))
            mock = '''
logecho() { :; }
uci() {
  [ "$1" = -q ] && shift
  case "$1:$2" in
    get:iperf.iperf.enabled) cat "$STATE" ;;
    show:network)
      [ "$NETWORK_READABLE" = 1 ] || return 1
      printf 'network.wan.proto=%s\\n' "$PROTO" ;;
    set:iperf.iperf.enabled=0)
      printf 0 > "$STATE"
      printf 'enabled=0\\n' > "$IPERF_CONFIG"
      echo 'iperf set 0' >> "$ACTIONS" ;;
    commit:iperf) echo 'iperf commit' >> "$ACTIONS" ;;
    *) return 1 ;;
  esac
}
'''
            result = subprocess.run(
                ['sh'], input=source + mock + '\npurge_default_services\n' * repeats,
                text=True, capture_output=True,
                env=dict(os.environ, STATE=str(state), ACTIONS=str(actions),
                         IPERF_CONFIG=str(etc / 'config/iperf'), PROTO=proto,
                         NETWORK_READABLE=str(int(network_readable))),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')
            return state.read_text(), actions.read_text().splitlines() if actions.exists() else []

    def test_factory_listeners_are_stopped_and_disabled(self):
        state, actions = self.cleanup()
        self.assertEqual(state, '0')
        self.assertEqual(actions, ['iperf stop', 'iperf disable', 'iperf set 0',
                                   'iperf commit', 'xl2tpd stop', 'xl2tpd disable'])

    def test_repeated_cleanup_does_not_rewrite_iperf(self):
        state, actions = self.cleanup(repeats=2)
        self.assertEqual(state, '0')
        self.assertEqual(actions.count('iperf commit'), 1)
        self.assertEqual(actions.count('iperf stop'), 1)

    def test_custom_iperf_server_is_preserved(self):
        state, actions = self.cleanup(custom_iperf=True)
        self.assertEqual(state, '1')
        self.assertEqual(actions, ['xl2tpd stop', 'xl2tpd disable'])

    def test_custom_l2tp_configuration_is_preserved(self):
        _, actions = self.cleanup(custom_l2tp=True)
        self.assertFalse(any(action.startswith('xl2tpd') for action in actions))

    def test_active_factory_lac_lns_sections_are_preserved(self):
        _, actions = self.cleanup(profile=True)
        self.assertFalse(any(action.startswith('xl2tpd') for action in actions))

    def test_l2tp_wan_and_old_unquoted_uci_values_are_preserved(self):
        for proto in ("'l2tp'", 'l2tp', "'l2tpv2'", "'l2tpv3'"):
            with self.subTest(proto=proto):
                _, actions = self.cleanup(proto=proto)
                self.assertFalse(any(action.startswith('xl2tpd') for action in actions))

    def test_vpn_extension_is_preserved(self):
        for marker in ('.modgui-l2tp-ipsec-installed', 'init.d/l2tp-ipsec-server',
                       'init.d/modgui-ipsec'):
            with self.subTest(marker=marker):
                _, actions = self.cleanup(vpn_marker=marker)
                self.assertFalse(any(action.startswith('xl2tpd') for action in actions))

    def test_unknown_firmware_or_missing_services_are_left_untouched(self):
        for options in ({'baseline': False}, {'services': False}, {'custom_init': True}):
            with self.subTest(options=options):
                state, actions = self.cleanup(**options)
                self.assertEqual(state, '1')
                self.assertEqual(actions, [])

    def test_missing_legacy_iperf_flag_is_not_created(self):
        state, actions = self.cleanup(iperf_flag='')
        self.assertEqual(state, '')
        self.assertEqual(actions, ['xl2tpd stop', 'xl2tpd disable'])

    def test_unreadable_network_config_preserves_l2tp(self):
        _, actions = self.cleanup(network_readable=False)
        self.assertFalse(any(action.startswith('xl2tpd') for action in actions))


if __name__ == '__main__':
    unittest.main()
