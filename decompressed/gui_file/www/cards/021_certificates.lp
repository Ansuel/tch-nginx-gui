--pretranslated: do not change this file
 
--pretranslated: do not change this file
-- Enable localization
local ui_helper = require("web.ui_helper")
gettext.textdomain('webui-core')

local session = ngx.ctx.session
local modalPath = "/modals/certificates-list-modal.lp"
if session:hasAccess(modalPath) then
  ngx.print('\
\
<div class = "span3">\
  <div class = "smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Paired devices", modalPath) ); ngx.print('\
    <div class = "content card_bg" data-bg-text = "">\
      <p class="subinfos">');  ngx.print(T"Details for paired devices"); ngx.print('</p>\
    </div>\
  </div>\
</div>\
');  end  ngx.print('\
'); 