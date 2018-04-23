local require = require
local type = type
local ipairs = ipairs

local M = {}

local uci = require "transformer.mapper.ucihelper"
local ubus = require("transformer.mapper.ubus").connect()

local activedev_binding = {config="wanconfig", sectionname="activedevice"}
function M.getActiveDevices()
	local devices = {}
	uci.foreach_on_uci(activedev_binding, function(s)
		devices[#devices+1] = s['.name']
	end)
	return devices
end

local function getInterfaceConfig(intf)
	local ifname, config = intf:match("^([^:]+):?(.*)$")
	return {
		ifname = ifname,
		config = config~="" and config or "ip,ppp"
	}
end

local function getInterfaceList(iflist)
	local interfaces = {}
	if type(iflist) == "table" then
		-- interface configured as list
		for _, ifname in ipairs(iflist) do
			interfaces[#interfaces+1] = getInterfaceConfig(ifname)
		end
	elseif iflist and iflist ~= "" then
		-- interface configured as normal option
		-- only a single interface is possible
		interfaces[#interfaces+1] = getInterfaceConfig(iflist)
	end
	return interfaces
end

local activeintf_binding = {config="wanconfig"}
local function getActiveInterfaces(device)
	local interfaces = {}
	activeintf_binding.sectionname = device
	activeintf_binding.option = "interface"
	local iflist = uci.get_from_uci(activeintf_binding)
	for _, ifconfig in ipairs(getInterfaceList(iflist)) do
		interfaces[#interfaces+1] = ifconfig.ifname
	end
	return interfaces
end
M.getActiveInterfaces = getActiveInterfaces

function M.getDevtypeAndName(device)
	local interfaces = getActiveInterfaces(device)
	local intf = interfaces[1]
	if intf then
		local stat = ubus:call("network.interface."..intf, "status", {})
		local device = stat and stat.device
		if device then
			local xtm = uci.get_from_uci{config="xtm", sectionname=device}
			if xtm~= "" then
				-- I hardcoded dsl0 here as I have no known way of getting from the
				-- given device name (eg atm_wan) to the DSL device name. But in general
				-- there is only one DSL device named dsl0
				return "DSL", "dsl0"
			end
			return "ETH", device
		end
	end
end

local function findInterfaceConfig(interface)
	local ifconfig
	uci.foreach_on_uci(activedev_binding, function(s)
		local iflist = getInterfaceList(s.interface)
		for  _, intf in ipairs(iflist) do
			if intf.ifname == interface then
				ifconfig = intf.config
			end
		end
		if ifconfig then return false end
	end)
	return ifconfig or ""
end

function M.isActiveInterface(interface)
	return findInterfaceConfig(interface) ~= ""
end

local function configHasProto(config, proto)
	for p in config:gmatch("([^,]+)") do
		if p==proto then
			return true
		end
	end
	return false
end

local function interfaceHasProtocol(interface, protocol)
	local ifconfig = findInterfaceConfig(interface)
	return configHasProto(ifconfig, protocol)
end

function M.interfaceHasPPP(interface)
	return interfaceHasProtocol(interface, "ppp")
end

function M.interfaceHasIP(interface)
	return interfaceHasProtocol(interface, "ip")
end

return M
