local proxy = require("datamodel")

local M = {}

-- Bridge is a topology choice; routed protocols follow the actual WAN
-- configuration, which vendor scripts can change without updating wan_mode.
function M.getConnectionMode(configured, protocol, device)
    if configured == "bridge" or protocol == "bridge" or device == "br-lan" then return "bridge" end
    for _, mode in ipairs({"dhcp", "pppoe", "pppoa", "static"}) do
        if protocol == mode then return mode end
    end
    for _, mode in ipairs({"dhcp", "pppoe", "pppoa", "static"}) do
        if configured == mode then return mode end
    end
    return "dhcp"
end

function M.getValue(path)
	local result = proxy.get(path)
	return result and result[1] and result[1].value or ""
end

local function phoneUplink()
    local phone = "rpc.network.interface.@modgui_phone."
    if M.getValue("uci.network.interface.@modgui_phone.defaultroute") ~= "1" or M.getValue(phone .. "up") ~= "1" then
        return
    end
    local device = M.getValue(phone .. "ifname")
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

function M.sampleWanTraffic()
    local netrate = require("netrate")
    local device = phoneUplink()
    local bridged
    if not device then
        local wan = "uci.network.interface.@wan."
        local mode = M.getConnectionMode(
            M.getValue("uci.network.config.wan_mode"), M.getValue(wan .. "proto"), M.getValue(wan .. "ifname"))
        bridged = mode == "bridge"
        if bridged then
            local bridge = require("bridgehelper")
            device = bridge.resolveUplink(bridge.getUplink(true))
        elseif M.getValue("rpc.network.interface.@wan.up") == "1" then
            device = M.getValue("rpc.network.interface.@wan.ifname")
        end
    end
    if string.untaint and device then device = string.untaint(device) end
    if not device or device == "" or device == "br-lan" then return nil, "interface_unavailable" end

    local sample, reason = netrate.sample(device)
    if not sample and reason == "interface_unavailable" and not bridged and device:match("^wan") then
        device = M.getValue("uci.network.device.@" .. device .. ".ifname")
        if string.untaint then device = string.untaint(device) end
        if device ~= "br-lan" then sample, reason = netrate.sample(device) end
    end
    return sample, reason, device
end

function M.getMtuValidator(protocol)
	return function(value, object)
		-- An empty option leaves protocol/driver defaults in effect.
		if not value or value == "" then return true end
		local minimum = ((object or {}).uci_wan_ipv6 or M.getValue("uci.network.interface.@wan.ipv6")) == "1" and 1280 or 576
		local overhead = protocol == "pppoe" and 8 or 0
		local maximum = 1500 - overhead
		local link_known = false
		local interface = protocol == "pppoe" and M.getValue("rpc.network.interface.@wan.ppp.ll_intf") or ""
		if interface == "" then interface = M.getValue("uci.network.interface.@wan.ifname") end
		if interface:match("^[%w_.:-]+$") then
			local link_mtu = tonumber(M.getValue("sys.class.net.@" .. interface .. ".mtu"))
			if link_mtu and link_mtu > overhead then
				maximum = link_mtu - overhead
				link_known = true
			end
		end
		local number = tonumber(value)
		-- Preserve existing jumbo/RFC4638 settings when the link is unavailable.
		local current = tonumber(M.getValue("uci.network.interface.@wan.mtu"))
		if value:match("^%d+$") and number and number >= minimum and (number <= maximum or (not link_known and number == current)) then
			return true
		end
		return nil, string.format(T"Input must be a number between %d and %d included.", minimum, maximum)
	end
end

