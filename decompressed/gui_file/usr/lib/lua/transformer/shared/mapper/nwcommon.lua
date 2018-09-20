--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local M = {}

local math, string = math, string
local uci_helper = require("transformer.mapper.ucihelper")
local posix = require("tch.posix")
local inet_pton = posix.inet_pton
local inet_ntop = posix.inet_ntop
local AF_INET = posix.AF_INET
local AF_INET6 = posix.AF_INET6
local foreach_on_uci = uci_helper.foreach_on_uci
local io = require("io")
local open = io.open
local popen = io.popen
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub
local format = string.format
local min = math.min
local sub = string.sub
local max = math.max
local type, pairs, ipairs, tonumber, tostring = type, pairs, ipairs, tonumber, tostring
local ethBinding = { config = "ethernet", sectionname = "port"}
local xtmBinding = { config = "xtm"}

-- local reference table to map the fields present in /proc/net/dev_extstats file.
-- For multicast alone, the field is fetched from /proc/net/dev file.
local statFields = {
  [1] = 'interface',
  [3] = 'rx_pckts',
  [9] = 'multicast',
  [11] = 'tx_pckts',
  [18] = 'txpckt',
  [21] = 'rx_unicast',
  [22] = 'tx_unicast',
  [23] = 'rx_broadcast',
  [24] = 'tx_broadcast',
  [25] = 'rxerr',
}

local bit = require("bit")
local ubus = require("ubus")
local conn = ubus.connect()
if not conn then
  error("Failed to connect to ubusd")
end

-- Convert an interface name ('wan', 'lan' ...) to a zone
local firewallzone_binding = {config="firewall", sectionname="zone"}
function M.interface2zone(interfacename)
  local result = {}
  local zoneName = uci_helper.get_from_uci({config = "network", sectionname = interfacename, option = "zone"})
  if zoneName ~= "" then
    foreach_on_uci(firewallzone_binding, function(s)
      if s.name == zoneName then
        result = s
        return false
      end
    end)
  else
    foreach_on_uci(firewallzone_binding, function(s)
      if (s.network == nil and s.name == interfacename) then
        result = s
        return false
      end
      if (type(s.network) == "table") then
        for _, zone_interfacename in pairs(s.network) do
          if (zone_interfacename == interfacename) then
            result = s
            return false
          end
        end
      end
    end)
  end
  return result
end

-- function to convert zone name ('wan') to interfaces ('wan','wan6', ..)
-- @param #string zoneName Name of the zone defined in firewall config.
-- @returns #table interfaces returns a table that contains all network interfaces related to the input zone name.
function M.zoneToInterfaces(zoneName)
  local interfaces = {}
  foreach_on_uci(firewallzone_binding, function(s)
    if s.name == zoneName then
      interfaces = s.network
      return false
    end
  end)
  return interfaces
end

-- Get lan zones in {[zone] = true} format, plus nr of items
function M.get_lan_zones()
  local result={}
  local count=0

  foreach_on_uci(firewallzone_binding, function(s)
    if s['wan']~='1' then
      result[s['name']] = true
      count = count + 1
    end
  end
  )
  return result, count
end

