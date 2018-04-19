local ipairs = ipairs
local conn = require("transformer.mapper.ubus").connect()

local M = {}

local function get_session_data(mobile_iface)
    local result = {}

    local mobiled_status = conn:call("mobiled", "status", {})
    if type(mobiled_status) == "table" then
        local numDevices = tonumber(mobiled_status.devices)
        if numDevices and numDevices >= 1 then
            for i=1,numDevices do
                local data =  conn:call("mobiled.network", "sessions", { dev_idx = i })
                if data and data.sessions then
                    for _,v in ipairs(data.sessions) do
                        if v.interface == mobile_iface and v.session_state == "connected" then
                            result.proto = v.proto
                            if v.proto and type(v[v.proto]) == "table" then
                                result.ipv4_addr = v[v.proto].ipv4_addr
                                result.ipv6_addr = v[v.proto].ipv6_addr
                            end
                            return result
                        end
                    end
                end
            end
        end
    end
    return result
end

function M.get_network_interface(mobile_iface)
    local result = get_session_data(mobile_iface)
    if result.proto == "dhcp" then
        result.interface = mobile_iface .. "_4"
        result.interface6 = mobile_iface .. "_6"
    elseif result.proto == "ppp" then
        result.interface = mobile_iface .. "_ppp"
    end
    return result
end

return M
