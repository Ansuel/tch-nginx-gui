local bridge = require("bridgehelper")
local internet = require("internethelper")
local netrate = require("netrate")
local get = internet.getValue
local M = {}

local function phoneUplink()
    local phone = "rpc.network.interface.@modgui_phone."
    if get("uci.network.interface.@modgui_phone.defaultroute") ~= "1" or get(phone .. "up") ~= "1" then
        return
    end
    local device = get(phone .. "ifname")
    if string.untaint then device = string.untaint(device) end
    if device == "" then return end

    -- The tethering service installs the selected uplink in this policy
    -- table. The USB interface can be up while the main WAN is still in use.
    local routes = io.popen("ip -4 route show table 29995 default 2>/dev/null", "r")
    if not routes then return end
    local route = routes:read("*l")
    routes:close()
    if route and route:match("^default%s+.*%f[%w]dev%s+(%S+)") == device then return device end
end

function M.sample()
    local device = phoneUplink()
    local bridged
    if not device then
        local wan = "uci.network.interface.@wan."
        local mode = internet.getConnectionMode(
            get("uci.network.config.wan_mode"), get(wan .. "proto"), get(wan .. "ifname"))
        bridged = mode == "bridge"
        if bridged then
            device = bridge.resolveUplink(bridge.getUplink(true))
        elseif get("rpc.network.interface.@wan.up") == "1" then
            device = get("rpc.network.interface.@wan.ifname")
        end
    end
    if string.untaint and device then device = string.untaint(device) end
    if not device or device == "" or device == "br-lan" then return nil, "interface_unavailable" end

    local sample, reason = netrate.sample(device)
    if not sample and reason == "interface_unavailable" and not bridged and device:match("^wan") then
        device = get("uci.network.device.@" .. device .. ".ifname")
        if string.untaint then device = string.untaint(device) end
        if device ~= "br-lan" then sample, reason = netrate.sample(device) end
    end
    return sample, reason, device
end

return M
