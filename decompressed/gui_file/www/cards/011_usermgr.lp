--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session

local modem_graph_link = ""

if session:hasAccess("/modals/usermgr-modal.lp") then
modem_stats_link = 'class="modal-link" data-toggle="modal" data-remote="/modals/modem-stats-modal.lp" data-id="modem-stats-modal"'
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
			<p class="subinfos">\
				<i style="margin-left:-20px;" class="fas fa-chart-line" href="#">&nbsp</i>\
				'); ngx.print( format( '<strong id = "Modem_Stats" %1$s>%s</strong>', modem_stats_link, T"Modem Stats") ); ngx.print('\
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
