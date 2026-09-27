local M = {}
local gmatch, ipairs, concat = string.gmatch, ipairs, table.concat
local uciHelper = require("transformer.mapper.ucihelper")
local wirelessBinding = { config = "wireless" }
local userFriendlyNameBinding = { config = "user_friendly_name" }
local ubus = require("ubus")
local conn = ubus.connect()

--- function to convert a string into a map based on the match pattern
-- @param #string str the input string that needs to be converted into a map
-- @param #string matchPattern value containing the pattern to be applied for generating table keys
-- @param #string validateInputPattern optional If present, then the matched string is validated with the pattern provided.
-- @return #table tbl containing the map of elements that were converted from the input string
-- @return #nil if parameter validateInput is true and the input does not match validateInputPattern
--   the function returns nil, along with an error message "Invalid Value"
local function toMap(str, matchPattern, validateInputPattern)
  local tbl={}
  for item in gmatch(str , matchPattern) do
    if validateInputPattern and not item:match(validateInputPattern) then
      return nil, "Invalid Value"
    end
    tbl[item] = true
  end
  return tbl
end

--- function to convert a string into a list based on the match pattern
-- @param #string str the input string that needs to be converted into a list
-- @param #string matchPattern value containing the pattern to be applied for generating list elements
-- @param #string validateInputPattern optional If present, then the matched string is validated with the pattern provided.
-- @return #table tbl containing the list of elements that were converted from the input string
-- @return #nil if parameter validateInput is true and the input does not match validateInputPattern
--   the function returns nil, along with an error message "Invalid Value"
local function toList(str, matchPattern, validateInputPattern)
  local tbl = {}
  for item in gmatch(str, matchPattern) do
    if validateInputPattern and not item:match(validateInputPattern) then
      return nil, "Invalid Value"
    end
    tbl[#tbl+1] = item
  end
  return tbl
end

--- function to manipulate basic values in rateset option
--  the existing non-basic values are preserved and the existing basic values are over-written
--  In case the input contains a value which is already an existing non-basic value, then it is converted into a basic value.
-- @param #string value The value that needs to be set
-- @param #string rateset The rateset fetched from uci
-- @return #string containing the Basic Rateset list.
-- @return #nil when the input string is not a properly formatted string of (comma or space separated) integer or float values,
--   the function returns nil, along with an error message "Invalid Value"
function M.setBasicRateset(value,rateset)
  local ratesetTable = string.gsub(rateset, "%d*%.*%d*%(b%)[,%s]?", "") -- removes all the values containing (b)
  ratesetTable = toList(ratesetTable, "([^,%s]+)")
  local basicRatesetMap, errMsg = toMap(value, "([^,%s]+)", "^%d+%.?%d*$") -- match all comma or space separated values, validate if match contains numbers
  if not basicRatesetMap then
    return nil, errMsg
  end
  for index, rate in ipairs(ratesetTable) do
    if basicRatesetMap[rate] then -- If the rate is in the basic rates map append "(b)" and add to result list
      ratesetTable[index] = rate .. "(b)"
      basicRatesetMap[rate] = nil
    end
  end
  for rate in pairs(basicRatesetMap) do
    ratesetTable[#ratesetTable+1] = rate .. "(b)" -- Add the new basic rate values to the result list
  end
  return concat(ratesetTable," ")
end

--- function to manipulate operational values in rateset option
--   operational will have basic and other values
--   if value given is already present as basic then it should be retained as such
-- @param #string value The value that needs to be set
-- @param #string rateset The rateset fetched from uci
-- @return #string containing the Operational Rateset list.
-- @return #nil when the input string is not a properly formatted string of (comma or space separated) integer or float values,
--   the function returns nil, along with an error message "Invalid Value"
function M.setOperationalRateset(value,rateset)
  local errMsg
  local basicRatesetMap = toMap(rateset, "([^,%s]+)%(b%),?") -- match only values containing '(b)'
  value, errMsg = toList(value, "([^,%s]+)", "^%d+%.?%d*$") -- match all comma or space separated values, validate if match contains numbers
  if not value then
    return nil, errMsg
  end
  for index, rate in ipairs(value) do
    if basicRatesetMap[rate] then -- If the rate is in the basic rates map append "(b)" and add to result list
      value[index] = rate .. "(b)"
      basicRatesetMap[rate] = nil
    end
  end
  for rate in pairs(basicRatesetMap) do
    value[#value+1] = rate .. "(b)"
  end
  return concat(value," ")
end

--- Checks if the given security mode is supported or not
-- @function isSupportedMode
-- @param ap the accesspoint name
-- @param mode given mode to check whether it is in supported security modes
function M.isSupportedMode(ap, mode)
  wirelessBinding.sectionname = ap
  wirelessBinding.option = "supported_security_modes"
  local modeList = uciHelper.get_from_uci(wirelessBinding)
  if (not modeList or modeList == "") and conn then
    -- some firmwares don't store supported_security_modes in uci:
    -- fall back to the wireless ubus objects like stock wifi.lua does
    local ok, data = pcall(conn.call, conn, "wireless.accesspoint.security", "get", { name = ap })
    if not ok or data == nil then
      ok, data = pcall(conn.call, conn, "wireless.accesspoint", "get", { name = ap })
    end
    if ok and data then
      modeList = data[ap] and data[ap].supported_modes or ""
    else
      modeList = ""
    end
  end
  if modeList == "" then
    -- unsupported modes can't be detected, don't block the setting
    return true
  end
  for imode in modeList:gmatch('([^%s]+)') do
    if imode == mode then
      return true
    end
  end
  return false
end

-- function to calculate the signal strength of wireless device
function M.getSignalStrength(rssi)
  local strength = 1
  if rssi then
    if rssi <= -127 then
      strength = "1"
    elseif rssi < -85 and rssi > -127 then
      strength = "2"
    elseif rssi == -85 then
      strength = "3"
    elseif rssi < -75 and rssi > -85 then
      strength = "4"
    else
      strength = "5"
    end
  end
  return strength
end

function M.getTxPower(max_target_power, max_target_power_adjusted)
  local tx_power = ""
  local tmp_power = 0
  local max_power = tonumber(max_target_power)
  local adjusted_power = tonumber(max_target_power_adjusted)
  if max_power and adjusted_power and max_power > 0 then
    tmp_power = (adjusted_power / max_power) * 100
    local power = tmp_power and math.ceil(tmp_power) or 0
    local roundOff = tmp_power and math.floor(tmp_power / 10) or 0
    tx_power = power and power % 10 or 0
    if tx_power > 5 then
      tx_power = (roundOff + 1) * 10
    else
      tx_power =  roundOff * 10
    end
    -- Regulatory overrides can make the adjusted target exceed the nominal
    -- maximum.  The exposed values are percentages and only support 0..100.
    tx_power = math.max(0, math.min(100, tx_power))
  end
  return tx_power
end

function M.setTxPower(maxPower, value)
  maxPower = tonumber(maxPower)
  value = tonumber(value)
  if not maxPower or maxPower <= 0 or not value or value < 10 or value > 100 or value % 10 ~= 0 then
    return nil, "Transmit power must be a multiple of 10 between 10 and 100"
  end
  local tmp_power = ((value -100) * maxPower) / 100
  return math.ceil(tmp_power)
end

function M.getUserFriendlyName(key)
  local friendlyName
  userFriendlyNameBinding.sectionname = nil
  userFriendlyNameBinding.option = nil
  uciHelper.foreach_on_uci(userFriendlyNameBinding, function(s)
    if s["mac"] == key then
      friendlyName = s.name
      return false
    end
  end)
  return friendlyName or ""
end

function M.setUserFriendlyName(key, value, commitapply)
  local macPresent = false
  userFriendlyNameBinding.sectionname = nil
  userFriendlyNameBinding.option = nil
  uciHelper.foreach_on_uci(userFriendlyNameBinding, function(s)
    if s["mac"] == key then
      userFriendlyNameBinding.sectionname = s[".name"]
      userFriendlyNameBinding.option = "name"
      uciHelper.set_on_uci(userFriendlyNameBinding, value, commitapply)
      macPresent = true
      return false
    end
  end)
  if not macPresent then
    userFriendlyNameBinding.sectionname = "name"
    userFriendlyNameBinding.option = nil
    local newSectionName = uciHelper.add_on_uci(userFriendlyNameBinding)
    if newSectionName then
      userFriendlyNameBinding.sectionname = newSectionName
      userFriendlyNameBinding.option = "mac"
      uciHelper.set_on_uci(userFriendlyNameBinding, key, commitapply)
      userFriendlyNameBinding.option = "name"
      uciHelper.set_on_uci(userFriendlyNameBinding, value, commitapply)
    end
  end
  userFriendlyNameBinding.option = nil
end

return M
