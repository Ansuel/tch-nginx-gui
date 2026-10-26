local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local conn = require("transformer.mapper.ubus").connect()

local wirelessBinding = { config = "wireless" }
local bandSteerHelper = require("transformer.shared.bandsteerhelper")
local envBinding = { config = "env", sectionname = "var" }
local pairs, tostring = pairs, tostring
local configChanged

function M.getFromWireless(sectionname, option, default)
  wirelessBinding.sectionname = sectionname
  if option then
    wirelessBinding.option = option
    wirelessBinding.default = default
    return uciHelper.get_from_uci(wirelessBinding)
  end
  return uciHelper.getall_from_uci(wirelessBinding)
end

function M.setOnWireless(sectionname, option, value, commitapply)
  wirelessBinding.sectionname = sectionname
  wirelessBinding.option = option
  uciHelper.set_on_uci(wirelessBinding, value, commitapply)
  configChanged = true
end

--- Retrieves the ap for the given iface
-- @function getAPFromIface
-- @param iface interface name
-- @return ap name if present or ""
function M.getAPFromIface(iface)
  local ifaceVal = iface:gsub("_remote", "")
  local apInfo = conn:call("wireless.accesspoint", "get", {}) or {}
  for ap, data in pairs(apInfo) do
    if data.ssid == ifaceVal then
      return ap
    end
  end
  return ""
end

--- Retrieves the radio for the given interface
-- @function getRadioFromIface
-- @param iface interface name
-- @return the radio name if present or ""
function M.getRadioFromIface(iface)
  local ifaceVal = iface:gsub("_remote", "")
  local radio = M.getFromWireless(ifaceVal, "device")
  if radio == "" then
    local ssidInfo = conn:call("wireless.ssid", "get", { name = ifaceVal }) or {}
    radio = ssidInfo[ifaceVal] and ssidInfo[ifaceVal].radio or ""
  end
  return radio
end

local ubusTable = {
  ["accesspoint"] = "wireless.accesspoint",
  ["security"] = "wireless.accesspoint.security",
  ["ssid"] = "wireless.ssid",
  ["radio"] = "wireless.radio",
  ["radiostats"] = "wireless.radio.stats",
  ["acs"] = "wireless.radio.acs",
  ["upgrade"] = "wireless.radio.remote.upgrade",
}

function M.getWirelessUbus(ubus, iface, option, default)
  default = default or ""
  if ubus == "accesspoint" or ubus == "security" then
    iface = M.getAPFromIface(iface)
  end
  local info = conn:call(ubusTable[ubus], "get", { name = iface }) or {}
  if option then
    return info[iface] and tostring(info[iface][option] or default) or default
  end
  return info[iface] or {}
end

--- Retrieves the bandsteering related nodes
-- @function getBandSteerRelatedNode
-- @param ap the accesspoint name
-- @param key the interface name
-- @return ap base accesspoint
-- @return peerAP peer accesspoint
-- @return key the base interface
-- @return iface the peer interface
function M.getBandSteerRelatedNode(ap, key)
  local iface = bandSteerHelper.getBandSteerPeerIface(key)
  if not iface then
    return nil, "Band steering switching node does not exist."
  end
  local peerAP = M.getAPFromIface(iface)
  if peerAP == "" then
    return nil, "Band steering peer AP is invalid."
  end
  if bandSteerHelper.isBaseIface(peerAP) then
    return peerAP, ap, iface, key
  else
    return ap, peerAP, key, iface
  end
end

--- Sets the bandsteering_id in the base and peer accesspoints
-- @function setBandSteerID
-- @param ap base accesspoint
-- @param relatedAP peer accesspoint
-- @param bsid the bandsteering id
-- @param enable boolean value to indicate enable/disable bandsteer
function M.setBandSteerID(ap, relatedAP, bsid, enable, commitapply)
  if enable then
    -- set the "bandsteer_id" option in both the AP and related AP to enable BandSteer
    M.setOnWireless(ap, "bandsteer_id", bsid, commitapply)
    M.setOnWireless(relatedAP, "bandsteer_id", bsid, commitapply)
  else
    -- set the "bandsteer_id" option to "off" in both the AP and related AP to disable BandSteer
    M.setOnWireless(ap, "bandsteer_id", "off", commitapply)
    M.setOnWireless(relatedAP, "bandsteer_id", "off", commitapply)
  end
end

