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
local sfp = proxy.get("uci.env.rip.sfp") and proxy.get("uci.env.rip.sfp")[1].value or 0

local function get_wansensing() 
	if proxy.get("uci.wansensing.global.enable") then
		return proxy.get("uci.wansensing.global.enable")[1].value
	end
	return ""
end

local function get_wan_mode()
	if proxy.get("uci.network.config.wan_mode") then
		return proxy.get("uci.network.config.wan_mode")[1].value 
	end
	return ""
end

local function isVoiceMode()
	local ppp_mgmt = proxy.get("uci.modgui.var.ppp_mgmt")
	local wan_username = proxy.get("uci.network.interface.@wan.username")
    if wan_username and ppp_mgmt and ( wan_username[1].value == ppp_mgmt[1].value ) and not ( wan_username[1].value == "" )then
        return true
    end
	return nil
end

-- find requested interface in the uci network file, device section
local function findwan(interface)
	for i,v in ipairs(proxy.getPN("uci.network.device.", true)) do
		local result = string.match(v.path, "uci%.network%.device%.@.*".. interface .. ".*%.")
		if result then
			return (result:gsub("uci%.network%.device%.",""):gsub("%.",""))
		end
	end
	
	return nil --return null if not found
end

local function restartNetwork() 
	local ubus = require("ubus")

	local conn = ubus.connect()
	if not conn then
		return "Failed to connect to ubusd"
	end
	
	conn:call("network", "restart", {})
	
	conn:close()
end

local function bridge(mode) 
	local ifnames = proxy.get("uci.network.interface.@lan.ifname")[1].value
	local wan_ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
	local state = proxy.get("uci.network.config.wan_mode")
	if mode == "enable" then
		proxy.set({
			["uci.wansensing.global.enable"] = '0',
			["uci.network.interface.@wan.enabled"] = '0',
			["uci.network.interface.@wan.auto"] = '0',
			["uci.network.interface.@wan6.enabled"] = '0',
			["uci.network.interface.@wwan.enabled"] = '0',
			["uci.wireless.wifi-device.@radio_2G.state"] = '0',
			["uci.wireless.wifi-device.@radio_5G.state"] = '0',
			["uci.mmpbx.mmpbx.@global.enabled"] = '0',
			["uci.dhcp.dhcp.@lan.ignore"] = '1',
			["uci.cwmpd.cwmpd_config.state"] = '0',
			["uci.mobiled.device_defaults.enabled"] = '0',
			["uci.network.interface.@lan.ifname"] = ifnames ..' '.. wan_ifname,
			["uci.network.config.wan_mode"] = 'bridge',
		})
	elseif not ( state and state[1].value == "bridge" ) then
		return --skip setting everything as we are not restoring a bridge mode
	else
		local wan_proto = proxy.get("uci.network.interface.@wan.proto")
		
		proxy.set({
			["uci.wansensing.global.enable"] = '1',
			["uci.network.interface.@wan.enabled"] = '1',
			["uci.network.interface.@wan.auto"] = '1',
			["uci.network.interface.@wan6.enabled"] = '1',
			["uci.network.interface.@wwan.enabled"] = '1',
			["uci.wireless.wifi-device.@radio_2G.state"] = '1',
			["uci.wireless.wifi-device.@radio_5G.state"] = '1',
			["uci.mmpbx.mmpbx.@global.enabled"] = '1',
			["uci.dhcp.dhcp.@lan.ignore"] = '0',
			["uci.cwmpd.cwmpd_config.state"] = '1',
			["uci.mobiled.device_defaults.enabled"] = '1',
			["uci.network.interface.@lan.ifname"] = string.gsub(string.gsub(ifnames, wan_ifname, ""), "%s$", ""),
			["uci.network.config.wan_mode"] = wan_proto and wan_proto[1].value or "dhcp",
		})
	end
	
	restartNetwork()

    return
end

