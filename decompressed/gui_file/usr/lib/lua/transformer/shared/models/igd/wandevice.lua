local require = require

local M = {}

local activedevice = require 'transformer.shared.models.igd.activedevice'

function M.getDevtypeAndName(wandevice_key)
	local devtype, devname = wandevice_key:match("^([^|]*)|(.*)$")
	devname = devname:match("^([^|]+)")
	if devtype == "ACTIVE" then
		devtype, devname = activedevice.getDevtypeAndName(devname)
	end
	return devtype, devname
end

return M
