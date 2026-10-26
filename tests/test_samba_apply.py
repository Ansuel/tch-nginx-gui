"""Exercise NQE shutdown, printer dependencies and legacy Samba fallback."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
SCRIPT = ROOT / 'usr/share/transformer/scripts/ispConfigHelper.sh'


class SambaApply(unittest.TestCase):
    def apply(self, files='0', printing='0', printershare='1', enabled='1',
              nqe=True, alias=True, nmbd=False, samba=True, action='reload'):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            state = base / 'enabled'
            state.write_text(enabled)
            log = base / 'log'
            service = '#!/bin/sh\necho "${0##*/} $1" >> "$LOG"\n'
            for name, present in [('nqe', nqe), ('samba-nmbd', nmbd)]:
                if present:
                    path = base / name
                    path.write_text(service)
                    path.chmod(0o755)
            if samba:
                path = base / 'samba'
                if nqe and alias:
                    path.symlink_to(base / 'nqe')
                else:
                    path.write_text(service)
                    path.chmod(0o755)
            uci = base / 'uci'
            uci.write_text('''#!/bin/sh
[ "$1" = -q ] && shift
case "$1:$2" in
  get:samba.samba.filesharing) printf '%s' "$FILES" ;;
  get:printersharing.config.enabled) printf '%s' "$PRINTING" ;;
  get:samba.printers.enabled) printf '%s' "$PRINTERSHARE" ;;
  get:samba.samba.enabled) cat "$STATE" ;;
  set:samba.samba.enabled=0 | set:samba.samba.enabled=1)
    printf '%s' "${2##*=}" > "$STATE"
    echo "uci $*" >> "$LOG" ;;
  commit:samba) echo 'uci commit samba' >> "$LOG" ;;
  *) exit 1 ;;
esac
''')
            uci.chmod(0o755)
            source = SCRIPT.read_text().replace('/etc/init.d/', str(base) + '/')
            result = subprocess.run(
                ['sh', '-s', '--', 'samba', action], input=source, text=True, capture_output=True,
                env=dict(os.environ, PATH=f'{base}:{os.environ["PATH"]}',
                         STATE=str(state), LOG=str(log), FILES=files,
                         PRINTING=printing, PRINTERSHARE=printershare),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')
            return state.read_text(), log.read_text().splitlines() if log.exists() else []

    def test_no_file_or_printer_sharing_stops_both_service_names(self):
        enabled, actions = self.apply()
        self.assertEqual(enabled, '0')
        self.assertEqual(actions, ['uci set samba.samba.enabled=0', 'uci commit samba',
                                   'samba disable', 'samba stop', 'nqe disable', 'nqe stop'])

    def test_already_disabled_still_cleans_up_running_instances(self):
        enabled, actions = self.apply(enabled='0')
        self.assertEqual(enabled, '0')
        self.assertEqual(actions, ['samba disable', 'samba stop', 'nqe disable', 'nqe stop'])

    def test_file_sharing_reenables_canonical_boot_service(self):
        enabled, actions = self.apply(files='1', enabled='0')
        self.assertEqual(enabled, '1')
        self.assertEqual(actions, ['uci set samba.samba.enabled=1', 'uci commit samba',
                                   'samba disable', 'samba stop', 'nqe enable', 'nqe restart'])

    def test_smb_printer_sharing_keeps_nqe_active(self):
        for printershare in ('1', ''):
            with self.subTest(printershare=printershare):
                enabled, actions = self.apply(printing='1', printershare=printershare)
                self.assertEqual(enabled, '1')
                self.assertEqual(actions[-2:], ['nqe enable', 'nqe restart'])

    def test_printing_without_smb_share_does_not_need_nqe(self):
        enabled, actions = self.apply(printing='1', printershare='0')
        self.assertEqual(enabled, '0')
        self.assertEqual(actions[-2:], ['nqe disable', 'nqe stop'])

    def test_unknown_nqe_config_falls_back_without_creating_options(self):
        for options in ({'files': ''}, {'printing': ''}, {'enabled': ''}):
            with self.subTest(options=options):
                enabled, actions = self.apply(**options)
                self.assertEqual(enabled, options.get('enabled', '1'))
                self.assertEqual(actions, ['samba reload'])

    def test_classic_samba_preserves_native_reload_and_nmbd(self):
        for nmbd in (True, False):
            with self.subTest(nmbd=nmbd):
                enabled, actions = self.apply(nqe=False, nmbd=nmbd)
                self.assertEqual(enabled, '1')
                self.assertEqual(actions, ['samba reload'] + (['samba-nmbd reload'] if nmbd else []))

    def test_classic_samba_preserves_native_restart(self):
        _, actions = self.apply(nqe=False, nmbd=True, action='restart')
        self.assertEqual(actions, ['samba restart'])

    def test_unrelated_nqe_script_does_not_change_classic_samba(self):
        _, actions = self.apply(alias=False)
        self.assertEqual(actions, ['samba reload'])

    def test_firmware_without_samba_is_supported(self):
        _, actions = self.apply(nqe=False, samba=False)
        self.assertEqual(actions, [])

    def test_file_and_printer_gui_apply_both_use_helper(self):
        for name in ('uci_samba.ca', 'uci_printersharing.ca'):
            rule = (ROOT / 'usr/share/transformer/commitapply' / name).read_text()
            self.assertIn('/usr/share/transformer/scripts/ispConfigHelper.sh samba reload', rule)
            self.assertNotIn('/etc/init.d/samba ', rule)


if __name__ == '__main__':
    unittest.main()
