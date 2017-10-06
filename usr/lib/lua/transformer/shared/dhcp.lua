local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local ipairs = ipairs
local INFINITE = "4294967295" -- string containing the largest possible integer value to achieve infinity. LNUM patch prevents using 0xFFFFFFFF directly
local getFromUci = uciHelper.get_from_uci
local getAllFromUci = uciHelper.getall_from_uci
local setOnUci = uciHelper.set_on_uci
local dhcpBinding = { config = "dhcp", option = "dhcp_option", default = {} }
local networkBinding = { config = "network" }
local nwCommon = require("transformer.mapper.nwcommon")
local inet = require "tch.inet"
local bit = require("bit")
local min = require("math").min

--- function to get default route for DHCP client of GW/CPE
-- @param #table ipTable contains the list of address of routers on subnet taken from specified interface in dhcp config
-- @return #string routeIP contains the default route for DHCP client of GW/CPE

function M.getRouteIPAddress(ipTable)
  local routeIP
  for _,ipaddr in ipairs(ipTable) do
    routeIP = ipaddr:match("3,(%d+.%d+.%d+.%d+)")
    if routeIP then
      break
    end
  end
  return routeIP
end

--- function to set new/change default route for DHCP client of GW/CPE for specified interface in dhcp config
-- @param #string value contains the default route to be set for DHCP client of GW/CPE
-- @param #string key contains the specified interface in dhcp config
-- @param #Boolean defaultRouteExists checks for existence of default route of specified interface in dhcp config
-- @return #error when the input value is not a valid IPv4 Address

function M.setDefaultRoute(value, key)
  local defaultRouteExists = false
  dhcpBinding.sectionname = key
  local dhcpList = getFromUci(dhcpBinding)
  value = "3," .. value
  -- iterate all dhcpList values to replace dhcp option(3) with new ip router value
  for i,ipaddr in ipairs(dhcpList) do
    if ipaddr:match("3,(%d+.%d+.%d+.%d+)") then
      dhcpList[i] = value
      defaultRouteExists = true
      break
    end
  end
  -- otherwise add new ip router value in dhcpList
  if not defaultRouteExists then
    dhcpList[#dhcpList+1] = value
  end
  setOnUci(dhcpBinding, dhcpList, commitapply)
end

--- Function to convert time in hours, minutes, days or weeks into time in seconds
-- @param #string timestr containing the time in hours, minutes, days, or weeks. Ex. 12h, 30m
-- If no post-fix is specified (m,h,d,w) then it is treated as seconds, and the same value is returned.
-- @return #string containing the equivalent number of seconds.
-- if the input is empty or nil, then it returns the daemon default time value 43200 seconds.
-- Ref: https://wiki.openwrt.org/doc/techref/odhcpd
-- if the input is infinity(represented by the number 4294967295), then it returns -1
function M.convertTimeStringToSeconds(timestr)
  if not timestr or timestr == "" then
    return "43200"
  end
  -- If the uci time value is infinity (represented by the number 4294967295) then return -1
  if timestr == INFINITE then
    return "-1"
  end
  local factor = 1
  local endString = -2
  local duration
  local unit = timestr:sub(-1,-1)
  if unit == "s" then
    factor = 1
  elseif unit == "m" then
    factor = 60
  elseif unit == "h" then
    factor = 3600
  elseif unit == "d" then
    factor = 86400
  elseif unit == "w" then
    factor = 604800
  else
    endString = -1
  end
  duration = tonumber(timestr:sub(1,endString)) or -1
  return tostring(factor * duration)
end

--- function to get DNSServers for DHCP client of GW/CPE
-- @param #table dhcpList contains the list of addresses of dnsServers on subnet taken from specified interface in dhcp config
-- @return #string contains the DNSServers for DHCP client of GW/CPE

function M.parseDNSServersFromUCI(dhcpList)
  local dnsServers
  for _,value in ipairs(dhcpList) do
    if (value:find("^6,") == 1) then
      dnsServers = value:sub(3)
      break
    elseif value:find("^option:dns") then
      dnsServers = value:sub(19)
      break
    end
  end
  return dnsServers
end

--- function to set new DNSServers for DHCP client of GW/CPE for specified interface in dhcp config
-- @param #string value contains the DNSServers to be set for DHCP client of GW/CPE
-- @param #string key contains the specified interface in dhcp config
-- @return #table dhcpTable contains the values to be set on uci for dhcp_option of dhcp config in specified interface

function M.parseDNSServersFromDatamodel(value, key)
  local dnsServers = {}
  for ip in value:gmatch("([^,]+)") do
    dnsServers[#dnsServers + 1] = ip
  end
  for _,ip in ipairs(dnsServers) do
    local check, err = inet.isValidIPv4(ip)
    if not check then
      return nil, err
    end
  end
  dhcpBinding.sectionname = key
  local dhcpList = getFromUci(dhcpBinding)
  local dhcpTable = {}
  local dhcpValue = "6"
  for _,value in ipairs(dhcpList) do
    if not ( (value:find("^6,") == 1) or (value:find("^option:dns") == 1) ) then
      dhcpTable[#dhcpTable + 1] = value
    end
  end
  for _,ip in ipairs(dnsServers) do
    dhcpValue = dhcpValue .. "," .. ip
  end
  dhcpTable[#dhcpTable + 1] = dhcpValue
  return dhcpTable
end


-- function to calculate StartIPRange, EndIPRange, MinIPAddress and MaxIPAddress for DHCP interface
-- @param #string dhcp interface name
-- @param #string network interface name
-- @return #table dhcpTable that contains the numerical representation of Start IP, End IP, network IP, Min IPAddress and Max IPAddress

function M.parseDHCPData(dhcpIntfName, nwIntfName)
  local networkIntfTable = {}
  if not nwIntfName then
    local lan = nwCommon.findLanWanInterfaces(false)
    for _, v in ipairs(lan) do
      lan[v] = true
    end
    dhcpBinding.sectionname = "dhcp"
    uciHelper.foreach_on_uci(dhcpBinding, function(s)
      if lan[s.interface] then
        networkIntfTable[s['.name']] = s.interface
      end
    end)
  end
  nwIntfName = nwIntfName or networkIntfTable[dhcpIntfName]
  networkBinding.sectionname = nwIntfName
  local networkConfig = getAllFromUci(networkBinding)
  dhcpBinding.sectionname = dhcpIntfName
  local dhcpConfig = getAllFromUci(dhcpBinding)

  local netMask = nwCommon.ipv4ToNum(networkConfig["netmask"])
  local baseIp = nwCommon.ipv4ToNum(networkConfig["ipaddr"])
  local start = tonumber(dhcpConfig["start"] or "100")
  local numIps = tonumber(dhcpConfig["limit"] or "150")

  if baseIp == "" then
    baseIp = 0
  end
  if netMask == "" then
    netMask = 0
  end

  local network = bit.band(baseIp, netMask)
  local ipMin = network + 1
  local ipMax = bit.bor(network, bit.bnot(netMask)) - 1
  local startIp = network + start
  local ipStart = bit.bor(network, bit.band(startIp, bit.bnot(netMask)))
  local ipEnd = min(ipStart + numIps - 1, ipMax)

  return {
    ipStart = ipStart,
    ipEnd = ipEnd,
    network = network,
    ipMin = ipMin,
    ipMax = ipMax,
  }
end

return M
