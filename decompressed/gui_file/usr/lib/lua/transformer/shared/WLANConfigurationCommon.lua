local uciHelper = require("transformer.mapper.ucihelper")
local ubus = require("ubus")
local bandSteerHelper = require("transformer.shared.bandsteerhelper")
local nwWifi = require("transformer.shared.wifi")
local nwCommon = require("transformer.mapper.nwcommon")

local conn = ubus.connect()
local wirelessBinding = { config = "wireless" }
local wirelessDefaultsBinding = { config = "wireless-defaults" }
local pairs, string, table, tonumber, tostring = pairs, string, table, tonumber, tostring
local envBinding = { config = "env", sectionname = "var" }
local floor = math.floor
local transactions = {}

local beaconTypeMap = {
  ["none"]         = "Basic",
  ["wep"]          = "Basic",
  ["wpa-psk"]      = "WPA",
  ["wpa2-psk"]     = "11i",
  ["wpa-wpa2-psk"] = "WPAand11i",
  ["wpa"]          = "WPA",
  ["wpa2"]         = "11i",
  ["wpa-wpa2"]     = "WPAand11i",
  ["WPA"]          = "wpa",
  ["WPAand11i"]    = "wpa-wpa2",
  ["11i"]          = "wpa2"
}

local encryptionModeMap = {
  wep  = "WEPEncryption",
  none = "None"
}

local wpaAuthenticationModeMap = {
  ["wpa2-psk"]     = "PSKAuthentication",
  ["wpa-wpa2-psk"] = "PSKAuthentication",
  ["wpa2"]         = "EAPAuthentication",
  ["wpa-wpa2"]     = "EAPAuthentication",
}

local authServiceModeMap = {
  ["none"]         = "None",
  ["wep"]          = "None",
  ["wpa"]          = "RadiusClient",
  ["wpa2"]         = "RadiusClient",
  ["wpa-wpa2"]     = "RadiusClient",
  ["None"]         = "none",
  ["LinkAuthentication"] = "wpa2-psk",
  ["RadiusClient"] = "wpa2"
}

local powerLevelMap = {
  ["-6"] = "1",
  ["-3"] = "2",
  ["-1"] = "3",
  ["0"] = "4",
  ["1"] = "-6",
  ["2"] = "-3",
  ["3"] = "-1",
  ["4"] = "0",
}

local transmitPowerMap = {
  ["-6"] = "25",
  ["-3"] = "50",
  ["-1"] = "75",
  ["0"]  = "100",
  ["25"] = "-6",
  ["50"] = "-3",
  ["75"] = "-1",
  ["100"]= "0",
}

local wpsStateMap = {
    configured    = "Configured",
    notconfigured = "Not configured",
}

local DFSChannels = { 52, 56, 60, 64, 100, 104, 108, 112, 116, 132, 136, 140 }

local function getFromUci(sectionname, option, default)
  wirelessBinding.sectionname = sectionname
  if option then
    wirelessBinding.option = option
    wirelessBinding.default = default
    return uciHelper.get_from_uci(wirelessBinding)
  end
  return uciHelper.getall_from_uci(wirelessBinding)
end

local function commit()
  for config, changed in pairs(transactions) do
    if changed then
      uciHelper.commit({ config = config })
      transactions[config] = false
    end
  end
end

local function revert()
  for config, changed in pairs(transactions) do
    if changed then
      uciHelper.revert({ config = config })
      transactions[config] = false
    end
  end
  transactions = {}
end

local function getFromWirelessDefaults(sectionname, option, default)
  wirelessDefaultsBinding.sectionname = sectionname
  if option then
    wirelessDefaultsBinding.option = option
    wirelessDefaultsBinding.default = default
    return uciHelper.get_from_uci(wirelessDefaultsBinding)
  end
  return uciHelper.getall_from_uci(wirelessDefaultsBinding)
end

local function setOnUci(sectionname, option, value, commitapply)
  wirelessBinding.sectionname = sectionname
  wirelessBinding.option = option
  uciHelper.set_on_uci(wirelessBinding, value, commitapply)
  transactions[wirelessBinding.config] = true  
end

local function deleteOnUci(sectionname, commitapply)
  wirelessBinding.sectionname = sectionname
  wirelessBinding.option = nil
  uciHelper.delete_on_uci(wirelessBinding, commitapply)
  transactions[wirelessBinding.config] = true
end

--- Retrieves the ap for the given iface
-- @function getAPFromIface
-- @param iface interface name
-- @return ap name if present or ""
local function getAPFromIface(iface)
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
local function getRadioFromIface(iface)
  local ifaceVal = iface:gsub("_remote", "")
  local radio = getFromUci(ifaceVal, "device")
  if radio == "" then
    local ssidInfo = conn:call("wireless.ssid", "get", { name = ifaceVal }) or {}
    radio = ssidInfo[ifaceVal] and ssidInfo[ifaceVal].radio or ""
  end
  return radio
end

--- retrieve the accesspoint data
-- @function getDataFromAP
-- @param iface interface name
-- @param option if present only particular value is returned(used in get) else the entire AP info is returned(used in getall)
-- @return the table containing AP information for the given interface if present or {}
local function getDataFromAP(iface, option)
  local ap = getAPFromIface(iface)
  local apInfo = conn:call("wireless.accesspoint", "get", { name = ap }) or {}
  if option then
    return apInfo[ap] and tostring(apInfo[ap][option] or "") or ""
  end
  return apInfo[ap] and apInfo[ap] or {}
end

--- Retrieve the accesspoint security data
-- @function getDataFromAPSecurity
-- @param iface interface name
-- @param option if present only particular value is returned(used in get) else the entire AP security info is returned(used in getall)
-- @return the table containing AP Security information for the given interface or {}
local function getDataFromAPSecurity(iface, option)
  local ap = getAPFromIface(iface)
  local apSecInfo = conn:call("wireless.accesspoint.security", "get", { name = ap }) or {}
  if option then
    return apSecInfo[ap] and tostring(apSecInfo[ap][option] or "") or ""
  end
  return apSecInfo[ap] or {}
end

--- Retrieves the SSID information for the given interface
-- @function getDataFromSsid
-- @param iface interface name
-- @param option if present only particular value is returned(used in get) else the entire SSID info is returned(used in getall)
-- @return the table containing the SSID information for the given interface or {}
local function getDataFromSsid(iface, option)
  local ifaceVal = iface:gsub("_remote", "")
  local ssidInfo = conn:call("wireless.ssid", "get", { name = ifaceVal }) or {}
  if option then
    return ssidInfo[ifaceVal] and tostring(ssidInfo[ifaceVal][option] or "") or ""
  end
  return ssidInfo[ifaceVal] or {}
end

--- Retrieve the Radio information
-- @function getDataFromRadio
-- @param radio radio name
-- @param option if present only particular value is returned(used in get) else the entire radio info is returned(used in getall)
-- @return the table containing the radio information or {}
local function getDataFromRadio(radio, option)
  local radioInfo = conn:call("wireless.radio", "get", { name = radio }) or {}
  if option then
    return radioInfo[radio] and tostring(radioInfo[radio][option] or "") or ""
  end
  return radioInfo[radio] or {}
end

--- Retrieves the Radio stats information
-- @function getDataFromRadioStats
-- @param radio radio name
-- @param option if present only particular value is returned(used in get) else the entire radio stats info is returned(used in getall)
-- @return the table containing the radio stats information or {}
local function getDataFromRadioStats(radio, option)
  local radioStatsData = conn:call("wireless.radio.stats", "get", { name = radio }) or {}
  if option then
    return radioStatsData[radio] and tostring(radioStatsData[radio][option] or "") or ""
  end
  return radioStatsData[radio] or {}
end

--- Retrieves the acs information
-- @function getDataFromAcs
-- @param radio radio name
-- @param option if present only particular value is returned(used in get) else the entire radio stats info is returned(used in getall)
-- @return the table containing the acs information or {}
local function getDataFromAcs(radio, option)
  local acsData = conn:call("wireless.radio.acs", "get", { name = radio }) or {}
  if option then
    return acsData[radio] and tostring(acsData[radio][option] or "") or ""
  end
  return acsData[radio] or {}
end

--- Retrieves the remote upgrade information
-- @function getDataFromRadioRemoteUpgrade
-- @param radio radio name
-- @param option if present only particular value is returned(used in get) else the entire remote upgrade info is returned(used in getall)
-- @return the table containing the remote upgrade information or {}
local function getDataFromRadioRemoteUpgrade(radio, option)
  local remoteUpgradeData = conn:call("wireless.radio.remote.upgrade", "get", { name = radio }) or {}
  if option then
    return remoteUpgradeData[radio] and tostring(remoteUpgradeData[radio][option] or "") or ""
  end
  return remoteUpgradeData[radio] or {}
end

