--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")

local find, sub, format, floor = string.find, string.sub, string.format, math.floor

local content = {
  status = "Device.DSL.Line.1.Status",
  version = "rpc.xdsl.dslversion",
  max_upstream = "Device.DSL.Line.1.UpstreamMaxBitRate",
  max_downstream = "Device.DSL.Line.1.DownstreamMaxBitRate",
  dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
  dsl_margin_up = "sys.class.xdsl.@line0.UpstreamNoiseMargin",
  dsl_margin_down = "sys.class.xdsl.@line0.DownstreamNoiseMargin",
  dsl_attenuation_up = "sys.class.xdsl.@line0.UpstreamAttenuation",
  dsl_attenuation_down = "sys.class.xdsl.@line0.DownstreamAttenuation",
  dsl_power_up = "sys.class.xdsl.@line0.UpstreamPower",
  dsl_power_down = "sys.class.xdsl.@line0.DownstreamPower",
  dsl_type = "sys.class.xdsl.@line0.ModulationType",
  dsl_margin_SNRM_up = "sys.class.xdsl.@line0.UpstreamSNRMpb",
  dsl_margin_SNRM_down = "sys.class.xdsl.@line0.DownstreamSNRMpb",
  dslam_chipset = "rpc.xdslctl.DslamChipset",
  dslam_version = "rpc.xdslctl.DslamVersion",
  dslam_version_raw = "rpc.xdslctl.DslamVersionRaw"
}

content_helper.getExactContent(content)

if not ( content.max_upstream == "0" ) then

content.dsl_linerate_up = floor(tonumber(content.dsl_linerate_up) / 10) / 100 .. "Mbps"
content.dsl_linerate_down = floor(tonumber(content.dsl_linerate_down) / 10) / 100 .. "Mbps"
content.max_upstream = floor(tonumber(content.max_upstream) / 10) / 100 .. "Mbps"
content.max_downstream = floor(tonumber(content.max_downstream) / 10) / 100 .. "Mbps"

if not ( content.dsl_type:match("ADSL") ) then
	content.dsl_margin_down = content.dsl_margin_SNRM_down
	content.dsl_margin_up = content.dsl_margin_SNRM_up
end

if content.dslam_chipset:match("BDCM") then
	content.dslam_chipset = "Broadcom" .. " ( " .. content.dslam_chipset .. " )"
elseif content.dslam_chipset:match("IFTN") then
	content.dslam_chipset = "Infineon" .. " ( " .. content.dslam_chipset .. " )"
end

  ngx.print('\
\
<div class="infocard" id="xdsltab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"xDSL Info", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf022;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local basic = {
      span = {
        class = "span3"
      },
    }
	
	local html = {}
	
	html[#html + 1] = ui_helper.createLabel(T"Status", content["status"], basic)
	html[#html + 1] = ui_helper.createLabel(T"xDSL Version", content["version"], basic)
	html[#html + 1] = ui_helper.createLabel(T"Dslam Chipset",content.dslam_chipset, span5 )
	if content.dslam_version_raw:sub(0,2) == "0x" then
		html[#html + 1] = ui_helper.createLabel(T"Dslam Firmware Version",format("%s ( %s )", content.dslam_version , content.dslam_version_raw) , span5 )
	elseif content.dslam_version_raw == "" then
		html[#html + 1] = ui_helper.createLabel(T"Dslam Firmware Version",T"Can't recover dslam version." , span5 )
	else
		html[#html + 1] = ui_helper.createLabel(T"Dslam Firmware Version",format(T"Invalid version, can't convert. Raw value: %s", content.dslam_version_raw) , span5 )
	end
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Max Rate") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> %s',content["max_downstream"])
	html[#html + 1] =		'&nbsp'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> %s', content["max_upstream"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Rate") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> %s',content["dsl_linerate_down"])
	html[#html + 1] =		'&nbsp'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> %s', content["dsl_linerate_up"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Noise Margin") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> %s dB',content["dsl_margin_up"])
	html[#html + 1] =		'</br>'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> %s dB', content["dsl_margin_down"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Attenuation") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> %s dB',content["dsl_attenuation_up"])
	html[#html + 1] =		'</br>'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> %s dB', content["dsl_attenuation_down"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Power") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> %s dBm',content["dsl_power_up"])
	html[#html + 1] =		'&nbsp'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> %s dBm', content["dsl_power_down"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
'); 
end