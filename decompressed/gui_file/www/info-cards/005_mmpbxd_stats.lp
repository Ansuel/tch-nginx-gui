--pretranslated: do not change this file
 
-- Enable localization

gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local mmpbxd_columns = {
  {--[2]
    header = T"Status",
    name = "sipRegisterState",
    param = "sipRegisterState",
    type = "text",
  },
  {--[3]
    header = T"Number",
    name = "uri",
    param = "uri",
    type = "text",
  },
  {--[4]
    header = T"Line State",
    name = "callState",
    param = "callState",
    type = "text",
  },
}

local mmpbxd_filter = function(data)
  if ( data.enable == "false" ) or ( data.sipRegisterState == "" ) then
	return false
  end
  if data.uri and data.uri:match("+") then
    data.uri = data.uri:sub(4)
  end
  
  if data.callState then
    if ( data.callState == "MMPBX_CALLSTATE_IDLE" ) then
	  data.callState =  T"Idle"
    end
	  
    if ( data.callState == "MMPBX_CALLSTATE_DIALING" ) then
	  data.callState =  T"Dialing"
    end
	  
    if ( data.callState == "MMPBX_CALLSTATE_CALL_DELIVERED" ) then
	  data.callState =  T"Delivered/In Progress"
    end
  end
  
  return true
end

local  mmpbxd_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "mmpbxd",
    basepath = "rpc.mmpbx.profile.",
}

local  mmpbxd_data = content_helper.loadTableData(mmpbxd_options.basepath, mmpbxd_columns ,  mmpbxd_filter , nil)

local content = {
  status = "rpc.mmpbx.state",

  accCode = "uci.mmpbxbrcmdectdev.dect_base.access_code",
  baseName = "uci.mmpbxbrcmdectdev.dect_base.user_friendly_name",

  emission = "rpc.mmpbx.dectemission.state", 

}

content_helper.getExactContent(content)

if not ( content.max_upstream == "0" ) then
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
	
	html[#html + 1] = ui_helper.createLabel(T"Service", content["status"], basic)
	
	if ( variant == "Technicolor TG799vac" ) or ( variant == "Technicolor TG800vac" )  then
		if ( content.emission == "1" ) then
			html[#html + 1] = ui_helper.createLabel(T"DECT Emission Mode ", T"Enabled", basic)
		else 
			html[#html + 1] = ui_helper.createLabel(T"DECT Emission Mode ", T"Disabled", basic)
		end
	html[#html + 1] = ui_helper.createLabel(T"Base Name", content["baseName"], basic)
	html[#html + 1] = ui_helper.createLabel(T"Base Code", content["accCode"], basic)
	end
	
	html[#html + 1] = '<span data-bind="html: mmpbx_table">'
	html[#html + 1] = ui_helper.createTable(mmpbxd_columns, mmpbxd_data, mmpbxd_options, nil, nil)
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
var InfoMmpbxCardInterval;\
$(document).ready(function () {\
	var InfoMmpbxCardBinding = {\
		mmpbx_table: ko.observable(),\
	};\
	function InfoMmpbxCardRefresh() {\
		$.post("/ajax/mmpbx_status.lua", [tch.elementCSRFtoken()], function(data) {\
			if(data.mmpbx_table != undefined) {\
				InfoMmpbxCardBinding.mmpbx_table(data.mmpbx_table);\
			}\
		}, "json");\
	};\
\
	InfoMmpbxCardRefresh();\
	ko.applyBindings(InfoMmpbxCardBinding, document.getElementById("infommpbxdtab"));\
	InfoMmpbxCardInterval = setInterval(InfoMmpbxCardRefresh, 10000);\
	KoRequest.push(InfoMmpbxCardInterval);\
})\
</script>\
'); 
end