--- Retrieves the bandsteering related nodes
-- @function getBandSteerRelatedNode
-- @param ap the accesspoint name
-- @param key the interface name
-- @return ap base accesspoint
-- @return peerAP peer accesspoint
-- @return key the base interface
-- @return iface the peer interface
local function getBandSteerRelatedNode(ap, key)
  local iface = bandSteerHelper.getBandSteerPeerIface(key)
  if not iface then
    return nil, "Band steering switching node does not exist."
  end
  local peerAP = getAPFromIface(iface)
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
local function setBandSteerID(ap, relatedAP, bsid, enable, commitapply)
  if enable then
    -- set the "bandsteer_id" option in both the AP and related AP to enable BandSteer
    setOnUci(ap, "bandsteer_id", bsid, commitapply)
    setOnUci(relatedAP, "bandsteer_id", bsid, commitapply)
  else
    -- set the "bandsteer_id" option to "off" in both the AP and related AP to disable BandSteer
    setOnUci(ap, "bandsteer_id", "off", commitapply)
    setOnUci(relatedAP, "bandsteer_id", "off", commitapply)
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
    ssid = getFromUci(baseIface, "ssid")
  else
    ssid = getFromUci(relatedIface, "ssid")
    envBinding.option = "commonssid_suffix"
    local suffix = uciHelper.get_from_uci(envBinding)
    ssid = ssid ~= "" and ssid .. suffix or ""
  end
  setOnUci(relatedIface, "ssid", ssid, commitapply)
end

--- Enables bandsteering
-- @function enableBandSteer
-- @param key the interface name
local function enableBandSteer(key, commitapply)
  local ap = getAPFromIface(key)
  local ret, err = bandSteerHelper.canEnableBandSteer(ap, getDataFromAP(key), key)
  if not ret then
    return nil, err
  end
  local bsid, errmsg = bandSteerHelper.getBandSteerId(key)
  if not bsid then
    return nil, errmsg
  end
  local baseAP, relatedAP, baseIface, relatedIface = getBandSteerRelatedNode(ap, key)
  setBandSteerID(baseAP, relatedAP, bsid, true, commitapply)
  setBandSteerPeerIfaceSSID(baseIface, relatedIface, true, commitapply)
  -- set the authentication according to base AP authentication
  setOnUci(relatedAP, "security_mode", getFromUci(baseAP, "security_mode"), commitapply)
  setOnUci(relatedAP, "wpa_psk_key", getFromUci(baseAP, "wpa_psk_key"), commitapply)
end

-- Disables bandsteering
-- @function disableBandSteer
-- @param key the interface name
local function disableBandSteer(key, commitapply)
  local ap = getAPFromIface(key)
  local ret, err = bandSteerHelper.canDisableBandSteer(ap, key)
  if not ret then
    return nil, err
  end
  local baseAP, relatedAP, baseIface, relatedIface = getBandSteerRelatedNode(ap, key)
  setBandSteerID(baseAP, relatedAP, "off", nil, commitapply)
  setBandSteerPeerIfaceSSID(baseIface, relatedIface, nil, commitapply)
end

--- Modifies the cofiguration of bandsteer peer node
-- @function modifyBSPeerNodeAuthentication
-- @param option the option to be modified
-- @param value the value to be set in the given option
-- @param iface the interface name
local function modifyBSPeerNodeAuthentication(option, value, iface, commitapply)
  local ap = getAPFromIface(iface)
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
      local bsPeerAP = getAPFromIface(bsPeerIface)
      sectionname = bsPeerAP
    end
    setOnUci(sectionname, option, value, commitapply)
  end
  return
end

--- Retrieves the standard used by the given radio
-- @function getRadioStandard
-- @param radio the radio name
-- @return the standard value
local function getRadioStandard(radio)
  local standard = getDataFromRadio(radio, "standard")
  if standard:find("n") then
    return "n"
  elseif standard:find("g") then
    if standard:find("b") then
      return "g"
    else
      return "g-only"
    end
  else
    return "b"
  end
end

--- Retrieves the channels used by the given interface
-- @function getChannels
-- @param key the interface name
-- @param val the channel value(passed from getall and it is nil when this function is called from get)
-- @param channel ubus option to fetch the channel
-- @return the string of comma separated channels
local function getChannels(key, val, channel)
  local channels
  if not val then
    local radio = getRadioFromIface(key)
    channels = getDataFromRadio(radio, channel)
  else
    channels = val
  end
  channels = channels:gsub("%s+", ",")
  return channels:match("^,?(.-),?$") or ""
end

