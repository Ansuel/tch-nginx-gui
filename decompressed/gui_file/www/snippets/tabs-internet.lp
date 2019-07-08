--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"iproutes-modal.lp", T"IP Extras"},
    {"mwan-modal.lp", T"Routing Policy"},
	{"bridge-grouping-modal.lp", T"Bridge Grouping"},
	{"fast-cache-option-modal.lp", T"Flow Cache"},
	{"dosprotect-modal.lp", T"DoS Protect"},
}

require("sharedModalTabHelper").createModalTab(items)
