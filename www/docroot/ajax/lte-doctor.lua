-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local utils = require("web.lte-utils")

local setmetatable = setmetatable

local simInfo = utils.getContent("rpc.mobiled.device.@1.sim.sim_state")
local indicatorInfo = utils.getContent("rpc.mobiled.device.@1.leds.")
local networkInfo = utils.getContent("rpc.mobiled.device.@1.network.serving_system.network_desc")

local data = {
	indicator_info = indicatorInfo
}

if(networkInfo.network_desc == "") then
	networkInfo.network_desc = T"None"
end
data['network_info'] = networkInfo

setmetatable(simInfo, { __index = function() return "" end })
simInfo['status'] = utils.sim_state_map[simInfo['sim_state']]
data['sim_info'] = simInfo

local buffer = {}
local ret = json.encode (data, { indent = false, buffer = buffer })
if ret then
	utils.sendResponse(buffer)
end
utils.sendResponse("{}")
