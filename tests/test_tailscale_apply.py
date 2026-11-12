"""Disabling must terminate Tailscale even with unusable connection settings."""
import os
from pathlib import Path
import subprocess
import unittest

APPLY = (Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
         / 'usr/share/transformer/scripts/tailscaleApply.sh')


class TailscaleApply(unittest.TestCase):
    def test_disable_ignores_invalid_settings_and_funnel_failures(self):
        source = APPLY.read_text().replace('/usr/share/modgui-tailscale/tailscale.connect', 'worker')
        source = source.replace('/etc/init.d/tailscale', 'service')
        source = source.replace('/etc/init.d/network', 'network_service')
        source = source.replace('/etc/init.d/firewall', 'firewall_service')
        prelude = '''
uci() {
 case "$*" in
 *service.enabled) echo "$ENABLED" ;;
 *service.hostname) echo invalid/hostname ;;
 *service.port|*service.funnel_port|*service.funnel_ssh_port) echo invalid ;;
 *service.funnel_enabled|*service.funnel_ssh_enabled) echo 1 ;;
 *) echo "uci:$*" ;;
 esac
}
worker() { echo "worker:$*"; return "$FAIL_WORKER"; }
service() { echo "service:$*" >&3; }
network_service() { echo NETWORK_REMOVED >&3; }
firewall_service() { echo FIREWALL_REMOVED >&3; }
rm() { :; }
exec 3>&1
'''
        for enabled in ('0', '1'):
            for fail in ('0', '1'):
                with self.subTest(enabled=enabled, fail=fail):
                    result = subprocess.run(['sh', '-c', prelude + source],
                                            env=dict(os.environ, ENABLED=enabled, FAIL_WORKER=fail),
                                            capture_output=True, text=True, timeout=5)
                    if enabled == '0':
                        self.assertEqual(result.returncode, 0, result.stderr)
                        for action in ('worker:funnel-stop', 'worker:funnel-ssh-stop',
                                       'service:stop', 'NETWORK_REMOVED', 'FIREWALL_REMOVED'):
                            self.assertIn(action, result.stdout)
                    else:
                        self.assertNotEqual(result.returncode, 0)
                        self.assertNotIn('service:stop', result.stdout)
                        self.assertNotIn('NETWORK_REMOVED', result.stdout)


if __name__ == '__main__':
    unittest.main()
