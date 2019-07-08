local M = {}

local match, format = string.match, string.format

local dscpMap = {
  ["EF"] = "46", ["BE"] = "0", ["AF11"] = "10", ["AF12"] = "12", ["AF13"] = "14",
  ["AF21"] = "18", ["AF22"] = "20", ["AF23"] = "22", ["AF31"] = "26", ["AF32"] = "28",
  ["AF33"] = "30", ["AF41"] = "34", ["AF42"] = "36", ["AF43"] = "38", ["CS1"] = "8",
  ["CS2"] = "16",  ["CS3"] = "24", ["CS4"] = "32", ["CS5"] = "40", ["CS6"] = "48", ["CS7"] = "56",
}

-- Map the dscp value from uci to corresponding decimal value
-- @param dscp value that needs to be converted to decimal
function M.mapDSCP(dscp, name)
  if dscp == "" or dscp == "-1" then
    if name:match('^rpc.') then
      return "0"
    end
    return "-1"
  end
  return dscpMap[dscp] and dscpMap[dscp] or tostring(tonumber(dscp, 16))
end

-- Map the decimal value to corresponding dscp value
-- @value the deimal value to be mapped
local function mapDecimal(value)
  local dscp
  for dscpHex, dscpDecimal in pairs(dscpMap) do
    if value == dscpDecimal then
      dscp = dscpHex
      break
    end
  end
  return dscp
end

-- converts the decimal value to corresponding dscp value
-- @param value set by the user
-- @dscp present dscp value for the rule to check for exclude pattern
function M.convertToHexDscp(value, dscp)
  local decValue = mapDecimal(value)
  if not decValue then
    decValue = format("0x%x",value)
  end
  if match(dscp or "", "^!") then
    decValue = "!" .. decValue
  end
  return decValue
end

return M
