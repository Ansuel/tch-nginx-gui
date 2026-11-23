local json = require("dkjson")
local proxy = require("datamodel")
local readfile = require("web.content_helper").readfile
local post_helper = require("web.post_helper")
local resources = require("resource_usage")
local ngx = ngx

local function get_value(path)
	local result = proxy.get(path)
	return result and result[1] and result[1].value
end

local ram = tonumber(get_value("sys.mem.RAMUsed")) or 0
local cpu_usage = get_value("sys.proc.CPUUsage") or "0"
local memory = resources.memory() or {}
local internal, usb = resources.storage()
local first_usb = usb[1]
local more_usb = #usb > 1 and (" +" .. (#usb - 1)) or ""

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

-- Free space
local has_posix, posix = pcall(require, "tch.posix")
local function free_space(path)
	if has_posix then
		local ok, stat = pcall(posix.statvfs, path)
		if ok and type(stat) == "table" then
			local blocks = tonumber(stat.f_bavail)
			local size = tonumber(stat.f_frsize) or tonumber(stat.f_bsize)
			if blocks and size and blocks >= 0 and size > 0 then
				local mib = blocks * size / 1048576
				return mib >= 1024 and string.format("%.2f GiB", mib / 1024) or string.format("%.2f MiB", mib)
			end
		end
	end
	return "-"
end

local function storage_data()
	local usb = {}
	local mounts = io.open("/proc/mounts", "r")
	if mounts then
		for line in mounts:lines() do
			local device, mount, options = line:match("^(%S+)%s+(%S+)%s+%S+%s+(%S+)")
			if device and device:match("^/dev/sd[a-z]%d*$") and mount:match("^/tmp/run/mountd/sd[a-z]%d*$") then
				local readonly = not ("," .. options .. ","):find(",rw,", 1, true)
				usb[#usb + 1] = device:match("[^/]+$") .. ": " .. free_space(mount) .. (readonly and " (RO)" or "")
			end
		end
		mounts:close()
	end
	local usb_text = "-"
	if #usb > 0 then
		usb_text = usb[1] .. (#usb > 1 and (" +" .. (#usb - 1)) or "")
	end
	return { storage_internal = free_space("/usr"), storage_usb = usb_text }
end

local mem = memory_data()
local storage = storage_data()

local data = {
	cpuusage = cpu_usage .. "%",
	ram_used = math.floor(ram / 1024),
	uptime = post_helper.secondsToTime(readfile("/proc/uptime","number",floor)),
	connection = readfile("/proc/sys/net/netfilter/nf_conntrack_count"),
	system_time = os.date("%d/%m/%Y %Hh:%Mm:%Ss",os.time()),
	cpuload = readfile("/proc/loadavg","string"):sub(1,14),
	mem_total = resources.format_mib(memory.total),
	mem_used = resources.format_mib(memory.used),
	mem_free = resources.format_mib(memory.free),
	mem_available = resources.format_mib(memory.available),
	mem_cache = resources.format_mib(memory.cache),
	mem_used_mib = resources.format_mib(memory.used, true),
	mem_free_mib = resources.format_mib(memory.free, true),
	mem_available_mib = resources.format_mib(memory.available, true),
	mem_cache_mib = resources.format_mib(memory.cache, true),
	mem_pct = memory.total and string.format("%.1f%%", memory.used * 100 / memory.total) or "-",
	storage_internal = resources.format_storage(internal.available),
	storage_usb = first_usb and (first_usb.device .. " (" .. resources.format_storage(first_usb.available) .. ")" .. more_usb) or "-",
	storage_internal_capacity = resources.format_capacity(internal),
	storage_usb_capacity = first_usb and (resources.format_capacity(first_usb) .. more_usb) or "-",
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
