--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local datamodel = require ("datamodel")

local session = ngx.ctx.session
local modalPath = "/modals/cwmpconf-modal.lp"

local cwmp_run, error = datamodel.get("uci.cwmpd.cwmpd_config.state")

if cwmp_run then
    cwmp_run = format("%s",cwmp_run[1].value)
else
    cwmp_run = "0"
end

if session:hasAccess(modalPath) then

local value = {
      cwmp_url              = "uci.cwmpd.cwmpd_config.acs_url",
      cwmp_enabled            = "uci.cwmpd.cwmpd_config.state",
      cwmp_periodic         = "uci.cwmpd.cwmpd_config.periodicinform_interval",
}

content_helper.getExactContent(value)

local switchName = "cwmp_state"

local url = value.cwmp_url
if url == "" then
  url = T"Not Set"
end

local state, light
if value.cwmp_enabled  == "1" then
  state = T"Enabled"
  light = "green"
else
  state = T"Disabled"
  light = "off"
end

ngx.print('\
<div class="span3">\
    <div class="smallcard" data-aos="fade-up" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
        '); ngx.print( ui_helper.createCardHeader(T"CWMP", modalPath, switchName, cwmp_run) ); ngx.print('\
        <div class="content card_bg" data-bg-text="&#xf1c0;">\
		<div class="divtable">\
                '); ngx.print(ui_helper.createSimpleLight(nil, state, { light = { class = light, id = "cwmpconfcard_cwmpstatusled"}, span = { id = "cwmpconfcard_cwmpstatus" } }) );  if content.cwmp_state == "1" then ngx.print('\
            <p class="subinfos">\
                '); ngx.print(format(T"ACS URL: <strong id=\"cwmpconfcard_acsurl\">%s</strong>",url )); ngx.print('\
            </p>\
            <p class="subinfos">\
                '); ngx.print(format(T"Periodic: <strong id=\"cwmpconfcard_periodicinterval\">%s</strong>",value["cwmp_periodic"] )); end ngx.print('\
            </p>\
         </div>\
		 </div>\
    </div>\
</div>\
');

end
