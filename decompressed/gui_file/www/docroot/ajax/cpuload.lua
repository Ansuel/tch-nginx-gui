local json = require("dkjson")
local proxy = require("datamodel")
local readfile = require("web.content_helper").readfile
local post_helper = require("web.post_helper")
local ngx = ngx

local ram = tonumber(proxy.get("sys.mem.RAMUsed")[1].value or 0) or 0
local cpu_usage = proxy.get("sys.proc.CPUUsage")[1].value or "0"

-- Memory from /proc/meminfo (read-only)
local function read_meminfo()
	local info = {}
	local f = io.open("/proc/meminfo", "r")
	if f then
		for line in f:lines() do
			local key, value = line:match("^(%w+):%s+(%d+)")
			if key then
				info[key] = tonumber(value)
			end
		end
		f:close()
	end
	return info
end

local function kb_to_mb(kb)
	return string.format("%.1f MB", kb / 1024)
end

local function memory_data()
	local m = read_meminfo()
	local total = m.MemTotal
	if not total or total <= 0 then
		return { mem_total = "-", mem_used = "-", mem_free = "-", mem_available = "-",
			mem_cache = "-", mem_pct = "-", mem_bar = "", mem_time = os.date("%H:%M:%S") }
	end
	local free = m.MemFree or 0
	local available = m.MemAvailable or (free + (m.Buffers or 0) + (m.Cached or 0))
	local used = total - available
	if used < 0 then used = 0 end
	local pct = used * 100 / total
	local filled = math.floor(pct / 10 + 0.5)
	if filled > 10 then filled = 10 end
	return {
		mem_total = kb_to_mb(total),
		mem_used = kb_to_mb(used),
		mem_free = kb_to_mb(free),
		mem_available = kb_to_mb(available),
		mem_cache = kb_to_mb((m.Buffers or 0) + (m.Cached or 0)),
		mem_pct = string.format("%.1f%%", pct),
		mem_time = os.date("%H:%M:%S"),
		mem_bar = string.rep("\226\150\136", filled) .. string.rep("\226\150\145", 10 - filled)
	}
end

local mem = memory_data()

local data = {
	cpuusage = cpu_usage .. "%" or "0",
	ram_used = math.floor(ram / 1024),
	uptime = post_helper.secondsToTime(readfile("/proc/uptime","number",floor)),
	connection = readfile("/proc/sys/net/netfilter/nf_conntrack_count"),
	system_time = os.date("%d/%m/%Y %Hh:%Mm:%Ss",os.time()),
	cpuload = readfile("/proc/loadavg","string"):sub(1,14),
	mem_total = mem.mem_total,
	mem_used = mem.mem_used,
	mem_free = mem.mem_free,
	mem_available = mem.mem_available,
	mem_cache = mem.mem_cache,
	mem_pct = mem.mem_pct,
	mem_bar = mem.mem_bar,
	mem_time = mem.mem_time,
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
