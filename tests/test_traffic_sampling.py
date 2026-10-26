"""Exercise traffic samples, counter resets, old firmware and real graph callbacks."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
LUA = shutil.which('luajit') or shutil.which('lua')


@unittest.skipUnless(LUA, 'Lua interpreter required')
class TrafficSampling(unittest.TestCase):
    def run_lua(self, body):
        setup = r'''
local files, opened, closed, requests = {}, 0, 0, {}
local tainted = {}
string.untaint = function(value) return tainted[value] or value end
local function fileOpen(path)
    requests[#requests + 1] = path
    local content = files[path]
    if content == nil then return nil end
    opened = opened + 1
    return {
        read = function() return content:match('([^\n]*)') end,
        lines = function() return (content .. '\n'):gmatch('([^\n]*)\n') end,
        close = function() closed = closed + 1 end,
    }
end
io.open = fileOpen
io.popen = function() error('unexpected subprocess') end
os.execute = function() error('unexpected subprocess') end
local netrate = dofile(NETRATE_PATH)
package.preload.netrate = function() return netrate end
local function counters(interface, rx, tx)
    return interface .. ': ' .. rx .. ' 1 2 3 4 5 6 7 ' .. tx .. ' 9 10 11 12 13 14 15\n'
end
'''.replace('NETRATE_PATH', repr(str(GUI / 'usr/lib/lua/netrate.lua')))
        result = subprocess.run([LUA, '-'], input=setup + body,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_proc_sample_reads_both_counters_and_closes_files(self):
        self.run_lua('''
files['/proc/uptime'] = '120.50 42.00'
files['/proc/net/dev'] = 'Inter-| Receive | Transmit\\n' .. counters('eth4.835', '4294967297', '9876543210')
local sample = assert(netrate.sample('eth4.835'))
assert(sample.time == 120.5 and sample.rx == 4294967297 and sample.tx == 9876543210)
assert(opened == 2 and opened == closed)
''')

    def test_sysfs_fast_path_and_missing_interfaces(self):
        self.run_lua('''
files['/proc/uptime'] = '120.00 42.00'
files['/sys/class/net/ptm0/statistics/rx_bytes'] = '1000'
files['/sys/class/net/ptm0/statistics/tx_bytes'] = '2000'
local sample = assert(netrate.sample('ptm0'))
assert(sample.rx == 1000 and sample.tx == 2000)
assert(#requests == 3) -- uptime and two counters, without scanning proc
files['/proc/net/dev'] = counters('ptm0', '9999', '9999')
assert(netrate.sample('ptm0').rx == 1000)
files['/proc/net/dev'] = nil
files['/sys/class/net/ptm0/statistics/rx_bytes'] = nil
local missing, reason = netrate.sample('ptm0')
assert(not missing and reason == 'interface_unavailable')
files['/proc/net/dev'] = counters('eth0', '1000', '2000')
missing, reason = netrate.sample('ptm0')
assert(not missing and reason == 'interface_unavailable')
files['/proc/net/dev'] = 'ptm0: broken counters'
assert(netrate.sample('ptm0') == nil)
files['/proc/uptime'] = nil
missing, reason = netrate.sample('ptm0')
assert(not missing and reason == 'clock_unavailable')
assert(opened == closed)
''')

    def test_firmware_tainted_interface_is_unwrapped_then_validated(self):
        self.run_lua('''
local interface = newproxy and newproxy() or {}
tainted[interface] = 'eth4'
files['/proc/uptime'] = '120.00 42.00'
files['/proc/net/dev'] = counters('eth4', '1000', '2000')
local sample = assert(netrate.sample(interface))
assert(sample.rx == 1000 and sample.tx == 2000)
tainted[interface] = '../etc/passwd'
local count = #requests
local value, reason = netrate.sample(interface)
assert(not value and reason == 'invalid_interface' and #requests == count)
assert(opened == closed)
''')

    def test_taint_support_can_be_loaded_after_the_sampler(self):
        self.run_lua('''
local clean = string.untaint
string.untaint = nil
local late = dofile(NETRATE_PATH)
string.untaint = clean
local interface = newproxy and newproxy() or {}
tainted[interface] = 'eth4'
files['/proc/uptime'] = '120.00 42.00'
files['/proc/net/dev'] = counters('eth4', '1000', '2000')
assert(late.sample(interface).rx == 1000)
'''.replace('NETRATE_PATH', repr(str(GUI / 'usr/lib/lua/netrate.lua'))))

    def test_invalid_interfaces_never_reach_the_filesystem(self):
        self.run_lua('''
for _, name in ipairs({'', '../etc/passwd', 'eth0/../../x', 'eth0;id', 'a b', string.rep('x', 16), {'eth0'}}) do
  local value, reason = netrate.sample(name)
  assert(not value and reason == 'invalid_interface')
end
assert(netrate.sample(nil) == nil)
assert(#requests == 0)
''')

    def test_rates_are_independent_per_browser_and_use_monotonic_time(self):
        self.run_lua('''
local current = {time = 30, rx = 10000, tx = 20000}
local first = {time = 20, rx = 9000, tx = 15000}
local second = {time = 10, rx = 8000, tx = 10000}
for i = 1, 3 do
  local a, b = assert(netrate.rate(first, current)), assert(netrate.rate(second, current))
  assert(a.rx == 100 and a.tx == 500 and b.rx == 100 and b.tx == 500)
end
assert(first.time == 20 and second.time == 10 and current.time == 30)
local idle = assert(netrate.rate(current, {time = 40, rx = 10000, tx = 20000}))
assert(idle.rx == 0 and idle.tx == 0)
''')

    def test_wraps_resets_missing_baselines_and_stale_samples(self):
        self.run_lua('''
local wrap = 4294967296
local rate = assert(netrate.rate({time = 10, rx = wrap - 100, tx = wrap - 200}, {time = 20, rx = 50, tx = 100}))
assert(rate.rx == 15 and rate.tx == 30)
local current = {time = 20, rx = 50, tx = 100}
local value, reason = netrate.rate({time = 10, rx = wrap + 100, tx = wrap + 200}, current)
assert(not value and reason == 'counter_reset')
value, reason = netrate.rate({time = 10, rx = 10000, tx = 20000}, current)
assert(not value and reason == 'counter_reset')
value, reason = netrate.rate({time = 20, rx = 0, tx = 0}, current)
assert(not value and reason == 'clock_reset')
value, reason = netrate.rate({time = 30, rx = 0, tx = 0}, current)
assert(not value and reason == 'clock_reset')
value, reason = netrate.rate({time = 10, rx = 0, tx = 0}, {time = 41, rx = 100, tx = 100})
assert(not value and reason == 'stale_sample')
value, reason = netrate.rate(nil, current)
assert(not value and reason == 'initial_sample')
for _, invalid in ipairs({'nan', 'inf', '-1', '9007199254740992', {}}) do
  assert(netrate.rate({time = 10, rx = invalid, tx = 0}, current) == nil)
end
''')

    def test_endpoint_rebases_without_losing_legacy_counter_fields(self):
        self.run_lua('''
local args, output = {}, nil
ngx = {req = {get_method = function() return 'POST' end, get_uri_args = function() return args end},
  header = {}, HTTP_OK = 200, say = function() end, exit = function() end}
package.preload.dkjson = function() return {encode = function(data) output = data; return true end} end
files['/proc/uptime'] = '20.0 0'
files['/proc/net/dev'] = counters('ptm0', '2000', '5000')
local function request()
  dofile(ENDPOINT_PATH)
  assert(ngx.header['Cache-Control'] == 'no-store')
  return output
end
args = {interface = 'ptm0', oldrx = '1000', oldtx = '3000', oldtime = '10'}
request()
assert(output.valid and output.rx_traffic == '2000' and output.tx_traffic == '5000')
assert(output.old_rx_traffic == '1000' and output.old_tx_traffic == '3000')
assert(output.rx_bytes_per_second == 100 and output.tx_bytes_per_second == 200)
args.oldtime = nil
request(); assert(output.valid and output.reason == 'initial_sample' and output.rx_bytes_per_second == nil)
args.oldtime, args.oldrx = '10', '90000'
request(); assert(output.valid and output.reason == 'counter_reset' and output.sample_time == 20)
args.interface = 'missing'
request(); assert(not output.valid and output.rx_traffic == nil)
args.interface = {'ptm0'}
request(); assert(not output.valid and output.reason == 'invalid_interface')
assert(opened == closed)
'''.replace('ENDPOINT_PATH', repr(str(GUI / 'www/docroot/ajax/traffic_graph.lua'))))

    def test_card_handles_disappearing_wan_and_embeds_initial_sample(self):
        self.run_lua('''
gettext = {textdomain = function() end}
T = function(value) return value end
local up, output = '1', {}
local function append(value)
  if type(value) == 'table' then for _, entry in ipairs(value) do append(entry) end
  else output[#output + 1] = tostring(value) end
end
ngx = {print = append}
package.preload.datamodel = function() return {get = function(path)
  if path:match('ifname$') then return {{value = 'ptm0'}} end
  return {{value = up}}
end} end
package.preload['web.ui_helper'] = function() return {createCardHeader = function(title) return title end} end
local function render()
  output = {}
  dofile(CARD_PATH)
  return table.concat(output)
end
assert(render() == '')
files['/proc/uptime'] = '10.5 0'
files['/proc/net/dev'] = counters('ptm0', '1000', '2000')
local html = render()
assert(html:find('WAN Traffic', 1, true) and html:find('traffic_sample_time', 1, true))
up = '0'
assert(render() == '')
assert(opened == closed)
'''.replace('CARD_PATH', repr(str(GUI / 'www/info-cards/004_graph.lp'))))

    @unittest.skipUnless(shutil.which('node'), 'Node.js required')
    def test_real_graph_callback(self):
        result = subprocess.run(['node', 'tests/test_traffic_graph.js'], cwd=ROOT,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
