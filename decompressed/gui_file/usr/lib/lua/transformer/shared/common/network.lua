local M = {}

local uciHelper = require("transformer.mapper.ucihelper")
local conn = require("transformer.mapper.ubus").connect()
local dhcp = require("transformer.shared.dhcp")
local bit = require("bit")
local math = require("math")
local posix = require("tch.posix")

local dhcpBinding = { config = "dhcp" }
local ethernetBinding = { config = "ethernet", sectionname = "mapping" }
local firewallZoneBinding = { config = "firewall", sectionname = "zone" }
local networkBinding = { config = "network" }

local AF_INET = posix.AF_INET
local emptyTable = {}
local pairs, tonumber, string = pairs, tonumber, string
local integratedQtnMAC = string.lower(uciHelper.get_from_uci({config = "env", sectionname = "var", option = "qtn_eth_mac"}))

-- Returns the list of interfaces based on the interface type.
local function getInterfacesByType(interfaceType)
  local interfaces = {}
  local expectedWan = interfaceType == "wan"
  -- iterate over all firewall zones. If zone wan flag is set/not set, add interfaces to result
  uciHelper.foreach_on_uci(firewallZoneBinding, function(s)
    local wanIntf = s.wan == "1"
    if wanIntf == expectedWan then
      if type(s.network) == "table" then
        for _, v in pairs(s.network) do
          interfaces[v] = true
        end
      else
        interfaces[s.name] = true
      end
    end
  end)
  return interfaces
end

-- Checks whether the given host technology is ethernet or wireless.
local function checkHostTechnology(info)
  -- Disconnected devices are to be included as well even though their technology is not known.
  if info["state"] == "disconnected" or info["technology"] == "wireless" or info["technology"] == "ethernet" then
    return true
  end
end

--- Returns the given number as 32-bit unsigned int.
local function castToUInt32(value)
  return value % (2^32)
end

-- Return number representing the IP address.
local function ipv4ToNum(ipStr)
  local rc = posix.inet_pton(AF_INET, ipStr)
  if rc then
    local b1, b2, b3, b4 = rc:byte(1, 4)
    return (b1 * (256^3)) + (b2 * (256^2)) + (b3 * 256) + b4
  end
end

-- Returns the network address for the given interface.
local function getNetworkAddressForIntf(interface)
  networkBinding.sectionname = interface
  local interfaceInfo = uciHelper.getall_from_uci(networkBinding) or {}
  local baseip = interfaceInfo.ipaddr and ipv4ToNum(interfaceInfo.ipaddr)
  local netmask = interfaceInfo.netmask and ipv4ToNum(interfaceInfo.netmask)
  if baseip and netmask then
    return castToUInt32(bit.band(baseip, netmask))
  end
end

-- Checks whether the limit of the particular dhcp pool overlaps with the other pool range.
local function overlapCheck(network, poolname, ipStart, limit, ipMax)
  local ipEnd = math.min(ipStart + limit - 1, ipMax)
  local result = 0
  dhcpBinding.sectionname = "dhcp"
  uciHelper.foreach_on_uci(dhcpBinding, function(s)
    if s[".name"] ~= poolname and s.interface then
      local intfNetwork = getNetworkAddressForIntf(s.interface)
      if intfNetwork and intfNetwork == network and s.start and s.limit then
        s.start = tonumber(s.start)
        s.limit = tonumber(s.limit)
        if (ipStart >= s.start and ipStart < (s.start + s.limit)) or
          (ipEnd >= s.start and ipEnd < (s.limit + s.start)) then
          result = 1
          return false
        end
        if ipStart < s.start and ipEnd > (s.limit + s.start) then
          result = 1
          return false
        end
      end
    end
  end)
  if result == 1 then
    return nil, "The specified range overlaps an existing range."
  end
  return true
end

--- Retrieves the list of wan interfaces.
-- @treturn table The array containing wan interfaces.
function M.getWanInterfaces()
  return getInterfacesByType("wan")
end

--- Retrieves the list of lan interfaces.
-- @treturn table The array containing lan interfaces.
function M.getLanInterfaces()
  return getInterfacesByType("lan")
end

