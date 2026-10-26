"""Run the LED service decision with mocked firmware configuration."""

from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'decompressed/gui_file/tmp/status-led-eventing.lua_new'
LUA = shutil.which('lua5.1') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua is required')
class StatusLedServices(unittest.TestCase):
    def check_status(self, network='{}', checks='{internet={check="1"}, iptv={check="1"}}',
                     services='{internet=true, iptv=false}', expected=True):
        source = SOURCE.read_text()
        decision = source[source.index('local function is_service_ok()'):
                          source.index('local function ledaction()')]
        harness = '''
local network = %s
local checks = %s
local services = %s
local ledcfg = 'ledfw'
local cursors = 0
local cursor = {}
function cursor:load() end
function cursor:get_all(config, section)
    if config == 'ledfw' then return checks end
    return network[section]
end
function cursor:get(config, section, option)
    if config == 'mmpbx' then return '0' end
    local value = checks and checks[section]
    return value and value[option]
end
function cursor:foreach() end
function cursor:close() cursors = cursors - 1 end
local uci = {cursor = function() cursors = cursors + 1; return cursor end}
''' % (network, checks, services)
        result = subprocess.run([LUA, '-'], input=harness + decision + '''
assert(is_service_ok() == %s, 'incorrect service status')
assert(cursors == 0, 'configuration cursor leaked')
''' % str(expected).lower(), capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_iptv_does_not_fail_bridge_or_routed_internet(self):
        self.check_status()

    def test_disabled_iptv_does_not_fail_status(self):
        for option in ('auto', 'enabled'):
            with self.subTest(option=option):
                self.check_status(network='{iptv={[".type"]="interface", %s="0"}}' % option)

    def test_configured_iptv_outage_is_reported(self):
        self.check_status(network='{iptv={[".type"]="interface"}}', expected=False)

    def test_configured_iptv_up_is_healthy(self):
        self.check_status(network='{iptv={[".type"]="interface"}}',
                          services='{internet=true, iptv=true}')

    def test_user_can_disable_check_for_configured_iptv(self):
        self.check_status(network='{iptv={[".type"]="interface"}}',
                          checks='{internet={check="1"}, iptv={check="0"}}')

    def test_configured_iptv_interface_name_is_respected(self):
        self.check_status(network='{tv={[".type"]="interface"}}',
                          checks='{iptv={check="1", itf="tv"}}', expected=False)

    def test_missing_led_settings_do_not_crash_or_hide_internet_failure(self):
        for checks in ('nil', '{}', '{iptv={check="1"}}'):
            with self.subTest(checks=checks):
                self.check_status(checks=checks)
                self.check_status(checks=checks, services='{internet=false, iptv=false}',
                                  expected=False)

    def test_disabled_voice_does_not_fail_status_or_leak_cursor(self):
        self.check_status(services='{internet=true, iptv=false, voip=false}')


if __name__ == '__main__':
    unittest.main()
