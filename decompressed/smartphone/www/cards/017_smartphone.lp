--pretranslated: do not change this file
gettext.textdomain('webui-mobiled')
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local target
if session:hasAccess("/modals/smartphone-modal.lp") then target = "/modals/smartphone-modal.lp" end
ngx.print('<div class="span3"><div class="smallcard">')
ngx.print(ui_helper.createCardHeader(T"Smartphone USB", target))
ngx.print('<div class="content card_bg" data-bg-text="&#xf10b;"><p class="subinfos">',
    T"Android telemetry and USB tethering controls", '</p><p class="subinfos">',
    T"Open for phone status and USB debugging authorization", '</p></div></div></div>')