--- Retrieves the list of mac-addresses or the device names of the connected hosts.
-- @table hostData The table containing the information of the connected hosts.
-- @function getInfo It specifies the function to retrieve information of the hosts and
-- if not specified dev names will be returned.
-- @treturn table The array containing the information of the connected hosts based on the option parameter.
function M.getHostInfo(hostData, getInfo)
  local hosts = {}
  local data = hostData or conn:call("hostmanager.device", "get", emptyTable) or emptyTable
  local lanInterfaces = M.getLanInterfaces()
  for dev, info in pairs(data) do
    if lanInterfaces[info.interface] and info["mac-address"] ~= integratedQtnMAC and checkHostTechnology(info) then
      hosts[#hosts+1] = getInfo and getInfo(info) or dev
    end
  end
  return hosts
end

--- Triggers the ACS rescan on the particular radio if radio is specified else on all the radios.
-- @string radio Specifies the radio name on which the acs rescan should be triggered
-- and if radio is nil, then rescan is triggered on all the radios.
function M.triggerACSRescan(radio)
  if radio then
    conn:call("wireless.radio.acs", "rescan", { name = radio, act = 0 })
  else
    conn:call("wireless.radio.acs", "rescan", {})
  end
end

--- Check whether the particular value is present in the given table.
-- @table list A table with different values
-- @string value The value to be checked in the given list of values.
-- @treturn boolean True the given value is present in the table.
function M.listContains(list, value)
  for _, val in pairs(list) do
    if value == val then
      return true
    end
  end
end

--- Set the minaddress for the given interface.
-- @string interface The interface for which the start address to be modified.
-- @string address The IP Address to be set as start address.
-- @treturn boolean True if the given address is successfully set for the interface else nil + error message.
-- @string commitapply is to apply all changes it will execute all queued actions asynchronously in the background.

function M.setDHCPMinAddress(interface, address, commitapply)
  local newStart = ipv4ToNum(address)
  if not newStart then
    return nil, "Invalid IP Address"
  end
  local data = dhcp.parseDHCPData(interface)
  if newStart < data.ipMin or newStart >= data.ipEnd then
    return nil, "Invalid start address"
  end
  local newValue = newStart - data.network
  local result, err = overlapCheck(data.network, data.name, newValue, data.ipEnd - newStart + 1, data.ipMax)
  if result then
    dhcpBinding.sectionname = interface
    dhcpBinding.option = "start"
    uciHelper.set_on_uci(dhcpBinding, newStart - data.network, commitapply)
    dhcpBinding.option = "limit"
    uciHelper.set_on_uci(dhcpBinding, data.ipEnd - newStart + 1, commitapply)
    return true
  end
  return result, err
end

--- Set the maxaddress for the given interface.
-- @string interface The interface for which the end address to be modified.
-- @string address The IP Address to be set as end address.
-- @treturn boolean True if the given address is successfully set for the interface else nil + error message.
-- @string commitapply is to apply all changes it will execute all queued actions asynchronously in the background.

function M.setDHCPMaxAddress(interface, address, commitapply)
  local newEnd = ipv4ToNum(address)
  if not newEnd then
    return nil, "Invalid IP Address"
  end
  local data = dhcp.parseDHCPData(interface)
  if newEnd < data.ipStart or newEnd > data.ipMax then
    return nil, "Invalid End address"
  end
  local newValue = newEnd - data.ipStart + 1
  local result , err = overlapCheck(data.network, interface, data.ipStart - data.network, newValue, data.ipMax)
  if result then
    dhcpBinding.sectionname = interface
    dhcpBinding.option = "limit"
    uciHelper.set_on_uci(dhcpBinding, newValue, commitapply)
    return true
  end
  return result, err
end

--- Retrieves the wlan port.
-- @treturn string Wlan port if it is present else nil is returned.
function M.wlanRemotePort()
  local port
  uciHelper.foreach_on_uci(ethernetBinding, function(s)
    if s.wlan_remote == "1" then
      port = s.port
      return false
    end
  end)
  return port
end

--- Retrieves the list of DHCP Lan interfaces.
-- @treturn table The array containing the list of lan dhcp interfaces.
function M.getDHCPLanInterfaces()
  local interfaces = {}
  local lanInterfaces = M.getLanInterfaces()
  dhcpBinding.sectionname = "dhcp"
  uciHelper.foreach_on_uci(dhcpBinding, function(s)
    for intf in pairs(lanInterfaces) do
      if s.interface == intf then
        interfaces[#interfaces + 1] = s[".name"]
        break
      end
    end
  end)
  return interfaces
end

--- Retrieves the host information based on the given device name.
-- @string devname The device name for which the information to be retrieved.
-- @treturn table The array containing the host information like mac-address, ip address, etc.
function M.getHostDataByName(devname)
  local data = conn:call("hostmanager.device", "get", { name = devname }) or {}
  return data[devname] or {}
end

--- Converts the given epoch time to ISO 8601 format for combined date
-- and UTC time representation ("2016-12-29T10:24:00Z").
-- @number time The epoch timestamp value.
-- @treturn string The ISO 8601 format for combined date and UTC time representation
-- else 9999-12-31T23:59:59Z if the given time is nil.
function M.convertEpochToISO(time)
  return time and os.date("!%Y-%m-%dT%H:%M:%SZ", time) or "9999-12-31T23:59:59Z"
end

--- Retrieves the accesspoint information.
-- @string devname The accesspoint name name for which the information to be retrieved.
-- @treturn table The array containing the accesspoint information like state, ssid, etc.
function M.getAccessPointInfo(apName)
  local data = conn:call("wireless.accesspoint", "get", { name = apName }) or {}
  return data[apName] or {}
end

--- Converts the given string to hex value.
-- @string strValue the string to be converted to hex.
-- @return string The equivalent hex value for the given string.
function M.stringToHex(strValue)
  return strValue and (strValue:gsub('.', function (c) return string.format('%02x', string.byte(c)) end))
end

return M
