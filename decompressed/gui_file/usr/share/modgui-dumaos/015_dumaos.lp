--pretranslated: do not change this file
gettext.textdomain('webui-dumaos')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local content_dumaos = {
  status = "rpc.dumaos.status",
  enabled = "rpc.dumaos.enabled"
}

content_helper.getExactContent(content_dumaos)

local running = content_dumaos.status == "1"
local switchtext = running and T"DumaOS running" or T"DumaOS stopped"
local modal_path
if ngx.ctx.session:hasAccess("/modals/dumaos-modal.lp") then
  modal_path = "/modals/dumaos-modal.lp"
end

ngx.print('<div class="span3"><div class="smallcard">')
ngx.print(ui_helper.createCardHeader(T"DumaOS", modal_path, "enabled", content_dumaos.enabled))
ngx.print('<div class="content card_bg" data-bg-text="&#xf201;"><div class="divtable">')
ngx.print(
  ui_helper.createSimpleLight(running and "1" or "0", switchtext),
  '<p class="subinfos"><a class="card-direct-link" href="/desktop/">',
  T"Open interface",
  '</a></p>'
)
ngx.print('</div></div></div></div>')
