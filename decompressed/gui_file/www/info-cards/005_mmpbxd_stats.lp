--pretranslated: do not change this file
 
-- Enable localization
-- NG-92675 implement changes required from the customer

gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")

local find, sub, format = string.find, string.sub, string.format

local contentonly
local call1simple

if ngx.req.get_method() == "GET" then
	contentonly = ngx.req.get_uri_args().contentonly or false
end

local content = {
  status = "rpc.mmpbx.state",
  mode = "rpc.mmpbx.mode",
  
  en1 = "rpc.mmpbx.profile.@sip_profile_0.enable",
  en2 = "rpc.mmpbx.profile.@sip_profile_1.enable",
  en3 = "rpc.mmpbx.profile.@sip_profile_2.enable",
  
  state1 = "rpc.mmpbx.profile.@sip_profile_0.sipRegisterState",
  state2 = "rpc.mmpbx.profile.@sip_profile_1.sipRegisterState",
  state3 = "rpc.mmpbx.profile.@sip_profile_2.sipRegisterState",
  
  username1 = "uci.mmpbxrvsipnet.profile.@sip_profile_0.user_name",
  username2 = "uci.mmpbxrvsipnet.profile.@sip_profile_1.user_name",
  username3 = "uci.mmpbxrvsipnet.profile.@sip_profile_2.user_name",
  
  call1 = "rpc.mmpbx.profile.@sip_profile_0.callState",
  call2 = "rpc.mmpbx.profile.@sip_profile_1.callState",
  call3 = "rpc.mmpbx.profile.@sip_profile_2.callState",
  
  uri1 = "rpc.mmpbx.profile.@sip_profile_0.uri",
  uri2 = "rpc.mmpbx.profile.@sip_profile_1.uri",
  uri3 = "rpc.mmpbx.profile.@sip_profile_2.uri",

  accCode = "uci.mmpbxbrcmdectdev.dect_base.access_code",
  baseName = "uci.mmpbxbrcmdectdev.dect_base.user_friendly_name",

  emission = "rpc.mmpbx.dectemission.state", 

}


content_helper.getExactContent(content)



if not ( content.max_upstream == "0" ) then
  ngx.print('\
\
<div class="infocard" id="mmpbxdtab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Telephony Info", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf129;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local basic = {
      span = {
        class = "span3"
      },
    }
    local advanced = {
      group = {
        class = "advanced hide",
      },
      span = {
        class = "span5"
      },
    }
	local advancedshow = {
      group = {
        class = "advanced show",
      },
      span = {
        class = "span5"
      },
    }
	
	local html = {}
	
html[#html + 1] = ui_helper.createLabel(T"Status", content["status"], basic)
html[#html + 1] = ui_helper.createLabel(T"Mode", content["mode"], basic)
------------------------------------------------------------------------------------------------------------line1
if ( content.en1 == "true" ) then
html[#html + 1] = ui_helper.createLabel(T"Line 1 Status", T"Enabled", basic)                  
else
html[#html + 1] = ui_helper.createLabel(T"Line 1 Status", T"Disabled", basic)
end
html[#html + 1] = ui_helper.createLabel(T"Line 1 State", content["state1"], basic)

if not ( content.state1 == "Unregistered" ) then
html[#html + 1] = ui_helper.createLabel(T"      Username", content["username1"], basic)

if ( content.call1 == "MMPBX_CALLSTATE_IDLE" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Idle", basic)
end

if ( content.call1 == "MMPBX_CALLSTATE_DIALING" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Dialing", basic)
end

if ( content.call1 == "MMPBX_CALLSTATE_CALL_DELIVERED" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Delivered/In Progress", basic)
end

end
------------------------------------------------------------------------------------------------------------line2
if ( content.en2 == "true" ) then
html[#html + 1] = ui_helper.createLabel(T"Line 2 Status", T"Enabled", basic)                  
else
html[#html + 1] = ui_helper.createLabel(T"Line 2 Status", T"Disabled", basic)
end

html[#html + 1] = ui_helper.createLabel(T"Line 2 State", content["state2"], basic)                  
if not ( content.state2 == "Unregistered" ) then
html[#html + 1] = ui_helper.createLabel(T"      Username", content["username2"], basic)

if ( content.call2 == "MMPBX_CALLSTATE_IDLE" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Idle", basic)
end

if ( content.call2 == "MMPBX_CALLSTATE_DIALING" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Dialing", basic)
end

if ( content.call2 == "MMPBX_CALLSTATE_CALL_DELIVERED" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Delivered/In Progress", basic)
end

end
-----------------------------------------------------------------------------------------------------------line3
if ( content.en3 == "true" ) then
html[#html + 1] = ui_helper.createLabel(T"Line 3 Status", T"Enabled", basic)                  
else
html[#html + 1] = ui_helper.createLabel(T"Line 3 Status", T"Disabled", basic)
end

html[#html + 1] = ui_helper.createLabel(T"Line 3 State", content["state3"], basic)                
if not ( content.state3 == "Unregistered" ) then
html[#html + 1] = ui_helper.createLabel(T"      Username", content["username3"], basic)

if ( content.call3 == "MMPBX_CALLSTATE_IDLE" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Idle", basic)
end

if ( content.call3 == "MMPBX_CALLSTATE_DIALING" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Dialing", basic)
end

if ( content.call3 == "MMPBX_CALLSTATE_CALL_DELIVERED" ) then
html[#html + 1] = ui_helper.createLabel(T"      Call State", T"Delivered/In Progress", basic)
end

end
---------------------------------------------------------------------------------------------------------DECT
if ( content.emission == "true" ) then
html[#html + 1] = ui_helper.createLabel(T"DECT Emission Mode ", T"Enabled", basic)
else 
html[#html + 1] = ui_helper.createLabel(T"DECT Emission Mode ", T"Disabled", basic)
end

html[#html + 1] = ui_helper.createLabel(T"Base Name", content["baseName"], basic)
html[#html + 1] = ui_helper.createLabel(T"Base Code", content["accCode"], basic)




--------------------------------------------------------------------------------------------------------


-- html[#html + 1] = ui_helper.createLabel(T"Max Upstream Rate", content["max_upstream"] .. " kbps", basic)


	
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