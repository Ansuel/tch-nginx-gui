--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"parental-modal.lp", T"Parental Control"},
    {"tod-modal.lp", T"Access Control"},
	{"tod_dnd-modal.lp", T"DoNotDisturb Control"},
}

require("sharedModalTabHelper").createModalTab(items)