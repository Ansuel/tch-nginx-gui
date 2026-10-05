local io = io
local pcall = pcall
local uci = require("uci")

local M = {}

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
