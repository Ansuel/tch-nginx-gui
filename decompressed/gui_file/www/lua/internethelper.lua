local proxy = require("datamodel")

local M = {}

function M.getValue(path)
	local result = proxy.get(path)
	return result and result[1] and result[1].value or ""
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

return M
