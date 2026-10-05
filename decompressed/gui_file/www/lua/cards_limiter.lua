local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local M = {}

local function has_datamodel(path)
	local ok, result = pcall(proxy.get, path)
	return ok and type(result) == "table" and result[1] ~= nil
end

local function has_datausage_backend()
	for _, path in ipairs({ "/etc/config/datausage", "/usr/bin/datausaged" }) do
		local file = io.open(path, "r")
		if not file then return false end
		file:close()
	end
	return has_datamodel("uci.datausage.interfaceNumberOfEntries")
end

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
		hasEasyMesh = hasEasyMesh,
		hasDataUsage = has_datausage_backend(),
		hasPairing = has_datamodel("sys.generic_app.PairingNumberOfEntries")
	}
end

function M.card_limited(info, cardname)
	if info and info.isLTEBoard and lte_exclude_list[cardname] then
		return true
	end
	if info and not info.hasEasyMesh and (cardname == "wifiExtender.lp" or cardname == "020_wifiExtender.lp") then
		return true
	end
	if info and not info.hasDataUsage and (cardname == "datausage.lp" or cardname == "011_datausage.lp") then
		return true
	end
	if info and not info.hasPairing and (cardname == "certificates.lp" or cardname == "021_certificates.lp") then
		return true
	end
	return false
end

return M
