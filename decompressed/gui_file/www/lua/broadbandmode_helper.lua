gettext.textdomain('webui-core')

--NG-95382 [GPON-Broadband] Incorporate new GUI Pages for GPON
--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
local proxy = require("datamodel")
local bridge = require("bridgehelper")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
format, match = string.format, string.match

local ok_sfp, sfp_module = pcall(require, "transformer.shared.sfp")
local sfp
if ok_sfp and sfp_module and type(sfp_module.readSFPFlag) == "function" then
    local ok_flag, flag = pcall(sfp_module.readSFPFlag)
    if ok_flag then sfp = flag end
end
if sfp == nil then
    local ok_flag, flag = pcall(proxy.get, "uci.env.rip.sfp")
    sfp = (ok_flag and flag and flag[1] and flag[1].value == "1") and 1 or 0
end

--Support ethernet mode for devices with no eth4 port
local ethname = proxy.get("sys.eth.port.@eth4.status")
if ethname and ethname[1].value then
    ethname =  "eth4"
else
    ethname =  "eth3"
end

local function selected(kind)
    if bridge.get("uci.wansensing.global.enable") == "1" then
        local l2 = bridge.get("uci.wansensing.global.l2type") or ""
        if kind == "gpon" then return l2 == "SFP" or l2 == "FIBER" end
        return l2 == ({adsl = "ADSL", vdsl = "VDSL", ethernet = "ETH"})[kind]
    end
    local parent = bridge.vlanContext().connection
    if kind == "adsl" then return bridge.isDslInterface(parent, "atm") end
    if kind == "vdsl" then return bridge.isDslInterface(parent, "ptm") end
    if parent ~= bridge.ethernetPort(ethname) then return false end
    if sfp ~= 1 then return kind == "ethernet" end
    local optical = bridge.get("uci.ethernet.globals.eth4lanwanmode") == "1"
    return (kind == "gpon") == optical
end

local function selectInterface(kind)
    local ethname = bridge.ethernetPort(ethname)
    local ifname, err = bridge.broadbandUplink(kind, ethname)
    if not ifname then return false, err end
    if bridge.isBridged() then
        local valid, message = bridge.canBridge(ifname)
        if not valid then return false, message end
    end
    local values = {
        ["uci.network.interface.@wan.ifname"] = ifname,
    }
    -- Some firmware has no sensing configuration at all.
    if bridge.get("uci.wansensing.global.enable") ~= nil then
        values["uci.wansensing.global.l2type"] = ({adsl = "ADSL", vdsl = "VDSL", ethernet = "ETH", gpon = "SFP"})[kind]
    end
    if sfp == 1 then
        values["uci.ethernet.globals.eth4lanwanmode"] = kind == "ethernet" and "0" or "1"
    end
    if ethname == "eth3" then
        local isWan = kind == "ethernet" or kind == "gpon"
        values["uci.network.interface.@lan.ifname"] = isWan and bridge.lanWithout(ethname) or bridge.lanWith(ethname)
        values["uci.ethernet.port.@eth3.wan"] = isWan and "1" or "0"
    end
    return proxy.set(values)
end

local definitions = {
    {"adsl", "ADSL2+", "broadband-adsl-advanced.lp", "002_broadband_xdsl.lp"},
    {"vdsl", "VDSL2", "broadband-vdsl-advanced.lp", "002_broadband_xdsl.lp"},
    {"ethernet", "Ethernet", "broadband-ethernet-advanced.lp", "002_broadband_ethernet.lp"},
}
if sfp == 1 then
    definitions[#definitions + 1] = {"gpon", "GPON", "broadband-gpon-advanced.lp", "002_broadband_gpon.lp"}
end
local modes = {}
for _, definition in ipairs(definitions) do
    local kind = definition[1]
    modes[#modes + 1] = {
        name = kind,
        default = kind == "vdsl",
        description = definition[2],
        view = definition[3],
        card = definition[4],
        check = function() return selected(kind) end,
        operations = function()
            return bridge.changeUplink(function() return selectInterface(kind) end)
        end,
    }
end
return modes