-- Get all interfaces marked as WAN in firewall zones
function M.findLanWanInterfaces(wan)
  -- iterate over all firewall zones. If zone wan flag is set/not set, add interfaces to result
  local interfaces={}
  uci_helper.foreach_on_uci(firewallzone_binding,function(s)
    -- iterate over all zones and append interface names
    if (s['wan']=='1') == wan then
      -- 'network' is optional, check for its presence (and that's it's a table)
      if type(s['network']) == "table" then
        for _,v in pairs(s['network']) do
          interfaces[#interfaces+1]=v
        end
	  elseif not ( s['network'] == "" ) then
		interfaces[#interfaces+1]=s['network']
      else
        -- network interface name equals zone name if network is unspecified
        interfaces[#interfaces+1]=s['name']
      end
    end
  end
  )
  return interfaces
end

-- Checks whether a certain device is part of a certain bridge
local function device_in_bridge(device, bridge)
  if not bridge then
    return false
  end
  local bridge_status = M.get_ubus_device_status(bridge)
  if (bridge_status and bridge_status['bridge-members']) then
    for _, v in ipairs(bridge_status['bridge-members']) do
      if (v == device) then
        return true
      end
    end
  end
  return false
end

-- Retrieve the information on UBUS under network.device
local function get_ubus_device_status(devname)
  return conn:call("network.device", "status", { name = devname })
end
M.get_ubus_device_status = get_ubus_device_status

-- Retrieve the information on UBUS under network.interface.{wan/lan/...}
local function get_ubus_interface_status(intf)
  return conn:call("network.interface." .. intf, "status", { })
end
M.get_ubus_interface_status = get_ubus_interface_status


-- Find lower-layer interface from ubus, returns an array
-- If lower layer is a bridge, returns the interfaces in the bridge
local function get_lower_layers_with_status(intf, show_bridge)
  local llintf={}
  local status=get_ubus_interface_status(intf)
  if status then
    local dev=status['device'] or status['l3_device']
    if dev then
      if (show_bridge ~= 1) and match(dev,"^br%-") then -- bridge
        local devicestatus=conn:call("network.device", "status", { name = dev })
        if devicestatus then
          local bridgemembers=devicestatus['bridge-members']
          if bridgemembers then
            if type(bridgemembers)=='table' then
              llintf=bridgemembers
            elseif type(bridgemembers)=='string' then
              llintf[1]=bridgemembers
            end
          end
        end
      else
        llintf[1]=dev
      end
    end
  end
  return llintf, status
end
M.get_lower_layers_with_status = get_lower_layers_with_status

function M.get_lower_layers(intf, show_bridge)
  local lowerLayers, _ = get_lower_layers_with_status(intf, show_bridge)
  return lowerLayers
end

-- Convert a device ('eth4') to an interface name ('wan') (using UBUS)
function M.dev2interface(device)
  local namespaces = conn:objects()
  for _, interface in pairs(namespaces) do
    local name = match(interface, "^network%.interface%.(.*)")
    if (name) then
      local info = conn:call(interface, "status", { })
      if (info and (info['device'] == device or info['l3_device'] == device or device_in_bridge(device, info['device']))) then
        return name
      end
    end
  end
  return nil
end

-- Split key in two parts and return these parts.
-- Used separator is |.
function M.split_key(key)
  return match(key, "^([^|]*)|(.*)")
end

-- Convert the interface to the real device (including VLAN)
function M.intf2device(intf, wan_con_key)
  local ll_intfs = M.get_lower_layers(intf)
  local _, expected_novid = M.split_key(wan_con_key)
  for _,v in ipairs(ll_intfs) do
    -- strip vlan id
    local no_vid=gsub(v,'%.%d+','')
    if no_vid == expected_novid then
      return v
    end
  end
  return nil
end


-- lookup table for getIntfInfo
local pathlookup = {
  ["operstate"] = "/sys/class/net/%s/operstate",
  ["address"] = "/sys/class/net/%s/address",
  ["carrier"] = "/sys/class/net/%s/carrier",
  ["multicast"] = "/sys/class/net/%s/statistics/multicast",
  ["rx_bytes"] = "/sys/class/net/%s/statistics/rx_bytes",
  ["rx_compressed"] = "/sys/class/net/%s/statistics/rx_compressed",
  ["rx_crc_errors"] = "/sys/class/net/%s/statistics/rx_crc_errors",
  ["rx_dropped"] = "/sys/class/net/%s/statistics/rx_dropped",
  ["rx_errors"] = "/sys/class/net/%s/statistics/rx_errors",
  ["rx_fifo_errors"] = "/sys/class/net/%s/statistics/rx_fifo_errors",
  ["rx_frame_errors"] = "/sys/class/net/%s/statistics/rx_frame_errors",
  ["rx_length_errors"] = "/sys/class/net/%s/statistics/rx_length_errors",
  ["rx_missed_errors"] = "/sys/class/net/%s/statistics/rx_missed_errors",
  ["rx_over_errors"] = "/sys/class/net/%s/statistics/rx_over_errors",
  ["rx_packets"] = "/sys/class/net/%s/statistics/rx_packets",
  ["tx_aborted_errors"] = "/sys/class/net/%s/statistics/tx_aborted_errors",
  ["tx_bytes"] = "/sys/class/net/%s/statistics/tx_bytes",
  ["tx_carrier_errors"] = "/sys/class/net/%s/statistics/tx_carrier_errors",
  ["tx_compressed"] = "/sys/class/net/%s/statistics/tx_compressed",
  ["tx_dropped"] = "/sys/class/net/%s/statistics/tx_dropped",
  ["tx_errors"] = "/sys/class/net/%s/statistics/tx_errors",
  ["tx_fifo_errors"] = "/sys/class/net/%s/statistics/tx_fifo_errors",
  ["tx_heartbeat_errors"] = "/sys/class/net/%s/statistics/tx_heartbeat_errors",
  ["tx_packets"] = "/sys/class/net/%s/statistics/tx_packets",
  ["tx_window_errors"] = "/sys/class/net/%s/statistics/tx_window_errors",
  ["mtu"] = "/sys/class/net/%s/mtu",
  ["type"] = "/sys/class/net/%s/type",
  ["speed"] = "/sys/class/net/%s/speed",
}

-- get info from /sys/class/net
function M.getIntfInfo(dev, param, default)
  local value = default
  local pathtemplate = pathlookup[param]
  if pathtemplate then
    local realpath = format(pathtemplate, dev)
    local fd = open(realpath)
    if fd then
      value = fd:read("*line")
      fd:close()
    end
  end
  return value or default or ""
end

-- determine if an interface is an alias
local alias_binding={config="network",sectionname="",option=""}
function M.is_alias(intf)
  alias_binding.sectionname=intf
  alias_binding.option="ifname"
  local ifname=uci_helper.get_from_uci(alias_binding)
  alias_binding.option="device"
  local device=uci_helper.get_from_uci(alias_binding)
  local pat="^@"
  if type(ifname)=='string' and type(device)=='string' and (match(device,pat) or match(ifname,pat)) then
    return true
  end
  return false
end

-- get statistics for network interface
function M.get_intf_stat(intfname, statname)
  local status = M.get_ubus_interface_status(intfname)
  if status then
    local l3device = status.l3_device
    if l3device then
      status = M.get_ubus_device_status(l3device)
      if status.statistics and status.statistics[statname] then
        return tostring(status.statistics[statname])
      end
      -- statname not available in ubus, try /sys/class/net
      local stat = M.getIntfInfo(l3device, statname)
      if stat then
        return stat
      end
    end
  end
  return "0"
end

-- Determine whether a network device is currently in use, by
-- checking whether it is up and it has received bytes
function M.device_in_use(device)
-- for pppoa, ll interfaces do not show up in ubus call network.device status
-- we need to get this info from /sys/class/net/
  local operstate = M.getIntfInfo(device,"operstate")
  local rx_bytes = M.getIntfInfo(device,"rx_bytes")
  return (operstate=="up" and rx_bytes and tonumber(rx_bytes)>0)
end

-- hex2decimal function
local hexmap = {
  ["0"]=0,["1"]=1,["2"]=2,["3"]=3,
  ["4"]=4,["5"]=5,["6"]=6,["7"]=7,
  ["8"]=8,["9"]=9,["A"]=10,["B"]=11,
  ["C"]=12,["D"]=13,["E"]=14,["F"]=15,
  ["a"]=10,["b"]=11,["c"]=12,["d"]=13,
  ["e"]=14,["f"]=15,
}

function M.hex2Decimal(hexstring)
  local result=0
  local multiplier=1
  if hexstring then
    local reversehexstring=hexstring:reverse()
    for hexdigit in gmatch(reversehexstring,"%x") do
      result=result+hexmap[hexdigit]*multiplier
      multiplier=multiplier*16
    end
  end
  return format("%.0f",result)
end

function M.hex2String(hexString)
  return hexString:gsub('(..)', function(value) return string.char(tonumber(value, 16)) end)
end

-- Convert the given string to hexadecimal string
-- User has to take care of passing the proper input to the function.
function M.string2Hex(str)
  return (str:gsub('.', function (char)
    return string.format('%02X', string.byte(char))
  end))
end

-- Convert netmask from /24 to 255.255.255.0
function M.netmask2mask(maskbits)
    if (type(maskbits) ~= "number") then
      return nil
    end
    local result = ""
    for i=1,4 do
      result = result .. tostring(256 - 2^(8 - min(8, maskbits)))
      if (i < 4) then
        result = result .. "."
      end
      maskbits = max(0, maskbits - 8)
    end
    return result
end

-- Convert mask from 255.255.255.0 to /24
function M.mask2netmask(dotted)
  local mask=0
  for num in string.gmatch(dotted, "(%d+).?") do
    num = tonumber(num)
    local shifts = 0
    if num > 0 then
      while bit.band(num, 1) == 0 do
        return nil, "Not a valid mask"
      end
      mask = mask + 8 - shifts
    else
      break
    end
  end
  return mask
end

-- Return number representing the IP address / netmask (first byte is first part ...)
function M.ipv4ToNum(ipStr)
  local rc = posix.inet_pton(AF_INET, ipStr)
  if rc then
    local b1, b2, b3, b4 = rc:byte(1, 4)
    return (b1 * (256^3)) + (b2 * (256^2)) + (b3 * 256) + b4
  end
end

-- Return IP address / netmask representing the number.
function M.numToIPv4(ip)
  if ip > 0 then
    local ret = bit.band(ip, 255)
    local ip = bit.rshift(ip,8)
    for i=1,3 do
      ret = bit.band(ip,255) .. "." .. ret
      ip = bit.rshift(ip,8)
    end
    return ret
  end
end

-- Validate string is MAC
function M.isMAC(value)
  if not value then
    return false
  end
  local macPattern = "^(%x%x):(%x%x):(%x%x):(%x%x):(%x%x):(%x%x)$"
  local chunks = { value:match(macPattern) }
  if #chunks == 6 then
    return true
  end
  return false
end

-- Logic to retrive the tag and its corresponding value of DHCP options
-- passthru-> value fetched from ubus call
function M.get_dhcp_tag_value(passthru)
  local tagValues = {}
  while passthru and sub(passthru,1,2) ~= "" do
    local tag = M.hex2Decimal(sub(passthru,1,2))
    local len = M.hex2Decimal(sub(passthru,3,4))
    tagValues[tag] = sub(passthru,5,(2*len)+4)
    passthru = sub(passthru,(2*len)+5)
  end
  return tagValues
end

function M.get_devices_for_lowerlayers()
  local allDevices = {}
  foreach_on_uci(ethBinding,function(s)
    allDevices[s[".name"]] = "Device.Ethernet.Link.{i}."
  end)

  xtmBinding.sectionname = "atmdevice"
  foreach_on_uci(xtmBinding,function(atmDevice)
    allDevices[atmDevice[".name"]] = "Device.ATM.Link.{i}."
  end)

  xtmBinding.sectionname = "ptmdevice"
  foreach_on_uci(xtmBinding,function(ptmDevice)
    allDevices[ptmDevice[".name"]] = "Device.PTM.Link.{i}."
  end)
  return allDevices
end

-- Get interface name
function M.getIntfName(key)
  local ubusStatus = conn:call("network.interface." .. key,"status",{})
  return ubusStatus and (ubusStatus.device or ubusStatus.l3_device) or ""
end

-- function to read "/proc/net/dev_extstats" and "/proc/net/dev" file to fetch stats
-- @key #string interface name. Can be ip,ppp,eth,etc
-- @param #string sent or received packets stat name based on statFields table mapping defined on top of the file
-- @default #string default value to be returned
-- @return #string stat value for the given param to the function
function M.getIntfStats(key,param,default)
  local index, fd, intfStat = 0
  default = default or '0'
  key = key:gsub("%-", "%%-")
  if param == "multicast" then
    fd = io.open("/proc/net/dev")
  else
    fd = io.open("/proc/net/dev_extstats")
  end
  if fd then
    for line in fd:lines() do
      if line:match("^%s*"..key..":") then
        index = 1
        for field in line:gmatch("[^%s:]+") do
          if statFields[index] == param then
            intfStat = field ~= "-" and field or default
            break
          end
          index = index + 1
        end
      end
      if intfStat then
        break
      end
    end
    fd:close()
  end
  return intfStat or default
end

-- Returns the list of routes based on "ip -4 route show table all"
-- If only default route is required, then set the parameter onlyDefault to true
-- otherwise, by default it returns all routes
-- Returns nil when the parameter onlyDefault is set to true and the default route is not found
-- "ip -4 route show table all" shows all table information including local
-- sample Route format "ip -4 route show" is given below
-- 10.10.21.1 dev pppoe-wan  proto kernel  scope link  src 10.50.50.43
-- 10.179.0.61 via 10.10.20.1 dev atm_voip_mgmt  proto static  src 10.10.20.186

-- sample Route format "ip -4 route show table local" is given below
-- broadcast 10.10.20.0 dev atm_voip_mgmt  proto kernel  scope link  src 10.10.20.186
-- local 10.10.20.186 dev atm_voip_mgmt  proto kernel  scope host  src 10.10.20.186

-- Reads destination ip from the second string if it starts with broadcast/local, otherwise reads first string
-- Reads interface name which is next to the string "dev"
-- Reads metric if there is a digit at the end of the line
-- Reads gateway if the line contains "via"

function M.loadRoutes(onlyDefault)
  local routes = {}
  local keys = {}
  local defaultRoute, key
  local fd = popen("ip -4 route show table all")
  if fd then
    for line in fd:lines() do
      local fields = {}
      fields.destip = line:match("^broadcast%s(%d%S+)") or line:match("^local%s(%d%S+)") or line:match("^(%S+)")
      if fields.destip == "default" then
        fields.destip = "0.0.0.0/0"
      end
      fields.gateway = line:match("via%s(%S+)") or "0.0.0.0"
      fields.ifname = line:match("dev%s(%S+)")
      fields.metric = line:match("metric%s+(%d+)%s$") or "0"
      key = fields.destip .. fields.ifname
      if onlyDefault and fields.destip == "0.0.0.0/0" then
        defaultRoute = fields.ifname
        break
      end
      if not keys[key] then
        keys[key] = true
        routes[#routes+1] = fields
      end
    end
    fd:close()
  end
  if onlyDefault then
    return defaultRoute
  else
    return routes
  end
end

-- Returns all the default ip6 routes as a table, based on "ip -6 route show table all"
-- Returns an empty table when default route is not found
-- "ip -6 route show table all" shows all table information including local
-- sample Route format "ip -6 route show table all" is given below
-- default from 2001:470:ec9c:20::c31c via fe80::2a0:a50f:fc78:ff8e dev pppoe-wan  proto static  metric 4096
-- default from 2001:470:ec9c:2650::/60 via fe80::2a0:a50f:fc78:ff8e dev pppoe-wan  proto static  metric 4096
-- 2001:470:ec9c:2310::/64 dev br-lan  proto static  metric 1024
-- local 2001:470:ec9c:20::c490 via :: dev lo  table local  proto none  metric 0

function M.getip6DefaultRoutes()
  local ip6DefaultRoutes = {}
  local routes = popen("ip -6 route show table all")
  if routes then
    for line in routes:lines() do
      local ipv6addr, device, proto = line:match("^default from (%S+) .* dev (%S+) .* proto (%S+)")
      if ipv6addr then
        ip6DefaultRoutes[#ip6DefaultRoutes + 1] = { ipv6addr = ipv6addr, device = device, proto = proto }
      end
    end
    routes:close()
  end
  return ip6DefaultRoutes
end

--- Returns the given number as 32-bit unsigned int.
-- @value #number, the value to be converted as unsigned integer.
-- @return #number, returns the unsigned integer for the given value
local function castToUInt32(value)
  return value % (2^32)
end

--- Retrieves IPv6 LinkLocalAddress for the given device
-- @param deviceName #string device name
-- @return linkLocalAddress #string IPv6 link local address for the given device
function M.getLinkLocalAddress(deviceName)
  local linkLocalAddress = ""
  local fd = io.open("/proc/net/if_inet6", "r")
  if fd then
    for line in fd:lines() do
      local ip, scope, interface = line:match("(%S+)%s+%S+%s+%S+%s+(%S+)%s+%S+%s+(%S+)")
      if interface == deviceName and scope == "20" then
	ip = gsub(ip, "..", function(s) return string.char(tonumber(s, 16)) end)
	linkLocalAddress = inet_ntop(AF_INET6, ip) or ""
      end
    end
    fd:close()
  end
  return linkLocalAddress
end

--- Returns the network address for the given ip and netmask.
-- @ip #number, the base IP address as integer.
-- @netmask #number, the nesmask as integer.
-- @return network #number, the network address as integer.
function M.extractNetworkAddress(ip, netmask)
  local network = castToUInt32(bit.band(ip, netmask))
  return network
end

--- Returns the broadcast address for the given ip and netmask.
-- @ip #number, the base IP address as integer.
-- @netmask #number, the nesmask as integer.
-- @return broadcast #number, the broadcast address as integer.
function M.extractBroadcastAddress(network, netmask)
  local broadcast = castToUInt32(bit.bor(network, bit.bnot(netmask)))
  return broadcast
end

--- Calculates the start address based on the given startip, network and netmask.
-- @startIP #number, the start IP address as integer.
-- @network #number, the network address as integer.
-- @netmask #number, the nesmask as integer.
-- @return ipStart #number, the start address in the given network as integer.
function M.getStartAddress(startIP, network, netmask)
  local ipStart = bit.bor(network, castToUInt32(bit.band(startIP, bit.bnot(netmask))))
  ipStart = castToUInt32(ipStart)
  return ipStart
end
-- Function to check whether the input baseip address is valid for device
-- (i.e) baseip address should differ from network address and broadcastaddress
-- @baseip #string, contains the ip address of the device
-- @netmask #string, contains the netmask of the device
-- @return #boolean, returns true when baseip address is valid for device

function M.isValidIPv4AddressForDevice(baseip, netmask)
  baseip = baseip and M.ipv4ToNum(baseip)
  netmask = netmask and M.ipv4ToNum(netmask)
  if not netmask then
    return nil, "Invalid SubnetMask"
  end
  if not baseip then
    return nil, "Invalid BaseIP"
  end
  local network = M.extractNetworkAddress(baseip, netmask)
  if baseip == network then
    return nil, "IP address is same as network address"
  end
  local broadcast = M.extractBroadcastAddress(network, netmask)
  if baseip == broadcast then
    return nil, "IP address is same as broadcast address"
  end
  return true
end

-- Function to check whether input netmask address is valid for device
-- (e.g) 128.0.0.0, 255.254.0.0, 255.255.255.0, 255.255.255.255
-- @netmask #string, contains the netmask address of the device
-- @return #boolean, returns true when the netmask address is valid for device

-- Example test cases:
-- Valid subnet mask:
-- mask(string):       255.255.255.0
-- mask(binary):       11111111 11111111 11111111 00000000
-- mask : bitwise NOT: 00000000 00000000 00000000 11111111
-- mask +1 :           00000000 00000000 00000001 00000000
-- mask : bitwise AND: 00000000 00000000 00000000 00000000  -> equal to zero = VALID

-- Invalid subnet mask:
-- mask(string):       255.255.0.255
-- mask(binary):       11111111 11111111 00000000 11111111
-- mask: bitwise NOT:  00000000 00000000 11111111 00000000
-- mask +1:            00000000 00000000 11111111 00000001
-- mask : bitwise AND: 00000000 00000000 11111111 00000000 -> not equal to zero = INVALID

function M.isValidIPv4SubnetMask(netmask)
  local ip = inet_pton(AF_INET, netmask)
  if not ip then
    return false
  end
  local num= 0
  for i = 1,4 do
    num = (num * 256) + ip:byte(i)
  end
  num = bit.bnot(num)
  return bit.band(num,num+1) == 0
end

return M
