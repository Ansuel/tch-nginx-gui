
local M = {}

local bridge_limit_list = {
	["/www/cards/"] = {
		["gateway.lp"] = true,
		["modgui.lp"] = true,
		["broadband.lp"] = true,
		["internet.lp"] = true,
		["wireless.lp"] = true,
		["LAN.lp"] = true,
		["usermgr.lp"] = true,
		["diagnostics.lp"] = true,
		["iproutes.lp"] = true,
		["system.lp"] = true,
		["xdsl.lp"] = true,
		["extensions.lp"] = true,
		["eco.lp"] = true,
	},
	["/www/info-cards/"] = {
		["gateway.lp"] = true,
		["wanstats.lp"] = true,
		["graph.lp"] = true,
		["xdsl_stats.lp"] = true,
		["internet.lp"] = true,
	}
}

local voice_limit_list = {
	["/www/cards/"] = {
		["gateway.lp"] = true,
		["modgui.lp"] = true,
		["broadband.lp"] = true,
		["internet.lp"] = true,
		["wireless.lp"] = true,
		["LAN.lp"] = true,
		["usermgr.lp"] = true,
		["telephony.lp"] = true,
		["diagnostics.lp"] = true,
		["iproutes.lp"] = true,
		["system.lp"] = true,
		["xdsl.lp"] = true,
		["extensions.lp"] = true,
		["eco.lp"] = true,
	},
	["/www/info-cards/"] = {
		["gateway.lp"] = true,
		["wanstats.lp"] = true,
		["graph.lp"] = true,
		["xdsl_stats.lp"] = true,
		["mmpbxd_stats.lp"] = true,
		["internet.lp"] = true,
	}
}

function M.get_limit_info()
	local dyntab_helper = require("web.dyntab_helper")
	local bmh = require("broadbandmode_helper")
	local tabdata = dyntab_helper.process(bmh)
	
	local bridgemode_status = tabdata.current.name:match("bridge") and true or false
	local voicemode_status = tabdata.current.name:match("voice") and true or false
	
	return {bridgemode=bridgemode_status,voicemode=voicemode_status}
end

function M.card_limited(info, cardname, includepath)
  if not includepath:match("/$") then 
	includepath = includepath .. "/"
  end
  if info.bridgemode or info.voicemode then
	if info.bridgemode then
		return not bridge_limit_list[includepath][cardname]
	else
		return not voice_limit_list[includepath][cardname]
	end
  end
  return false
end

return M
