<%
-- NG-78959
local lfs = require("lfs")
if lfs.attributes("/etc/config/mmpbx", "mode") ~= "file" then
  return
end

-- Enable localization

gettext.textdomain('webui-voice')
local tinsert, format = table.insert, string.format
local datamodel = require ("datamodel")
local ui_helper = require ("web.ui_helper")
local content_helper = require ("web.content_helper")
local session = ngx.ctx.session

local switchName = nil
local modalPath = nil
local mmpbx_info = nil

local sipprofile_path = "uci.mmpbxrvsipnet.profile."
local sipprofile_ubus_path = "rpc.mmpbx.profile.@"
local sipprofile_content = content_helper.getMatchedContent(sipprofile_path)
local mmpbx_state, error = datamodel.get("uci.mmpbx.mmpbx.@global.enabled")

if mmpbx_state then
    mmpbx_state = format("%s",mmpbx_state[1].value)
else
    mmpbx_state = "0"
end


if mmpbx_state and mmpbx_state == "1" then
    mmpbx_info = T"Telephony enabled"
else
    mmpbx_info = T"Telephony disabled"
end

local sipprofile_info = {}
local v = {}
for _, v in pairs (sipprofile_content) do
    local name = string.match (v.path, "@([^%.]+)")
    if v.userfriendlyname ~= nil and v.userfriendlyname ~= "" then
        sipprofile_info[name] = v.userfriendlyname
    else
        sipprofile_info[name] = v.uri
    end
end

if mmpbx_state == "1" then
    if session:hasAccess("/modals/mmpbx-global-modal.lp") then
        modalPath = "/modals/mmpbx-global-modal.lp"
    elseif session:hasAccess("/modals/mmpbx-dect-modal.lp") then
        modalPath = "/modals/mmpbx-dect-modal.lp"
    elseif session:hasAccess("mmpbx-contacts-modal.lp") then
        modalPath = "/modals/mmpbx-contacts-modal.lp"
    elseif session:hasAccess("/modals/mmpbx-inoutgoingmap-modal.lp") then
        modalPath = "/modals/mmpbx-inoutgoingmap-modal.lp"		
    end
elseif session:hasAccess("/modals/mmpbx-global-modal.lp") then
    modalPath = "/modals/mmpbx-global-modal.lp"
end

if session:hasAccess("/modals/mmpbx-global-modal.lp") then
	switchName = "mmpbx_enabled"
end

%>

<div class="span3">
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">
    <%
      ngx.print(ui_helper.createCardHeader(T"Telephony", modalPath, switchName, mmpbx_state))
    %>
    <div class="content card_bg" data-bg-text="&#xf095;">
	  <div class="divtable">
	  <%
	  local html = {}
	  tinsert(html, ui_helper.createSimpleLight(mmpbx_state, mmpbx_info, { light = { id =  "Telephony_LEDStatus" }, span = { id =  "Telephony_Status" } },"fa fa-phone"))
	  tinsert (html,[[<p class= "subinfos">]] )
	  local name, value = "", ""
	  local reged, notreged, reging = 0,0,0
	  for name, value in pairs (sipprofile_info) do
	  	local res = datamodel.get (sipprofile_ubus_path..name..".sipRegisterState")
	  	local enYN = datamodel.get (sipprofile_ubus_path..name..".enable")
	  	if (type(res) == "table") then
	  		if (res[1].value == "Registered") then
	  			reged = reged +1
	  		elseif (enYN[1].value == "true") and (res[1].value == "Unregistered") then
	  			notreged = notreged +1
	  		elseif (enYN[1].value == "true") and (res[1].value == "Registering") then
	  			reging = reging +1
	  		end
	  	end
	  end
	  tinsert (html, [[<br/>]])
	  if reged ~= 0 then
	  	tinsert(html, format( N("<strong %s>%d </strong> Registered Account",
	  							"<strong %s>%d </strong> Registered Accounts", reged), 0,
	  							reged))
	  	tinsert (html, [[<br/>]])
	  end
	  if reging ~= 0 then
	  	tinsert(html, format( N("<strong %s>%d </strong> Registering Account",
	  							"<strong %s>%d </strong> Registering Accounts", reging), 0,
	  							reging))
	  	tinsert (html, [[<br/>]])
	  end
	  if notreged ~= 0 then
	  	tinsert(html, format( N("<strong %s>%d </strong> Unregistered Account",
	  							"<strong %s>%d </strong> Unregistered Accounts", notreged), 0,
	  							notreged))
	  	tinsert (html, [[</p>]])
	  end
	  ngx.print (html)
	  %>
	  </div>
    </div>
  </div>
</div>
