local M = {}
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local string=  string
local type = type

local uciHelper = require("transformer.mapper.ucihelper")
local conn = require("transformer.mapper.ubus").connect()
local dhcp = require("transformer.shared.dhcp")
local bit = require("bit")
local math = require("math")
local posix = require("tch.posix")
local io = require("io")

local dhcpBinding = { config = "dhcp" }
local ethernetBinding = { config = "ethernet", sectionname = "mapping" }
local firewallZoneBinding = { config = "firewall", sectionname = "zone" }
local networkBinding = { config = "network" }
local wirelessBinding = { config = "wireless" }
local binding = {}

local AF_INET = posix.AF_INET
local emptyTable = {}
local open = io.open
local integratedQtnMAC = string.lower(uciHelper.get_from_uci({config = "env", sectionname = "var", option = "qtn_eth_mac"}))
local lxcMAC = string.lower(uciHelper.get_from_uci({config = "env", sectionname = "var", option = "local_eth_mac_lxc"}))
local match, find, sub = string.match, string.find, string.sub

local intfType, macAddr, keyValue, remotelyManaged

--- Load uci info for firewall zones
-- @returns table keyed on zone name. Values are the uci sections.
function M.firewallZones()
  local zones = {}
  uciHelper.foreach_on_uci(firewallZoneBinding, function(zone)
    if type(zone.network) ~= "table" then
      zone.network = {zone.network}
    end
    zones[zone.name or zone['.name']] = zone
  end)
  return zones
end
local firewallZones = M.firewallZones

--- the firewall zone of the given interface
-- @string intf the interface name
-- @tparam table the zones as returned by firewalZones, or nil in which case the function
--   retrieves the data on its own
-- @return the zone data if found or nil if the interface is in none of the given zones
function M.firewallZoneForInterface(intf, zones)
  zones = zones or firewallZones()
  for _, zone in pairs(zones) do
    for _, network in ipairs(zone.network) do
      if network==intf then
        return zone
      end
    end
  end
end

-- Returns the list of interfaces based on the interface type.
local function getInterfacesByType(interfaceType)
  local interfaces = {}
  local expectedWan = interfaceType == "wan"
  for _, zone in pairs(firewallZones()) do
    local wanIntf = zone.wan == "1"
    if wanIntf == expectedWan then
      for _, intf in pairs(zone.network) do
        interfaces[intf] = true
      end
    end
  end
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

-- Retrieves the data for the given ubus call.
local function fetchUbusData(call, method, name)
  local data = conn:call(call, method, { name = name }) or {}
  return data[name] or {}
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

