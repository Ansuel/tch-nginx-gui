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
