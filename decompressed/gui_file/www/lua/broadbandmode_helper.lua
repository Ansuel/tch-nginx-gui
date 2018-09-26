gettext.textdomain('webui-core')

--NG-95382 [GPON-Broadband] Incorporate new GUI Pages for GPON
--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
format = string.format
local sfp = 0
local wansensing = proxy.get("uci.wansensing.global.enable")[1].value
local wan_mode = proxy.get("uci.network.config.wan_mode")[1].value

local tablecontent = {}
tablecontent[#tablecontent + 1] = {
    name = "adsl",
    default = false,
    description = "ADSL2+",
    view = "broadband-adsl-advanced.lp",
    card = "002_broadband_xdsl.lp",
    check = function()

        if wansensing == "1" then
            local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
            if L2 == "ADSL" then
                return true
            end
        else
            if not wan_mode == "bridge" then
                local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

                local iface = string.match(ifname, "atm")

                if iface then
                    return true
                end
            end
        end
    end,
    operations = function()
        local difname = proxy.get("uci.network.device.@wanatmwan.ifname")
        if difname then
            local dname = proxy.get("uci.network.device.@wanatmwan.name")[1].value
            difname = proxy.get("uci.network.device.@wanatmwan.ifname")[1].value
            if difname ~= "" and difname ~= nil then
                proxy.set("uci.network.interface.@wan.ifname", dname)
            else
                proxy.set("uci.network.interface.@wan.ifname", "atmwan")
            end
        else
            proxy.set("uci.network.interface.@wan.ifname", "atmwan")
        end
        if sfp == "1" then
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
        end
        proxy.set("uci.wansensing.global.l2type", "ADSL")
    end,
}
tablecontent[#tablecontent + 1] = {
    name = "vdsl",
    default = true,
    description = "VDSL2",
    view = "broadband-vdsl-advanced.lp",
    card = "002_broadband_xdsl.lp",
    check = function()

        if wansensing == "1" then
            local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
            if L2 == "VDSL" then
                return true
            end
        else
            if not wan_mode == "bridge" then
                local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

                local iface = string.match(ifname, "ptm0")

                if iface then
                    return true
                end
            end
        end
    end,
    operations = function()
        local difname = proxy.get("uci.network.device.@wanptm0.ifname")
        if difname then
            local dname = proxy.get("uci.network.device.@wanptm0.name")[1].value
            difname = proxy.get("uci.network.device.@wanptm0.ifname")[1].value
            if difname ~= "" and difname ~= nil then
                proxy.set("uci.network.interface.@wan.ifname", dname)
            else
                proxy.set("uci.network.interface.@wan.ifname", "ptm0")
            end
        else
            proxy.set("uci.network.interface.@wan.ifname", "ptm0")
        end
        if sfp == "1" then
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
        end
        proxy.set("uci.wansensing.global.l2type", "VDSL")
    end,
}
tablecontent[#tablecontent + 1] = {
    name = "bridge",
    default = false,
    description = "Bridge Mode",
    view = "broadband-bridge.lp",
    card = "002_broadband_bridge.lp",
    check = function()
        if wansensing == "0" and wan_mode == "bridge" then
            return true
        end
    end,
    operations = nil,
}
tablecontent[#tablecontent + 1] = {
    name = "ethernet",
    default = false,
    description = "Ethernet",
    view = "broadband-ethernet-advanced.lp",
    card = "002_broadband_ethernet.lp",
    check = function()

        if wansensing == "1" then
            local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
            if L2 == "ETH" then
                return true
            end
        else
            if not wan_mode == "bridge" then
                local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

                local iface = string.match(ifname, "eth4")
                if sfp == "1" then
                    local lwmode = proxy.get("uci.ethernet.globals.eth4lanwanmode")[1].value
                    if iface and lwmode == "0" then
                        return true
                    end
                else
                    if iface then
                        return true
                    end
                end
            end
        end
    end,
    operations = function()
        local difname = proxy.get("uci.network.device.@waneth4.ifname")
        if difname then
            local dname = proxy.get("uci.network.device.@waneth4.name")[1].value
            difname = proxy.get("uci.network.device.@waneth4.ifname")[1].value
            if difname ~= "" and difname ~= nil then
                proxy.set("uci.network.interface.@wan.ifname", dname)
            else
                proxy.set("uci.network.interface.@wan.ifname", "eth4")
            end
        else
            proxy.set("uci.network.interface.@wan.ifname", "eth4")
        end
        if sfp == "1" then
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
        end
        proxy.set("uci.wansensing.global.l2type", "ETH")
    end,
}

if sfp == "1" then
    tablecontent[#tablecontent + 1] = {
        name = "gpon",
        default = false,
        description = "GPON",
        view = "broadband-gpon-advanced.lp",
        card = "002_broadband_gpon.lp",
        check = function()
            if wansensing == "1" then
                local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
                if L2 == "SFP" then
                    return true
                end
            else
                if not wan_mode == "bridge" then
                    local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

                    local iface = string.match(ifname, "eth4")

                    if sfp == "1" then
                        local lwmode = proxy.get("uci.ethernet.globals.eth4lanwanmode")[1].value
                        if iface and lwmode == "1" then
                            return true
                        end
                    else
                        if iface then
                            return true
                        end
                    end
                end
            end
        end,
        operations = function()
            local difname = proxy.get("uci.network.device.@waneth4.ifname")
            if difname then
                local dname = proxy.get("uci.network.device.@waneth4.name")[1].value
                difname = proxy.get("uci.network.device.@waneth4.ifname")[1].value
                if difname ~= "" and difname ~= nil then
                    proxy.set("uci.network.interface.@wan.ifname", dname)
                else
                    proxy.set("uci.network.interface.@wan.ifname", "eth4")
                end
            else
                proxy.set("uci.network.interface.@wan.ifname", "eth4")
            end
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
            proxy.set("uci.wansensing.global.l2type", "SFP")
        end,
    }
end
return tablecontent