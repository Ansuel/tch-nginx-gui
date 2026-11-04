"""The managed resolver must exist before dnsmasq starts after a reboot."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INIT = ROOT / 'decompressed/smartphone/etc/init.d/modgui-smartphone-uplink'


class SmartphoneBootTest(unittest.TestCase):
    def test_both_boot_links_use_one_script_and_late_phase_starts_monitor(self):
        with tempfile.TemporaryDirectory() as folder:
            links = Path(folder) / 'etc/rc.d'
            links.mkdir(parents=True)
            subprocess.run(['sh', '-c', '''
. "$1"
enable || exit 1
initscript=/etc/rc.d/S95modgui-smartphone-uplink
start() { echo monitor; }
boot
''', 'sh', str(INIT)], check=True, capture_output=True, text=True,
                env={**os.environ, 'IPKG_INSTROOT': folder})
            self.assertEqual(sorted(p.name for p in links.iterdir()), [
                'K10modgui-smartphone-uplink', 'S18modgui-smartphone-uplink',
                'S95modgui-smartphone-uplink'])
            for link in links.iterdir():
                self.assertEqual(os.readlink(link), '../init.d/modgui-smartphone-uplink')
            result = subprocess.run(['sh', '-c', '''
. "$1"
initscript=/etc/rc.d/S95modgui-smartphone-uplink
start() { echo monitor; }
boot
disable
''', 'sh', str(INIT)], check=True, capture_output=True, text=True,
                env={**os.environ, 'IPKG_INSTROOT': folder})
            self.assertEqual(result.stdout.strip(), 'monitor')
            self.assertEqual(list(links.iterdir()), [])

    def test_resolver_preparation_before_dnsmasq_is_guarded_and_idempotent(self):
        source = INIT.read_text()
        self.assertIn('START=95', source)
        with tempfile.TemporaryDirectory() as folder:
            resolver = Path(folder) / 'dns/resolv.conf'
            script = Path(folder) / 'init.sh'
            script.write_text(source.replace('/var/run/modgui-smartphone-dns', str(resolver.parent)))
            command = '''
uci() { case "$*" in *enabled) echo "$ENABLED";; *dns_managed) echo "$MANAGED";; esac; }
. "$1"
initscript=/etc/rc.d/S18modgui-smartphone-uplink
start() { exit 99; }
boot
'''
            def run(enabled, managed):
                subprocess.run(['sh', '-c', command, 'sh', str(script)], check=True,
                               env={**os.environ, 'ENABLED': enabled, 'MANAGED': managed})
            run('0', '1')
            self.assertFalse(resolver.exists())
            run('1', '0')
            self.assertFalse(resolver.exists())
            run('1', '1')
            self.assertTrue(resolver.exists())
            self.assertEqual(resolver.parent.stat().st_mode & 0o777, 0o755)
            self.assertEqual(resolver.stat().st_mode & 0o777, 0o644)
            resolver.write_text('nameserver 192.0.2.1\n')
            run('1', '1')
            self.assertEqual(resolver.read_text(), 'nameserver 192.0.2.1\n')
