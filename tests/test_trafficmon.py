"""Check the legacy file format, slot rollover and migration from drifted rows."""
from pathlib import Path
import shutil
import subprocess
import unittest

LUA = shutil.which("luajit") or shutil.which("lua")
COLLECTOR = Path(__file__).resolve().parents[1] / "decompressed/traffic_mon/sbin/trafficmon.lua"


@unittest.skipUnless(LUA, "Lua required")
class TrafficMonitor(unittest.TestCase):
    def test_scheduler_migrates_and_replaces_old_slots(self):
        script = r'''
local now = os.time({year=2026, month=11, day=23, hour=9, min=9, sec=50})
local files, modified = {}, {}
local path = "/tmp/trafficmon/"
local old = now - 290
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
    if mode == "w" then
        return {write=function(_, data) files[name]=data; return true end, close=function() return true end}
    end
    local data = files[name]
    if not data then return end
    local iter = data:gmatch("([^\n]+)")
    return {read=function() return iter() end, lines=function() return iter end, close=function() end}
end
package.preload.lfs = function() return {
    attributes=function(name, key)
        if key=="mode" then return (files[name] or name==path) and "file" end
        return modified[name]
    end,
    lock_dir=function() return {free=function() end} end,
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
assert(files[path.."stats_cpu"]=="100\n21 08:55\n25 09:05\n3 09:19\n",files[path.."stats_cpu"])
assert(files[path.."eth4_rx_bytes"]=="1500\n100 08:55\n150 09:05\n",files[path.."eth4_rx_bytes"])
now=now+600
files[rx]="1750\n"
callback()
assert(files[path.."eth4_rx_bytes"]=="1750\n100 08:55\n150 09:05\n250 09:29\n")
now=now+86400
files[rx]="2000\n"
callback()
assert(files[path.."stats_cpu"]=="100\n3 09:29\n")
assert(files[path.."eth4_rx_bytes"]=="2000\n")
'''.replace("COLLECTOR_PATH", repr(str(COLLECTOR)))
        result = subprocess.run([LUA, "-"], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
