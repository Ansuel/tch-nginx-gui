local M = {}

local uci_helper = require("transformer.mapper.ucihelper")
local ubus = require("ubus")
local binding_wireless = {config = "wireless"}
local conn = ubus.connect()
local strmatch, format = string.match, string.format
local envBinding = { config = "env", sectionname = "var" }
local network = require("transformer.shared.common.network")

function M.isBaseIface(iface)
  return "0" == strmatch(iface, "%d+")
end

function M.getBsAp(iface)
  local data = conn:call("wireless.accesspoint", "get",  {})
  for k, v in pairs(data) do
    if v.ssid == iface then
      return k, v
    end
  end
  return nil
end

local function getAllSSID()
  local data = conn:call("wireless.ssid", "get",  { })
    if data == nil then
      return {}
    end
  local entries = {}
  for k in pairs(data) do
    entries[#entries + 1] = k
  end
  return entries
end

local function getSecurityMode(ap)
  binding_wireless.sectionname = ap
  binding_wireless.option = "security_mode"
  return uci_helper.get_from_uci(binding_wireless)
end

local function setWirelessUciValue(value, sectionName, option, commitapply)
  binding_wireless.sectionname = sectionName
  binding_wireless.option = option
  uci_helper.set_on_uci(binding_wireless, value, commitapply)
end

function M.getBandSteerPeerIface(key)
  local ssidData = getAllSSID()
  if ssidData and next(ssidData) then
    local tmpstr = strmatch(key, ".*_(%d+)")
    for _, v in pairs(ssidData) do
      if v ~= key then
          if not tmpstr then
            if not strmatch(v, ".*_(%d+)") then
              return v
            end
          else
            if tmpstr == strmatch(v, ".*_(%d+)") then
              return v
            end
          end
      end
    end
  end

  return nil, "To get band steer switching SSID failed."
end

function M.isBandSteerSectionConfigured(bandsteerID)
  local data = conn:call("wireless.bandsteer", "get", {})
  if not data then
      return false, "Please configure band steer section " .. bandsteerID
  end

  for k, _ in pairs(data) do
      if k == bandsteerID then
          return true
      end
  end

  return false, "Please configure band steer section " .. bandsteerID
end

function M.getBandSteerId(iface)
  local tmpstr = strmatch(iface, ".*_(%d+)")
  local bsID
  if not tmpstr then
      bsID = format("%s", "bs0")
  else
      bsID = format("%s", "bs" .. tmpstr)
  end

  --to judge whether the section configed or not
  local ret, errmsg = M.isBandSteerSectionConfigured(bsID)
  if not ret then
      return nil, errmsg
  end

  return bsID
end

function M.getApBandSteerId(ap)
  binding_wireless.sectionname = ap
  binding_wireless.option = "bandsteer_id"
  return uci_helper.get_from_uci(binding_wireless)
end

function M.isBandSteerEnabledByAp(ap)
  local bandsteerid = M.getApBandSteerId(ap)
  if bandsteerid and "" ~= bandsteerid and "off" ~= bandsteerid then
      return true
  end
  return false
end

local function getAllSSID()
  local data = conn:call("wireless.ssid", "get",  { })
    if data == nil then
      return {}
    end
  local entries = {}
  for k in pairs(data) do
    entries[#entries + 1] = k
  end
  return entries
end

--For 5G when bandsteer enabled, the ssid and authentication related option cannot be modified
function M.isBandSteerEnabledByIface(iface)
  local ap = M.getBsAp(iface)
  if type(ap) == 'string' then
      return M.isBandSteerEnabledByAp(ap)
  end

  return false
end

function M.canEnableBandSteer(apKey, apData, iface)
  if type(apKey) ~= 'string' or type(iface) ~= 'string' then
    return false, "Ap or Iface is invalid."
  end

  if not apData or not next(apData) or "1" ~= tostring(apData.admin_state) then
    return false, "Please enable network firstly."
  end

  local bandsteerID = M.getApBandSteerId(apKey)
  if bandsteerID and "" ~= bandsteerID and "off" ~= bandsteerID then
    return false, "Band steering has already been enabled."
  end

  if "wep" == getSecurityMode(apKey) then
    return false, "Band steering cannot be supported in wep mode."
  end

  local peerIface, errmsg = M.getBandSteerPeerIface(iface)
  if not peerIface then
    return false, errmsg
  end

  local peerAP, peerAPNode = M.getBsAp(peerIface)
  if not peerAP then
    return false, "Band steering switching node does not exist."
  end

  if "1" ~= tostring(peerAPNode.admin_state) then
    return false, "Please enable network for band steering switching node firstly."
  end

  if "wep" == getSecurityMode(peerAP) then
    return false, "Band steering cannot be supported in wep mode."
  end

  return true
end

function M.canDisableBandSteer(apKey, iface)
  if type(apKey) ~= 'string' then
    return false, "Ap is invalid."
  end

  local bandsteerid = M.getApBandSteerId(apKey)
  if not bandsteerid or "" == bandsteerid or "off" == bandsteerid then
    return false, "Band steering has already been disabled."
  end

  local peerIface = M.getBandSteerPeerIface(iface)
  if not peerIface then
    return false, "Band steering switching node does not exist."
  end

  local peerAP, peerAPNode = M.getBsAp(peerIface)
  if not peerAP then
    return false, "Band steering switching node does not exist."
  end

  return true
end

function M.setBandSteerPeerIfaceSSIDByLocalIface(baseiface, needsetiface, oper)
  if "1" == oper then
    --to get the baseiface ssid
    binding_wireless.sectionname = baseiface
    binding_wireless.option = "ssid"
    local baseifacessid = uci_helper.get_from_uci(binding_wireless)

    if "" ~= baseifacessid then
      binding_wireless.sectionname = needsetiface
      binding_wireless.option = "ssid"
      uci_helper.set_on_uci(binding_wireless, baseifacessid, commitapply)
    end
  else
    binding_wireless.sectionname = needsetiface
    binding_wireless.option = "ssid"
    envBinding.option = "commonssid_suffix"
    local suffix = uci_helper.get_from_uci(envBinding)
    uci_helper.set_on_uci(binding_wireless, uci_helper.get_from_uci(binding_wireless) .. suffix, commitapply)
  end

  return
end

function M.setBandSteerPeerIfaceSSIDValue(needsetiface, value)
  binding_wireless.sectionname = needsetiface
  binding_wireless.option = "ssid"
  uci_helper.set_on_uci(binding_wireless, value, commitapply)

  return
end

local function getBandSteerRelatedNode(apKey, apNode)
  local peerIface, errmsg = M.getBandSteerPeerIface(apNode.ssid)
  if not peerIface then
    return nil, errmsg
  end

  local bspeerap = M.getBsAp(peerIface)
  if not bspeerap then
    return nil, "Band steering switching node does not exist"
  end

  if M.isBaseIface(apNode.ssid) then
    return apKey, bspeerap, apNode.ssid, peerIface
  else
    return bspeerap, apKey, peerIface, apNode.ssid
  end
end

local function setBandSteerID(ap, bspeerap, bsid, commitapply)
  setWirelessUciValue(bsid, ap, "bandsteer_id", commitapply)
  setWirelessUciValue(bsid, bspeerap, "bandsteer_id", commitapply)
end

local function disableBandSteer(key, commitapply)
  local apData = network.getAccessPointInfo(key)
  if not apData or not next(apData) then
    return nil, "The related AP node cannot be found."
  end

  local ret, errmsg = M.canDisableBandSteer(key, apData.ssid)
  if not ret then
    return nil, errmsg
  end

  local baseap, needsetap, baseiface, needsetiface = getBandSteerRelatedNode(key, apData)
  setBandSteerID(baseap, needsetap, "off", commitapply)

  --to reset the ssid
  M.setBandSteerPeerIfaceSSIDByLocalIface(baseiface, needsetiface, "0", commitapply)
  return true
end

--1\Only the admin_state enabled, then enable bandsteering
--2\2.4G related ap will act as based node
local function enableBandSteer(key, commitapply)
  local apNode = network.getAccessPointInfo(key)
  if not apNode then
    return nil, "AP node is invalid."
  end

  local ret, errmsg = M.canEnableBandSteer(key, apNode, apNode.ssid)
  if not ret then
    return nil, errmsg
  end
  --to set the bandsteer ids
  local baseap, needsetap, baseiface, needsetiface = getBandSteerRelatedNode(key, apNode)
  local bsid, errorMsg = M.getBandSteerId(apNode.ssid)
  if not bsid then
    return nil, errorMsg
  end
  setBandSteerID(baseap, needsetap, bsid)
  M.setBandSteerPeerIfaceSSIDByLocalIface(baseiface, needsetiface, "1", commitapply)
  setBandSteerPeerApAuthentication(baseap, needsetap)
  return true
end

function M.setBandSteerValue(value, key, commitapply)
  local bandSteer, errMsg
  if value == "1" then
    bandSteer, errMsg = enableBandSteer(key, commitapply)
  else
    bandSteer, errMsg = disableBandSteer(key, commitapply)
  end
  if not bandSteer then
    return nil, errMsg
  end
  return bandSteer
end

return M
