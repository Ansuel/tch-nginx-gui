--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local untaint_mt = require("web.taint").untaint_mt
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local content_helper = require("web.content_helper")

local modem_graph_link = ""

local content = {
  cronEntires   = "rpc.system.cron.CronNumberOfEntries",
  initEntries = "rpc.system.init.InitNumberOfEntries",
}
content_helper.getExactContent(content)

if session:hasAccess("/modals/usermgr-modal.lp") then
modem_stats_link = 'class="modal-link" data-toggle="modal" data-remote="/modals/modem-stats-modal.lp" data-id="modem-stats-modal"'
  ngx.print('\
\
<div class="span3">\
    <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
        ');  ngx.print( ui_helper.createCardHeader(T"Management", "/modals/usermgr-modal.lp") ); ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf0c0;">\
		    <div class="divtable">')
        
        local html = {}

        html[#html + 1] = '<i " class="fas fa-user-alt" aria-hidden="true" href="#">&nbsp</i>'
        html[#html + 1] = '<strong>'..T"User Management and Log Viewer"..'</strong>'
        html[#html + 1] = '<br>'
        html[#html + 1] = '<i class="fas fa-chart-line" href="#">&nbsp</i>'
        html[#html + 1] = format( '<strong id = "Modem_Stats" %1$s>%s</strong>', modem_stats_link, T"Modem Stats")
        html[#html + 1] = '<br>'
        html[#html + 1] = '<i " class="fas fa-list-ul" aria-hidden="true" href="#">&nbsp</i>'
        html[#html + 1] = format(N("<strong>%s cron rule</strong> active","<strong>%s cron rules</strong> active"), content.cronEntires,content.cronEntires)
        html[#html + 1] = '<br>'
        html[#html + 1] = '<i " class="fas fa-list-ul" aria-hidden="true" href="#">&nbsp</i>'
        html[#html + 1] = format(N("<strong>%s init script</strong> active","<strong>%s init scripts</strong> active"), content.initEntries,content.initEntries)
        html[#html + 1] = '<br>'
        
        ngx.print(html)

        ngx.print('\
        </div>\
		  </div>\
    </div>\
</div>\
\
');  
end
  ngx.print('\
'); 
