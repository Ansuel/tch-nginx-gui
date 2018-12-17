--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local match = string.match

local devices_columns = {
  {--[2]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
  },
  {--[3]
    header = T"IPv4",
    name = "ipv4",
    param = "IPAddress",
    type = "text",
  },
  {--[6]
    header = T"InterfaceType",
    name = "interfacetype",
    param = "InterfaceType",
	type = "text",
  },
  {--[11]
    header = T"SSID",
    name = "ssid",
    param = "SSID",
    type = "text",
  },
}

--Construct the device type based on value of L2Interface
local devices_filter = function(data)

  --Display only the IP Address of physically connected devices
  if data["State"] and data["State"] == "0" then
     return false
  end

  if match(data["L2Interface"], "^wl0") then
    data["InterfaceType"] = "wireless - 2.4GHz"
  elseif match(data["L2Interface"], "^wl1") then
    data["InterfaceType"] = "wireless - 5GHz"
  elseif match(data["L2Interface"], "eth*") then
    data["InterfaceType"] = "Ethernet - " .. data.Port
  elseif match(data["L2Interface"], "moca*") then
    data["InterfaceType"] = "MoCA"
  end

  return true
end

local devices_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "rpc.hosts.host.",
}

local devices_data = content_helper.loadTableData(devices_options.basepath, devices_columns, devices_filter , nil)

  ngx.print('\
\
<div class="infocard" id="infodevicetab">\
    <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Connected Devices", nil, nil, nil, nil) ); ngx.print('\
      <div class="content card_bg" data-bg-text="&#xf1e6;">\
		<div class="divtable">\
		  <form class="form-horizontal">\
			<fieldset>');
	
	local html = {}
	
	html[#html + 1] = '<span data-bind="html: device_table">'
    html[#html + 1] = ui_helper.createTable(devices_columns, devices_data, devices_options, nil, nil)
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
var InfoDeviceCardInterval;\
$(document).ready(function () {\
	var InfoDeviceCardBinding = {\
		device_table: ko.observable(),\
	};\
	function InfoDeviceCardRefresh() {\
		$.post("/ajax/connected_device.lua", [tch.elementCSRFtoken()], function(data) {\
			if(data.device_table != undefined) {\
				InfoDeviceCardBinding.device_table(data.device_table);\
			}\
		}, "json");\
	};\
\
	InfoDeviceCardRefresh();\
	ko.applyBindings(InfoDeviceCardBinding, document.getElementById("infodevicetab"));\
	InfoDeviceCardInterval = setInterval(InfoDeviceCardRefresh, 10000);\
	KoRequest.push(InfoDeviceCardInterval);\
})\
</script>\
'); 
