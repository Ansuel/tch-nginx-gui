-- Read router-side link state without invoking ADB or changing Mobile settings.
local proxy = require("datamodel")
local M = {}
local function value(path)
    local ok, rows = pcall(proxy.get, path)
    if not ok or not rows or not rows[1] then return nil end
    local v = string.untaint(rows[1].value)
    if v == "" then return nil end
    return v
end

function M.get_status(session)
    if not session:hasAccess("/modals/smartphone-modal.lp") or
        value("uci.modgui.app.smartphone_app") ~= "1" then
        return { visible = false, status = "" }
    end
    local iface = value("uci.network.interface.@smartphone.ifname")
    local status
    if not iface then
        status = T"Not configured"
    elseif #iface > 64 or iface:find("[^%w_.:%- ]") then
        status = T"Status unavailable"
    else
        local up = value("rpc.network.interface.@smartphone.up")
        if up == "1" then status = T"Active"
        elseif up == "0" then status = T"Inactive"
        else status = T"Status unavailable" end
        status = status .. " (" .. iface .. ")"
    end
    return { visible = true, status = status }
end

return M
