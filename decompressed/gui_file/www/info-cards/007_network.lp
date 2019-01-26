--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

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