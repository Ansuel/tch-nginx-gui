--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local quantenna_wifi = proxy.get("uci.env.var.qtn_eth_mac")
quantenna_wifi = ((quantenna_wifi and quantenna_wifi[1].value~="") and true or false)

local port_columns = {
  {--[1]
    header = T"Type",
    name = "type",
    param = "paramindex",
    type = "text",
    readonly = true,
  },
  {--[2]
    header = T"Status",
    name = "status",
    param = "status",
    type = "text",
    readonly = true,
  },
  {--[3]
    header = T"Speed",
    name = "speed",
    param = "speed",
    type = "text",
    readonly = true,
  },
  {--[4]
    header = T"Mode",
    name = "mode",
    param = "mode",
    type = "text",
    readonly = true,
  },
}

local  port_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "port",
    basepath = "sys.eth.port.@.",
}

local port_filter = function(data)

	data.status = ui_helper.createSimpleLight(data.status == "Up" and "1" or "0", "", {}) --status

	if data.speed == "1000" then
		data.speed = "1 Gpbs"
	elseif data.speed == "100" then
		data.speed = "100 Mbps"
	elseif data.speed == "10" then
		data.speed = "10 Mbps"
	end

	if quantenna_wifi and data.paramindex:match("eth5") then
		return false
	elseif data.paramindex:match("eth4") and ( proxy.get("uci.ethernet.port.@eth4.wan")[1].value == "1" ) then
		data.paramindex = "WAN"
	else
		port = data.paramindex:gsub("eth","")
		data.paramindex = "LAN - " .. tonumber(port)+1
	end

  return true
end

local  port_data = content_helper.loadTableData(port_options.basepath, port_columns,  port_filter , nil)

local wifi_content = {
	wifi24_status = "rpc.wireless.radio.@radio_2G.admin_state",
	wifi24_speed = "rpc.wireless.radio.@radio_2G.phy_rate",
	wifi24_mode = "rpc.wireless.radio.@radio_2G.standard",
	wifi5_status = "rpc.wireless.radio.@radio_5G.admin_state",
	wifi5_speed = "rpc.wireless.radio.@radio_5G.phy_rate",
	wifi5_mode = "rpc.wireless.radio.@radio_5G.standard",
}

content_helper.getExactContent(wifi_content)

if wifi_content.wifi24_mode == "bgn" then
	wifi_content.wifi24_mode = "b/g/n"
elseif wifi_content.wifi24_mode == "gn" then
	wifi_content.wifi24_mode = "g/n"
end

if wifi_content.wifi5_mode == "anac" then
	wifi_content.wifi5_mode = "a/n/ac"
elseif wifi_content.wifi5_mode == "an" then
	wifi_content.wifi5_mode = "a/n"
end

port_data[#port_data+1] = {
	"Wi-Fi 2.4 Ghz", --type
	ui_helper.createSimpleLight(wifi_content.wifi24_status, "", {}, "fa fa-wifi"), --status
	( wifi_content.wifi24_status == "1" ) and ( wifi_content.wifi24_speed / 1000 .. " Mbps" ) or "", --speed
	( wifi_content.wifi24_status == "1" ) and wifi_content.wifi24_mode or "", --mode
}

port_data[#port_data+1] = {
	"Wi-Fi 5 Ghz", --type
	ui_helper.createSimpleLight(wifi_content.wifi5_status, "", {}, "fa fa-wifi"), --status
	( wifi_content.wifi5_status == "1" ) and ( wifi_content.wifi5_speed / 1000 .. " Mbps" ) or "", --speed
	( wifi_content.wifi5_status == "1" ) and wifi_content.wifi5_mode or "", --mode
}

table.sort(port_data, function (a, b)
    return a[1] < b[1]
end)

  ngx.print('\
\
<div class="infocard" id="infoporttab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Interfaces", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf362;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');

	local html = {}

	html[#html + 1] = '<span data-bind="html: port_table">'
	html[#html + 1] = ui_helper.createTable(port_columns, port_data, port_options, nil, nil)
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
var InfoPortCardInterval;\
$(document).ready(function () {\
	var InfoPortCardBinding = {\
		port_table: ko.observable(),\
	};\
	function InfoPortCardRefresh() {\
		$.post("/ajax/port_status.lua", [tch.elementCSRFtoken()], function(data) {\
			if(data.port_table != undefined) {\
				InfoPortCardBinding.port_table(data.port_table);\
			}\
		}, "json");\
	};\
\
	InfoPortCardRefresh();\
	ko.applyBindings(InfoPortCardBinding, document.getElementById("infoporttab"));\
	InfoPortCardInterval = setInterval(InfoPortCardRefresh, 10000);\
	KoRequest.push(InfoPortCardInterval);\
})\
</script>\
'); 