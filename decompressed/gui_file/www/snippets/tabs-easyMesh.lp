--pretranslated: do not change this file
gettext.textdomain('webui-core')
local mesh = require("easymesh_helper")
local post = require("web.post_helper")
local ok, variants = pcall(require, "variant_helper")
local variant = ok and post.getVariant(variants, "ExtenderPage", "extenderConfig") or nil
local function modal_available(name)
  local file = io.open("/www/docroot/modals/" .. name, "r")
  if not file then return false end
  file:close()
  return true
end
local newLayout = mesh.use_new_layout()
local configPage = newLayout and modal_available("easymesh-configuration-modal-newEM.lp")
  and "easymesh-configuration-modal-newEM.lp" or "easy-mesh-configuration.lp"
local topologyPage = newLayout and modal_available("easymesh-topology-modal-newEM.lp")
  and "easymesh-topology-modal-newEM.lp" or "wifi-extender-status.lp"
local items = {}
if mesh.is_supported() then
  items[#items + 1] = {configPage, T"EasyMesh Configuration"}
end
items[#items + 1] = {"easy-mesh-configuration.lp?setup=1", T"Setup and role"}
if mesh.is_supported() then
  items[#items + 1] = {topologyPage, T"Topology"}
  -- This native inventory uses the same RPCs on both GUI layouts.
  items[#items + 1] = {"easymesh-devices-info-modal-newEM.lp", T"Devices"}
  if post.getVariantValue(variant, "agentAndStationInfo") and modal_available("agent-list.lp") then
    items[#items + 1] = {"agent-list.lp", T"Agent List"}
  end
  if not newLayout and post.getVariantValue(variant, "wifiDevicesList") and modal_available("wifi-devices-info.lp") then
    items[#items + 1] = {"wifi-devices-info.lp", T"WiFi Devices"}
  end
end
local uri = ngx.var.uri
local args = "&" .. (ngx.var.args or "") .. "&"
if uri == "/modals/easy-mesh-configuration.lp" and args:find("&setup=1&", 1, true) then
  uri = uri .. "?setup=1"
end
local tabs = {}
for _, item in ipairs(items) do
  local target = "/modals/" .. item[1]
  local accessPath = target:match("^[^?]+")
  if modal_available(item[1]:match("^[^?]+")) and ngx.ctx.session:hasAccess(accessPath) then
    tabs[#tabs + 1] = {desc=item[2],target=target,active=uri == target and "active" or nil}
  end
end
ngx.print(require("web.ui_helper").createModalTabs(tabs))
