local M = {}
local type = type

--- Copy a table with some limitations like copying only values and not metatables.
-- @table tbl The table to be copied into other table.
-- @treturn table result The table copied from the given table.
local function copyTable(tbl)
  local result = {}
  for key, value in pairs(tbl) do
    if type(value) == "table" then
      result[key] = copyTable(value)
    else
      result[key] = value
    end
  end
  return result
end

M.copyTable = copyTable

--- Converts the given comma separated string into table.
-- @string str The comma separated string which needs to be converted to table.
-- @treturn table The array containing the separated values of the given string.
function M.csvSplit(str)
  local result = {}
  for val in str:gmatch("([^,]*),?") do
    result[#result + 1] = val
  end
  if not str:match(",$") then
    result[#result] = nil
  end
  return result
end

--- Ensures the given value is a list.
-- @string/table value The comma separated string or a table which needs to be converted to table.
-- @treturn table The array containing the separated values of the given string.
function M.ensureList(value)
  if not value then
    return {""}
  end
  if type(value) ~= "table" then
    return M.csvSplit(value)
  end
  return value
end

return M
