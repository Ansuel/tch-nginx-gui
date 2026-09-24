--pretranslated: do not change this file
gettext.textdomain('webui-wireguard')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format

local function escape(value)
  local raw = string.untaint(value or "")
  if type(raw) ~= "string" then raw = tostring(raw) end
  return raw:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function status_snapshot()
  local result = {}
  local command = io.popen("/usr/share/transformer/scripts/wireguardStatus.sh", "r")
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
  enabled = "uci.wireguard.wg.enabled",
}
content_helper.getExactContent(content)
local status = status_snapshot()
local enabled_on = content.enabled == "1"
local running = status.running == "true"
local live = tonumber(status.live) or 0
local peers = tonumber(status.peers) or 0
local state_text = T"Tunnel disabled"
if enabled_on and running and live > 0 then
  state_text = T"Peers connected"
elseif enabled_on and running then
  state_text = T"Waiting for peers"
elseif enabled_on then
  state_text = T"Interface down"
end
local light = (enabled_on and running) and "1" or "0"
local modal_path
if ngx.ctx.session:hasAccess("/modals/wireguard-modal.lp") then modal_path = "/modals/wireguard-modal.lp" end

ngx.print('<div class="span3"><div class="smallcard">')
ngx.print(ui_helper.createCardHeader(T"WireGuard", modal_path))
ngx.print('<div class="content card_bg" data-bg-text="&#xf084;">')
ngx.print(
  '<p class="subinfos wireguard-card-status">',
  ui_helper.createSimpleLight(
    light,
    state_text,
    { span = { class = "simple-desc wireguard-status-light" } }
  ),
  '</p>'
)
if status.ip and status.ip ~= "" then
  ngx.print('<p class="subinfos">', T"Tunnel address", ': <strong>', escape(status.ip), '</strong></p>')
end
ngx.print('<p class="subinfos">')
ngx.print(format(N("<strong>%d of %d peer</strong> active", "<strong>%d of %d peers</strong> active", peers), live, peers))
ngx.print('</p>')
ngx.print('</div></div></div>')
