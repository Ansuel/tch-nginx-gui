local M = {}

local uci_helper = require("transformer.mapper.ucihelper")
local forEachOnUci = uci_helper.foreach_on_uci
local networkBinding = { config = "network" , sectionname = "interface" }
local secRouteIntfMap = {}
local nwCommon = require("transformer.mapper.nwcommon")
local getUbusInterfaceStatus=nwCommon.get_ubus_interface_status

--Retrieves all the Routing tables present. It also populates the table:secRouteIntfMap which maps the Interfaces to their associated rttable.
function M.getRoutingTables()
  local routerEntries = {"main"}
  local interfaces = {}
  forEachOnUci(networkBinding, function(s)
    if s.ip4table and s.ip4table ~= "main" then
      secRouteIntfMap[s[".name"]] = s.ip4table
      if not interfaces[s.ip4table] then
        interfaces[s.ip4table] = true
        routerEntries[#routerEntries + 1] = s.ip4table
      end
    end
  end)
  return routerEntries
end

-- Function to fetch the table: secRouteIntfMap that contains the map between secondary routing tables and their interfaces.
function M.getCachedSecRouteMap()
  return secRouteIntfMap
end

--Fetch the Device name(l3_device) name and associated rttable from the route Interface
--@param rtTableIntfMap - Table that contains the map between secondary routing tables and their interfaces.
function getDeviceRtTableMap(rtTableIntfMap)
  local deviceRtTableMap = {}
  for interface, rttable in pairs(rtTableIntfMap) do
    local ubusStatus = getUbusInterfaceStatus(interface)
    if ubusStatus and ubusStatus.device then
      deviceRtTableMap[ubusStatus.device] = rttable
    end
    if ubusStatus and ubusStatus.l3_device then
      deviceRtTableMap[ubusStatus.l3_device] = rttable
    end
  end
  return deviceRtTableMap
end

-- Function to filter the routes the list of routes specific to the routing table.
--@param rtTable  Parentkey of the caller function
--@param loadRoutes list of routes fetched from the /proc/net/route(ipv6_route) file
--@param secIntfList Table that contains the map between secondary routing tables and their interfaces
function M.getRoutesforRtTable(rtTable, loadRoutes, secIntfList)
  local entries = {}
  local routeEntries = {}
  local interfaceName
  local secRouteDevList = getDeviceRtTableMap(secIntfList)
  for _, route in ipairs(loadRoutes) do
    interfaceName = route.deviceName ~= '' and route.deviceName or route.ifname
  -- check for the device(ifname) name in the route table and filter the routes specific to primary or secondary routing table
    if (rtTable == "main" and not secRouteDevList[interfaceName]) or secRouteDevList[interfaceName]  == rtTable then
      routeEntries[#routeEntries+1] = route
    end
  end
  return routeEntries
end

return M
