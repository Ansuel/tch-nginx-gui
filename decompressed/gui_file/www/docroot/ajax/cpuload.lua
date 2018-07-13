-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local content_helper = require("web.content_helper")
local ngx = ngx

local cpuload

cpuload = content_helper.readfile("/proc/loadavg","string")
cpuload = string.sub(cpuload,1,14)

local data = {
	cpuload = cpuload,
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)