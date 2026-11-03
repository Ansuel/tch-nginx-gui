"""Test owned network configuration and both directions of IPv4 failover."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class SmartphoneUplinkTest(unittest.TestCase):
    def run_case(self, case):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/'runtime').mkdir()
            (Path(folder)/'config').touch()
            result = subprocess.run([LUA, str(ROOT/'tests/smartphone_uplink_fixture.lua'),
                                     str(ROOT), folder, case], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_hysteresis_and_recovery_in_both_modes(self): self.run_case('health')
    def test_apply_and_stop_preserve_wan_and_other_zone_members(self): self.run_case('apply')
    def test_failed_apply_restores_network_firewall_dns_and_mode(self): self.run_case('rollback')
    def test_mode_change_preserves_original_dns_and_metric(self): self.run_case('change')
    def test_pending_changes_and_foreign_interface_are_rejected(self): self.run_case('conflict')
    def test_reserved_rules_and_tables_are_not_overwritten(self): self.run_case('reserved')
    def test_monitor_switches_and_returns_to_preferred_line(self): self.run_case('monitor')
    def test_unplugged_phone_selects_wan_and_preserves_marked_policies(self): self.run_case('unplug')
    def test_invalid_mode_cannot_reach_shell_or_configuration(self): self.run_case('invalid')
    def test_control_lock_rejects_concurrent_actions_and_recovers_stale_pid(self): self.run_case('lock')
    def test_failed_apply_keeps_unrelated_concurrent_configuration(self): self.run_case('concurrent')


if __name__ == '__main__': unittest.main()
