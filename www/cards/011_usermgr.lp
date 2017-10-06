--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session

if session:hasAccess("/modals/usermgr-modal.lp") then
  ngx.print('\
\
<div class="span3">\
    <div class="smallcard">\
        ');  ngx.print( ui_helper.createCardHeader(T"Management", "modals/usermgr-modal.lp") ); ngx.print('\
        <div class="content card_bg" data-bg-text="&#xf0c0;">\
		<div class="divtable">\
            <p class="subinfos">\
		<strong>\
		   ');  ngx.print(T"User management and log viewer"); ngx.print('<br>		      \
		</strong>\
            </p>\
        </div>\
		</div>\
    </div>\
</div>\
\
');  
end
  ngx.print('\
'); 