-- Optional runtime paths vary with firmware and WAN protocol. Keep reads batched
-- when possible, but do not expose missing-path diagnostics as addresses/status.
function M.getOptionalContent(content)
	local paths = {}
	for _, path in pairs(content) do paths[#paths + 1] = path end
	if #paths == 0 then return end
	local result = proxy.get(unpack(paths))
	if result then
		local values = {}
		for _, entry in ipairs(result) do
			values[entry.path .. entry.param] = entry.value
		end
		for key, path in pairs(content) do content[key] = values[path] or "" end
	else
		for key, path in pairs(content) do content[key] = M.getValue(path) end
	end
end

function M.getIpv6Content()

	local content = {}
	local function selectInterface(intf)
		for key, parameter in pairs({ip6addr = "ip6addr", ip6prefix = "ip6prefix", dnsv6 = "dnsservers"}) do
			content[key] = nil
			local path = "rpc.network.interface.@" .. intf .. "." .. parameter
			local result = proxy.get(path)
			-- Do not put unsupported paths in the modal's AJAX request map.
			if result and result[1] and (key ~= "dnsv6" or intf ~= "wan") then content[key] = path end
		end
	end
	selectInterface("wan")

	local supported = {wan = true, wan6 = true, wan_6 = true, ["6rd"] = true}
	for _, entry in ipairs(proxy.getPN("rpc.network.interface.", true) or {}) do
		local intf = string.match(entry.path or "", "rpc%.network%.interface%.@([^%.]+)%.")
		if supported[intf] and M.getValue("rpc.network.interface.@" .. intf .. ".ip6addr") ~= "" then
			selectInterface(intf)
			break
		end
	end

	return content
end

function M.getWanStats()
	local config = {
		mode = "uci.network.config.wan_mode",
		device = "uci.network.interface.@wan.ifname",
		proto = "uci.network.interface.@wan.proto",
	}
	M.getOptionalContent(config)

	local phone = phoneUplink()
	local connection = phone and "dhcp" or M.getConnectionMode(config.mode, config.proto, config.device)
	local stats = {}
	for _, mode in ipairs(require("internetmode_helper")) do
		if mode.name == connection then
			stats.connection = mode.description
			break
		end
	end

	local path = "rpc.network.interface.@" .. (phone and "modgui_phone" or "wan") .. "."
	local link = {up = path .. "up", device = path .. "ifname"}
	M.getOptionalContent(link)
	if not phone and (connection == "bridge" or link.up == "1") then
		local bridge = require("bridgehelper")
		local uplink = connection == "bridge" and bridge.getUplink(true) or config.device
		if connection ~= "bridge" and (uplink == "" or not config.proto:match("^ppp")) and link.device ~= "" then
			uplink = link.device
		end
		uplink = bridge.resolveUplink(uplink)
		if uplink then
			for _, mode in ipairs(require("broadbandmode_helper")) do
				if mode.check(uplink) then
					stats.broadband = mode.description
					break
				end
			end
		end
	end

	local protocol = phone and "dhcp" or config.proto
	local ppp = protocol == "pppoe" or protocol == "pppoa"
	if connection == "bridge" and not (ppp or protocol == "dhcp" or protocol == "static") then return stats end

	local content = {
		ipv4 = path .. "ipaddr",
		gateway = path .. "nexthop",
		dns = path .. "dnsservers",
		uptime = path .. "uptime",
	}
	if ppp then content.concentrator = path .. "ppp.access_concentrator_name" end
	if not phone then content.ipv6 = M.getIpv6Content().ip6addr end
	M.getOptionalContent(content)

	if link.up == "1" or link.up == "0" then
		stats.connected = link.up == "1"
		stats.status = stats.connected and T"Connected" or T"Disconnected"
	end
	for _, name in ipairs({"ipv4", "ipv6", "concentrator", "gateway", "dns"}) do
		local value = content[name]
		if value and value:match("%S") and value ~= "N/A" and value ~= "0.0.0.0" and value ~= "::" then
			stats[name] = value
		end
	end
	if stats.dns then stats.dns = stats.dns:gsub(",", " , ") end
	if link.up == "1" and tonumber(content.uptime) then
		stats.uptime = require("web.post_helper").secondsToTime(content.uptime)
	end
	return stats
end

return M
