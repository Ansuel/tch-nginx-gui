local io = io
local pcall = pcall
local uci = require("uci")

local M = {}

-- Expose only radio identifiers and bands actually provided by the driver.
-- This also covers single/dual/tri-band models without assuming Quantenna IDs.
function M.get_frequency_options()
  local proxy = require("datamodel")
  local ok, radios = pcall(proxy.getPN, "rpc.wireless.radio.", true)
  if not ok then return {} end
  local groups, all, seen = {}, {}, {}
  for _, entry in ipairs(radios or {}) do
    local name = entry.path:match("^rpc%.wireless%.radio%.@([%w_%-]+)%.$")
    if name then
      if string.untaint then name = string.untaint(name) end
      local success, values = pcall(proxy.get, "rpc.wireless.radio.@" .. name .. ".supported_frequency_bands")
      local band = success and values and values[1] and values[1].value
      if string.untaint then band = string.untaint(band) end
      if (band == "2.4GHz" or band == "5GHz" or band == "6GHz") and not seen[name] then
        groups[band] = groups[band] or {}
        groups[band][#groups[band] + 1] = name
        all[#all + 1], seen[name] = name, true
      end
    end
  end
  local result = {}
  for _, band in ipairs({"2.4GHz", "5GHz", "6GHz"}) do
    if groups[band] then
      table.sort(groups[band])
      result[#result + 1] = {table.concat(groups[band], ","), band}
    end
  end
  if #result > 1 then
    table.sort(all)
    result[#result + 1] = {table.concat(all, ","), "All bands"}
  end
  return result
end

local _is_supported = nil

function M.is_supported()
  if _is_supported ~= nil then
    return _is_supported
  end

  for _, path in ipairs({
    "/etc/config/multiap",
    "/usr/bin/multiap_agent",
    "/usr/bin/multiap_controller"
  }) do
    local f = io.open(path, "r")
    if not f then
      _is_supported = false
      return false
    end
    f:close()
  end

  local ok, res = pcall(function()
    local cursor = uci.cursor()
    local controller = cursor:get("multiap", "controller")
    local agent = cursor:get("multiap", "agent")
    cursor:unload("multiap")
    return (controller ~= nil and agent ~= nil)
  end)

  if ok and res then
    _is_supported = true
  else
    _is_supported = false
  end

  return _is_supported
end

return M
