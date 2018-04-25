local require, ipairs, print = require, ipairs, print
local format = string.format
local proxy = require("datamodel")

local M = {}

local ppp_state = proxy.get("uci.network.interface.@wan.username")
local ppp_original = proxy.get("uci.env.var.ppp_realm_ipv4")
local ppp_mgmt = proxy.get("uci.env.var.ppp_mgmt")

if ppp_state then
    ppp_state = ppp_state[1].value
end

if ppp_original then
    ppp_original = ppp_original[1].value
end

if ppp_mgmt then
    ppp_mgmt = ppp_mgmt[1].value
end

function M.isVoiceMode()
    if ppp_state and ppp_mgmt and ( ppp_state == ppp_mgmt ) then
        return true
    else
        return false
    end
end

function M.configVoiceMode()
    local success = false
	local ifnames = 'eth0 eth1 eth2 eth3 eth5 ptm0.835'
	
    success = proxy.set({
        ["uci.network.interface.@wan.username"] = ppp_mgmt or "Unknown",
		["uci.dhcp.dhcp.@lan.ignore"] = '1',
		["uci.wireless.wifi-device.@radio_2G.state"] = '0',
		["uci.wireless.wifi-device.@radio_5G.state"] = '0',
		["uci.network.interface.@lan.ifname"] = ifnames,
		["uci.network.interface.@wan.ifname"] = 'ptm0.837',
		["uci.network.interface.@wan.password"] = 'alicenewag',
    })
	
    success = success and proxy.apply()
    return success
end

function M.disableVoiceMode()
    local success = false
	local ifnames = 'eth0 eth1 eth2 eth3 eth5 ptm0.835'
	
    success = proxy.set({
        ["uci.network.interface.@wan.username"] = ppp_original or "Unknown",
		["uci.wireless.wifi-device.@radio_2G.state"] = '1',
		["uci.wireless.wifi-device.@radio_5G.state"] = '1',
		["uci.dhcp.dhcp.@lan.ignore"] = '0',
		["uci.network.interface.@lan.ifname"] = ifnames,
		["uci.network.interface.@wan.ifname"] = 'ptm0.835',
		["uci.network.interface.@wan.password"] = 'alicenewag',
    })

    success = success and proxy.apply()
    return success
end

return M
