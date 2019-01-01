--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")

local find, sub, format, floor = string.find, string.sub, string.format, math.floor

local content = {
  status = "sys.class.xdsl.@line0.LinkStatus",
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
  dslam_version_raw = "rpc.xdslctl.DslamVersionRaw",
  dsl_profile = "rpc.xdslctl.DslProfile",
  dsl_port = "rpc.xdslctl.DslamPort"
}

content_helper.getExactContent(content)

if not ( content.dsl_linerate_down == "0" ) then

content.dsl_linerate_up = floor(tonumber(content.dsl_linerate_up) / 10) / 100 .. " Mbps"
content.dsl_linerate_down = floor(tonumber(content.dsl_linerate_down) / 10) / 100 .. " Mbps"
content.max_upstream = floor(tonumber(content.max_upstream) / 10) / 100 .. " Mbps"
content.max_downstream = floor(tonumber(content.max_downstream) / 10) / 100 .. " Mbps"

if not ( content.dsl_type:match("ADSL") ) then
	content.dsl_margin_down = content.dsl_margin_SNRM_down
	content.dsl_margin_up = content.dsl_margin_SNRM_up
end

if content.dslam_chipset:match("BDCM") then
	content.dslam_chipset = "Broadcom" .. " ( " .. content.dslam_chipset .. " )"
elseif content.dslam_chipset:match("IFTN") then
	content.dslam_chipset = "Infineon" .. " ( " .. content.dslam_chipset .. " )"
end

if content.status == "Showtime" then
	content.status = T"Connected"
elseif content.status == "" then
	content.status = T"Disconnected"
