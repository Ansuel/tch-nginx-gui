--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")

local quantenna_wifi = proxy.get("uci.env.var.qtn_eth_mac") and true or false

local port_columns = {
  {--[2]
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
	
	if data.status == "Up" then
		data.status = T"Connected"
	else
		data.status = T"Disconnected"
	end
	
	if data.speed == "1000" then
		data.speed = "1 Gpbs"
	elseif data.speed == "100" then
		data.speed = "100 Mbps"
	elseif data.speed == "10" then
		data.speed = "10 Mbps"
	end
	
	if quantenna_wifi and data.paramindex:match("eth5") then
		data.paramindex = "WiFi 5GHz"
	elseif data.paramindex:match("eth4") and ( proxy.get("uci.ethernet.port.@eth4.wan")[1].value == "1" ) then
		data.paramindex = "WAN"
	else
		port = data.paramindex:gsub("eth","")
		data.paramindex = "LAN - " .. tonumber(port)+1
	end
  
  return true
end

local  port_data,  port_helpmsg = post_helper.handleTableQuery(port_columns,  port_options,  port_filter , nil, nil)

  ngx.print('\
\
<div class="infocard" id="portstab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Ports", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf362;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local html = {}
	
	html[#html + 1] = ui_helper.createTable(port_columns, port_data, port_options, nil, port_helpmsg)
	
	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
'); 