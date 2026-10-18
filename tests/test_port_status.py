"""Exercise dashboard port snapshots, firmware fallbacks and request isolation."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua required')
class PortStatus(unittest.TestCase):
    def run_endpoint(self, scenario):
        helper = (ROOT / 'usr/lib/lua/web/content_helper.lua').read_text()
        start = helper.index('local function convertResultToObject(')
        end = helper.index('\nend', start) + len('\nend')
        script = f"package.path = {str(ROOT / 'www/lua/?.lua')!r} .. ';' .. package.path\n"
        script += helper[start:end] + r'''
local rows, emitted, calls, batch_sizes = {}, nil, 0, {}
local ethernet = {}
local values = {['uci.env.var.qtn_eth_mac'] = '', ['uci.ethernet.port.@eth4.wan'] = '1',
  ['uci.ethernet.port.@eth3.wan'] = '1'}
local names = {{path = 'rpc.wireless.radio.@radio_2G.'},
               {path = 'rpc.wireless.radio.@radio_5G.'}}
local function addPort(name, status, speed, mode)
  for param, value in pairs({status = status, speed = speed, mode = mode}) do
    ethernet[#ethernet+1] = {path = 'sys.eth.port.@' .. name .. '.', param = param, value = value}
  end
end
local function addRadio(name, status, speed, mode, band)
  for param, value in pairs({admin_state = status, phy_rate = speed,
      standard = mode, supported_frequency_bands = band}) do
    values['rpc.wireless.radio.@' .. name .. '.' .. param] = value
  end
end
addPort('eth0', 'up', '100', '100BASE-T')
addPort('eth3', 'down', '0', '0BASE-T')
addPort('eth4', 'up', '1000', '1000BASE-T')
addRadio('radio_2G', '1', '65000', 'bgn', '2.4GHz')
addRadio('radio_5G', '1', '1734000', 'anac', '5GHz')
package.preload.datamodel = function() return {
  get = function(...)
    calls = calls + 1
    local paths = {...}
    batch_sizes[#batch_sizes+1] = #paths
    if paths[1] == 'sys.eth.port.' then return ethernet end
    local result = {}
    for i = #paths, 1, -1 do
      local path = paths[i]
      if values[path] == nil then return nil, 'unsupported path' end
      local base, param = path:match('^(.*%.)([^%.]+)$')
      result[#result+1] = {path = base, param = param, value = values[path]}
    end
    return result
  end,
  getPN = function(path, nextlevel)
    assert(path == 'rpc.wireless.radio.' and nextlevel)
    calls = calls + 1
    return names
  end,
} end
package.preload['web.content_helper'] = function() return {
  convertResultToObject = convertResultToObject,
} end
package.preload['web.ui_helper'] = function() return {
  createSimpleLight = function(value) return 'light:' .. value end,
  createTable = function(columns, data, options)
    assert(options.canEdit == false and options.canAdd == false and options.canDelete == false)
    rows = data
    return {'<table>', {'ports'}, '</table>'}
  end,
} end
package.preload.dkjson = function() return {encode = function(data, options)
  emitted = data
  options.buffer[1] = '{}'
  return true
end} end
gettext = {textdomain = function() end}
T = function(s) return s end
ngx = {HTTP_OK = 200, say = function() end, exit = function(status) assert(status == 200) end}
local function row(name)
  for _, value in ipairs(rows) do if value[1] == name then return value end end
end
'''
        script += f'local endpoint = assert(loadfile({str(ROOT / "www/docroot/ajax/port_status.lua")!r}))\n'
        result = subprocess.run([LUA, '-'], input=script + scenario,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_supported_snapshot_uses_three_calls_and_preserves_labels(self):
        self.run_endpoint(r'''
endpoint()
assert(calls == 3 and batch_sizes[2] == 10)
assert(#rows == 5 and row('WAN')[3] == '1 Gbps')
assert(row('LAN - 1')[3] == '100 Mbps')
assert(row('Wi-Fi 2.4GHz')[3] == '65 Mbps' and row('Wi-Fi 2.4GHz')[4] == 'b/g/n')
assert(row('Wi-Fi 5GHz')[3] == '1734 Mbps' and row('Wi-Fi 5GHz')[4] == 'a/n/ac')
assert(emitted.port_table == '<table>ports</table>')
''')

    def test_eth3_fallback_quantenna_and_additional_radio(self):
        self.run_endpoint(r'''
for i = #ethernet, 1, -1 do
  if ethernet[i].path == 'sys.eth.port.@eth4.' then table.remove(ethernet, i) end
end
addPort('eth5', 'up', '1000', '1000BASE-T')
values['uci.env.var.qtn_eth_mac'] = 'present'
names[#names+1] = {path = 'rpc.wireless.radio.@radio_6G.'}
addRadio('radio_6G', '1', '2400000', 'ax', '6GHz')
endpoint()
assert(calls == 3 and #rows == 5)
assert(row('WAN')[4] == '0BASE-T' and not row('LAN - 6'))
assert(row('Wi-Fi 6GHz')[4] == 'ax' and row('Wi-Fi 6GHz')[3] == '2400 Mbps')
''')

    def test_missing_optional_paths_do_not_discard_supported_radios(self):
        self.run_endpoint(r'''
values['uci.env.var.qtn_eth_mac'] = nil
values['rpc.wireless.radio.@radio_5G.supported_frequency_bands'] = nil
values['rpc.wireless.radio.@radio_5G.phy_rate'] = nil
endpoint()
assert(#rows == 5 and row('WAN'))
assert(row('Wi-Fi 2.4GHz')[3] == '65 Mbps')
assert(row('Wi-Fi radio_5G')[3] == '' and row('Wi-Fi radio_5G')[4] == 'a/n/ac')
assert(not emitted.port_table:find('Exact path not found', 1, true))
''')

    def test_empty_or_unsupported_hardware_and_malformed_discovery(self):
        self.run_endpoint(r'''
ethernet, names = nil, nil
endpoint()
assert(#rows == 0)
names = {{path = 'rpc.wireless.radio.@bad.extra.'}, {path = 'other.@radio.'}}
endpoint()
assert(#rows == 0)
''')

    def test_each_request_observes_current_configuration_and_radio_state(self):
        self.run_endpoint(r'''
endpoint()
assert(row('WAN'))
values['uci.ethernet.port.@eth4.wan'] = '0'
values['rpc.wireless.radio.@radio_5G.admin_state'] = '0'
endpoint()
assert(not row('WAN') and row('LAN - 5'))
assert(row('Wi-Fi 5GHz')[2] == 'light:0')
assert(row('Wi-Fi 5GHz')[3] == '' and row('Wi-Fi 5GHz')[4] == '')
assert(calls == 6)
''')


if __name__ == '__main__':
    unittest.main()