--- Retrieves the bsslist info
-- @function getACSBssList
-- @param radio the radio name
-- @param return the string of bssinfo
local function getACSBssList(radio)
  local bssList = conn:call("wireless.radio.bsslist", "get", { name = radio }) or {}
  local bssData = ""
  for mac, data in pairs(bssList[radio] or {}) do
    -- all the colons are removed from the mac
    local bssid = mac:gsub(":","") or ""
    local bssInfo = string.format("%s:%s:%s:%s:%s:%s;", bssid, data.ssid or "", data.channel or "", data.rssi or "", data.sec or "", data.cap or "")
    if ((#bssData + #bssInfo) <= 16*1024) then
      bssData = bssData .. bssInfo
    else
      return bssData
    end
  end
  return bssData
end

--- Validates whether the pin following the Wifi certification, we need to check if the pin with 8 digits the last digit is the
-- the checksum of the others
-- @function validatePin
-- @param pin the 8 digit pin to be validated
-- @return true if the given pin is valid else nil and error is returned
local function validatePin(pin)
  -- check whether the last digit of the pin is the the checksum of the others
  local accum = 0
  accum = accum + 3*(floor(pin/10000000)%10)
  accum = accum + (floor(pin/1000000)%10)
  accum = accum + 3*(floor(pin/100000)%10)
  accum = accum + (floor(pin/10000)%10)
  accum = accum + 3*(floor(pin/1000)%10)
  accum = accum + (floor(pin/100)%10)
  accum = accum + 3*(floor(pin/10)%10)
  accum = accum + (pin%10)
  if (accum % 10) == 0 then
    return true
  end
  return nil, "Invalid Pin"
end

--- validate WPS pin code
-- @function validateWPSPIN
-- @param pin the pin to be validated
-- @return true if the given pin is valid else nil and error is returned
local function validateWPSPIN(pin)
  if pin == "" or pin:match("^%d%d%d%d$") then
    return true
  end
  if pin:match("^%d%d%d%d%d%d%d%d$") then
    return validatePin(pin)
  end
  return nil, "Invalid Pin"
end

--- Retrieves the state of ap
-- @function getEnable
-- @param key the interface name(eg. wl0)
-- @return the value from uci(if present) or from ubus
local function getEnable(key)
  local ap = getAPFromIface(key)
  local val = getFromUci(ap, "state")
  if val ~= "" then
    return val
  end
  return getDataFromAP(key, "admin_state")
end

--- Retrieves the security mode of ap
-- @function getAPMode
-- @param key the interface name(eg. wl0)
-- @return the value from uci(if present) or from ubus
local function getAPMode(key)
  local ap = getAPFromIface(key)
  local mode = getFromUci(ap, "security_mode")
  if mode == "" then
    mode = getDataFromAPSecurity(key, "mode")
  end
  return mode
end

--- Retrieves the acl mode of ap
-- @function getMACAddressControlEnabled
-- @param key the interface name(eg. wl0)
-- @return the value "1" if acl mode is enabled or "0" is returned
local function getMACAddressControlEnabled(key)
  local ap = getAPFromIface(key)
  local aclMode = getFromUci(ap, "acl_mode")
  return (aclMode == "lock" or aclMode == "register") and "1" or "0"
end

local ratePatternMap = {
  BasicDataTransmitRates       = "([%d.]+)%(b%)",
  OperationalDataTransmitRates = "([%d.]+)",
  PossibleDataTransmitRates    = "([%d.]+)"
}

--- Retrieves the transmit rates for the given iface
-- @function getRates
-- @param param the parameter name(BasicDataTransmitRates/OperationalDataTransmitRates/PossibleDataTransmitRates)
-- @return the string of comma separated rates
local function getRates(param, key)
  local radio = getRadioFromIface(key)
  local rateSet = getFromUci(radio, "rateset")
  local rates = {}
  for rate in rateSet:gmatch(ratePatternMap[param]) do
    rates[#rates +1] = rate
  end
  return table.concat(rates, ",")
end

--- Retrieves the value of ssid advertisement enabled
-- @function getSSIDAdvertisementEnabled
-- @param key the interface name
-- @return the value from uci(if present) or from ubus
local function getSSIDAdvertisementEnabled(key)
  local ap = getAPFromIface(key)
  local val = getFromUci(ap, "public")
  if val ~= "" then
    return val
  end
  return getDataFromAP(key, "public")
end

--- Retrieves the state of radio
-- @function getRadioEnabled
-- @param key the interface name
-- @return the value from uci(if present) or from ubus
local function getRadioEnabled(key)
  local radio = getRadioFromIface(key)
  local state = getFromUci(radio, "state")
  if state == "" then
    state = getDataFromRadio(radio, "admin_state")
  end
  return state ~= "" and tostring(state) or "0"
end

--- Retrieves the security mode of ap
-- @function getAuthenticationServiceMode
-- @param key the interface name
-- @return the value from uci(if present) or from ubus
local function getAuthenticationServiceMode(key)
  local ap = getAPFromIface(key)
  local mode = getFromUci(ap, "security_mode")
  if mode == "" then
    mode = getDataFromAPSecurity(key, "mode")
  end
  return authServiceModeMap[mode] or "LinkAuthentication"
end

--- set authentication mode for ap
-- @function setAuthenticationMode
-- @param key the interface name
-- @param value the value to be set in the given option
local function setAuthenticationMode(key, value, commitapply)
  local ap = getAPFromIface(key)
  local secMode = getDataFromAPSecurity(key, "mode")
  local val
  if not wpaAuthenticationModeMap[secMode] then
    return nil, "Authentication mode cannot be set for this capability"
  end
  if value == "PSKAuthentication" then
    if (secMode == "wpa-wpa2" or secMode == "wpa-wpa2-psk") then
      val = "wpa-wpa2-psk"
    else
      val = "wpa2-psk"
    end
  elseif value == "EAPAuthentication" then
    if (secMode == "wpa-wpa2" or secMode == "wpa-wpa2-psk") then
      val = "wpa-wpa2"
    else
      val = "wpa2"
    end
  end
  setOnUci(ap, "security_mode", val, commitapply)
  modifyBSPeerNodeAuthentication("security_mode", val, key, commitapply)
end

local uciACSOptionMap = {
  X_000E50_ACSCHMonitorPeriod   = "acs_channel_monitor_period",
  X_000E50_ACSRescanPeriod      = "acs_rescan_period",
  X_000E50_ACSRescanDelayPolicy = "acs_rescan_delay_policy",
  X_000E50_ACSRescanDelay       = "acs_rescan_delay",
  X_000E50_ACSRescanDelayMaxEvents = "acs_rescan_delay_max_events",
  X_000E50_ACSCHFailLockoutPeriod  = "acs_channel_fail_lockout_period",
}

local ubusACSOptionMap = {
  X_000E50_ACSCHMonitorPeriod   = "channel_monitor_period",
  X_000E50_ACSRescanPeriod      = "rescan_period",
  X_000E50_ACSRescanDelayPolicy = "rescan_delay_policy",
  X_000E50_ACSRescanDelay       = "rescan_delay",
  X_000E50_ACSRescanDelayMaxEvents = "rescan_delay_max_events",
  X_000E50_ACSCHFailLockoutPeriod  = "channel_lockout_period",
}

--- Retrieves the acs info for the given param
-- @function getACSOptionValue
-- @param the parameter name
-- @param key the interface name
-- @return the value for the given param from uci(if present) or from ubus
local function getACSOptionValue(param, key)
  local radio = getRadioFromIface(key)
  local val = getFromUci(radio, uciACSOptionMap[param])
  if val == "" then
    val = getDataFromAcs(radio, ubusACSOptionMap[param])
  end
  return val
end

--- retrieves the channel mode(Auto/Manual)
-- @function getChannelMode
-- @param key the interface name
-- @return Auto/Manual based on the mode of the channel
local function getChannelMode(key)
  local radio = getRadioFromIface(key)
  local channel = getFromUci(radio, "channel")
  if channel == "" then
    channel = getDataFromRadio(radio, "requested_channel")
  end
  return (channel == "auto" ) and "Auto" or "Manual"
end

--- retrieves the transmit power of the radio
-- @function getTransmitPower
-- @param key the interface name
-- @return transmit power value
local function getTransmitPower(key)
  local radio = getRadioFromIface(key)
  local power = getFromUci(radio, "tx_power_adjust")
  return power == "" and "50" or transmitPowerMap[power] or ""
end

local uciUpgradeOptionMap = {
  X_000E50_UpgradeURL         = "remote_upgrade_url",
  X_000E50_UpgradeCheckPeriod = "remote_upgrade_check_period"
}

local ubusUpgradeOptionMap = {
  X_000E50_UpgradeURL         = "url",
  X_000E50_UpgradeCheckPeriod = "check_period"
}

--- Retrieves the remote upgrade information
-- @function getUpgradeInfo
-- @param the parameter name
-- @param key the interface name
-- @return the value for the given param from uci(if present) or the value is retrieved from ubus
local function getUpgradeInfo(param, key)
  local radio = getRadioFromIface(key)
  local val = getFromUci(radio, uciUpgradeOptionMap[param])
  if val == "" then
    val = getDataFromRadioRemoteUpgrade(radio, ubusUpgradeOptionMap[param]) or ""
  end
  return val
end

--- Sets the device password
-- @function setDevicePassword
-- @param value the pin to be set
-- @param key the interface name
local function setDevicePassword(value, key)
  local ap = getAPFromIface(key)
  local pin = value
  local res, err = validateWPSPIN(value)
  if res then
    conn:call("wireless.accesspoint.wps", "enrollee_pin", { name = ap, value = pin })
  else
    return nil, err
  end
end

local function getUUID(key)
  local uuid = getDataFromAP(key, "uuid")
  local uuidValue = {}
  local pattern = { uuid:sub(1,8), uuid:sub(9,12), uuid:sub(13,16), uuid:sub(17,20), uuid:sub(21,32) }
  if uuid ~= "" then
    for _, v in ipairs(pattern) do
      uuidValue[ #uuidValue + 1] = v
    end
  end
  return table.concat(uuidValue, "-")
end

local function getConfigurationState(key)
  local ap = getAPFromIface(key)
  local state = getFromUci(ap, "wsc_state")
  if state == "" then
    local data = conn:call("wireless.accesspoint.wps", "get", { name = ap }) or {}
    state = data[ap] and data[ap].wsc_state or ""
  end
  return wpsStateMap[state] or ""
end

--- retrieves either allowed or denied MAC addresses
-- @function getMACAddresses
-- @param iface the interface name
-- @param option the option to get either allowed or denied MAC addresses
local function getMACAddresses(iface, option)
  local macList = {}
  local result = getFromUci(getAPFromIface(iface), option)
  if result ~= "" then
    for _,v in ipairs(result) do
      macList[#macList+1] = v
    end
  end
  return table.concat(macList, ',')
end

--- sets either allowed or denied MAC addresses
-- @function setMACAddresses
-- @param iface the interface name
-- @param option the option to set either allowed or denied MAC addresses
local function setMACAddresses(iface, option, value)
  local macList = {}
  for mac in string.gmatch(value, '([^,]+)') do
    if nwCommon.isMAC(mac) then
      macList[#macList + 1] = mac
    else
      return nil, "Invalid MAC address; cannot set"
    end
  end
  setOnUci(getAPFromIface(iface), option, macList, commitapply)
end

--- returns the supported standards list
-- @function convertToList
-- @param standards the supported standards
local function convertToList(standards)
  local stdList = {}
  for std in standards:gmatch("[abgn]c?") do
    stdList[#stdList+1] = std
  end
  return table.concat(stdList, ",")
end

--- Deletes existing section and creates new section
-- @param sectionType section type
-- @param sectionName section name
local function createSection(sectionType, sectionName)
  deleteOnUci(sectionName, commitapply)
  wirelessBinding.sectionname = sectionName
  uciHelper.set_on_uci(wirelessBinding, sectionType)
end

--- Restores the default configuration from wireless-defaults config
-- @param sectionType section type
-- @param sectionName section name
local function restoreSection(sectionType, sectionName)
  createSection(sectionType, sectionName)
  local wirelessDefaults = getFromWirelessDefaults(sectionName)
  for option, value in pairs(wirelessDefaults) do
    if not option:match("^%.") then
      setOnUci(sectionName, option, value, commitapply)
    end
  end
end

--- Converts channel string into list
-- @param str channel string
local function channelStrToList(str)
  local list = {}
  for channel in str:gmatch("(%d+)") do
    list[#list+1] = tonumber(channel)
  end
  return list
end

--- Checks if the given channel is present in the given channel list
-- @param channels channels list
-- @param chan channel number
local function channelExist(channels, chan)
  for _, channel in pairs(channels) do
    if chan == channel then
      return true
    end
  end
  return false
end

--- Checks whether DFS channels are enabled
-- @param radio the radio name
local function getDFSStatus(radio)
  local channels = channelStrToList(getFromUci(radio, "allowed_channels"))
  for _, channel in pairs(channels) do
    if channelExist(DFSChannels, channel) then
      return "1"
    end
  end
  return "0"
end

--- Adds DFS channels to allowed channels list
-- @param channels the allowed channels list
local function addDFSChannels(channels)
  for _, dfsChannel in pairs(DFSChannels) do
    local exist = channelExist(channels, dfsChannel)
    if not exist then
      channels[#channels + 1] = tonumber(dfsChannel)
    end
  end
  table.sort(channels)
  return table.concat(channels, " ")
end

--- Removes DFS channels from allowed channels list
-- @param channels the allowed channels list
local function removeDFSChannels(channels)
  for key, channel in pairs(channels) do
    if channelExist(DFSChannels, channel) then
      channels[key] = nil
    end
  end
  table.sort(channels)
  return table.concat(channels, " ")
end

local M = {}

M.getMappings = function(commitapply)

  local wepKeys = {}
  local wepKeyIndex = {}
  uciHelper.foreach_on_uci({ config = "wireless", sectionname = "wifi-ap" }, function(s)
    local name = s[".name"]
    wepKeyIndex[name] = 1
    wepKeys[name] = { "", "", "", "" }
  end)

  local getWLANDevice = {
    WMMEnable = "1",
    UAPSDEnable = "0",
    WMMSupported = "1",
    UAPSDSupported = "0",
    Enable = function(mapping, param, key)
      return getEnable(key)
    end,
    Status = function(mapping, param, key)
      local status = getDataFromSsid(key, "oper_state")
      return tostring(status) == "1" and "Up" or "Disabled"
    end,
    BSSID = function(mapping, param, key)
      return getDataFromSsid(key, "bssid")
    end,
    MaxBitRate = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local bitRate = getDataFromRadio(radio, "max_phy_rate")
      return bitRate ~= "" and tostring(tonumber(bitRate)/1000) or "Auto"
    end,
    Channel = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local val = getFromUci(radio, "channel")
      if val ~= "" and val ~= "auto" then
        return val
      end
      return getDataFromRadio(radio, "channel")
    end,
    Name = function(mapping, param, key)
      return key:gsub("_remote", "") or ""
    end,
    SSID = function(mapping, param, key)
      local iface = key:gsub("_remote", "")
      return getFromUci(iface, "ssid")
    end,
    TransmitPowerSupported = "25,50,75,100",
    TransmitPower = function(mapping, param, key)
      return getTransmitPower(key)
    end,
    BeaconType = function(mapping, param, key)
      return beaconTypeMap[getAPMode(key)] or ""
    end,
    MACAddressControlEnabled = function(mapping, param, key)
      return getMACAddressControlEnabled(key)
    end,
    Standard = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getRadioStandard(radio)
    end,
    WEPKeyIndex = function(mapping, param, key)
      local ap = getAPFromIface(key)
      return tostring(wepKeyIndex[ap])
    end,
    KeyPassphrase = function(mapping, param, key)
      local ap = getAPFromIface(key)
      return getFromUci(ap, "wpa_psk_key")
    end,
    WEPEncryptionLevel = "Disabled,40-bit,104-bit",
    BasicEncryptionModes = function(mapping, param, key)
      return encryptionModeMap[getAPMode(key)] or ""
    end,
    BasicAuthenticationMode = "None",
    WPAEncryptionModes = "TKIPEncryption",
    WPAAuthenticationMode = function(mapping, param, key)
      local mode = getDataFromAPSecurity(key, "mode")
      return wpaAuthenticationModeMap[mode] or ""
    end,
    IEEE11iEncryptionModes = "AESEncryption",
    IEEE11iAuthenticationMode = function(mapping, param, key)
      return wpaAuthenticationModeMap[getAPMode(key)] or ""
    end,
    PossibleChannels = function(mapping, param, key)
      return getChannels(key, nil, "allowed_channels")
    end,
    BasicDataTransmitRates = function(mapping, param, key)
      return getRates(param, key)
    end,
    OperationalDataTransmitRates = function(mapping, param, key)
      return getRates(param, key)
    end,
    PossibleDataTransmitRates = function(mapping, param, key)
      return getRates(param, key)
    end,
    InsecureOOBAccessEnabled = "1",
    BeaconAdvertisementEnabled = "1",
    SSIDAdvertisementEnabled = function(mapping, param, key)
      return getSSIDAdvertisementEnabled(key)
    end,
    RadioEnabled = function(mapping, param, key)
      return getRadioEnabled(key)
    end,
    AutoRateFallBackEnabled = "1",
    LocationDescription = "",
    RegulatoryDomain = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getFromUci(radio, "country")
    end,
    TotalPSKFailures = "0",
    TotalIntegrityFailures = "0",
    ChannelsInUse = function(mapping, param, key)
      return getChannels(key, nil, "used_channels")
    end,
    DeviceOperationMode = "InfrastructureAccessPoint",
    DistanceFromRoot = "0",
    PeerBSSID = "",
    AuthenticationServiceMode = function(mapping, param, key)
      return getAuthenticationServiceMode(key)
    end,
    TotalBytesSent = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadioStats(radio, "tx_bytes")
    end,
    TotalBytesReceived = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadioStats(radio, "rx_bytes")
    end,
    TotalPacketsSent = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadioStats(radio, "tx_packets")
    end,
    TotalPacketsReceived = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadioStats(radio, "rx_packets")
    end,
    X_000E50_ACSState = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromAcs(radio, "state")
    end,
    X_000E50_ACSMode = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromAcs(radio, "policy")
    end,
    X_000E50_ACSCHMonitorPeriod = function(mapping, param, key)
      return getACSOptionValue(param, key)
    end,
    X_000E50_ACSScanReport = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromAcs(radio, "scan_report")
    end,
    X_000E50_ACSScanHistory = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromAcs(radio, "scan_history")
    end,
    X_000E50_ACSRescanPeriod = function(mapping, param, key)
      return getACSOptionValue(param, key)
    end,
    X_000E50_ACSRescanDelayPolicy = function(mapping, param, key)
      return getACSOptionValue(param, key):lower()
    end,
    X_000E50_ACSRescanDelay = function(mapping, param, key)
      return getACSOptionValue(param, key)
    end,
    X_000E50_ACSRescanDelayMaxEvents = function(mapping, param, key)
      return getACSOptionValue(param, key)
    end,
    X_000E50_ACSCHFailLockoutPeriod = function(mapping, param, key)
      return getACSOptionValue(param, key)
    end,
    AutoChannelEnable  = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local channel = getFromUci(radio, "channel")
      return (channel == "auto") and "1" or "0"
    end,
    X_AutoChannelReselectionTimeout = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local acsdata = getDataFromAcs(radio)
      return acsdata["rescan_period"] and tostring(acsdata["rescan_period"]) or "0"
    end,
    X_AutoChannelReselectionEnable = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local channel = getFromUci(radio, "channel")
      return (channel == "auto") and "1" or "0"
    end,
    X_WPS_V2_ENABLE = function(mapping, param, key)
      local ap = getAPFromIface(key)
      return getFromUci(ap, "wps_state")
    end,
    X_000E50_ACSRescan = "0",
    X_000E50_ACSBssList = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getACSBssList(radio)
    end,
    X_000E50_ChannelMode = function(mapping, param , key)
      return getChannelMode(key)
    end,
    X_000E50_Power = function(mapping, param , key)
      local radio = getRadioFromIface(key)
      local power = getFromUci(radio, "tx_power_adjust")
      return power ~= "" and powerLevelMap[power] or "4"
    end,
    X_000E50_PowerDefault = "1",
    X_000E50_PowerList = "1,2,3,4",
    X_000E50_PacketsDropped = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local stats = getDataFromRadioStats(radio)
      return stats and tostring((tonumber(stats.rx_discards) or 0) + (tonumber(stats.tx_discards) or 0)) or "0"
    end,
    X_000E50_PacketsErrored = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local stats = getDataFromRadioStats(radio)
      return stats and tostring((tonumber(stats.rx_errors) or 0) + (tonumber(stats.tx_errors) or 0)) or "0"
    end,
    X_000E50_RemotelyManaged = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadio(radio, "remotely_managed")
    end,
    X_000E50_UpgradeURL = function(mapping, param, key)
      return getUpgradeInfo(param, key)
    end,
    X_000E50_UpgradeCheckPeriod = function(mapping, param, key)
      return getUpgradeInfo(param, key)
    end,
    X_000E50_UpgradeSWVersion = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadioRemoteUpgrade(radio, "software_version") or ""
    end,
    X_000E50_BandSteerEnable = function(mapping, param, key)
      local ap = getAPFromIface(key)
      return bandSteerHelper.isBandSteerEnabledByAp(ap) and "1" or "0"
    end,
    X_000E50_ChannelWidth = function(mapping, param , key)
      local radio = getRadioFromIface(key)
      return getFromUci(radio, "channelwidth")
    end,
    X_000E50_ShortGuardInterval = function(mapping, param , key)
      local radio = getRadioFromIface(key)
      return getFromUci(radio, "sgi")
    end,
    X_000E50_SpaceTimeBlockCoding = function(mapping, param , key)
      local radio = getRadioFromIface(key)
      return getFromUci(radio, "stbc")
    end,
    X_000E50_CyclicDelayDiversity = function(mapping, param , key)
      local radio = getRadioFromIface(key)
      return getFromUci(radio, "cdd")
    end,
    X_000E50_ChannelBandwidth = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      local channelBandWidth = getFromUci(radio, "channelwidth")
      return channelBandWidth == "auto" and "Auto" or tostring(channelBandWidth)
    end,
    X_0876FF_AllowedMACAddresses = function(mapping, param, key)
      return getMACAddresses(key, "acl_accept_list")
    end,
    X_0876FF_DeniedMACAddresses = function(mapping, param, key)
      return getMACAddresses(key, "acl_deny_list")
    end,
    X_0876FF_SupportedFrequencyBands = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadio(radio, "supported_frequency_bands")
    end,
    X_0876FF_OperatingFrequencyBand = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      return getDataFromRadio(radio, "band")
    end,
    X_0876FF_SupportedStandards = function(mapping, param, key)
      local standards = getDataFromRadio(getRadioFromIface(key), "supported_standards")
      return convertToList(standards)
    end,
    X_0876FF_KeyPassphrase = function(mapping, param, key)
      local ap = getAPFromIface(key)
      return getFromUci(ap, "wpa_psk_key")
    end,
    X_0876FF_RestoreDefaultKey = "0", -- always returns "0", If enabled sets the default key from wireless-defaults
    X_0876FF_RestoreDefaultWireless = "0", -- always returns "0", If enabled, resets the default configuration of particular interface and ap
    X_0876FF_DFSAvailable = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      if radio == "radio_2G" then
        return "0" -- always returns "0", since DFS Channels are supported only for radio_5G
      else
        return "1" -- always returns "1", since DFS Channels are supported
      end
    end,
    X_0876FF_DFSEnable = function(mapping, param, key)
      local radio = getRadioFromIface(key)
      if radio == "radio_2G" then
        return "0" -- always returns "0", since DFS Channels are supported only for radio_5G
      else
        return getDFSStatus(radio)
      end
    end,
    X_0876FF_MaxConcurrentDevices = function(mapping, param, key)
      local ap = getAPFromIface(key)
      return getFromUci(ap, "max_assoc", "0")
    end,
  }

  local function getallWLANDevice(mapping, key)
    local radio = getRadioFromIface(key)
    local uciValues = getFromUci(radio)
    local ap = getAPFromIface(key)
    local radioData = getDataFromRadio(radio)
    local apSecData = getDataFromAPSecurity(key)
    local acsData = getDataFromAcs(radio)
    local ssidData = getDataFromSsid(key)
    local radioStats = getDataFromRadioStats(radio)
    local ifaceName = key:gsub("_remote", "") or ""
    return {
      Enable = getEnable(key),
      Status = ssidData.oper_state and tostring(ssidData.oper_state) == "1" and "Up" or "Disabled",
      BSSID = ssidData.bssid and tostring(ssidData.bssid) or "",
      MaxBitRate = radioData.max_phy_rate and tostring(tonumber(radioData.max_phy_rate)/1000) or "Auto",
      Channel = radioData.channel and tostring(radioData.channel) or "",
      Name = ifaceName,
      SSID = getFromUci(ifaceName, "ssid"),
      TransmitPowerSupported = "25,50,75,100",
      TransmitPower = getTransmitPower(key),
      BeaconType = beaconTypeMap[getAPMode(key)] or "",
      MACAddressControlEnabled = getMACAddressControlEnabled(key),
      Standard = getRadioStandard(radio),
      WEPKeyIndex = tostring(wepKeyIndex[ap]),
      KeyPassphrase = getFromUci(ap, "wpa_psk_key"),
      BasicEncryptionModes = encryptionModeMap[getAPMode(key)] or "",
      WPAAuthenticationMode = apSecData.mode and wpaAuthenticationModeMap[apSecData.mode] or "",
      IEEE11iAuthenticationMode = wpaAuthenticationModeMap[getAPMode(key)] or "",
      OperationalDataTransmitRates = getRates("OperationalDataTransmitRates", key),
      PossibleDataTransmitRates = getRates("PossibleDataTransmitRates", key),
      BasicDataTransmitRates = getRates("BasicDataTransmitRates", key),
      PossibleChannels = getChannels(key, radioData.allowed_channels),
      SSIDAdvertisementEnabled = getSSIDAdvertisementEnabled(key),
      RadioEnabled = getRadioEnabled(key),
      RegulatoryDomain = radioData.country and tostring(radioData.country) or "",
      ChannelsInUse = getChannels(key, radioData.used_channels),
      AuthenticationServiceMode = getAuthenticationServiceMode(key),
      TotalBytesSent = radioStats.tx_bytes and tostring(radioStats.tx_bytes) or "",
      TotalBytesReceived = radioStats.rx_bytes and tostring(radioStats.rx_bytes) or "",
      TotalPacketsSent = radioStats.tx_packets and tostring(radioStats.tx_packets) or "",
      TotalPacketsReceived = radioStats.rx_packets and tostring(radioStats.rx_packets) or "",
      X_000E50_ACSState = acsData.state and tostring(acsData.state) or "",
      X_000E50_ACSMode = acsData.policy and tostring(acsData.policy) or "",
      X_000E50_ACSCHMonitorPeriod = getACSOptionValue("X_000E50_ACSCHMonitorPeriod", key),
      X_000E50_ACSScanReport = acsData.scan_report and tostring(acsData.scan_report) or "",
      X_000E50_ACSScanHistory = acsData.scan_history and tostring(acsData.scan_history) or "",
      X_000E50_ACSRescanPeriod = getACSOptionValue("X_000E50_ACSRescanPeriod", key),
      X_000E50_ACSRescanDelayPolicy = getACSOptionValue("X_000E50_ACSRescanDelayPolicy", key):lower(),
      X_000E50_ACSRescanDelay = getACSOptionValue("X_000E50_ACSRescanDelay", key),
      X_000E50_ACSRescanDelayMaxEvents = getACSOptionValue("X_000E50_ACSRescanDelayMaxEvents", key),
      X_000E50_ACSCHFailLockoutPeriod = getACSOptionValue("X_000E50_ACSCHFailLockoutPeriod", key),
      AutoChannelEnable = uciValues.channel and uciValues.channel == "auto" and "1" or "0",
      X_000E50_ACSBssList = getACSBssList(radio),
      X_000E50_ChannelMode = getChannelMode(key),
      X_000E50_Power = uciValues.tx_power_adjust and powerLevelMap[uciValues.tx_power_adjust] or "4",
      X_000E50_PacketsDropped = tostring((radioStats.rx_discards or 0) + (radioStats.tx_discards or 0)) or "0",
      X_000E50_PacketsErrored = tostring((radioStats.rx_errors or 0) + (radioStats.tx_errors + 0)) or "0",
      X_000E50_RemotelyManaged = radioData.remotely_managed and tostring(radioData.remotely_managed) or "0",
      X_000E50_UpgradeURL = getUpgradeInfo("X_000E50_UpgradeURL", key),
      X_000E50_UpgradeCheckPeriod = getUpgradeInfo("X_000E50_UpgradeCheckPeriod", key),
      X_000E50_UpgradeSWVersion = getDataFromRadioRemoteUpgrade(radio, "software_version") or "",
      X_000E50_BandSteerEnable = bandSteerHelper.isBandSteerEnabledByAp(ap) and "1" or "0",
      X_000E50_ChannelWidth = uciValues.channelwidth and uciValues.channelwidth or "",
      X_000E50_ShortGuardInterval = uciValues.sgi and uciValues.sgi or "",
      X_000E50_SpaceTimeBlockCoding = uciValues.stbc and uciValues.stbc or "",
      X_000E50_CyclicDelayDiversity = uciValues.cdd and uciValues.cdd or "",
      X_000E50_ChannelBandwidth = uciValues.channelwidth and (uciValues.channelwidth == "auto" and "Auto" or tostring(uciValues.channelwidth)) or "",
      X_0876FF_AllowedMACAddresses = getMACAddresses(key, "acl_accept_list"),
      X_0876FF_DeniedMACAddresses = getMACAddresses(key, "acl_deny_list"),
      X_0876FF_SupportedFrequencyBands = radioData.supported_frequency_bands and tostring(radioData.supported_frequency_bands) or "",
      X_0876FF_OperatingFrequencyBand = radioData.band and tostring(radioData.band) or "",
      X_0876FF_SupportedStandards = convertToList(radioData.supported_standards),
      X_0876FF_KeyPassphrase = getFromUci(ap, "wpa_psk_key"),
      X_0876FF_DFSAvailable = (radio == "radio_2G") and "0" or "1",
      X_0876FF_DFSEnable = (radio == "radio_2G") and "0" or getDFSStatus(radio),
      X_0876FF_MaxConcurrentDevices = getFromUci(ap, "max_assoc", "0"),
   }
   end

  local setWLANDevice = {
    Enable = function(mapping, param, value, key)
      local ap = getAPFromIface(key)
      setOnUci(ap, "state", value, commitapply)
    end,
    Channel = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      local allowedChannels = getDataFromRadio(radio, "allowed_channels")
      -- set the given channel if the allowed channels list is empty
      if allowedChannels == "" then
        return setOnUci(radio, "channel", value, commitapply)
      end
      for channel in allowedChannels:gmatch("(%d+)") do
        -- set the given channel if it is present in the allowed channels list
        if channel == value then
          return setOnUci(radio, "channel", value, commitapply)
        end
      end
      return nil, "Given channel is not allowed"
    end,
    SSID = function(mapping, param, value, key)
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) then
        return nil, "Cannot modify SSID when band steer enabled"
      else
        if value and value ~= "" then
          setOnUci(iface, "ssid", value, commitapply)
          modifyBSPeerNodeAuthentication("ssid", value, key, commitapply)
        else
          return nil, "SSID can not be empty"
        end
      end
    end,
    TransmitPower = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      local power = transmitPowerMap[value]
      if power then
        return setOnUci(radio, "tx_power_adjust", power, commitapply)
      end
      return nil,"Invalid power value"
    end,
    BeaconType = function(mapping, param, value, key)
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) then
        return nil, "Cannot modify the value when bandsteer is enabled"
      end
      local ap = getAPFromIface(key)
      local supportedSecMode = getDataFromAPSecurity(key, "supported_modes")
      local secMode = getFromUci(ap, "security_mode")
      local beaconType = beaconTypeMap[value]
      if not beaconType then
        if value == "Basic" then
          if secMode ~= "none" and secMode ~= "wep" then
            if supportedSecMode:match("wep") then
              beaconType = "wep"
            else
              beaconType = "none"
            end
          else
            beaconType = secMode
          end
        else
          return nil, "Unsupported BeaconType Value"
        end
      else
        if secMode:match("psk") then
          beaconType = beaconType .. "-psk"
        end
      end
      setOnUci(ap, "security_mode", beaconType, commitapply)
      modifyBSPeerNodeAuthentication("security_mode", beaconType, key, commitapply)
    end,
    MACAddressControlEnabled = function(mapping, param, value, key)
      local ap = getAPFromIface(key)
      local aclmode = "disabled"
      if value == "1" then
        aclmode = "lock"
      end
      setOnUci(ap, "acl_mode", aclmode, commitapply)
    end,
    WEPKeyIndex = function(mapping, param, value, key)
      local index = tonumber(value)
      local ap = getAPFromIface(key)
      if index ~= wepKeyIndex[ap] then
        wepKeyIndex[ap] = index
        setOnUci(ap, "wep_key", wepKeys[ap][index], commitapply)
      end
    end,
    KeyPassphrase = function(mapping, param, value, key)
      local len = value:len()
      if (len < 8 or len > 63) then
        return nil,"invalid value"
      end
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) then
        return nil, "Cannot modify KeyPassphrase when bandsteer is enabled"
      else
        local ap = getAPFromIface(key)
        setOnUci(ap, "wpa_psk_key", value, commitapply)
        modifyBSPeerNodeAuthentication("wpa_psk_key", value, key, commitapply)
        for wepKey in pairs(wepKeys[ap]) do
          wepKeys[ap][wepKey] = value
        end
      end
    end,
    BasicEncryptionModes = function(mapping, param, value, key)
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) and value == "WEPEncryption" then
        return nil, "Cannot modify BasicEncryptionModes when band steer enabled"
      end
      local ap = getAPFromIface(key)
      local supportedModes = getDataFromAPSecurity(key, "supported_modes")
      local secMode = getFromUci(ap, "security_mode")
      local mode = ""
      -- BasicEncryptionModes is effect only when BeaconType is Basic
      if secMode == "none" or secMode == "wep" then
        if value == "WEPEncryption" then
          if not supportedModes:match("wep") then
            return nil, "wep is not supported"
          end
          mode = "wep"
        elseif value == "None" then
          mode = "none"
        end
        if mode ~= "" then
          setOnUci(ap, "security_mode", mode, commitapply)
          modifyBSPeerNodeAuthentication("security_mode", mode, key, commitapply)
        end
      else
        return nil, "Not supported if BeaconType is not 'Basic'"
      end
    end,
    WPAEncryptionModes = function(mapping, param, value, key)
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) then
        return nil, "Cannot modify the value when bandsteer is enabled"
      end
      -- hardcoded to TKIPEncrytption, based on lower layer support.
    end,
    WPAAuthenticationMode = function(mapping, param, value, key)
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) then
        return nil, "Cannot modify the value when bandsteer is enabled"
      end
      return setAuthenticationMode(key, value, commitapply)
    end,
    IEEE11iEncryptionModes = function(mapping, param, value, key)
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) then
        return nil, "Cannot modify the value when bandsteer is enabled"
      end
      -- hardcoded to AESEncrytption, based on lower layer support.
    end,
    IEEE11iAuthenticationMode = function(mapping, param, value, key)
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) then
        return nil, "Cannot modify the value when bandsteer is enabled"
      end
      return setAuthenticationMode(key, value, commitapply)
    end,
    BasicDataTransmitRates = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      local rateSet = getFromUci(radio, "rateset")
      local rateSetVal, err = nwWifi.setBasicRateset(value, rateSet)
      if rateSetVal then
        setOnUci(radio, "rateset", rateSetVal, commitapply)
      else
        return nil, err
      end
    end,
    OperationalDataTransmitRates = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      local rateSet = getFromUci(radio, "rateset")
      local rateSetVal, err = nwWifi.setOperationalRateset(value, rateSet)
      if rateSetVal then
        setOnUci(radio, "rateset", rateSetVal, commitapply)
      else
        return nil, err
      end
    end,
    SSIDAdvertisementEnabled = function(mapping, param, value, key)
      local ap = getAPFromIface(key)
      setOnUci(ap, "public", value, commitapply)
    end,
    RadioEnabled = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      setOnUci(radio, "state", value, commitapply)
    end,
    RegulatoryDomain = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      setOnUci(radio, "country", value, commitapply)
    end,
    AuthenticationServiceMode = function(mapping, param, value, key)
      local mode = authServiceModeMap[value]
      local iface = key:gsub("_remote", "")
      if not bandSteerHelper.isBaseIface(iface) and bandSteerHelper.isBandSteerEnabledByIface(iface) and mode == "wep" then
        return nil, "Can not modify the value to wep when band steer enabled"
      end
      setOnUci(getAPFromIface(key), "security_mode", mode, commitapply)
      modifyBSPeerNodeAuthentication("security_mode", mode, key, commitapply)
    end,
    X_000E50_ACSCHMonitorPeriod = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "acs_channel_monitor_period", value, commitapply)
    end,
    X_000E50_ACSRescanPeriod = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "acs_rescan_period", value, commitapply)
    end,
    X_000E50_ACSRescanDelayPolicy = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "acs_rescan_delay_policy", value, commitapply)
    end,
    X_000E50_ACSRescanDelay = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "acs_rescan_delay", value, commitapply)
    end,
    X_000E50_ACSRescanDelayMaxEvents = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "acs_rescan_delay_max_events", value, commitapply)
    end,
    X_000E50_ACSCHFailLockoutPeriod = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "acs_channel_fail_lockout_period", value, commitapply)
    end,
    AutoChannelEnable  = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      if value == "1" then
        value = "auto"
      elseif value == "0" then
        local channel = getFromUci(radio, "channel")
        channel = channel == "" and "auto" or channel
        if channel ~= "auto" then
          value = channel
        else
          value = getDataFromRadio(radio, "channel")
        end
      end
      setOnUci(radio, "channel", value, commitapply)
    end,
    X_AutoChannelReselectionTimeout = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      setOnUci(radio, "acs_rescan_period", value, commitapply)
    end,
    X_AutoChannelReselectionEnable = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      if value == "1" then
        value = "auto"
      elseif value == "0" then
        local channel = getFromUci(radio, "channel")
        channel = channel == "" and "auto" or channel
        if channel ~= "auto" then
          value = channel
        else
          value = getDataFromRadio(radio, "channel")
        end
      end
      setOnUci(radio, "channel", value, commitapply)
    end,
    X_WPS_V2_ENABLE = function(mapping, param, value, key)
        local ap = getAPFromIface(key)
        setOnUci(ap, "wps_state", value, commitapply)
    end,
    X_000E50_ACSRescan = function(mapping, param, value, key)
      conn:call("wireless.radio.acs", "rescan", { name = getRadioFromIface(key), act = value })
    end,
    X_000E50_ChannelMode = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      local channel = getFromUci(radio, "channel")
      channel = channel == "" and "auto" or channel
      if value == "Manual" then
        if channel == "auto" then
          channel = getDataFromRadio(radio, "channel")
        end
      elseif value == "Auto" then
        channel = "auto"
      end
      setOnUci(radio, "channel", channel, commitapply)
    end,
    X_000E50_Power = function(mapping, param, value, key)
      local power = powerLevelMap[value] or "-3"
      setOnUci(getRadioFromIface(key), "tx_power_adjust", power, commitapply)
    end,
    X_000E50_UpgradeURL = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "remote_upgrade_url", value, commitapply)
    end,
    X_000E50_UpgradeCheckPeriod = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "remote_upgrade_check_period", value, commitapply)
    end,
    X_000E50_BandSteerEnable = function(mapping, param, value, key)
      if value == "1" then
        return enableBandSteer(key, commitapply)
      end
      return disableBandSteer(key, commitapply)
    end,
    X_000E50_ChannelWidth = function(mapping, param, value, key)
      setOnUci(getRadioFromIface(key), "channelwidth", value, commitapply)
    end,
    X_000E50_ShortGuardInterval = function(mapping, param , value, key)
      setOnUci(getRadioFromIface(key), "sgi", value, commitapply)
    end,
    X_000E50_SpaceTimeBlockCoding = function(mapping, param , value, key)
      local radio = getRadioFromIface(key)
      if radio == "radio_2G" then
        setOnUci(radio, "stbc", value, commitapply)
      else
        return nil, "For 5G mode, BCM setting is not available"
      end
    end,
    X_000E50_CyclicDelayDiversity = function(mapping, param , value, key)
      setOnUci(getRadioFromIface(key), "cdd", value, commitapply)
    end,
    X_000E50_ChannelBandwidth = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      value = value == "Auto" and "auto" or tostring(value)
      if value == "20/40MHz" and radio == "radio_2G" then
        return nil, "Invalid channelwidth for 2.4G"
      end
      setOnUci(radio, "channelwidth", value, commitapply)
    end,
    X_0876FF_AllowedMACAddresses = function(mapping, param, value, key)
      return setMACAddresses(key, "acl_accept_list", value)
    end,
    X_0876FF_DeniedMACAddresses = function(mapping, param, value, key)
      return setMACAddresses(key, "acl_deny_list", value)
    end,
    X_0876FF_KeyPassphrase = function(mapping, param, value, key)
      local ap = getAPFromIface(key)
      setOnUci(ap, "wpa_psk_key", value, commitapply)
    end,
    X_0876FF_RestoreDefaultKey = function(mapping, param, value, key)
      if value == "1" then
        local ap = getAPFromIface(key)
        local defaultKey = getFromWirelessDefaults(ap, "wpa_psk_key")
        setOnUci(ap, "wpa_psk_key", defaultKey, commitapply)
      end
    end,
    X_0876FF_RestoreDefaultWireless = function(mapping, param, value, key)
      if value == "1" then
        local ifaceName = key:gsub("_remote", "") or ""
        local ap = getAPFromIface(key)
        -- restore the default configuration for interface
        restoreSection("wifi-iface", ifaceName)
        -- restore the default configuration for accesspoint
        restoreSection("wifi-ap", ap)
      end
    end,
    X_0876FF_DFSEnable = function(mapping, param, value, key)
      local radio = getRadioFromIface(key)
      if radio == "radio_5G" then
        local channels = channelStrToList(getDataFromRadio(radio, "allowed_channels"))
        if value == "1" then
          channels = addDFSChannels(channels)
        else
          channels = removeDFSChannels(channels)
        end
        setOnUci(radio, "allowed_channels", channels, commitapply)
      else
        return nil, "For 2G mode, DFSEnable is not available"
      end
    end,
  }

  -- WEPKey section
  local function entriesWEPKey(mapping, parentkey)
    return { parentkey .. "_wep_1", parentkey .. "_wep_2", parentkey .. "_wep_3", parentkey .. "_wep_4" }
  end

  local function getWEPKey(mapping, param, key, parentkey)
    return getFromUci(getAPFromIface(parentkey), "wep_key")
  end

  -- 5,10,13 and 26 characters are allowed for the WEP key
  -- 5 and 13 can contain ASCII characters
  -- 10 and 26 can only contain Hexadecimal values
  local function setWEPKey(mapping, param, value, key, parentKey)
    if (#value ~= 5 and #value ~= 10 and #value ~= 13 and #value ~= 26) then
      return nil, "WEP key must be 5, 10, 13 or 26 characters long"
    end
    if (#value == 10 or #value == 26) and (not value:match("^[%x]+$")) then
      return nil, "WEP key of length 10 or 26 can only contain the hexadecimal digits"
    end
    local keyNumber = key:match(".+_wep_(%d+)$")
    local ap = getAPFromIface(parentKey)
    if tonumber(wepKeyIndex[ap]) == tonumber(keyNumber) then
      setOnUci(ap, "wep_key", value, commitapply)
      wepKeys[ap][keyNumber] = value
    end
  end

  -- PSK section
  local function entriesPreSharedKey(mapping, parentKey)
    local entries = {}
    -- The size of this table is fixed with exactly 10 entries
    for i = 1, 10 do
      entries[i] = parentKey .. "psk_" .. i
    end
    return entries
  end

  local getPreSharedKey =  {
    PreSharedKey = "",
    KeyPassphrase = function(mapping, param, key, parentKey)
      return getFromUci(getAPFromIface(parentKey), "wpa_psk_key")
    end,
    AssociatedDeviceMACAddress = "",
    X_0876FF_PreSharedKey = "",
    X_0876FF_KeyPassphrase = function(mapping, param, key, parentKey)
      return getFromUci(getAPFromIface(parentKey), "wpa_psk_key")
    end
  }

  local setPreSharedKey = {
    KeyPassphrase = function(mapping, param, value, key, parentKey)
      local keyNumber = key:match(".*(%d+)")
      if keyNumber == "1" then
        if not bandSteerHelper.isBaseIface(parentKey) and bandSteerHelper.isBandSteerEnabledByIface(parentKey) then
          return nil, "Cannot modify the value when bandsteer is enabled"
        else
          setOnUci(getAPFromIface(parentKey), "wpa_psk_key", value, commitapply)
          modifyBSPeerNodeAuthentication("wpa_psk_key", value, parentKey, commitapply)
        end
      else
        return nil, "Error setting KeyPassphrase! Invalid PreSharedKey!"
      end
    end,
  }

  -- Associated devices section
  local getStaDataFromIface = function(iface, macAddress, option, default)
    local ssid = getFromUci(iface, "ssid")
    local ap = getAPFromIface(iface)
    local stationInfo = conn:call("wireless.accesspoint.station", "get", { name = ap }) or {}
    if stationInfo[ap] and option then
      for mac, data in pairs(stationInfo[ap]) do
         if mac == macAddress and data.state:match("Associated") and data.last_ssid == ssid then
           return tostring(data[option] or default)
         end
      end
    end
    return stationInfo[ap] or {}
  end

  -- Function to retrieve information from SSID ubus call
  local function getStatus(mapping, param, key)
    local ssid = key:match("^(%S+)_sta*")
    local ssiddata = ssid and getDataFromSsid(ssid)
    local state = ssiddata and ssiddata["oper_state"]
    return state and tostring(state) == "1" and "Up" or "Down"
  end

  local paramMap = {
    AssociatedDeviceAuthenticationState = "state",
    LastRequestedUnicastCipher    = "encryption",
    LastDataTransmitRate          = "tx_data_rate_history",
    X_LastDataUplinkRate          = "tx_phy_rate",
    X_000E50_LastDataUplinkRate   = "tx_phy_rate",
    X_LastDataDownlinkRate        = "rx_phy_rate",
    X_000E50_LastDataDownlinkRate = "rx_phy_rate",
    X_000E50_AssociatedDeviceRSSI = "rssi",
    X_000E50_LastDisconnectBy     = "last_disconnect_by",
    X_000E50_LastDisconnectReason = "last_disconnect_reason",
    X_000E50_TxNoAckFailures      = "tx_noack_failures",
    X_000E50_TxPhyRate            = "tx_phy_rate",
    X_000E50_RxPhyRate            = "rx_phy_rate",
    X_000E50_RSSIHistory          = "rssi_history",
    X_000E50_Capabilities         = "capabilities"
  }

  local defaultValueMap = {
    AssociatedDeviceAuthenticationState = "",
    LastRequestedUnicastCipher    = "",
    LastDataTransmitRate          = "",
    X_LastDataUplinkRate          = "0",
    X_000E50_LastDataUplinkRate   = "0",
    X_LastDataDownlinkRate        = "0",
    X_000E50_LastDataDownlinkRate = "0",
    X_000E50_AssociatedDeviceRSSI = "0",
    X_000E50_LastDisconnectBy     = "0",
    X_000E50_LastDisconnectReason = "0",
    X_000E50_TxNoAckFailures      = "0",
    X_000E50_TxPhyRate            = "0",
    X_000E50_RxPhyRate            = "0",
    X_000E50_RSSIHistory          = "0",
    X_000E50_Capabilities         = ""
  }

  -- Function to retrieve information from accesspoint.station ubus call
  local function getStationInfo(_, param, key, parentKey)
    local macAddress = key:match("_sta_([%da-fA-F:]+)$") or ""
    return getStaDataFromIface(parentKey, macAddress, paramMap[param], defaultValueMap[param])
  end

  local entriesAssociatedDevice = function(mapping, parentKey)
    local entries = {}
    local ssid = getFromUci(parentKey, "ssid")
    local stationInfo = getStaDataFromIface(parentKey)
    if stationInfo then
      for mac, data in pairs(stationInfo) do
        if data.state:match("Associated") and data.last_ssid == ssid then
          entries[#entries + 1] = parentKey .. "_sta_" .. mac
        end
      end
    end
    return entries
  end

  local getAssociatedDevice = {
    AssociatedDeviceMACAddress = function(mapping, param, key)
      return key:match("_sta_([%da-fA-F:]+)$") or ""
    end,
    AssociatedDeviceIPAddress = function(mapping, param, key)
      local macAddress = key:match("_sta_([%da-fA-F:]+)$") or ""
      local hostData = conn:call("hostmanager.device", "get", { ["mac-address"] = macAddress }) or {}
      local ipv4Address = {}
      local ipv6Address = {}
      for _, data in pairs(hostData) do
        ipv4Address = data.ipv4 or {}
        ipv6Address = data.ipv6 or {}
      end
      for _, info in pairs(ipv4Address) do
        if info.state and info.state == "connected" then
          return info.address or ""
        end
      end
      for _, ip6Info in pairs(ipv6Address) do
        if ip6Info.state and ip6Info.state == "connected" then
          return ip6Info.address or ""
        end
      end
      return ""
    end,
    AssociatedDeviceAuthenticationState = function(mapping, param, key, parentKey)
      local state = getStationInfo(nil, param, key, parentKey)
      return state:match("Authenticated") and "1" or "0"
    end,
    LastRequestedUnicastCipher = getStationInfo,
    LastRequestedMulticastCipher = "",
    LastPMKId = "",
    LastDataTransmitRate = function(mapping, param, key, parentKey)
      local txRate = getStationInfo(nil, param, key, parentKey)
      return txRate:match("%d+") or ""
    end,
    X_Status = getStatus,
    X_000E50_Status = getStatus,
    X_LastDataUplinkRate = getStationInfo,
    X_000E50_LastDataUplinkRate = getStationInfo,
    X_LastDataDownlinkRate = getStationInfo,
    X_000E50_LastDataDownlinkRate = getStationInfo,
    X_000E50_AssociatedDeviceRSSI  = getStationInfo,
    X_000E50_LastDisconnectBy = getStationInfo,
    X_000E50_LastDisconnectReason = getStationInfo,
    X_000E50_TxNoAckFailures = getStationInfo,
    X_000E50_TxPhyRate = getStationInfo,
    X_000E50_RxPhyRate = getStationInfo,
    X_000E50_RSSIHistory = getStationInfo,
    X_000E50_Capabilities = getStationInfo,
  }

  -- WPS Section
  local getWPS = {
    Enable = function(mapping, param, key)
      return getFromUci(getAPFromIface(key), "wps_state")
    end,
    DevicePassword = "0",
    ConfigMethodsSupported = "Label,PushButton",
    X_0876FF_DevicePassword = function(mapping, param, key)
      return getFromUci(getAPFromIface(key), "wps_ap_pin")
    end,
    UUID = function(mapping, param, key)
      return getUUID(key)
    end,
    ConfigMethodsEnabled = "PushButton",
    ConfigurationState = function(mapping, param, key)
      return getConfigurationState(key)
    end,
    DeviceName = function(mapping, param, key)
      return getAPFromIface(key)
    end,
    SetupLockedState = function(mapping, param, key)
      local setupLock = getFromUci(getAPFromIface(key), "wps_ap_setup_locked", "0")
      return setupLock == "1" and "LockedByLocalManagement" or "Unlocked"
    end,
    SetupLock = function(mapping, param, key)
      return getFromUci(getAPFromIface(key), "wps_ap_setup_locked", "0")
    end,
    X_0876FF_PushButton = "0",
    X_000E50_PushButton = "0",
  }

  local getallWPS = function(mapping, key)
    local ap = getAPFromIface(key)
    local apData = getFromUci(ap)
    local setupLock = apData.wps_ap_setup_locked or "0"
    return {
      Enable = apData.wps_state and apData.wps_state or "",
      X_0876FF_DevicePassword = apData.wps_ap_pin and apData.wps_ap_pin or "",
      SetupLock = setupLock,
      SetupLockedState = setupLock == "1" and "LockedByLocalManagement" or "Unlocked",
      UUID = getUUID(key),
      ConfigurationState = getConfigurationState(key),
      DeviceName = ap
    }
  end

  local function triggerWPSPushButton(value)
    if value == "1" then
      conn:call("wireless", "wps_button", {})
    end
  end

  local setWPS = {
    Enable = function(mapping, param, value, key)
      local ap = getAPFromIface(key)
      setOnUci(ap, "wps_state", value, commitapply)
    end,
    DevicePassword = function(mapping, param, value, key)
      return setDevicePassword(value, key)
    end,
    SetupLock = function(mapping, param, value, key)
      setOnUci(getAPFromIface(key), "wps_ap_setup_locked", value, commitapply)
    end,
    X_0876FF_PushButton = function(mapping, param, value)
      triggerWPSPushButton(value)
    end,
    X_000E50_PushButton = function(mapping, param, value)
      triggerWPSPushButton(value)
    end,
  }

 -- X_Stats Section
  local getWifiStats = {
    SignalStrength = function(mapping, param, key, parentKey)
      local macAddress = key:match("_sta_([%da-fA-F:]+)$") or ""
      return getStaDataFromIface(parentKey, macAddress, "rssi") or "0"
    end,
    Retransmissions = function(mapping, param, key, parentKey)
      local macAddress = key:match("_sta_([%da-fA-F:]+)$") or ""
      return getStaDataFromIface(parentKey, macAddress, "av_txbw_used") or "0"
    end,
    }

  -- WLAN Stats section
  local function getDataFromSsidStats(key, option)
    local iface = key:gsub("_remote", "")
    local ssidStats = conn:call("wireless.ssid.stats", "get", { name = iface }) or {}
    if option then
      return ssidStats[iface] and ssidStats[iface][option] or ""
    end
    return ssidStats[iface] or {}
  end
  local wlanStatsMap = {
    UnicastPacketsSent = "tx_unicast_packets",
    UnicastPacketsReceived = "rx_unicast_packets",
    MulticastPacketsSent = "tx_multicast_packets",
    MulticastPacketsReceived = "rx_multicast_packets",
    BroadcastPacketsSent = "tx_broadcast_packets",
    BroadcastPacketsReceived = "rx_broadcast_packets",
    DiscardPacketsSent = "tx_discards",
    DiscardPacketsReceived = "rx_discards",
    ErrorsSent = "tx_errors",
    ErrorsReceived = "rx_errors",
  }

  local function getWLANStats(mapping, param, key)
    if param == "UnknownProtoPacketsReceived" then
      return nwCommon.getIntfStats(key, "rxerr", "")
    end
    return tostring(getDataFromSsidStats(key, wlanStatsMap[param]))
  end

  local function getallWLANStats(mapping, key)
    local ssidStats = getDataFromSsidStats(key)[key]
    return {
      UnicastPacketsSent = ssidStats[wlanStatsMap["UnicastPacketsSent"]] and tostring(ssidStats[wlanStatsMap["UnicastPacketsSent"]]) or "",
      UnicastPacketsReceived = ssidStats[wlanStatsMap["UnicastPacketsReceived"]] and tostring(ssidStats[wlanStatsMap["UnicastPacketsReceived"]]) or "",
      MulticastPacketsSent = ssidStats[wlanStatsMap["MulticastPacketsSent"]] and tostring(ssidStats[wlanStatsMap["MulticastPacketsSent"]]) or "",
      MulticastPacketsReceived = ssidStats[wlanStatsMap["MulticastPacketsReceived"]] and tostring(ssidStats[wlanStatsMap["MulticastPacketsReceived"]]) or "",
      BroadcastPacketsSent = ssidStats[wlanStatsMap["BroadcastPacketsSent"]] and tostring(ssidStats[wlanStatsMap["BroadcastPacketsSent"]]) or "",
      BroadcastPacketsReceived = ssidStats[wlanStatsMap["BroadcastPacketsReceived"]] and tostring(ssidStats[wlanStatsMap["BroadcastPacketsReceived"]]) or "",
      DiscardPacketsSent = ssidStats[wlanStatsMap["DiscardPacketsSent"]] and tostring(ssidStats[wlanStatsMap["DiscardPacketsSent"]]) or "",
      DiscardPacketsReceived = ssidStats[wlanStatsMap["DiscardPacketsReceived"]] and tostring(ssidStats[wlanStatsMap["DiscardPacketsReceived"]]) or "",
      ErrorsSent = ssidStats[wlanStatsMap["ErrorsSent"]] and tostring(ssidStats[wlanStatsMap["ErrorsSent"]]) or "",
      ErrorsReceived = ssidStats[wlanStatsMap["ErrorsReceived"]] and tostring(ssidStats[wlanStatsMap["ErrorsReceived"]]) or "",
      UnknownProtoPacketsReceived = nwCommon.getIntfStats(key, "rxerr", "")
    }
  end

  return {
    wlan = {
      getAll = getallWLANDevice,
      get = getWLANDevice,
      set = setWLANDevice,
      commit = commit,
      revert = revert
    },
    wps = {
      get = getWPS,
      getall = getallWPS,
      set = setWPS,
      commit = commit,
      revert = revert
    },
    stats = {
      getAll = getallWLANStats,
      get = getWLANStats,
    },
    wepkey = {
      entries = entriesWEPKey,
      get = getWEPKey,
      set = setWEPKey,
      commit = commit,
      revert = revert
    },
    psk = {
      entries = entriesPreSharedKey,
      get = getPreSharedKey,
      set = setPreSharedKey,
      commit = commit,
      revert = revert,
    },
    X_Stats = {
      get = getWifiStats,
    },
    assoc = {
      entries = entriesAssociatedDevice,
      get = getAssociatedDevice,
   }
 }

end

M.setBandSteerID = setBandSteerID
M.enableBandSteer = enableBandSteer
M.getAPFromIface = getAPFromIface
M.getFromUci = getFromUci     
M.setOnUci = setOnUci            
M.commit = commit             
M.revert = revert

return M
