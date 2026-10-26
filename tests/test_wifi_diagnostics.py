"""Exercise the diagnostic loop with simulated UBUS failures, never a router."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/diagnostics/wifi-watch.sh'


class WifiDiagnostics(unittest.TestCase):
    def simulate(self, states):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bindir = root / 'bin'
            bindir.mkdir()
            mocks = {
                'timeout': 'shift\nexec "$@"',
                'ubus': '''
n=$(cat "$FIXTURE/count" 2>/dev/null || echo 0)
if [ "$4" = wireless.radio ]; then n=$((n+1)); echo "$n" > "$FIXTURE/count"; fi
state=$(cut -c "$n" "$FIXTURE/states")
[ "$state" = S ] || exit 7
''',
                'sleep': '''
n=$(cat "$FIXTURE/count")
[ "$n" -lt "$SAMPLES" ] || kill -TERM "$PPID"
''',
                'logger': 'echo "$*" >> "$FIXTURE/events"',
                'logread': 'echo "hostapd: radio timeout"\necho "hostapd: password secret-value"',
                'dmesg': 'echo "quantenna: blocked"',
                'free': 'echo "memory fixture"',
            }
            for name, body in mocks.items():
                f = bindir / name
                f.write_text('#!/bin/sh\n' + body + '\n')
                f.chmod(0o755)
            (root / 'states').write_text(states)
            env = {**os.environ, 'PATH': str(bindir) + ':' + os.environ['PATH'],
                   'FIXTURE': tmp, 'SAMPLES': str(len(states)), 'DIAG_DIR': str(root / 'diag')}
            result = subprocess.run(['sh', str(SCRIPT)], env=env,
                                    capture_output=True, timeout=30)
            self.assertEqual(result.returncode, -15, result.stderr)
            reports = {p.name: p.read_text() for p in (root / 'diag').glob('capture-*.txt')}
            events = (root / 'events').read_text() if (root / 'events').exists() else ''
            health = (root / 'diag/health.log').read_text().splitlines()
            return reports, events, health

    def test_transient_failure_does_not_capture(self):
        reports, events, health = self.simulate('FSS')
        self.assertFalse(reports)
        self.assertFalse(events)
        self.assertEqual(len(health), 3)
        self.assertIn('failures=0', health[-1])

    def test_capture_latches_recovers_and_rotates(self):
        reports, events, health = self.simulate('FFFSFFSFFSFF')
        self.assertEqual(len(reports), 3)
        self.assertEqual(len(events.splitlines()), 4)
        for text in reports.values():
            self.assertIn('consecutive_failures=2', text)
            self.assertIn('radio timeout', text)
            self.assertNotIn('secret-value', text)
            self.assertLessEqual(len(text.encode()), 65536)

    def test_health_log_is_bounded(self):
        _, _, health = self.simulate('S' * 205)
        self.assertEqual(len(health), 200)


if __name__ == '__main__':
    unittest.main()
