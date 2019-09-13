--pretranslated: do not change this file

gettext.textdomain('webui-core')
local proxy = require("datamodel")

local items = {
    {"iproutes-modal.lp", T"IP Extras"},
    {"mwan-modal.lp", T"Routing Policy"},
	{"bridge-grouping-modal.lp", T"Bridge Grouping"}
}
local dosprotect = proxy.get("uci.dosprotect.globals.enabled")
if dosprotect and dosprotect[1].value ~="" then
	table.insert(items, {"dosprotect-modal.lp", T"DoS Protect"})
end
local flowcache = proxy.get("uci.fcctlsettings.state.enabled")
if flowcache and flowcache[1].value ~="" then
	table.insert(items, {"fast-cache-option-modal.lp", T"Flow Cache"})
end

require("sharedModalTabHelper").createModalTab(items)
