--pretranslated: do not change this file

gettext.textdomain('webui-voice')

local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local modal_path = "/modals/asterisk-profile-modal.lp"

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

if not session:hasAccess(modal_path) or
    not file_exists("/etc/init.d/asterisk") or
    not file_exists("/etc/init.d/pbx-asterisk") then
  return
end

ngx.print('<div class="span3"><div class="smallcard" data-aos="zoom-in">')
ngx.print(ui_helper.createCardHeader(T"Asterisk", modal_path))
ngx.print('<div class="content card_bg" data-bg-text="&#xf095;"><div class="divtable">')
ngx.print('<p class="subinfos">' .. T"Asterisk PBX settings and SIP accounts" .. '</p>')
ngx.print('</div></div></div></div>')
