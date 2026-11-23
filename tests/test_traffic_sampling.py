"""Exercise traffic samples, counter resets, old firmware and real graph callbacks."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
HISTORY = ROOT / 'decompressed/traffic_mon/usr/lib/lua/traffic_history.lua'
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
package.preload.traffic_history = function() return dofile(HISTORY_PATH) end
local function counters(interface, rx, tx)
    return interface .. ': ' .. rx .. ' 1 2 3 4 5 6 7 ' .. tx .. ' 9 10 11 12 13 14 15\n'
end
'''.replace('NETRATE_PATH', repr(str(GUI / 'usr/lib/lua/netrate.lua'))).replace('HISTORY_PATH', repr(str(HISTORY)))
        result = subprocess.run([LUA, '-'], input=setup + body,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_resources_support_legacy_meminfo_and_skip_unmounted_usb(self):
        self.run_lua(r'''
local resources = dofile(RESOURCE_PATH)
files['/proc/meminfo'] = 'MemTotal: 1000 kB\nMemFree: 200 kB\nMemAvailable: 450 kB\n' ..
    'Buffers: 10 kB\nCached: 100 kB\nSReclaimable: 20 kB\nShmem: 30 kB'
local memory = assert(resources.memory())
assert(memory.available == 450 and memory.used == 550 and memory.cache == 90)
files['/proc/meminfo'] = files['/proc/meminfo']:gsub('MemAvailable: 450 kB\n', '')
memory = assert(resources.memory())
assert(memory.available == 300 and memory.used == 700)
files['/proc/meminfo'] = 'MemTotal: 0 kB'
assert(resources.memory() == nil)
files['/proc/stat'] = 'cpu 10 2 4 60 3 1 2 5 8 1\ncpu0 1 1 1 1'
local cpu = assert(resources.cpu())
assert(cpu.total == 87 and cpu.idle == 63)
files['/proc/stat'] = 'cpu 10 2 4 60'
cpu = assert(resources.cpu())
assert(cpu.total == 76 and cpu.idle == 60)
files['/proc/mounts'] = '/dev/sda1 /unrelated ext4 rw 0 0\n' ..
    '/dev/sdb1 /tmp/run/mountd/sdb1 ext4 rw 0 0\n/dev/sdc /tmp/run/mountd/sdc ext4 rw 0 0'
package.preload['tch.posix'] = function()
    return {statvfs = function(path)
        assert(path == '/usr' or path == '/tmp/run/mountd/sdb1' or path == '/tmp/run/mountd/sdc')
        if path == '/tmp/run/mountd/sdc' then error('device removed') end
        return {f_bavail = 512, f_blocks = 2048, f_frsize = 0, f_bsize = 4096}
    end}
end
local internal, usb = resources.storage()
assert(resources.format_capacity(internal) == '2.0/8.0 MiB')
assert(resources.format_storage(internal.available) == '2.0 MiB')
assert(#usb == 2 and usb[1].device == 'sdb1' and usb[2].device == 'sdc')
assert(resources.format_capacity(usb[2]) == '-')
assert(resources.format_capacity({available = 536870912, total = 2147483648}) == '0.50/2.00 GiB')
assert(resources.format_capacity({available = 0, total = 1048576}) == '0.0/1.0 MiB')
assert(opened == closed)
'''.replace('RESOURCE_PATH', repr(str(GUI / 'www/lua/resource_usage.lua'))))

    def test_proc_sample_reads_both_counters_and_closes_files(self):
        self.run_lua('''
files['/proc/uptime'] = '120.50 42.00'
files['/proc/net/dev'] = 'Inter-| Receive | Transmit\\n' .. counters('eth4.835', '4294967297', '9876543210')
local sample = assert(netrate.sample('eth4.835'))
assert(sample.time == 120.5 and sample.rx == 4294967297 and sample.tx == 9876543210)
assert(opened == 2 and opened == closed)
''')

    def test_resource_history_coalesces_requests_and_keeps_a_bounded_window(self):
        self.run_lua('''
local now, calls, interface = 100, 0, 'eth4'
netrate.sample = function(device)
    assert(device == 'br-lan')
    return {time = now, rx = now * 40, tx = now * 30}
end
package.preload.lfs = function() return {attributes = function() end} end
package.preload.internethelper = function() return {sampleWanTraffic = function()
    calls = calls + 1
    if interface then return {time = now, rx = now * 20, tx = now * 10}, nil, interface end
end} end
local resources = dofile(RESOURCE_PATH)
resources.cpu = function() return {total = now * 10, idle = now * 8} end
resources.memory = function() return {used = 100, total = 200} end
local first = resources.history(now)
assert(first.replace and #first.samples == 1)
assert(first.samples[1].ram == 50 and first.samples[1].cpu == nil and first.samples[1].rx == nil)
now = 105
local same = resources.history(now, 100)
assert(not same.replace and #same.samples == 0 and calls == 1)
now = 110
local next = resources.history(now, 100)
assert(not next.replace and #next.samples == 1)
assert(next.samples[1].cpu == 20 and next.samples[1].rx == 20 and next.samples[1].tx == 10)
assert(next.samples[1].lan and next.samples[1].lan_rx == 40 and next.samples[1].lan_tx == 30)
assert(#resources.history(now).samples == 2 and calls == 2)
now, interface = 120, 'usb0'
assert(resources.history(now, 110).samples[1].rx == nil)
now, interface = 130, nil
local lan_only = resources.history(now, 120).samples[1]
assert(lan_only.interface == nil and lan_only.lan_rx == 40)
now, interface = 170, 'eth4'
local resumed = resources.history(now, 130).samples[1]
assert(resumed.cpu == nil and resumed.rx == nil and resumed.interface == 'eth4')
for tick = 180, 780, 10 do
    now = tick
    resources.history(now)
end
local retained = resources.history(now, 170)
assert(retained.replace and #retained.samples == 60 and retained.samples[1].time == 190)
now = 50
assert(#resources.history(now).samples == 1 and resources.history(now).samples[1].rx == nil)
now = 52
assert(#resources.history(now, 50, 3).samples == 0)
now = 53
local live = resources.history(now, 50, 3).samples
assert(#live == 1 and live[1].time == 53 and live[1].lan_rx == 40)
now = 56
assert(#resources.history(now, 53).samples == 0)
now = 57
assert(#resources.history(now, 53, 2).samples == 1)
now = 58
assert(#resources.history(now, 57, 2).samples == 0)
now = 59
assert(#resources.history(now, 57, 2).samples == 1)
'''.replace('RESOURCE_PATH', repr(str(GUI / 'www/lua/resource_usage.lua'))))

    def test_trafficmon_import_anchors_timestamps_and_rejects_long_wan_intervals(self):
        self.run_lua(r'''
local now = os.time({year = 2026, month = 11, day = 22, hour = 0, min = 15, sec = 30})
local path = '/tmp/trafficmon/'
local updated = now - 30
package.preload.lfs = function() return {attributes = function(file)
    if files[file] then return updated end
end} end
files[path .. 'stats_cpu'] = '100\n20 23:55\n99 00:04\n25 00:05\n99 00:14\n30 00:15\n99 20:00'
files[path .. 'stats_mem'] = '1000 \n400  00:05\n900  00:14\n300  00:15'
files[path .. 'eth4_rx_bytes'] = '99999999\n1 23:35\n4000 23:55\n123456 00:04\n6000 00:05\n123456 00:14\n12000 00:15'
files[path .. 'eth4_tx_bytes'] = '99999999\n1 23:35\n4000 23:55\n123456 00:04\n3000 00:05\n123456 00:14\n6000 00:15'
files[path .. 'br-lan_rx_bytes'] = '100000\n3000 23:55\n18000 00:05'
files[path .. 'br-lan_tx_bytes'] = '100000\n3000 23:55\n24000 00:05'
netrate.sample = function(device)
    assert(device == 'br-lan')
    return {time = 10, rx = 100, tx = 100}
end
package.preload.internethelper = function() return {sampleWanTraffic = function()
    return {time = 10, rx = 100, tx = 100}, nil, 'eth4'
end} end
local resources = dofile(RESOURCE_PATH)
local points = resources.history(now).samples
assert(#points == 4 and points[1].time == updated - 1200 and points[1].rx == nil)
assert(points[2].historical and points[2].interface == 'eth4' and points[2].rx == 10 and points[2].tx == 5)
assert(points[2].lan and points[2].lan_rx == 30 and points[2].lan_tx == 40)
assert(points[3].cpu == 30 and points[3].ram == 70 and points[3].rx == 20)
assert(#resources.history(now + 3600).samples == 1)
assert(opened == closed)
'''.replace('RESOURCE_PATH', repr(str(GUI / 'www/lua/resource_usage.lua'))))

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
package.preload.internethelper = function() return {sampleWanTraffic = function()
  return {time = 20, rx = 2000, tx = 5000}, nil, 'usb0'
end} end
args = {source = 'wan', interface = 'ptm0', oldrx = '1000', oldtx = '3000', oldtime = '10'}
request()
assert(output.valid and output.interface == 'usb0' and output.reason == 'interface_changed')
assert(output.rx_bytes_per_second == nil)
args.interface = 'usb0'
request()
assert(output.rx_bytes_per_second == 100 and output.tx_bytes_per_second == 200)
assert(opened == closed)
'''.replace('ENDPOINT_PATH', repr(str(GUI / 'www/docroot/ajax/traffic_graph.lua'))))

    def test_samples_bridge_port_and_only_uses_phone_when_selected(self):
        self.run_lua('''
local wan = 'uci.network.interface.@wan.'
local phone = 'uci.network.interface.@modgui_phone.'
local rpc = 'rpc.network.interface.@'
local values = {
  [wan .. 'proto'] = 'dhcp',
  [wan .. 'ifname'] = 'ptm0.835',
  [rpc .. 'wan.ifname'] = 'ptm0.835',
  [rpc .. 'wan.up'] = '1',
}
package.preload.datamodel = function() return {
  get = function(path)
    if values[path] then return {{value = values[path]}} end
  end,
  getPN = function(path)
    assert(path == 'uci.ethernet.port.')
    return {{path = path .. '@eth4.'}}
  end,
} end
package.path = LUA_PATH .. ';' .. package.path
local internet = require('internethelper')
files['/proc/uptime'] = '10.5 0'
files['/proc/net/dev'] = counters('ptm0.835', '1000', '2000')
  .. counters('eth4', '3000', '4000') .. counters('usb0', '5000', '6000')
local function check(device, rx)
  local sample, reason, source = internet.sampleWanTraffic()
  assert(sample and source == device and sample.rx == rx, reason or source)
end
check('ptm0.835', 1000)
values[rpc .. 'wan.up'] = '0'
assert(internet.sampleWanTraffic() == nil)
values[wan .. 'ifname'] = 'br-lan'
values['uci.network.config.wan_mode'] = 'pppoe'
values['uci.network.interface.@lan.ifname'] = 'eth0 eth4'
values['uci.ethernet.port.@eth4.wan'] = '1'
check('eth4', 3000)
values[phone .. 'defaultroute'] = '0'
values[rpc .. 'modgui_phone.up'] = '1'
values[rpc .. 'modgui_phone.ifname'] = 'usb0'
check('eth4', 3000)
values[phone .. 'defaultroute'] = '1'
local routeDevice = 'eth4'
local routeClosed = 0
io.popen = function(command)
  assert(command == 'ip -4 route show table 29995 default 2>/dev/null')
  return {
    read = function() return 'default via 192.0.2.1 dev ' .. routeDevice end,
    close = function() routeClosed = routeClosed + 1 end,
  }
end
check('eth4', 3000)
routeDevice = 'usb0'
check('usb0', 5000)
values[rpc .. 'modgui_phone.up'] = '0'
check('eth4', 3000)
values['uci.ethernet.port.@eth4.wan'] = '0'
assert(internet.sampleWanTraffic() == nil)
assert(routeClosed == 2)
assert(opened == closed)
'''.replace('LUA_PATH', repr(str(GUI / 'www/lua/?.lua'))))

    @unittest.skipUnless(shutil.which('node'), 'Node.js required')
    def test_real_graph_callback(self):
        result = subprocess.run(['node', 'tests/test_traffic_graph.js'], cwd=ROOT,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
