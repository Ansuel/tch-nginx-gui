--pretranslated: do not change this file
gettext.textdomain('webui-openvpn-server')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format
local content = {
  enabled = "uci.openvpn.openvpn.@server.enabled",
  client_enabled = "uci.openvpn.openvpn.@client.enabled",
}
content_helper.getExactContent(content)
local enabled = content.enabled == "1" and "1" or "0"
local status_text = enabled == "1" and T"OpenVPN server enabled" or T"OpenVPN server disabled"
local client_enabled = content.client_enabled == "1" and "1" or "0"
local client_text = client_enabled == "1" and T"OpenVPN client enabled" or T"OpenVPN client disabled"
local connected = 0
local status = enabled == "1" and io.open("/tmp/openvpn-status.log", "r")
if status then
  for line in status:lines() do
    if line:match("^CLIENT_LIST,") or (line:match("^[^,]+,[^,]+,%d+,%d+,") and not line:match("^Common Name,")) then connected = connected + 1 end
  end
  status:close()
end
local modal_path
if ngx.ctx.session:hasAccess("/modals/openvpn-server-modal.lp") then modal_path = "/modals/openvpn-server-modal.lp" end
ngx.print('<div class="span3"><div class="smallcard">')
ngx.print(ui_helper.createCardHeader(T"OpenVPN", modal_path))
ngx.print('<div class="content card_bg" data-bg-text="&#xf023;">', ui_helper.createSimpleLight(enabled, status_text), '<p class="subinfos">')
ngx.print(format(N("<strong>%d client</strong> is connected", "<strong>%d clients</strong> are connected", connected), connected))
ngx.print('</p>', ui_helper.createSimpleLight(client_enabled, client_text), '<p class="subinfos">')
if client_enabled == "1" then
  local tunnel = io.open("/sys/class/net/tun1/operstate", "r")
  ngx.print(tunnel and T"Client tunnel is up" or T"Client tunnel is down")
  if tunnel then tunnel:close() end
end
ngx.print('</p></div></div></div>')
