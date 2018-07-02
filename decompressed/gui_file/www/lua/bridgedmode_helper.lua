local require, ipairs, print = require, ipairs, print
local format = string.format
local proxy = require("datamodel")

local M = {}

local wansensing_state = proxy.get("uci.wansensing.global.enable")
local wan_proto = proxy.get("uci.network.interface.@wan.proto")
local wan_mode = proxy.get("uci.network.config.wan_mode")

function M.isBridgedMode()
    if ( wansensing_state and ( wansensing_state[1].value == "1" ) ) 
		and not ( wan_mode and ( wan_mode[1].value == "bridge" ) ) then
        return false
    else
        return true
    end
end

function M.configBridgedMode()
    local success = false
	local ifnames = 'eth0 eth1 eth2 eth3 eth5 ptm0.835'
	
    success = proxy.set({
        ["uci.wansensing.global.enable"] = '0',
		["uci.network.interface.@wan.enabled"] = '0',
		["uci.network.interface.@wan.auto"] = '0',
		["uci.network.interface.@wan6.enabled"] = '0',
		["uci.network.interface.@wwan.enabled"] = '0',
		["uci.wireless.wifi-device.@radio_2G.state"] = '0',
		["uci.wireless.wifi-device.@radio_5G.state"] = '0',
		["uci.mmpbx.mmpbx.@global.enabled"] = '0',
        ["uci.dhcp.dhcp.@lan.ignore"] = '1',
		["uci.cwmpd.cwmpd_config.state"] = '0',
		["uci.mobiled.device_defaults.enabled"] = '0',
		["uci.network.interface.@lan.ifname"] = ifnames,
		["uci.network.config.wan_mode"] = 'bridge',
    })
	
    success = success and proxy.apply()
    return success
end

function M.disableBridgedMode()
    local success = false
	local ifnames = 'eth0 eth1 eth2 eth3 eth5'
	
    success = proxy.set({
        ["uci.wansensing.global.enable"] = '1',
		["uci.network.interface.@wan.enabled"] = '1',
		["uci.network.interface.@wan.auto"] = '1',
		["uci.network.interface.@wan6.enabled"] = '1',
		["uci.network.interface.@wwan.enabled"] = '1',
		["uci.wireless.wifi-device.@radio_2G.state"] = '1',
		["uci.wireless.wifi-device.@radio_5G.state"] = '1',
		["uci.mmpbx.mmpbx.@global.enabled"] = '1',
        ["uci.dhcp.dhcp.@lan.ignore"] = '0',
		["uci.cwmpd.cwmpd_config.state"] = '1',
		["uci.mobiled.device_defaults.enabled"] = '1',
		["uci.network.interface.@lan.ifname"] = ifnames,
		["uci.network.config.wan_mode"] = wan_proto[1].value or "Unknown",
    })

    success = success and proxy.apply()
    return success
end

return M