-- Retrieves the connected host information based on the MAC address.
-- @string mac The MAC address for which the information to be retrieved.
-- @treturn info The table containing the information of the connected host.
-- @return string dev The device name of the connected host.
function M.getHostDataByMAC(mac)
  local data = conn:call("hostmanager.device", "get", { }) or {}
  for dev, info in pairs(data) do
    if info and info["mac-address"] == mac then
      return info, dev
    end
  end
  return {}, ""
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
    if lanInterfaces[info.interface] and info["mac-address"] ~= integratedQtnMAC and info["mac-address"] ~= lxcMAC and checkHostTechnology(info) then
      hosts[#hosts+1] = getInfo and getInfo(info) or dev
    end
  end
  return hosts
end

--- Triggers the ACS rescan on the particular radio if radio is specified else on all the radios.
-- @string radio Specifies the radio name on which the acs rescan should be triggered
-- and if radio is nil, then rescan is triggered on all the radios.
function M.triggerACSRescan(radio, act_val)
  local act_val = tonumber(act_val) or 0
  if radio then
    conn:call("wireless.radio.acs", "rescan", { name = radio, act = act_val })

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
  if newStart < data.ipMin or newStart > data.ipEnd then
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
  return fetchUbusData("hostmanager.device", "get", devname)
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
-- @string apName The accesspoint name name for which the information to be retrieved.
-- @treturn table The array containing the accesspoint information like state, ssid, etc.
function M.getAccessPointInfo(apName)
  return fetchUbusData("wireless.accesspoint", "get", apName)
end

--- Retrieves the station information connected to the given accesspoint.
-- @string apName The accesspoint name for which the station information to be retrieved.
-- @treturn table The array containing the station information like state, ssid, etc.
function M.getAccessPointStationInfo(apName)
  return fetchUbusData("wireless.accesspoint.station", "get", apName)
end

--- Retrieves the radio information.
-- @string radio The radio for which the information to be retrieved.
-- @treturn table The array containing the radio information like state, ssid, etc.
function M.getRadioInfo(radio)
  return fetchUbusData("wireless.radio", "get", radio)
end

--- Retrieves the ssid stats information.
-- @string ssid The ssid name for which the information to be retrieved.
-- @treturn table The array containing the ssid stats information.
function M.getSSIDStats(ssid)
  return fetchUbusData("wireless.ssid.stats", "get", ssid)
end

--- Converts the given string to hex value.
-- @string strValue the string to be converted to hex.
-- @return string The equivalent hex value for the given string.
function M.stringToHex(strValue)
  return strValue and (strValue:gsub('.', function (c) return string.format('%02x', string.byte(c)) end))
end

--- Retrieves whether the given object is IGD or Device2.
-- @table mapping The mapping table containing the object information(eg. name, parameters, etc.).
-- @treturn string Returns igd for IGD object name or device2 for thr Device objects.
function M.getMappingType(mapping)
  local objName = mapping.objectType and mapping.objectType.name or ""
  if objName:match("^InternetGatewayDevice") then
    return "igd"
  elseif objName:match("^Device") then
    return "device2"
  end
end

--- Retrieves the accesspoint name for the given interface.
-- @string iface The wifi-iface name.
-- @treturn ap The accesspoint for the given wifi interface.
function M.getAPForIface(iface)
  local ap = ""
  wirelessBinding.sectionname = "wifi-ap"
  uciHelper.foreach_on_uci(wirelessBinding, function(s)
    if s.iface == iface then
      ap = s[".name"]
      return false
    end
  end)
  return ap
end

--- Retrieves the first line from the given input file.
-- @string filename The file in which the first line to be retrieved.
-- @treturn string result The first line of the given file else empty string in case of any error.
function M.getFirstLine(filename)
  local result = ""
  local fd = open(filename)
  if fd then
    result = fd:read("*l") or ""
    fd:close()
  end
  return result
end

--- Executes the given command and returns the result.
-- @string cmd The command to be executed.
-- @treturn string result The output of the given command.
function M.executeCommand(cmd)
  local result = ""
  local fp = io.popen(cmd)
  if fp then
    result = fp:read("*l") or ""
    fp:close()
  end
  return result
end

--- Retrieves the list of reboot reasons.
-- @treturn table rebootreasons The array containing the reboot reasons.
function M.getRebootReasons()
  local rebootreasons = {}
  local fd = io.open("/lib/functions/reboot_reason.sh")
  if fd then
    for line in fd:lines() do
      -- Read until comment containing 'REASONS_END' is found.
      if line:match("#.*REASONS_END") then
        break
      end
      -- Known reboot reasons have format like 'PWR=0'.
      local reason = line:match('(%w+)=%d+')
      if reason then
        -- Exclude future-use reserved reasons.
        if not reason:match("RES") then
          rebootreasons[#rebootreasons + 1] = reason
        end
      end
    end
    fd:close()
  else
    -- On platforms which are not reboot-reason enabled (LTE, Qualcomm):
    -- Provide a default set of reasons which are called from the code,
    -- since GUI and CWMP code is taken along on all platforms,
    -- and hence set e.g. "rpc.system.reboot" to "GUI".
    rebootreasons = {"GUI", "CWMP", "STS", "CLI"}
  end
  return rebootreasons
end

--- Retrieves the interface type and mac of the external wifi.
-- @treturn string intfType of the external wifi.
-- @treturn string macAddr of the external wifi
function M.getExternalWifiIntfType()
  local ssid
  if not keyValue and not remotelyManaged then
    local wirelessRadio = conn:call("wireless.radio", "get" , {})
    if wirelessRadio then
      for key, value in pairs(wirelessRadio) do
        if value.remotely_managed == 1 and value.integrated_ap == 1 then
          keyValue = key
          remotelyManaged = true
        end
      end
    end
  end
  if keyValue then
    ssid = conn:call("wireless.ssid", "get", {})
    if not ssid then
      return intfType, macAddr
    end
    --get radio-remote information
    local radioremoteMAC, radioremoteIntf
    local radioremote = conn:call("wireless.radio.remote", "get", { name = keyValue })
    if radioremote then
      local _, v = next(radioremote)
      if v then
        radioremoteMAC = v.macaddr
        radioremoteIntf = v.ifname
      end
    end
    for _, info in pairs(ssid) do
      if info.radio == keyValue then
        local result = ("0x" .. string.sub(info.mac_address,(#info.mac_address -1)))
        local obtMacAddr = string.format("%02x",((result -1)%256))
        local mac_prefix = string.sub(info.mac_address, 1, (#info.mac_address -2))
        macAddr = string.format("%s%s", mac_prefix, obtMacAddr)
        if integratedQtnMAC == macAddr then
          break
        end
      end
      -- In case the ssid is remotely managed, integrated and disabled, the received macaddress via wireless.ssid is 0,
      -- then we need to get the mac via wireless.radio.remote
      if ((macAddr == "ff:ff:ff:ff:ff:ff" ) and keyValue ) then
        if not intfType or not macAddr then
          macAddr = radioremoteMAC
          intfType = radioremoteIntf
        end
      end
    end
    if not intfType  then
      local hosts = conn:call("hostmanager.device", "get", {}) or {}
      for _, info in pairs(hosts) do
        if info["mac-address"] == macAddr then
          intfType= info.l2interface
        end
      end
    end
    --Bridged to Routed mode change will not have host for Quantenna, intfType will not be available.
    if not intfType and macAddr == radioremoteMAC then
      intfType = radioremoteIntf
    end
  else
    macAddr = integratedQtnMAC
  end
  return intfType, macAddr
end

-- Checks whether the value is a valid domain name.
-- This function satisfies RFC1033 and RFC1035 so this function is not suitable for hostname validation.
function M.domainValidation(value)
  local count, currLabelIndex = 0, 0
  if type(value) ~= "string" or #value == 0 or #value > 255 then
    return nil, "Domain name cannot be empty or greater than 255 characters or non string value"
  end
  repeat
    count = count + 1
    currLabelIndex = find(value, ".", count, true)
    local label = sub(value, count, currLabelIndex)
    local strippedLabel = match(label, "[^%.]*")
    if strippedLabel ~= nil then
      if #strippedLabel == 0 or #strippedLabel > 63 then
        return nil, "Label should not be empty or more than 63 characters"
      end
      local correctLabel = match(strippedLabel, "^[a-zA-z0-9][a-zA-Z0-9-_]*[a-zA-Z0-9]")
      if #strippedLabel == 1 then
        if not match(strippedLabel, "[a-zA-Z0-9]") then
          return nil, "Label within domain name has invalid syntax"
        end
      elseif strippedLabel ~= correctLabel then
        return nil, "Label within domain name has invalid syntax"
      end
    end
    count = currLabelIndex
  until not currLabelIndex
  return true
end

function M.getNewSection(config, section)
  local sectionName
  local sectionList = {}
  binding.config = config
  binding.sectionname = section
  uciHelper.foreach_on_uci(binding, function(s)
    sectionList[s[".name"]] = true
  end)
  repeat
    sectionName = uciHelper.generate_key()
    sectionName = section .. "_" .. string.sub(sectionName, -4)
  until not sectionList[sectionName]
  return sectionName
end

return M
