local string, pairs = string, pairs
local greBinding = { config = "gre_hotspotd" }
local wirelessBinding = { config = "wireless" }
local uciHelper = require("transformer.mapper.ucihelper")
local forEachOnUci = uciHelper.foreach_on_uci
local M = {}

--- function to get the corresponding accesspoint value for the given interface
-- @param #string intf contains the interface name
-- @return #string accpoint contains the accesspoint value for the corresponding interface passed
function M.getAp(intf)
  local accpoint
  wirelessBinding.sectionname = "wifi-ap"
  forEachOnUci(wirelessBinding, function(s)
    wirelessBinding.sectionname = s['.name']
    if s.iface and intf and string.match(s.iface, intf) then
      accpoint = s['.name']
      return false
    end
  end)
  return accpoint
end

--- function to get all the Gre Hotspot Wifi Interfaces
-- @return #table interfaces contains all the Gre Hotspot Wifi Interfaces
local function getHotspotWiFiInterfaces()
  local interfaces = {}
  greBinding.sectionname = "hotspot"
  forEachOnUci(greBinding, function(s)
    greBinding.sectionname = s['.name']
    if type(s.wifi_iface) == "string" then
      interfaces[#interfaces + 1] = s.wifi_iface
    else
      for _, iface in pairs(s.wifi_iface) do
        interfaces[#interfaces + 1] = iface
      end
    end
  end)
  return interfaces
end

--- function to get the corresponding SSID name for the given interface
-- @param #string ifname contains the interface name
-- @param #string device contains the device information i.e 2G or 5G
-- @return #string ssidName contains the corresponding SSID name for the given interface
local function getSSIDName(ifname, device)
  local ssidName
  local isSecuredInterface
  local ap = M.getAp(ifname)
  wirelessBinding.sectionname = "wifi-radius-server"
  forEachOnUci(wirelessBinding, function(s)
    wirelessBinding.sectionname = s['.name']
    if string.match(s['.name'], ap) then
      isSecuredInterface = true
      if device == "2G" then
        ssidName = "EAPSSID"
        return false
      else
        ssidName = "EAPSSID5"
        return false
      end
    end
  end)
  if not isSecuredInterface then
    return device == "2G" and "SSID" or "SSID5"
  end
  return ssidName
end

--- function to get all the Gre Hotspot Wifi Interfaces
-- @return #table ifnames contains all the Gre Hotspot Wifi Interfaces mapped to ssid Names
function M.getIfnames()
  local ifnames = {}
  local ssidName
  local interfaces = getHotspotWiFiInterfaces()
  for _, iface in pairs(interfaces) do
    wirelessBinding.sectionname = iface
    wirelessBinding.option = "device"
    local device = uciHelper.get_from_uci(wirelessBinding)
    if device == "radio_2G" then
      ssidName = getSSIDName(iface, "2G")
      ifnames[ssidName] = iface
    elseif device == "radio_5G" then
      ssidName = getSSIDName(iface, "5G")
      ifnames[ssidName] = iface
    end
  end
  return ifnames
end

--- function to get all the accesspoints that corresponds to Gre Hotspot Wifi Interfaces
-- @return #table accpoints contains all the accesspoints that corresponds to Gre Hotspot Wifi Interfaces
function M.getAllAp()
  local accpoints = {}
  local interfaces = getHotspotWiFiInterfaces()
  wirelessBinding.sectionname = "wifi-ap"
  forEachOnUci(wirelessBinding, function(s)
    wirelessBinding.sectionname = s['.name']
    for _, ifname in pairs(interfaces) do
      if s.iface and string.match(s.iface, ifname) then
        accpoints[#accpoints + 1] = s['.name']
      end
    end
  end)
  return accpoints
end

--- function to get all the accesspoints and Interface names that correspond to Private WiFi Interfaces
-- @return #table privateAPs contains all the accesspoints that corresponds to Private Wifi Interfaces
-- @return #table privateIface contains all the interface names that corresponds to Private Wifi Interfaces
function M.getPrivateAp()
  local privateAPs, privateIface, hotspotAPs = {}, {}, {}
  for _, ifname in pairs(getHotspotWiFiInterfaces()) do
    hotspotAPs[ifname] = true
  end
  wirelessBinding.sectionname = "wifi-ap"
  forEachOnUci(wirelessBinding, function(s)
    if not hotspotAPs[s.iface] then
      privateAPs[#privateAPs + 1 ] = s['.name']
      privateIface[#privateIface + 1] = s.iface
    end
  end)
  return privateAPs, privateIface
end

--- To Validate whether the received 'value' has the syntax of a domain name [RFC 1123]
-- @function validateStringIsDomainName
-- @param #string value consists of domain names
-- @return #boolean true/nil true when all the validations are correct with respect to domain name check and nil when domain name check is violated
function M.validateStringIsDomainName(value)
  if #value == 0 or #value > 255 then
    return nil,"Domain name cannot be empty and it cannot be too long."
  end

  local fromIndex = 1

  repeat
    local toIndex = value:find("%.", fromIndex)
    local label = value:sub(fromIndex, toIndex and toIndex - 1)
    if #label == 0 or #label > 63 then
      return nil,"Domain name cannot be empty and not longer than 63 characters."
    end
    local correctLabel = label:match("^%w[%w%-]*%w$") or label:match("^%w$")
    if not correctLabel then
      return nil, "Label within domain name has invalid syntax"
    end
    fromIndex = toIndex and toIndex + 1
  until not toIndex
  return true
end

return M