else
	content.status = T(content.status)
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
	
	basic.span["data-bind"] = "text: status"
	html[#html + 1] = ui_helper.createLabel(T"Status", content["status"], basic)
	basic.span["data-bind"] = nil
	html[#html + 1] = ui_helper.createLabel(T"xDSL Version", content["version"], basic)
	basic.span["data-bind"] = "text: dslam_chipset"
	html[#html + 1] = ui_helper.createLabel(T"DSLAM Chipset",content.dslam_chipset, basic )
	basic.span["data-bind"] = "text: dslam_version"
	if content.dslam_version_raw:sub(0,2) == "0x" then
		html[#html + 1] = ui_helper.createLabel(T"DSLAM Firmware",format("%s ( %s )", content.dslam_version , content.dslam_version_raw) , basic )
	elseif content.dslam_version_raw == "" then
		html[#html + 1] = ui_helper.createLabel(T"DSLAM Firmware",T"Can't recover dslam version." , basic )
	else
		html[#html + 1] = ui_helper.createLabel(T"DSLAM Firmware",format(T"Invalid version, can't convert. Raw value: %s", content.dslam_version_raw) , basic )
	end
	if(content.dsl_profile ~= "Not Found") then
		basic.span["data-bind"] = "text: dsl_profile"
		html[#html + 1] = ui_helper.createLabel(T"VDSL Profile", content.dsl_profile, basic )
		basic.span["data-bind"] = "text: dsl_port"
		html[#html + 1] = ui_helper.createLabel(T"VDSL DSLAM Port", content.dsl_port, basic )
	end

	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Max Rate") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> <span data-bind="text: max_downstream">%s</span>',content["max_downstream"])
	html[#html + 1] =		'</br>'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> <span data-bind="text: max_upstream">%s</span>', content["max_upstream"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Rate") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> <span data-bind="text: dsl_linerate_down">%s</span>',content["dsl_linerate_down"])
	html[#html + 1] =		'</br>'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> <span data-bind="text: dsl_linerate_up">%s</span>', content["dsl_linerate_up"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Noise Margin") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> <span data-bind="text: dsl_margin_down">%s</span> dB',content["dsl_margin_down"])
	html[#html + 1] =		'</br>'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> <span data-bind="text: dsl_margin_up">%s</span> dB', content["dsl_margin_up"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Attenuation") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> <span data-bind="text: dsl_attenuation_down">%s</span> dB',content["dsl_attenuation_down"])
	html[#html + 1] =		'</br>'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> <span data-bind="text: dsl_attenuation_up">%s</span> dB', content["dsl_attenuation_up"])
	html[#html + 1] =	  '</span>'
	html[#html + 1] =   '</div>'
	html[#html + 1] = '</div>'
	
	html[#html + 1] = '<div class="control-group">'
	html[#html + 1] =   '<label class="control-label">' .. T("Power") .. '</label>'
	html[#html + 1] =   '<div class="controls">'
	html[#html + 1] =     '<span id="Rate" class=" simple-desc span3">'
	html[#html + 1] =		format('<i class="icon-download icon-small gray"></i> <span data-bind="text: dsl_power_down">%s</span> dBm',content["dsl_power_down"])
	html[#html + 1] =		'</br>'
	html[#html + 1] =		format('<i class="icon-upload icon-small gray"></i> <span data-bind="text: dsl_power_up">%s</span> dBm', content["dsl_power_up"])
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
<script>\
var InfoXdslCardInterval;\
$(document).ready(function () {\
	var InfoXdslCardBinding = { \
		status: ko.observable(), \
		max_upstream: ko.observable(), \
		max_downstream: ko.observable(), \
		dsl_linerate_up: ko.observable(), \
		dsl_linerate_down: ko.observable(), \
		dsl_margin_up: ko.observable(), \
		dsl_margin_down: ko.observable(), \
		dsl_attenuation_up: ko.observable(), \
		dsl_attenuation_down: ko.observable(), \
		dsl_power_up: ko.observable(), \
		dsl_power_down: ko.observable(), \
		dsl_type: ko.observable(), \
		dsl_margin_SNRM_up: ko.observable(), \
		dsl_margin_SNRM_down: ko.observable(), \
		dslam_version: ko.observable(), \
		dslam_chipset: ko.observable(), \
		dsl_profile: ko.observable(), \
		dsl_port: ko.observable(), \
	};\
	function InfoXdslCardRefresh() {\
		$.post("/ajax/internet.lua?datatype=xdsl", [tch.elementCSRFtoken()], function(data) {\
			if(data.status != undefined) {\
				InfoXdslCardBinding.status(data.status);\
				InfoXdslCardBinding.max_upstream(data.max_upstream);\
				InfoXdslCardBinding.max_downstream(data.max_downstream);\
				InfoXdslCardBinding.dsl_linerate_up(data.dsl_linerate_up);\
				InfoXdslCardBinding.dsl_linerate_down(data.dsl_linerate_down);\
				InfoXdslCardBinding.dsl_margin_up(data.dsl_margin_up);\
				InfoXdslCardBinding.dsl_margin_down(data.dsl_margin_down);\
				InfoXdslCardBinding.dsl_attenuation_up(data.dsl_attenuation_up);\
				InfoXdslCardBinding.dsl_attenuation_down(data.dsl_attenuation_down);\
				InfoXdslCardBinding.dsl_power_up(data.dsl_power_up);\
				InfoXdslCardBinding.dsl_power_down(data.dsl_power_down);\
				InfoXdslCardBinding.dsl_type(data.dsl_type);\
				InfoXdslCardBinding.dsl_margin_SNRM_up(data.dsl_margin_SNRM_up);\
				InfoXdslCardBinding.dsl_margin_SNRM_down(data.dsl_margin_SNRM_down);\
				InfoXdslCardBinding.dslam_version(data.dslam_version);\
				InfoXdslCardBinding.dslam_chipset(data.dslam_chipset);\
				InfoXdslCardBinding.dsl_profile(data.dsl_profile);\
				InfoXdslCardBinding.dsl_port(data.dsl_port);\
			}\
		}, "json");\
	};\
\
	InfoXdslCardRefresh();\
	ko.applyBindings(InfoXdslCardBinding, document.getElementById("xdsltab"));\
	InfoXdslCardInterval = setInterval(InfoXdslCardRefresh, 5000);\
	KoRequest.push(InfoXdslCardInterval);\
})\
</script>\
'); 
end