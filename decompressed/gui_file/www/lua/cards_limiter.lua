
local M = {}

local bridgemode = require("bridgedmode_helper")
local voicemode = require("voicemode_helper")

local bridge_limit_list = {
  ["gateway.lp"] = true,
  ["broadband.lp"] = true,
  ["wireless.lp"] = true,
  ["LAN.lp"] = true,
  ["usermgr.lp"] = true,
  ["diagnostics.lp"] = true,
  ["iproutes.lp"] = true,
  ["system.lp"] = true,
  ["xdsl.lp"] = true,
  ["extensions.lp"] = true,	
}

local voice_limit_list = {
  ["gateway.lp"] = true,
  ["broadband.lp"] = true,
  ["wireless.lp"] = true,
  ["LAN.lp"] = true,
  ["usermgr.lp"] = true,
  ["telephony.lp"] = true,
  ["diagnostics.lp"] = true,
  ["iproutes.lp"] = true,
  ["system.lp"] = true,
  ["xdsl.lp"] = true,
  ["extensions.lp"] = true,
}

function M.get_limit_info()
	return {bridgemode=bridgemode.isBridgedMode(),voicemode=voicemode.isVoiceMode()}
end

function M.card_limited(info, cardname)
  if info.bridgemode or info.voicemode then
	if info.bridgemode then
		return not bridge_limit_list[cardname]
	else
		return not voice_limit_list[cardname]
	end
  end
  return false
end

return M
