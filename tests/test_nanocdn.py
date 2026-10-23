"""Exercise nanoCDN cleanup with stock IPTV and missing boot links/services."""
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'decompressed/gui_file/usr/share/transformer/scripts/ispConfigHelper.sh'


class NanoCdnCleanup(unittest.TestCase):
    def run_cleanup(self, enabled, service=True, boot_link=True):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            init = base / 'nanocdn'
            state = base / 'enabled'
            actions = base / 'actions'
            if enabled is not None:
                state.write_text(enabled)
            if service:
                init.write_text('#!/bin/sh\necho "service $1" >> "$ACTIONS"\n')
                init.chmod(0o755)
            link = base / 'S99nanocdn'
            if boot_link:
                link.symlink_to(init)
            source = HELPER.read_text().split('firewall_specific_sip_rules_FASTWEB()')[0]
            source = source.replace('/etc/init.d/nanocdn', str(init))
            source = source.replace('/etc/rc.d/S99nanocdn', str(link))
            source = source.replace('/etc/init.d/bulkdata', str(base / 'bulkdata'))
            mock = r'''
uci() {
  [ "$1" = '-q' ] && shift
  case "$1:$2" in
    get:system.mabr) [ -f "$STATE" ] && echo agent ;;
    get:system.mabr.enabled) cat "$STATE" 2>/dev/null ;;
    get:system.acotel.enabled) return 1 ;;
    show:network) echo "network.iptv=interface" ;;
    set:system.mabr.enabled=0) echo 0 > "$STATE"; echo set >> "$ACTIONS" ;;
    commit:system) echo commit >> "$ACTIONS" ;;
    *) return 1 ;;
  esac
}
purge_telemetry
purge_telemetry
'''
            script = (
                f'STATE={shlex.quote(str(state))}\n'
                f'export ACTIONS={shlex.quote(str(actions))}\ndebug=0\n'
                + source + mock
            )
            result = subprocess.run(['sh'], input=script, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')
            self.assertEqual(state.read_text().strip() if state.exists() else None,
                             '0' if enabled is not None else None)
            expected = ['set', 'commit'] if enabled not in (None, '0') else []
            if service:
                expected += ['service stop', 'service disable'] * 2
            self.assertEqual(actions.read_text().splitlines() if actions.exists() else [],
                             expected)

    def test_stock_iptv_does_not_preserve_nanocdn(self):
        self.run_cleanup('1')

    def test_missing_boot_link_still_stops_service(self):
        self.run_cleanup('1', boot_link=False)

    def test_disabled_flag_still_stops_running_service(self):
        self.run_cleanup('0', boot_link=False)

    def test_firmware_without_mabr(self):
        self.run_cleanup(None, service=False, boot_link=False)


if __name__ == '__main__':
    unittest.main()
