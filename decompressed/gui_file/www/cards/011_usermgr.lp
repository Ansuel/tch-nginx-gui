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
    <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
        ');  ngx.print( ui_helper.createCardHeader(T"Management", "/modals/usermgr-modal.lp") ); ngx.print('\
        <div class="content card_bg" data-bg-text="&#xf0c0;">\
		<div class="divtable">\
            <span class="simple-desc">\
            <i " class="fas fa-user-alt" aria-hidden="true" href="#">&nbsp</i>\
		<strong>\
		   ');  ngx.print(T"User Management and Log Viewer"); ngx.print('<br>\
		</strong>\
            </span>\
        </div>\
		</div>\
    </div>\
</div>\
\
');  
end
  ngx.print('\
'); 