--- Sets the SSID of the bandsteer peer node
-- @function setBandSteerPeerIfaceSSID
-- @param baseIface the base interface
-- @param relatedIface the peer interface
-- @param enable boolean value to indicate enable/disable bandsteer
local function setBandSteerPeerIfaceSSID(baseIface, relatedIface, enable, commitapply)
  local ssid
  if enable then
    ssid = M.getFromWireless(baseIface, "ssid")
  else
    envBinding.option = "commonssid_suffix"
    local suffix = uciHelper.get_from_uci(envBinding)
    ssid = M.getFromWireless(relatedIface, "ssid")
    ssid = ssid ~= "" and ssid .. suffix or ""
  end
  M.setOnWireless(relatedIface, "ssid", ssid, commitapply)
end

--- Enables bandsteering
-- @function enableBandSteer
-- @param key the interface name
function M.enableBandSteer(key, commitapply)
  local ap = M.getAPFromIface(key)
  local ret, err = bandSteerHelper.canEnableBandSteer(ap, M.getWirelessUbus("accesspoint", key), key)
  if not ret then
    return nil, err
  end
  local bsid, errmsg = bandSteerHelper.getBandSteerId(key)
  if not bsid then
    return nil, errmsg
  end
  local baseAP, relatedAP, baseIface, relatedIface = M.getBandSteerRelatedNode(ap, key)
  M.setBandSteerID(baseAP, relatedAP, bsid, true, commitapply)
  setBandSteerPeerIfaceSSID(baseIface, relatedIface, true, commitapply)
  -- set the authentication according to base AP authentication
  M.setOnWireless(relatedAP, "security_mode", M.getFromWireless(baseAP, "security_mode"), commitapply)
  M.setOnWireless(relatedAP, "wpa_psk_key", M.getFromWireless(baseAP, "wpa_psk_key"), commitapply)
end

-- Disables bandsteering
-- @function disableBandSteer
-- @param key the interface name
function M.disableBandSteer(key, commitapply)
  local ap = M.getAPFromIface(key)
  local ret, err = bandSteerHelper.canDisableBandSteer(ap, key)
  if not ret then
    return nil, err
  end
  local baseAP, relatedAP, baseIface, relatedIface = M.getBandSteerRelatedNode(ap, key)
  M.setBandSteerID(baseAP, relatedAP, "off", nil, commitapply)
  setBandSteerPeerIfaceSSID(baseIface, relatedIface, nil, commitapply)
end

--- Modifies the cofiguration of bandsteer peer node
-- @function modifyBSPeerNodeAuthentication
-- @param option the option to be modified
-- @param value the value to be set in the given option
-- @param iface the interface name
function M.modifyBSPeerNodeAuthentication(option, value, iface, commitapply)
  local ap = M.getAPFromIface(iface)
  local bandSteerid = bandSteerHelper.getApBandSteerId(ap)
  if not bandSteerid or bandSteerid == "" or bandSteerid == "off" then
    return nil, "Bandsteer id is not available or disabled"
  end
  local bsPeerIface = bandSteerHelper.getBandSteerPeerIface(iface)
  if not bsPeerIface then
    return nil, "Band steering switching node does not exist."
  end
  if bandSteerHelper.isBaseIface(iface) then
    local sectionname
    if option == "ssid" then
      sectionname = bsPeerIface
    else
      local bsPeerAP = M.getAPFromIface(bsPeerIface)
      sectionname = bsPeerAP
    end
    M.setOnWireless(sectionname, option, value, commitapply)
  end
  return
end

function M.getStationDataFromIface(iface, macAddress, option, default)
  local ssid = M.getFromWireless(iface, "ssid")
  local ap = M.getAPFromIface(iface)
  local stationInfo = conn:call("wireless.accesspoint.station", "get", { name = ap }) or {}
  if stationInfo[ap] and option then
    for mac, data in pairs(stationInfo[ap]) do
      if mac == macAddress and data.state:match("Associated") and data.last_ssid == ssid then
        return tostring(data[option] or default)
      end
    end
    return default
  end
  return stationInfo[ap] or {}
end

function M.getDataFromWDS(key, option, default)
  local wdsIdx = key:match("[%S+%_]+%_(wds%S+)%_[%da-fA-F:]+$")
  local wdsData = conn:call("wireless.wds", "get", {}) or {}
  return wdsData[wdsIdx] and wdsData[wdsIdx][option] and tostring(wdsData[wdsIdx][option]) or default
end

function M.commit()
  if configChanged then
    uciHelper.commit(wirelessBinding)
    configChanged = false
  end
end

function M.revert()
  if configChanged then
    uciHelper.revert(wirelessBinding)
    configChanged = false
  end
end

return M
