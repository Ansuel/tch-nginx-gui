--- network information functions
local require = require
local ipairs = ipairs
local unpack = unpack
local untaint = string.untaint

local dm = require "datamodel"

local M = {}

local function constructDatamodelPaths(interfaces)
  local paths = {}
  for _, intf in ipairs(interfaces) do
    paths[#paths+1] = "rpc.network.interface.@"..intf..".ipaddr"
  end
  return paths
end

local function extractIPPerInterface(response)
  local intfToIP = {}
  for _, resp in ipairs(response) do
    if resp.param=="ipaddr" then
      local ifname = resp.path:match("^rpc%.network%.interface%.@([^.]+)")
      intfToIP[ifname] = untaint(resp.value)
    end
  end
  return intfToIP
end

local function getDatamodelValues(request)
  if #request>0 then
    return dm.get(unpack(request))
  end
  return {}
end

local function mapValuesInOrder(map, order)
  local result = {}
  for _, ifname in ipairs(order) do
    result[#result+1] = map[ifname] or ""
  end
  return result
end

--- convert interface names to corresponding IP addresses
-- @param interface a list of interface names
-- @returns a list of corresponding IP addresses.
--   In case a given interface has not IP address an empty string
--   will be substituted.
--   In case an error occurs (eg due to an invalid interface name)
--   an empty list is returned.
function M.interfacesToIP(interfaces)
  local dm_request = constructDatamodelPaths(interfaces)
  local dm_values = getDatamodelValues(dm_request)
  if dm_values then
    local intfToIP = extractIPPerInterface(dm_values)
    return mapValuesInOrder(intfToIP, interfaces)
  end
  return {}
end

return M
