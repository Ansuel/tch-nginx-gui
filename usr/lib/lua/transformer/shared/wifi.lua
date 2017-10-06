local M = {}
local gmatch, ipairs, concat = string.gmatch, ipairs, table.concat

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
  local ratesetTable = toList(rateset, "(%d+%.?%d?)%(?b?%)?[,%s]?")
  local basicRatesetMap, errMsg = toMap(value, "([^,%s]+)", "%d+") -- match all comma or space separated values, validate if match contains numbers
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
  value, errMsg = toList(value, "([^,%s]+)", "%d+") -- match all comma or space separated values, validate if match contains numbers
  if not value then
    return nil, errMsg
  end
  for index, rate in ipairs(value) do
    if basicRatesetMap[rate] then -- If the rate is in the basic rates map append "(b)" and add to result list
      value[index] = rate .. "(b)"
    end
  end
  return concat(value," ")
end

return M