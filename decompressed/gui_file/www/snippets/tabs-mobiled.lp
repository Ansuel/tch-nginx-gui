--pretranslated: do not change this file

local utils = require("web.lte-utils")
local device_capabilities = utils.getContent("rpc.mobiled.device.@1.capabilities.")

gettext.textdomain('webui-mobiled')

local items = {
	{"lte-modal.lp", T"Configuration"},
	{"lte-sim.lp", T"SIM"},
	{"lte-doctor.lp", T"LTE Doctor"},
	{"lte-profiles.lp", T"Profiles"}
}

-- #NG-93140 only show in case session has access (Engineer in case of TI)
if device_capabilities.sms_reading == "true" then
	table.insert(items, {"lte-sms.lp", T"SMS"})
end

require("sharedModalTabHelper").createModalTab(items)
