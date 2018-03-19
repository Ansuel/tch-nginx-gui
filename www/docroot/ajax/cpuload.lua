-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local utils = require("web.lte-utils")
local content_helper = require("web.content_helper")

local cpuload

cpuload = content_helper.readfile("/proc/loadavg","string")
cpuload = string.sub(cpuload,1,14)

local data = {
	cpuload = cpuload,
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	utils.sendResponse(buffer)
end
utils.sendResponse("{}")
