gettext.textdomain('webui-core')
local bridge = require("bridgehelper")

local modes = {
    {
        name = "bridge",
        default = false,
        description = T"Bridge mode",
        view = "internet-bridged.lp",
        card = "003_internet_bridged.lp",
        check = bridge.isBridged,
        operations = bridge.enter,
    },
}

local routed = {
    {"dhcp", T"DHCP routed mode", "internet-dhcp-routed.lp", "003_internet_dhcp_routed.lp"},
    {"pppoe", T"PPPoE routed", "internet-pppoe-routed.lp", "003_internet_pppoe_routed.lp"},
    {"pppoa", T"PPPoA routed", "internet-pppoa-routed.lp", "003_internet_pppoe_routed.lp"},
    {"static", T"Fixed IP mode", "internet-static-routed.lp", "003_internet_static_routed.lp"},
}
for _, item in ipairs(routed) do
    local mode = item[1]
    modes[#modes + 1] = {
        name = mode,
        default = mode == "dhcp",
        description = item[2],
        view = item[3],
        card = item[4],
        check = function()
            return not bridge.isBridged() and bridge.get("uci.network.interface.@wan.proto") == mode
        end,
        operations = function() return bridge.leave(mode) end,
    }
end
return modes
