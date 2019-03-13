--pretranslated: do not change this file
--www\snippets\tabs-voice.lp
-- Enable localization
gettext.textdomain('webui-voice')
local content_helper = require("web.content_helper")
local ipairs, string = ipairs, string
-- Check availability of file, return true if found, else false
local function file_check(file_name)
  local file_found=io.open(file_name, "r")
  if file_found==nil then
    return false
  else
    return true
  end
end
-- Check asterisk presence
local asterisk_available = file_check("/etc/init.d/asterisk")
if asterisk_available then
	local items = {
		{"mmpbx-global-modal.lp", T"Global"},
		{"mmpbx-dect-modal.lp", T"DECT"},
		{"mmpbx-contacts-modal.lp", T"Phone Book"},
		{"asterisk-profile-modal.lp", T"Asterisk Basic Manager"},
		{"mmpbx-profile-modal.lp", T"Phone Numbers"},
		{"mmpbx-inoutgoingmap-modal.lp", T"In/Out Mapping"},
		{"mmpbx-service-modal.lp", T"Service"},
		{"mmpbx-log-modal.lp", T"Call Log"},
		{"mmpbx-statistics-modal.lp", T"Quality Log"},
		{"mmpbx-sipdevice-modal.lp", T"Sip Device"},
		{"mmpbx-codec-modal.lp", T"Codec"},
	}
else
	local items = {
		{"mmpbx-global-modal.lp", T"Global"},
		{"mmpbx-dect-modal.lp", T"DECT"},
		{"mmpbx-contacts-modal.lp", T"Phone Book"},
		{"mmpbx-profile-modal.lp", T"Phone Numbers"},
		{"mmpbx-inoutgoingmap-modal.lp", T"In/Out Mapping"},
		{"mmpbx-service-modal.lp", T"Service"},
		{"mmpbx-log-modal.lp", T"Call Log"},
		{"mmpbx-statistics-modal.lp", T"Quality Log"},
		{"mmpbx-sipdevice-modal.lp", T"Sip Device"},
		{"mmpbx-codec-modal.lp", T"Codec"},
	}
end
local format = string.format
local datamodel = require ("datamodel")
local mmpbx_state, error = datamodel.get("uci.mmpbx.mmpbx.@global.enabled")

local variant = datamodel.get("uci.env.var.prod_friendly_name")[1].value or ""

if mmpbx_state then
    mmpbx_state = format("%s",mmpbx_state[1].value)
else
    mmpbx_state = "0"
end

-- Retrieving emission state
local emission_content = {
    emission_state = "rpc.mmpbx.dectemission.state",
}
content_helper.getExactContent(emission_content)
emission_state = format("%s", emission_content.emission_state)

local tabs = {}
local session = ngx.ctx.session
if mmpbx_state == "1" then
    for _,v in pairs(items) do
        if session:hasAccess("/modals/" .. v[1]) then
	    if v[1] == "mmpbx-dect-modal.lp" then
		if ( emission_state == "1" ) and 
		( variant == "Technicolor TG799vac" ) or ( variant == "Technicolor TG800vac" )  then
		   tabs[#tabs+1] = v
                end
	    else
            tabs[#tabs+1] = v
	    end
        end
    end
elseif session:hasAccess("/modals/mmpbx-global-modal.lp") then
    tabs[#tabs+1] = {"mmpbx-global-modal.lp", T"Global"}
end


local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

local html = {}

	html[#html+1] = '<ul class="nav nav-tabs">'
	for _,v in ipairs(tabs) do
		local active = ""
		if uri == ("/modals/" .. v[1]) then
			active = "active"
		end
	
		html[#html+1] = string.format('<li class="%s"><a id ="%s" href="#" class="open-modal" data-remote="/modals/%s">%s</a></li>', active, v[2], v[1], v[2])
	end
	html[#html+1] = '</ul>'

ngx.print(html)
