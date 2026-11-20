gettext.textdomain('webui-core')

--NG-95382 [GPON-Broadband] Incorporate new GUI Pages for GPON
--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
local proxy = require("datamodel")
local bridge = require("bridgehelper")
local hasXdsl = bridge.hasXdsl()
local integratedGpon = bridge.hasIntegratedGpon()

local sfp, ethname
if not integratedGpon then
    local ok_sfp, sfp_module = pcall(require, "transformer.shared.sfp")
    if ok_sfp and sfp_module and type(sfp_module.readSFPFlag) == "function" then
        local ok_flag, flag = pcall(sfp_module.readSFPFlag)
        if ok_flag then sfp = flag end
    end
    if sfp == nil then
        local ok_flag, flag = pcall(proxy.get, "uci.env.rip.sfp")
        sfp = (ok_flag and flag and flag[1] and flag[1].value == "1") and 1 or 0
    end

    local eth4 = proxy.get("sys.eth.port.@eth4.status")
    ethname = eth4 and eth4[1] and eth4[1].value and "eth4" or "eth3"
end

local function selected(kind, uplink)
    local parent
    if integratedGpon then
        parent = bridge.vlanContext(uplink).connection
        -- The configured WAN device distinguishes Ethernet from the integrated ONT.
        if bridge.isGponInterface(parent) then return kind == "gpon" end
        if parent == "eth3" then return kind == "ethernet" end
    end
    if not uplink and bridge.get("uci.wansensing.global.enable") == "1" then
        local l2 = bridge.get("uci.wansensing.global.l2type") or ""
        if kind == "gpon" then return l2 == "SFP" or l2 == "FIBER" or l2 == "GPON" end
        if kind == "ethernet" then return l2 == "ETH" or l2 == "GBE" end
        return l2 == (kind == "adsl" and "ADSL" or "VDSL")
    end
    if integratedGpon then return false end
    parent = bridge.vlanContext(uplink).connection
    if kind == "adsl" then return bridge.isDslInterface(parent, "atm") end
    if kind == "vdsl" then return bridge.isDslInterface(parent, "ptm") end
    if parent ~= bridge.ethernetPort(ethname) then return false end
    if sfp ~= 1 then return kind == "ethernet" end
    local optical = bridge.get("uci.ethernet.globals.eth4lanwanmode") == "1"
    return (kind == "gpon") == optical
end

local function selectInterface(kind)
    if integratedGpon then
        if selected(kind) then return true end
        return false, T"Enable WanSensing to switch between Ethernet and integrated GPON."
    end
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
    {"ethernet", "Ethernet", "broadband-ethernet-advanced.lp", "002_broadband_ethernet.lp"},
}
if hasXdsl then
    table.insert(definitions, 1, {"vdsl", "VDSL2", "broadband-vdsl-advanced.lp", "002_broadband_xdsl.lp"})
    table.insert(definitions, 1, {"adsl", "ADSL2+", "broadband-adsl-advanced.lp", "002_broadband_xdsl.lp"})
end
if integratedGpon or sfp == 1 then
    definitions[#definitions + 1] = {"gpon", "GPON", "broadband-gpon-advanced.lp", "002_broadband_gpon.lp"}
end
local modes = {}
for _, definition in ipairs(definitions) do
    local kind = definition[1]
    modes[#modes + 1] = {
        name = kind,
        default = kind == (hasXdsl and "vdsl" or "ethernet"),
        description = definition[2],
        view = definition[3],
        card = definition[4],
        check = function(uplink) return selected(kind, uplink) end,
        operations = function()
            return bridge.changeUplink(function() return selectInterface(kind) end)
        end,
    }
end
return modes
