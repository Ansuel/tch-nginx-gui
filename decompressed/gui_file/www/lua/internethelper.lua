local proxy = require("datamodel")

local M = {}

local function notEmpty(path)

	if proxy.get(path)[1].value ~= "" then
		return true
	end

	return false
end

function M.getIpv6Content()

	local content = {
		ip6addr = "",
		ip6prefix = "rpc.network.interface.@wan.ip6prefix",
	}

	for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
		local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
		if intf then
			if intf == "6rd" then
				content.ip6addr = "rpc.network.interface.@6rd.ip6addr"
				if notEmpty(content.ip6addr) then
					content.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
					content.dnsv6 = "rpc.network.interface.@6rd.dnsservers"
					break
				end
			elseif intf == "wan_6" then
				content.ip6addr = "rpc.network.interface.@wan_6.ip6addr"
				if notEmpty(content.ip6addr) then
					content.ip6prefix = "rpc.network.interface.@wan_6.ip6prefix"
					content.dnsv6 = "rpc.network.interface.@wan_6.dnsservers"
					break
				end
			elseif intf == "wan6" then
				content.ip6addr = "rpc.network.interface.@wan6.ip6addr"
				if notEmpty(content.ip6addr) then
					content.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
					content.dnsv6 = "rpc.network.interface.@wan6.dnsservers"
					break
				end
			elseif intf == "wan" then
				content.ip6addr = "rpc.network.interface.@wan.ip6addr"
				if notEmpty(content.ip6addr) then
					content.ip6prefix = "rpc.network.interface.@wan.ip6prefix"
					break
				end
			end
		end
	end
	
	return content
end

return M