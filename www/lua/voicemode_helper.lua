local require, ipairs, print = require, ipairs, print
local format = string.format
local proxy = require("datamodel")

local M = {}

local ppp_state, error = proxy.get("uci.network.interface.@wan.username")
local ppp_original, error = proxy.get("uci.env.var.ppp_realm_ipv4")
local ppp_mgmt, error = proxy.get("uci.env.var.ppp_mgmt")

if ppp_state then
    ppp_state = format("%s",ppp_state[1].value)
else
    ppp_state = "0"
end

if ppp_original then
    ppp_original = format("%s",ppp_original[1].value)
else
    ppp_original = "0"
end

if ppp_mgmt then
    ppp_mgmt = format("%s",ppp_mgmt[1].value)
else
    ppp_mgmt = "0"
end

function M.isVoiceMode()
    if ppp_state and ppp_mgmt[1].value != "" and ppp_state == ppp_mgmt then
        return true
    else
        return false
    end
end

function M.configVoiceMode()
    local success = false
	
    success = proxy.set({
        ["uci.network.interface.@wan.username"] = ppp_mgmt,
		["uci.dhcp.dhcp.@lan.ignore"] = '1',
		["uci.network.device.@wanptm0.vid"] = '835', --dovrebbe essere 837 ma ancora non ho trovato un modo per generare due vlanid... 
    })
	
    success = success and proxy.apply()
    return success
end

function M.disableVoiceMode()
    local success = false
	
    success = proxy.set({
        ["uci.network.interface.@wan.username"] = ppp_original,
		["uci.dhcp.dhcp.@lan.ignore"] = '0',
		["uci.network.device.@wanptm0.vid"] = '835',
    })

    success = success and proxy.apply()
    return success
end

return M
