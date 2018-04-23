--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
end
  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath) ); ngx.print('\
<div class="content card_bg" data-bg-text="&#xf0ac;">\
<div class="divtable">\
  <p class="subinfos">\
    ');  ngx.print( T("Gateway in bridge mode") ); ngx.print('\
  </p>\
</div>\
</div>\
'); 