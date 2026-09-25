--pretranslated: do not change this file
gettext.textdomain('webui-dumaos')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local content_dumaos = {
  status = "rpc.dumaos.status"
}

content_helper.getExactContent(content_dumaos)

local running = content_dumaos.status == "1"
local switchtext = running and T"DumaOS running" or T"DumaOS stopped"

ngx.print('<div class="span3"><div class="smallcard">')
ngx.print(ui_helper.createCardHeader(T"DumaOS", nil))
ngx.print('<div class="content card_bg" data-bg-text="&#xf201;"><div class="divtable">')
ngx.print(
  ui_helper.createSimpleLight(running and "1" or "0", switchtext),
  '<p class="subinfos"><a href="/desktop" target="_blank" rel="noopener" onclick="event.stopPropagation()" ontouchend="event.stopPropagation()">',
  T"Open interface",
  '</a></p>'
)
ngx.print('</div></div></div></div>')
