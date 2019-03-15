local require, ipairs = require, ipairs
local proxy = require("datamodel")
local strmatch = string.match

local M = {}

--Note:wl0, wl0-1, wl1, wl1-1, currently there is only one peeriface
--wl0\wl1 are in one pair, and bsid is bs0
--wl0_1\wl1_1 are in one pair, and bsid is bs1
--wl0_2\wl1_2 are in one pair, and bsid is bs2

--local piface = "uci.wireless.wifi-iface."
function M.getBandSteerPeerIface(curiface)
    local tmpstr = strmatch(curiface, ".*(_%d+)")
    local results = proxy.get("uci.wireless.wifi-iface.")
    local wl_pattern = "uci%.wireless%.wifi%-iface%.@([^%.]*)%."

    if results then
        for _,v in ipairs(results) do
            if v.param == "ssid" then
                local wl = v.path:match(wl_pattern)
                if wl ~= curiface then
                    if not tmpstr then
                        if not strmatch(wl, ".*(_%d+)") then
                            return wl
                        end
                    else
                        if tmpstr == strmatch(wl, ".*(_%d+)") then
                            return wl
                        end
                    end
                end
            end
        end
    end

    return nil
end

function M.isBaseIface(iface)
    if "0" == strmatch(iface, "%d+") then
        return true
    else
        return false
    end
end

function M.getBandSteerId(wl)
    local tmpstr = strmatch(wl, ".*_(%d+)")
    if not tmpstr then
        return string.format("%s", "bs0")
    else
        return string.format("%s", "bs" .. tmpstr)
    end
end

function M.disableBandSteer(object)
    if "" == object.bsid or "off" == object.bsid then
        return true
    else
        object.bsid = "off"
        object.bspeerid = "off"
        local suffix = proxy.get("uci.env.var.commonssid_suffix")[1].value 
        if object.bspifacessid then
            object.bspifacessid = object.ssid .. suffix
        else
            object.ssid = object.ssid .. suffix
        end
    end
    return true
end

return M
