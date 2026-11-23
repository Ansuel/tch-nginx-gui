"""Check the history rollover, legacy migration and graph timestamps."""
from pathlib import Path
import os
import shutil
import subprocess
import unittest

LUA = shutil.which("luajit") or shutil.which("lua")
PACKAGE = Path(__file__).resolve().parents[1] / "decompressed/traffic_mon"
COLLECTOR = PACKAGE / "sbin/trafficmon.lua"
HISTORY = PACKAGE / "usr/lib/lua/traffic_history.lua"


@unittest.skipUnless(LUA, "Lua required")
class TrafficMonitor(unittest.TestCase):
    def run_lua(self, script, tz="UTC"):
        setup = f'package.preload.traffic_history = function() return dofile({str(HISTORY)!r}) end\n'
        result = subprocess.run([LUA, "-"], input=setup + script, text=True,
                                capture_output=True, env={**os.environ, "TZ": tz})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_scheduler_migrates_and_expires_old_slots(self):
        self.run_lua(r'''
local now = os.time({year=2026, month=11, day=23, hour=9, min=9, sec=50})
local files, modified = {}, {}
local path = "/tmp/trafficmon/"
local old = now - 290
local first = old - 600
files[path.."stats_cpu"] = "100\n81 08:54\n21 08:55\n85 09:04\n25 09:05\n"
files[path.."eth4_rx_bytes"] = "1000\n180 08:54\n100 08:55\n150 09:05\n"
modified[path.."stats_cpu"], modified[path.."eth4_rx_bytes"] = old, old
files["/proc/meminfo"] = "MemTotal: 1000 kB\nMemAvailable: 450 kB\n"
local rx = "/sys/class/net/eth4/statistics/rx_bytes"
files[rx] = "1500\n"
local callback, delay
os.time = function() return now end
os.rename = function(a,b)
    files[b], modified[b], files[a] = files[a], now, nil
    return true
end
io.open = function(name, mode)
    if mode == "a+" then return {close=function() end} end
    if mode == "w" then
        return {write=function(_, data) files[name]=data; return true end, close=function() return true end}
    end
    local data = files[name]
    if not data then return end
    local iter = data:gmatch("([^\n]+)")
    return {read=function() return iter() end, lines=function() return iter end, close=function() end}
end
package.preload.lfs = function() return {
    lock=function() return true end,
    attributes=function(name, key)
        if key=="mode" then return (files[name] or name==path) and "file" end
        return modified[name]
    end,
    dir=function() local names={"eth4"}; return function() return table.remove(names) end end,
} end
package.preload["transformer.shared.processinfo"] = function() return {getCPUUsage=function() return 3 end} end
package.preload.uloop = function() return {
    init=function() end, run=function() end,
    timer=function(fn,ms) callback,delay=fn,ms; return {} end,
} end
dofile(COLLECTOR_PATH)
assert(delay==600000 and files[path.."eth4_rx_bytes"]:match("^1000"))
now=now+600
callback()
assert(delay==600000)
assert(files[path.."stats_cpu"]==("100\n21 %d\n25 %d\n3 %d\n"):format(first, old, now))
assert(files[path.."eth4_rx_bytes"]==("1500\n100 %d\n150 %d\n"):format(first, old))
now=now+600
files[rx]="1750\n"
callback()
assert(files[path.."eth4_rx_bytes"]==("1750\n100 %d\n150 %d\n250 %d\n"):format(first, old, now))
now=now+86400
files[rx]="2000\n"
callback()
assert(files[path.."stats_cpu"]==("100\n3 %d\n"):format(now))
assert(files[path.."eth4_rx_bytes"]=="2000\n")
'''.replace("COLLECTOR_PATH", repr(str(COLLECTOR))))


    def test_chart_orders_legacy_midnight_and_aligns_missing_traffic_samples(self):
        self.run_lua(r'''
local now = os.time({year=2026, month=11, day=23, hour=0, min=11, sec=0})
local files = {wan_rx_bytes = "40\n4 00:10\n2 23:50\n",
               wan_tx_bytes = "70\n5 00:00\n7 00:10\n",
               stats_cpu = "100\n8 00:10\n12 23:50\n10 00:00\n"}
package.preload.lfs = function() return {attributes=function() return now - 60 end} end
io.open = function(path)
    local iter = files[path:match("[^/]+$")]:gmatch("[^\n]+")
    return {read=iter, lines=function() return iter end, close=function() end}
end
local history = require("traffic_history")
local traffic = history.traffic_chart("wan", now)
assert(traffic.time == '"23:50","00:00","00:10"', traffic.time)
assert(traffic.rx == '2,null,4' and traffic.tx == 'null,5,7')
local cpu, times = history.read("stats_cpu", now)
local labels, data = history.chart(times, cpu)
assert(labels == traffic.time and data == "12,10,8")
''')

    def test_epoch_history_preserves_both_occurrences_of_repeated_dst_hour(self):
        self.run_lua(r'''
local first = 1792888200 -- 02:30 CEST
local second = first + 3600 -- 02:30 CET
local now = second + 60
assert(os.date("%H:%M", first) == "02:30" and os.date("%H:%M", second) == "02:30")
package.preload.lfs = function() return {attributes=function() return second end} end
io.open = function()
    local iter = ("100\n25 %d\n35 %d\n"):format(first, second):gmatch("[^\n]+")
    return {read=iter, lines=function() return iter end, close=function() end}
end
local history = require("traffic_history")
local cpu, times = history.read("stats_cpu", now)
assert(#times == 2 and times[1] == first and times[2] == second)
assert(cpu[first] == 25 and cpu[second] == 35)
''', tz="Europe/Rome")
