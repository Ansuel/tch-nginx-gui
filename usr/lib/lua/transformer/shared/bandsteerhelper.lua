local M = {}

local uci_helper = require("transformer.mapper.ucihelper")
local ubus = require("ubus")
local binding_wireless = {config = "wireless"}
local conn = ubus.connect()
local strmatch, format = string.match, string.format

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

  return false
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
    uci_helper.set_on_uci(binding_wireless, uci_helper.get_from_uci(binding_wireless) .. "-5G", commitapply)
  end

  return
end

function M.setBandSteerPeerIfaceSSIDValue(needsetiface, value)
  binding_wireless.sectionname = needsetiface
  binding_wireless.option = "ssid"
  uci_helper.set_on_uci(binding_wireless, value, commitapply)

  return
end

return M
