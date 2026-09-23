--pretranslated: do not change this file
gettext.textdomain('webui-tailscale')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local function escape(value)
  local raw = string.untaint(value or "")
  if type(raw) ~= "string" then raw = tostring(raw) end
  return raw:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function status_snapshot()
  local result = {}
  local command = io.popen("/usr/share/transformer/scripts/tailscaleStatus.sh", "r")
  if command then
    for line in command:lines() do
      local key, value = line:match("^([%w_]+)=(.*)$")
      if key then result[key] = value end
    end
    command:close()
  end
  return result
end

local content = {
  enabled = "uci.tailscale.service.enabled",
  connect = "uci.tailscale.service.connect",
  advertise_routes = "uci.tailscale.service.advertise_routes",
  advertise_exit_node = "uci.tailscale.service.advertise_exit_node",
}
content_helper.getExactContent(content)
local status = status_snapshot()
local online = status.online == "true" and "1" or "0"
local state_text = T"Tailscale disconnected"
if status.phase == "authorization_required" then
  state_text = T"Authorization required"
elseif status.phase == "downloading" then
  state_text = T"Downloading runtime"
elseif status.phase == "verifying" or status.phase == "extracting" or
    status.phase == "starting" or status.phase == "waiting" or status.phase == "connecting" then
  state_text = T"Preparing Tailscale"
elseif status.phase == "error" then
  state_text = T"Tailscale error"
elseif online == "1" then
  state_text = T"Tailscale connected"
end
local modal_path
if ngx.ctx.session:hasAccess("/modals/tailscale-modal.lp") then modal_path = "/modals/tailscale-modal.lp" end

ngx.print('<div class="span3"><div class="smallcard">')
ngx.print(ui_helper.createCardHeader(T"Tailscale", modal_path))
ngx.print('<div class="content card_bg" data-bg-text="&#xf0c2;">')
ngx.print('<p class="subinfos">', T"Service", ': <strong>', content.enabled == "1" and T"Enabled" or T"Disabled", '</strong></p>')
ngx.print(
  '<p class="subinfos tailscale-card-status">',
  ui_helper.createSimpleLight(
    online,
    state_text,
    { span = { class = "simple-desc tailscale-status-light" } }
  ),
  '</p>'
)
if status.ip and status.ip ~= "" then
  ngx.print('<p class="subinfos">', T"Tailscale IP", ': <strong>', escape(status.ip), '</strong></p>')
end
if content.advertise_routes and content.advertise_routes ~= "" then
  ngx.print('<p class="subinfos">', T"Subnet route", ': <strong>', escape(content.advertise_routes), '</strong></p>')
end
if content.advertise_exit_node == "1" then
  ngx.print('<p class="subinfos">', T"Exit node advertised", '</p>')
end
ngx.print('</div></div></div>')
