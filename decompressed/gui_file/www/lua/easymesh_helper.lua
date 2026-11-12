local io = io
local pcall = pcall
local uci = require("uci")

local M = {}

-- Follow the firmware's newEM layout flag without extending the env mapper.
function M.use_new_layout()
  local ok, variants = pcall(require, "variant_helper")
  if not ok or type(variants) ~= "table" or not variants.ExtenderPage
      or not variants.ExtenderPage.extenderConfig
      or not variants.ExtenderPage.extenderConfig.showEMConfigPage then
    return false
  end
  local success, enabled = pcall(function()
    local cursor = uci.cursor()
    local layout = cursor:get("env", "var", "em_new_ui_layout")
    cursor:unload("env")
    return layout == "1"
  end)
  return success and enabled or false
end

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

-- Card headers submit a single value through the GUI's standard SAVE handler.
function M.handle_card_toggle()
  if ngx.req.get_method() ~= "POST" then return false end
  local args = ngx.req.get_post_args()
  if args.action ~= "SAVE" or args.easyMeshCardEnable == nil or args.fromModal then return false end

  local post = require("web.post_helper")
  local proxy = require("datamodel")
  local params = {
    agentEnable = "uci.multiap.agent.enabled",
    controllerEnable = "uci.multiap.controller.enabled",
  }
  local conductor = proxy.get("uci.wifi_conductor.global.multiap_enabled")
  if conductor and conductor[1] then params.wificonductorEnable = "uci.wifi_conductor.global.multiap_enabled" end
  local controller = true
  local ok, variants = pcall(require, "variant_helper")
  if ok then
    local variant = post.getVariant(variants, "ExtenderPage", "extenderConfig")
    controller = post.getVariantValue(variant, "extenderInfo") ~= false
  end
  local valid = {agentEnable = post.validateBoolean, controllerEnable = post.validateBoolean,
    wificonductorEnable = post.validateBoolean}
  valid.easyMeshCardEnable = function(value, data, key)
    local success, err = post.validateBoolean(value, data, key)
    if not success then return success, err end
    for name in pairs(params) do data[name] = value end
    if not controller then data.controllerEnable = "0" end
    return true
  end
  post.handleQuery(params, valid)
  local messages = require("web.uimessage_helper").popMessages()
  ngx.print(require("web.ui_helper").createMessages(messages))
  ngx.exit(ngx.HTTP_OK)
  return true
end

return M
