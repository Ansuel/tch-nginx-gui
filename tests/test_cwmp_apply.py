"""Verify CWMP GUI apply stops disabled services and can re-enable them."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
SCRIPT = ROOT / 'usr/share/transformer/scripts/ispConfigHelper.sh'


class CwmpApply(unittest.TestCase):
    def apply(self, state, running=False, fail='', pid_running=False):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            actions = base / 'actions'
            uci = base / 'uci'
            uci.write_text('#!/bin/sh\n[ "$*" = "-q get cwmpd.cwmpd_config.state" ] || exit 1\nprintf "%s" "$STATE"\n')
            uci.chmod(0o755)
            pidof = base / 'pidof'
            pidof.write_text('#!/bin/sh\n[ "$PID_RUNNING" = 1 ]\n')
            pidof.chmod(0o755)
            service = base / 'cwmpd'
            service.write_text('''#!/bin/sh
echo "$1" >> "$ACTIONS"
[ "$1" = "$FAIL" ] && exit 1
if [ "$1" = running ]; then
  [ "$RUNNING" = 1 ]
else
  exit 0
fi
''')
            service.chmod(0o755)
            source = SCRIPT.read_text().replace('/etc/init.d/cwmpd', str(service))
            result = subprocess.run(
                ['sh', '-s', '--', 'cwmp'], input=source, text=True, capture_output=True,
                env=dict(os.environ, PATH=f'{base}:{os.environ["PATH"]}',
                         STATE=state, RUNNING=str(int(running)),
                         ACTIONS=str(actions), FAIL=fail, PID_RUNNING=str(int(pid_running))),
            )
            return result, actions.read_text().splitlines() if actions.exists() else []

    def test_disable_stops_and_removes_boot_enablement(self):
        for running in (True, False):
            with self.subTest(running=running):
                result, actions = self.apply('0', running)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(actions, ['disable', 'stop'])

    def test_enable_starts_previously_stopped_daemon(self):
        result, actions = self.apply('1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions, ['enable', 'running', 'start'])

    def test_configuration_edits_reload_running_daemon(self):
        result, actions = self.apply('1', running=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions, ['enable', 'running', 'reload'])

    def test_invalid_or_missing_state_does_not_start_cwmp(self):
        for state in ('', '2', 'garbage'):
            with self.subTest(state=state):
                result, actions = self.apply(state)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(actions, [])

    def test_legacy_init_without_running_command_reloads_existing_process(self):
        result, actions = self.apply('1', pid_running=True, fail='running')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions, ['enable', 'reload'])

    def test_service_errors_are_reported(self):
        for state, action in [('0', 'disable'), ('0', 'stop'),
                              ('1', 'enable'), ('1', 'start'), ('1', 'reload')]:
            with self.subTest(action=action):
                result, actions = self.apply(state, running=action == 'reload', fail=action)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(actions[-1], action)

    def test_transformer_apply_uses_state_aware_helper(self):
        rule = ROOT / 'usr/share/transformer/commitapply/uci_cwmpd.ca'
        self.assertEqual(rule.read_text().strip(),
                         '^cwmpd /usr/share/transformer/scripts/ispConfigHelper.sh cwmp')


if __name__ == '__main__':
    unittest.main()
