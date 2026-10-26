local json = require("dkjson")
local proxy = require("datamodel")
local readfile = require("web.content_helper").readfile
local post_helper = require("web.post_helper")
local ngx = ngx

local ram = tonumber(proxy.get("sys.mem.RAMUsed")[1].value or 0) or 0
local cpu_usage = proxy.get("sys.proc.CPUUsage")[1].value or "0"

local data = {
	cpuusage = cpu_usage .. "%" or "0",
	ram_used = math.floor(ram / 1024),
	uptime = post_helper.secondsToTime(readfile("/proc/uptime","number",floor)),
	connection = readfile("/proc/sys/net/netfilter/nf_conntrack_count"),
	system_time = os.date("%d/%m/%Y %Hh:%Mm:%Ss",os.time()),
	cpuload = readfile("/proc/loadavg","string"):sub(1,14),
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
