local io = io
local pcall = pcall
local uci = require("uci")

local M = {}

local _is_supported = nil

function M.is_supported()
  if _is_supported ~= nil then
    return _is_supported
  end

  local f = io.open("/etc/config/multiap", "r")
  if not f then
    _is_supported = false
    return false
  end

  local content = f:read("*a")
  f:close()
  if not content or #content < 50 then
    _is_supported = false
    return false
  end

  local ok, res = pcall(function()
    local cursor = uci.cursor()
    local controller = cursor:get("multiap", "controller")
    local agent = cursor:get("multiap", "agent")
    cursor:unload("multiap")
    return (controller ~= nil or agent ~= nil)
  end)

  if ok and res then
    _is_supported = true
  else
    _is_supported = false
  end

  return _is_supported
end

return M
