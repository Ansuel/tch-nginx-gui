--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local leds_columns = {
	{ --[1]
		header = T"Color",
		name = "Color",
		param = "Color",
		type = "text",
	},
	{ --[2]
		header = T"Name",
		name = "Name",
		param = "Name",
		type = "text",
	},
	{ --[3]
		header = T"Status",
		name = "Status",
		param = "Status",
		type = "text",
	},
	{ --[4]
		header = T"Brightness",
		name = "Brightness",
		param = "Brightness",
		type = "text",
	}
}

local leds_options = {
	canEdit = false,
	canAdd = false,
	canDelete = false,
	tableid = "ledstable",
	basepath = "rpc.Leds.Led.",
}

local leds_filter = function(data)
	
	local color
	
	if data.Color == "None" then
		color = "grey"
		data.Color = "Off"
	else
		color = data.Color:lower()
	end
	
	data.Color = ui_helper.createSimpleLight(nil, T(data.Color), { light = { style = "background-color:"..color } })
	
	return true
end

local leds_data, leds_index = content_helper.loadTableData(leds_options.basepath, leds_columns,leds_filter)

  ngx.print('\
');  ngx.print(ui_helper.createHeader(T"Diagnostics", false, false, 1) ); ngx.print('\
<div class="modal-body update">\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-diagnostics.lp")
  ngx.print('\
');  
-- dummy form so that refresh button knows which page to reload, keep it
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/diagnostics-leds-modal.lp">\
  </form>\
  <fieldset id="diagnostics-network-tab">\
	<fieldset>\
	<legend>');  ngx.print( T"Leds State" ); ngx.print('</legend>')
	
	ngx.print(ui_helper.createTable(leds_columns, leds_data, leds_options))
	
	ngx.print('\
	</fieldset>\
  </fiedlset>\
  </div>\
');  ngx.print(ui_helper.createFooter() ); ngx.print('\
'); 