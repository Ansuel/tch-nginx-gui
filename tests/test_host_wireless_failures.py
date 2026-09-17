"""Execute the affected Lua paths with failed/recovered backend responses."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('lua')


def source(path):
    return (ROOT / path).read_text()


@unittest.skipUnless(LUA, 'Lua interpreter required')
class HostWirelessFailures(unittest.TestCase):
    def run_lua(self, script):
        result = subprocess.run([LUA, '-'], input=script, text=True,
                                capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_host_cache_failure_and_recovery(self):
        for name in ('rpc.hosts.map', 'sys.hosts.map'):
            with self.subTest(mapping=name):
                text = source('usr/share/transformer/mappings/rpc/' + name)
                start = text.index('local function updateLanCache()')
                end = text.index('\nend', start) + len('\nend')
                self.run_lua('''
local hostsCache, lanInterfacesCache, response
local conn = {call = function(_, object, method, args)
  assert(object == 'hostmanager.device' and method == 'get')
  return response
end}
local nwcommon = {findLanWanInterfaces = function() return {'br-lan'} end}
''' + text[start:end] + '''
-- Cold failure remains an error, rather than a misleading empty host list.
local ok, err = pcall(updateLanCache)
assert(not ok and err:find('retrieving hosts failed', 1, true))
local first = {{['mac-address'] = '00:11:22:33:44:55'}}
response = first
updateLanCache()
assert(hostsCache == first)
response = nil
for i = 1, 3 do
  updateLanCache()
  assert(hostsCache == first)
end
response = {{['mac-address'] = '00:11:22:33:44:66'}}
updateLanCache()
assert(hostsCache == response and hostsCache ~= first)
-- An empty successful response must remove old hosts.
response = {}
updateLanCache()
assert(hostsCache == response and next(hostsCache) == nil)
''')

    def test_wireless_backend_failures_stop_before_settings(self):
        text = source('www/docroot/modals/wireless-modal.lp')
        block = text[text.index('local radios = {}'):text.index('local wls = {}')]
        self.run_lua('''
local radioResponse, apResponse, ssidResponse
local writes, exitCode, apCalls = 0, nil, 0
local match, getradio, curradio = string.match, nil, 'radio_2G'
local unpack = table.unpack or unpack
local proxy = {
  getPN = function(path)
    if path == 'rpc.wireless.radio.' then return radioResponse end
    apCalls = apCalls + 1
    return apResponse
  end,
  get = function() return ssidResponse end,
  set = function() writes = writes + 1 end
}
local ngx = {ERR = 3, HTTP_SERVICE_UNAVAILABLE = 503,
  log = function() end, exit = function(code) exitCode = code end}
local ajax_helper = {handleAjaxQuery = function() end}
local function render()
''' + block + '''
  return 'ready'
end
local radio = {{path = 'rpc.wireless.radio.@radio_2G.'}}
local ap = {{path = 'rpc.wireless.ap.@ap0.'}}
for _, empty in ipairs({false, true}) do
  radioResponse = empty and {} or nil
  apCalls, exitCode = 0, nil
  assert(render() == nil and exitCode == 503 and apCalls == 0)
  radioResponse, apResponse = radio, empty and {} or nil
  exitCode = nil
  assert(render() == nil and exitCode == 503)
end
radioResponse, apResponse, ssidResponse = radio, ap, nil
exitCode = nil
assert(render() == nil and exitCode == 503)
ssidResponse = {{path = 'rpc.wireless.ap.@ap0.ssid', value = 'wl0'}}
exitCode = nil
assert(render() == 'ready' and exitCode == nil)
assert(writes == 0)
''')

    def test_hostmap_missing_rssi(self):
        text = source('www/docroot/modals/hostmap-modal.lp')
        block = text[text.index('local function AJAX('):text.index('local args =')]
        self.run_lua('''
local response, output
local format = string.format
string.untaint = function(s) return s end
local proxy = {get = function() return response end}
local ch = {getExactContent = function(content)
  content.Speed, content.State = '100', '1'
end}
local T = function(s) return s end
local print = function(parts) output = table.concat(parts) end
''' + block + '''
local function check(value, expected)
  response = value
  AJAX('ap0', 'sys.hosts.host.1', '00:11:22:33:44:55')
  assert(output:find('"RSSI":"' .. expected .. '"', 1, true), output)
end
check(nil, '-100')
check({}, '-100')
check({{}}, '-100')
check({{value = '0'}}, '-100')
check({{value = '-47'}}, '-47')
''')


if __name__ == '__main__':
    unittest.main()
