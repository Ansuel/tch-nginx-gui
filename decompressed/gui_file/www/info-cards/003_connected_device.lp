--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local match = string.match

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