local function voice(mode) --voice mode is only for TIM for now...
    local ifnames = proxy.get("uci.network.interface.@lan.ifname")[1].value
	local tim_data_ptm = "ptm0.835"
	local ppp_mgmt = proxy.get("uci.modgui.var.ppp_mgmt")
	local ppp_original = proxy.get("uci.modgui.var.ppp_realm_ipv4")
	if mode == "enable" then
	
		proxy.set({
			["uci.network.interface.@wan.username"] = ppp_mgmt[1].value or "Unknown",
			["uci.dhcp.dhcp.@lan.ignore"] = '1',
			["uci.wireless.wifi-device.@radio_2G.state"] = '0',
			["uci.wireless.wifi-device.@radio_5G.state"] = '0',
			["uci.network.interface.@lan.ifname"] = ifnames .. ' ' .. tim_data_ptm,
			["uci.network.interface.@wan.ifname"] = 'ptm0.837',
			["uci.network.interface.@wan.password"] = 'alicenewag',
		})
	elseif not isVoiceMode() then
        return --skip setting everything as we are not restoring a voice mode
	else
		
		proxy.set({
			["uci.network.interface.@wan.username"] = ppp_original[1].value or "Unknown",
			["uci.wireless.wifi-device.@radio_2G.state"] = '1',
			["uci.wireless.wifi-device.@radio_5G.state"] = '1',
			["uci.dhcp.dhcp.@lan.ignore"] = '0',
			["uci.network.interface.@lan.ifname"] = string.gsub(string.gsub(ifnames, tim_data_ptm, ""), "%s$", ""),
			["uci.network.interface.@wan.ifname"] = 'wanptm0',
			["uci.network.interface.@wan.password"] = 'alicenewag',
		})
	end
	
	restartNetwork()

    return
end

local tablecontent = {}
tablecontent[#tablecontent + 1] = {
    name = "adsl",
    default = false,
    description = "ADSL2+",
    view = "broadband-adsl-advanced.lp",
    card = "002_broadband_xdsl.lp",
    check = function()
        if get_wansensing() == "1" then
			if isVoiceMode() then
				return false
			end
            local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
            if L2 == "ADSL" then
                return true
            end
			
        else
            if not ( get_wan_mode() == "bridge" ) then
                local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value

                local iface = string.match(ifname, "atm")

                if iface then
                    return true
                end
            end
        end
    end,
    operations = function()
		bridge("check")
		voice("check")
		local interface = findwan("atm") or "@wanatmwan"
        local difname = proxy.get("uci.network.device." .. interface .. ".ifname")
        if difname then
            local dname = proxy.get("uci.network.device." .. interface .. ".name")[1].value
            difname = proxy.get("uci.network.device." .. interface .. ".ifname")[1].value
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

        if get_wansensing() == "1" then
			if isVoiceMode() then
				return false
			end
            local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
            if L2 == "VDSL" then
                return true
            end
        else
            if not ( get_wan_mode() == "bridge" ) then
                local ifname = proxy.get("uci.network.interface.@wan.ifname")[1].value
        
                local iface = string.match(ifname, "ptm0")
        
                if iface then
                    return true
                end
            end
        end
    end,
    operations = function()
		bridge("check")
		voice("check")
		local interface = findwan("ptm") or "@wanptm0"
        local difname = proxy.get("uci.network.device." .. interface .. ".ifname")
        if difname then
            local dname = proxy.get("uci.network.device." .. interface .. ".name")[1].value
            difname = proxy.get("uci.network.device." .. interface .. ".ifname")[1].value
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
        if ( get_wansensing() == "0" ) and ( get_wan_mode() == "bridge" ) then
            return true
        end
    end,
    operations = function()
		voice("check")
		bridge("enable")
	end,
}
tablecontent[#tablecontent + 1] = {
    name = "voice",
    default = false,
    description = "Voice Mode",
    view = "broadband-bridge.lp",
    card = "002_broadband_bridge.lp",
    check = function()
        return isVoiceMode() or false
    end,
    operations = function()
		bridge("check")
		voice("enable")
	end,
}
tablecontent[#tablecontent + 1] = {
    name = "ethernet",
    default = false,
    description = "Ethernet",
    view = "broadband-ethernet-advanced.lp",
    card = "002_broadband_ethernet.lp",
    check = function()

        if get_wansensing() == "1" then
			if isVoiceMode() then
				return false
			end
            local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
            if L2 == "ETH" then
                return true
            end
        else
            if not ( get_wan_mode() == "bridge" ) then
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
		bridge("check")
		voice("check")
		local interface = findwan("eth4") or "@waneth4"
        local difname = proxy.get("uci.network.device." .. interface .. ".ifname")
        if difname then
            local dname = proxy.get("uci.network.device." .. interface .. ".name")[1].value
            difname = proxy.get("uci.network.device." .. interface .. ".ifname")[1].value
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
            if get_wansensing() == "1" then
				if isVoiceMode() then
					return false
				end
                local L2 = proxy.get("uci.wansensing.global.l2type")[1].value
                if L2 == "SFP" then
                    return true
                end
            else
                if not ( get_wan_mode() == "bridge" ) then
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
			bridge("check")
			voice("check")
			local interface = findwan("eth4") or "@waneth4"
            local difname = proxy.get("uci.network.device." .. interface .. ".ifname")
            if difname then
                local dname = proxy.get("uci.network.device." .. interface .. ".name")[1].value
                difname = proxy.get("uci.network.device." .. interface .. ".ifname")[1].value
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