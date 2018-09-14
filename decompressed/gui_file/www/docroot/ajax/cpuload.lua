-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ngx = ngx

local data = {
	cpuusage = proxy.get("sys.proc.CPUUsage")[1].value .. "%" or "0",
	ram_free = proxy.get("sys.mem.RAMFree")[1].value .. " kB" or "0",
	uptime = post_helper.secondsToTime(content_helper.readfile("/proc/uptime","number",floor)),
	connection = content_helper.readfile("/proc/sys/net/netfilter/nf_conntrack_count"),
	system_time = os.date("%F %T", os.time()),
	cpuload = content_helper.readfile("/proc/loadavg","string"):sub(1,14),
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)
