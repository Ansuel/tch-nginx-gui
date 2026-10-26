--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local content = {
  status = "rpc.mmpbx.state",
  accCode = "uci.mmpbxbrcmdectdev.dect_base.access_code",
  baseName = "uci.mmpbxbrcmdectdev.dect_base.user_friendly_name",
  emission = "rpc.mmpbx.dectemission.state",
}

content_helper.getExactContent(content)

local status_map = {
	STARTING = T"Starting",
	RUNNING = T"Running",
	STOPPING = T"Stopping",
	NA = T"Not Available",
}

local untaint_mt = require("web.taint").untaint_mt
setmetatable(status_map, untaint_mt)

local mmpbx_light = content["status"]=="NA" and "0" or "1"
local mmpbx_status = status_map[content.status] or content.status

  ngx.print('\
\
<div class="infocard" id="infommpbxdtab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Telephony Info", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf095;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local basic = {
      span = {
        class = "span3"
      },
    }
	
	local html = {}

    html[#html + 1] = '<span data-bind="html: mmpbx_status">'
	html[#html + 1] = ui_helper.createLabel(T"Service", ui_helper.createSimpleLight(mmpbx_light, mmpbx_status), basic)
    html[#html + 1] = '</span>'

	if ( variant == "Technicolor TG799vac" ) or ( variant == "Technicolor TG800vac" )  then
        html[#html + 1] = ui_helper.createLabel(T"DECT Emission Mode ", ui_helper.createSimpleLight(content.emission, content.emission == "1" and T"Enabled" or T"Disabled"), basic)
        html[#html + 1] = ui_helper.createLabel(T"Base Name", content["baseName"], basic)
        html[#html + 1] = ui_helper.createLabel(T"Base Code", content["accCode"], basic)
	end
	
	html[#html + 1] = '<span data-bind="html: mmpbx_table">'
    html[#html + 1] = '<div class="spinner3"><div class="rect1"></div><div class="rect2"></div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div>'
    html[#html + 1] = '</span>'
	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
<script>\
$(document).ready(function () {\
	new modgui.createAjaxUpdateCard("infommpbxdtab","/ajax/mmpbx_status.lua","InfoMmpbxCardInterval",4000);\
})\
</script>\
'); 
