--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-voice')

local getProxy = require("datamodel").get
local tinsert = table.insert
local content_helper = require("web.content_helper")

local content = {
	mmpbx_state = "uci.mmpbx.mmpbx.@global.enabled",
	emission_state = "rpc.mmpbx.dectemission.state",
	variant = "uci.env.var.prod_friendly_name",
}
content_helper.getExactContent(content)

local items = {
    {"mmpbx-global-modal.lp", T"Global"},
    {"asterisk-profile-modal.lp", T"Asterisk"}
}

if content.mmpbx_state == "1" then

	if content.emission_state == "1" and 
		variant == "Technicolor TG799vac" or variant == "Technicolor TG800vac" then
		
		tinsert(items, tinsert(items, {"mmpbx-dect-modal.lp", T"DECT"}))
	end
	
	tinsert(items, {"mmpbx-contacts-modal.lp", T"Phone Book"})
    tinsert(items, {"mmpbx-profile-modal.lp", T"Phone Lines"})
	tinsert(items, {"mmpbx-inoutgoingmap-modal.lp", T"In/Out Mapping"})
    tinsert(items, {"mmpbx-service-modal.lp", T"Service"})
    tinsert(items, {"mmpbx-log-modal.lp", T"Call Log"})
    tinsert(items, {"mmpbx-statistics-modal.lp", T"Quality Log"})
	tinsert(items, {"mmpbx-sipdevice-modal.lp", T"SIP Device"})
	tinsert(items, {"mmpbx-codec-modal.lp", T"Codec"})

end

require("sharedModalTabHelper").createModalTab(items)
