local content_helper = require("web.content_helper")
local M = {}

local lte_exclude_list = {
	["broadband.lp"] = true,
	["internet.lp"] = true,
}

function M.get_limit_info()
	local isLTEBoard = false
	local interfaces = {
		wan_proto = "uci.network.interface.@wan.proto",
		wwan_proto = "uci.network.interface.@wwan.proto",
		wan6_proto = "uci.network.interface.@wan6.proto"
	}
	content_helper.getExactContent(interfaces)
	if interfaces.wan_proto == 'mobiled' and
			interfaces.wwan_proto == 'mobiled' and
			interfaces.wan6_proto == 'mobiled' then
		isLTEBoard = true
	end
	return {isLTEBoard = isLTEBoard}
end

function M.card_limited(info, cardname)
	if info.isLTEBoard then
		return lte_exclude_list[cardname]
	end
	return false
end

return M
