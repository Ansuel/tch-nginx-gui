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
	local hasEasyMesh = false
	local ok_em, em = pcall(require, "easymesh_helper")
	if ok_em and em and em.is_supported then
		hasEasyMesh = em.is_supported()
	end

	return {
		isLTEBoard = isLTEBoard,
		hasEasyMesh = hasEasyMesh
	}
end

function M.card_limited(info, cardname)
	if info and info.isLTEBoard and lte_exclude_list[cardname] then
		return true
	end
	if info and not info.hasEasyMesh and (cardname == "wifiExtender.lp" or cardname == "020_wifiExtender.lp") then
		return true
	end
	return false
end

return M
